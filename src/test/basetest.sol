// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./tokenhelper.sol";
import "forge-std/Test.sol";

// Base contract for DeFi exploit POCs. Inherit from this instead of Test directly.
// Provides before/after balance logging via the `balanceLog` modifier.
//
// Single-asset mode (default):
//   Set `fundingToken` to the token you profit in (address(0) = native ETH/chain coin).
//   The `balanceLog` modifier logs that one token before and after testExploit().
//
// Multi-asset mode:
//   Set `multiAssetLog = true` and populate `fundingTokens` with every token you want tracked.
//   The same `balanceLog` modifier will log all of them. No override needed.
//   Optionally set `attacker` to log a different address (e.g. a separate profit contract).
//   If `attacker` is left as address(0), it resolves to address(this).
contract BaseTestWithBalanceLog is Test {
    // Single-asset mode: the token to log profit in. address(0) = native coin.
    address fundingToken = address(0);
    // Multi-asset mode: full list of tokens to track (ERC-20 or address(0) for native).
    address[] fundingTokens;
    // Set to true to enable multi-asset logging via fundingTokens[].
    bool multiAssetLog = false;
    // Address whose balances are logged. Defaults to address(this) when left as address(0).
    address attacker;

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

    function _attacker() private view returns (address) {
        return attacker == address(0) ? address(this) : attacker;
    }

    modifier balanceLog() virtual {
        if (multiAssetLog) {
            if (fundingToken == address(0)) vm.deal(_attacker(), 0);
            _logMultiAssetBalances("Before exploit");
        } else {
            if (fundingToken == address(0)) vm.deal(_attacker(), 0);
            _logTokenBalance(fundingToken, _attacker(), "Attacker Before exploit");
        }
        _;
        if (multiAssetLog) {
            _logMultiAssetBalances("After exploit");
        } else {
            _logTokenBalance(fundingToken, _attacker(), "Attacker After exploit");
        }
    }

    modifier balanceLog2(address target) virtual {
        if (fundingToken == address(0)) vm.deal(target, 0);
        _logTokenBalance(fundingToken, target, string(abi.encodePacked("Attacker Before exploit")));
        _;
        _logTokenBalance(fundingToken, target, string(abi.encodePacked("Attacker After exploit")));
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

    function _addFundingToken(address token) internal {
        fundingTokens.push(token);
    }

    function _addFundingTokens(address[] memory tokens) internal {
        for (uint256 i = 0; i < tokens.length; i++) {
            fundingTokens.push(tokens[i]);
        }
    }

    function _logMultiAssetBalances(string memory label) internal {
        logMultipleTokenBalances(fundingTokens, _attacker(), label);
    }
}
