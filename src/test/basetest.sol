// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./tokenhelper.sol";
import "forge-std/Test.sol";

contract BaseTestWithBalanceLog is Test {
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
        chainIdToInfo[1329] = ChainInfo("SEI", "SEI");
    }

    function getChainSymbol(
        uint256 chainId
    ) internal view returns (string memory symbol) {
        symbol = chainIdToInfo[chainId].symbol;
        if (bytes(symbol).length == 0) symbol = "ETH";
    }

    function _getTokenData(
        address token,
        address account
    ) internal returns (string memory symbol, uint256 balance, uint8 decimals) {
        if (token == address(0)) {
            symbol = getChainSymbol(block.chainid);
            balance = account.balance;
            decimals = 18;
        } else {
            symbol = TokenHelper.getTokenSymbol(token);
            balance = TokenHelper.getTokenBalance(token, account);
            decimals = TokenHelper.getTokenDecimals(token);
        }
    }

    function _logTokenBalance(
        address token,
        address account,
        string memory label
    ) private {
        (string memory symbol, uint256 balance, uint8 decimals) = _getTokenData(token, account);
        emit log_named_decimal_uint(string(abi.encodePacked(label, " ", symbol, " Balance")), balance, decimals);
    }

    modifier balanceLog() virtual {
        if (fundingToken == address(0)) vm.deal(address(this), 0);
        _logTokenBalance(fundingToken, address(this), string(abi.encodePacked("Attacker Before exploit")));
        _;
        _logTokenBalance(fundingToken, address(this), string(abi.encodePacked("Attacker After exploit")));
    }

    function logTokenBalance(
        address token,
        address account,
        string memory label
    ) internal {
        _logTokenBalance(token, account, label);
    }

    function logMultipleTokenBalances(
        address[] memory tokens,
        address account,
        string memory label
    ) internal {
        emit log_string(string(abi.encodePacked("=== ", label, " ===")));
        for (uint256 i = 0; i < tokens.length; i++) {
            _logTokenBalance(tokens[i], account, "");
        }
    }
}
