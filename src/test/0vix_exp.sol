// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1651932529874853888
// https://twitter.com/peckshield/status/1651923235603361793
// https://twitter.com/Mudit__Gupta/status/1651958883634536448
// @TX
// https://polygonscan.com/tx/0x10f2c28f5d6cd8d7b56210b4d5e0cece27e45a30808cd3d3443c05d4275bb008
// @Summary
// VGHSTOracle was donate to manipulate 
// STOP LISTING TOKENS WHOSE PRICE CAN BE MANIPULATED ATOMICALLY
// Cream, Hundred, bZx, Loadstar, bonq.... same exploit

interface IVGHST is IERC20 {
    function enter(uint256 _amount) external returns(uint256);
    function leave(uint256 _amount) external;
}

contract ContractTest is Test {
    IERC20 GHST = IERC20(0x385Eeac5cB85A38A9a07A70c73e0a3271CfB54A7);
    IERC20 USDC = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    IERC20 USDT = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    IVGHST vGHST = IVGHST(0x51195e21BDaE8722B29919db56d95Ef51FaecA6C);
    ICErc20Delegate oUSDT = ICErc20Delegate(0x1372c34acC14F1E8644C72Dad82E3a21C211729f);
    ICErc20Delegate oMATIC = ICErc20Delegate(0xE554E874c9c60E45F1Debd479389C76230ae25A8);
    ICErc20Delegate oWBTC = ICErc20Delegate(0x3B9128Ddd834cE06A60B0eC31CCfB11582d8ee18);
    ICErc20Delegate oDAI = ICErc20Delegate(0x2175110F2936bf630a278660E9B6E4EFa358490A);
    ICErc20Delegate oWETH = ICErc20Delegate(0xb2D9646A1394bf784E376612136B3686e74A325F);
    ICErc20Delegate oUSDC = ICErc20Delegate(0xEBb865Bf286e6eA8aBf5ac97e1b56A76530F3fBe);
    ICErc20Delegate oMATICX = ICErc20Delegate(0xAAcc5108419Ae55Bc3588E759E28016d06ce5F40);
    ICErc20Delegate ostMATIC = ICErc20Delegate(0xDc3C5E5c01817872599e5915999c0dE70722D07f);
    ICErc20Delegate owstWETH = ICErc20Delegate(0xf06edA703C62b9889C75DccDe927b93bde1Ae654);
    ICErc20Delegate ovGHST = ICErc20Delegate(0xE053A4014b50666ED388ab8CbB18D5834de0aB12);
    IUnitroller unitroller = IUnitroller(0x8849f1a0cB6b5D6076aB150546EddEe193754F1C);
    IAaveFlashloan aaveV3 = IAaveFlashloan(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    IAaveFlashloan aaveV2 = IAaveFlashloan(0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf);
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
}

