// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "./interface.sol";

contract ContractTest is DSTest {
  WETH9 weth = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  Uni_Pair_V2 UniswapV2Pair =
    Uni_Pair_V2(0xd3d2E2692501A5c9Ca623199D38826e513033a17);
  CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

  function setUp() public {
    cheats.createSelectFork("mainnet", 15012670); //fork mainnet at block 15012670
  }

  function testExploit() public {
    weth.deposit{ value: 2 ether }();
    Uni_Pair_V2(UniswapV2Pair).swap(0, 100 * 1e18, address(this), "0x00");
  }

  function uniswapV2Call(
    address sender,
    uint256 amount0,
    uint256 amount1,
    bytes calldata data
  ) external {
    emit log_named_uint(
      "After flashswap, WETH balance of attacker:",
      weth.balanceOf(address(this))
    );
    // 0.3% fees
    uint256 fee = ((amount1 * 3) / 997) + 1;
    uint256 amountToRepay = amount1 + fee;
    emit log_named_uint("After flashswap, Amount to repay:", amountToRepay);
    weth.transfer(address(UniswapV2Pair), amountToRepay);
  }

  receive() external payable {}
}
