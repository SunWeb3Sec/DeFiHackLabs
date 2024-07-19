// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "./../interface.sol";


/**
 * Here's a simple example of a Foundry test that simulates transferring USDC from any user to this contract.  
 */
contract foundryDemo is BaseTestWithBalanceLog {
    address _USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address user = 0x6F17CeBEa98d247afEC682aEE781D23059236E3a;
    IERC20 USDC = IERC20(_USDC);

    receive() external payable {}

    function setUp() public {
        /**
           Create a fork environment
                Specify the chain as Ethereum mainnet
                Specify the block number as: 20272996
         */
        vm.createSelectFork("mainnet", 20272996);
        fundingToken = _USDC;

    }

    function testTransfer() public balanceLog {
        uint256 balanceBefore = USDC.balanceOf(user);
        uint256 amount = 10_000_000;
        vm.prank(user);
        USDC.transfer(address(this), amount);
        uint256 balanceAfter = USDC.balanceOf(user);
        require(balanceBefore - balanceAfter  == amount, "Test fail01!");
        require(USDC.balanceOf(address(this)) == amount, "Test fail02!");
    }
}