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
        chainIdToInfo[238] = ChainInfo("BLAST", "ETH");
        chainIdToInfo[10] = ChainInfo("OPTIMISM", "ETH");
        chainIdToInfo[250] = ChainInfo("FANTOM", "FTM");
        chainIdToInfo[42_161] = ChainInfo("ARBITRUM", "ETH");
        chainIdToInfo[56] = ChainInfo("BSC", "BNB");
        chainIdToInfo[1285] = ChainInfo("MOONRIVER", "MOVR");
        chainIdToInfo[100] = ChainInfo("GNOSIS", "XDAI");
        chainIdToInfo[43_114] = ChainInfo("AVALANCHE", "AVAX");
        chainIdToInfo[137] = ChainInfo("POLYGON", "MATIC");
        chainIdToInfo[42_220] = ChainInfo("CELO", "CELO");
        chainIdToInfo[8453] = ChainInfo("BASE", "ETH");
    }

    function getChainInfo(uint256 chainId) internal view returns (string memory, string memory) {
        ChainInfo storage info = chainIdToInfo[chainId];
        return (info.name, info.symbol);
    }

    function getChainSymbol(uint256 chainId) internal view returns (string memory symbol) {
        (, symbol) = getChainInfo(chainId);
        //Return eth as default if chainid is not registed in mapping
        // Return eth as default if chainid is not registered in mapping
        if (bytes(symbol).length == 0) {
            symbol = "ETH";
        }
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
        string memory chainSymbol = getChainSymbol(block.chainid);
        return fundingToken == address(0) ? chainSymbol : TokenHelper.getTokenSymbol(fundingToken);
    }

    modifier balanceLog() {
        if (fundingToken == address(0)) vm.deal(address(this), 0);
        logBalance("Before");
        _;
        logBalance("After");
    }

    function logBalance(string memory stage) private {
        emit log_named_decimal_uint(
            string(abi.encodePacked("Attacker ", getBaseCurrencySymbol(), " Balance ", stage, " exploit")),
            getFundingBal(),
            getFundingDecimals()
        );
    }
}