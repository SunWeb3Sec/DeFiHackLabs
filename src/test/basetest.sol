// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./tokenhelper.sol";
import "forge-std/Test.sol";

contract BaseTestWithBalanceLog is Test {
    //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
    address fundingToken = address(0);

    function getFundingBal() internal view returns (uint256) {
        return fundingToken == address(0) ? address(this).balance : TokenHelper.getTokenBalance(fundingToken, address(this));
    }

    function getFundingDecimals() internal view returns (uint8) {
        return fundingToken == address(0) ? 18 : TokenHelper.getTokenDecimals(fundingToken);
    }

    function getBaseCurrencySymbol() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        console.log(chainId);
        //Eth or ethl2s should have eth as base currency
        if (chainId == 1 || chainId == 10 || chainId == 250 || chainId == 42161  || chainId == 1285 || chainId == 8453) {
            return "ETH";
        }
        else if (chainId == 100) {
            return "XDAI";
        }
        else if (chainId == 56) {
            return "BNB";
        } else if (chainId == 43114) {
            return "AVAX";
        } else if (chainId == 137) {
            return "MATIC";
        } else if (chainId == 42220) {
            return "CELO";
        } else {
            return "ETH";
        }
    }

    modifier balanceLog() {
        //Set eth balance to 0 if eth is funding token as foundry sets a high default balance for contracts unless set
        if (fundingToken == address(0)) vm.deal(address(this), 0);

        string memory tokenSymbol = fundingToken == address(0) ? getBaseCurrencySymbol() : TokenHelper.getTokenSymbol(fundingToken);
        string memory balanceBeforeStr = string(abi.encodePacked("Attacker ", tokenSymbol, " Balance Before exploit"));
        string memory balanceAfterStr = string(abi.encodePacked("Attacker ", tokenSymbol, " Balance After exploit"));

        emit log_named_decimal_uint(balanceBeforeStr, getFundingBal(), getFundingDecimals());
        _;
        emit log_named_decimal_uint(balanceAfterStr, getFundingBal(), getFundingDecimals());
    }
}