// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "./interface.sol";



contract ContractTest is DSTest {
    WETH9 weth = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    Uni_Pair_V2 uniSwapRouter02 = Uni_Pair_V2(0xd3d2E2692501A5c9Ca623199D38826e513033a17);

    function testExploit() public {

        weth.deposit{value: 2 ether}();
        Uni_Pair_V2(uniSwapRouter02).swap(0, 100*1e18, address(this), "0x00");
}

    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external{

       emit log_named_uint("After flashswap, WETH balance of attacker:", weth.balanceOf(address(this)));
       // 0.3% fees
       uint fee = ((amount1 * 3) / 997) + 1;
       uint amountToRepay = amount1 + fee;
       emit log_named_uint("After flashswap, Amount to repay:", amountToRepay);
       weth.transfer(address(uniSwapRouter02),amountToRepay);
    }
  receive() external payable {}
}