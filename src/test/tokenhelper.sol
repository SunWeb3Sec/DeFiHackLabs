// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

library TokenHelper {
    function callTokenFunction(address tokenAddress, bytes memory data) private view returns (bytes memory) {
        (bool success, bytes memory result) = tokenAddress.staticcall(data);
        require(success, "Failed to call token function");
        return result;
    }

    function getTokenBalance(address tokenAddress, address targetAddress) internal view returns (uint256) {
        bytes memory result =
            callTokenFunction(tokenAddress, abi.encodeWithSignature("balanceOf(address)", targetAddress));
        return abi.decode(result, (uint256));
    }

    function getTokenDecimals(address tokenAddress) internal view returns (uint8) {
        bytes memory result = callTokenFunction(tokenAddress, abi.encodeWithSignature("decimals()"));
        return abi.decode(result, (uint8));
    }

    function getTokenSymbol(address tokenAddress) internal view returns (string memory) {
        bytes memory result = callTokenFunction(tokenAddress, abi.encodeWithSignature("symbol()"));
        return abi.decode(result, (string));
    }
}