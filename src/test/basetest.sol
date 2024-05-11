// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./tokenhelper.sol";
import "forge-std/Test.sol";

contract BaseTestWithBalanceLog is Test {
    //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
    address fundingToken = address(0);

    function getFundingBal() internal view returns (uint256) {
        return fundingToken == address(0)
            ? address(this).balance
            : TokenHelper.getTokenBalance(fundingToken, address(this));
    }

    function getFundingDecimals() internal view returns (uint8) {
        return fundingToken == address(0) ? 18 : TokenHelper.getTokenDecimals(fundingToken);
    }

    modifier balanceLog() {
        //Set eth balance to 0 if eth  is funding token as foundry sets a high default balance for contracts unless set
        if (fundingToken == address(0)) vm.deal(address(this), 0);
        emit log_named_decimal_uint("Attacker ETH Balance Before exploit", getFundingBal(), getFundingDecimals());
        _;
        emit log_named_decimal_uint("Attacker ETH Balance After exploit", getFundingBal(), getFundingDecimals());
    }
}