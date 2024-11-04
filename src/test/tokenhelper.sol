// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

library TokenHelper {
    function callTokenFunction(
        address tokenAddress,
        bytes memory data,
        bool staticCall
    ) private returns (bytes memory) {
        (bool success, bytes memory result) = staticCall ? tokenAddress.staticcall(data) : tokenAddress.call(data);
        require(success, "Failed to call token function");
        return result;
    }

    function getTokenBalance(address tokenAddress, address targetAddress) internal returns (uint256) {
        bytes memory result =
            callTokenFunction(tokenAddress, abi.encodeWithSignature("balanceOf(address)", targetAddress), true);
        return abi.decode(result, (uint256));
    }

    function getTokenDecimals(
        address tokenAddress
    ) internal returns (uint8) {
        bytes memory result = callTokenFunction(tokenAddress, abi.encodeWithSignature("decimals()"), true);
        return abi.decode(result, (uint8));
    }

    function getTokenSymbol(
        address tokenAddress
    ) internal returns (string memory) {
        bytes memory result = callTokenFunction(tokenAddress, abi.encodeWithSignature("symbol()"), true);
        return abi.decode(result, (string));
    }

    function approveToken(address token, address spender, uint256 spendAmount) internal returns (bool) {
        bytes memory result =
            callTokenFunction(token, abi.encodeWithSignature("approve(address,uint256)", spender, spendAmount), false);
        return abi.decode(result, (bool));
    }

    function transferToken(address token, address receiver, uint256 amount) internal returns (bool) {
        bytes memory result =
            callTokenFunction(token, abi.encodeWithSignature("transfer(address,uint256)", receiver, amount), false);
        return abi.decode(result, (bool));
    }
}
