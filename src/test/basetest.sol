// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./tokenhelper.sol";
import "forge-std/Test.sol";

contract BaseTestWithBalanceLog is Test {
    //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
    address fundingToken = address(0);

    struct ChainInfo {
        string name;
        string symbol;
    }

    mapping(uint256 => ChainInfo) private chainIdToInfo;

    constructor() {
        chainIdToInfo[1] = ChainInfo("MAINNET", "ETH");
        chainIdToInfo[10] = ChainInfo("OPTIMISM", "ETH");
        chainIdToInfo[56] = ChainInfo("BSC", "BNB");
        chainIdToInfo[100] = ChainInfo("XDAI", "XDAI");
        chainIdToInfo[137] = ChainInfo("POLYGON", "MATIC");
        chainIdToInfo[250] = ChainInfo("FANTOM", "FTM");
        chainIdToInfo[42161] = ChainInfo("ARBITRUM", "ETH");
        chainIdToInfo[43114] = ChainInfo("AVALANCHE", "AVAX");
        chainIdToInfo[42220] = ChainInfo("CELO", "CELO");
        chainIdToInfo[1285] = ChainInfo("MOONRIVER", "MOVR");
        chainIdToInfo[8453] = ChainInfo("BASE", "ETH");
    }

    function getChainInfo(uint256 chainId) internal view returns (string memory, string memory) {
        ChainInfo storage info = chainIdToInfo[chainId];
        return (info.name, info.symbol);
    }

    function getChainSymbol(uint256 chainId) internal view returns (string memory symbol) {
        (, symbol) = getChainInfo(chainId);
    }

    function getFundingBal() internal view returns (uint256) {
        return fundingToken == address(0)
            ? address(this).balance
            : TokenHelper.getTokenBalance(fundingToken, address(this));
    }

    function getFundingDecimals() internal view returns (uint8) {
        return fundingToken == address(0) ? 18 : TokenHelper.getTokenDecimals(fundingToken);
    }

    function getBaseCurrencySymbol() internal view returns (string memory) {
        return getChainSymbol(block.chainid);
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
