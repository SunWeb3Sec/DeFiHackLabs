// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IGMXVaultV1 {
    event BuyUSDG(address account, address token, uint256 tokenAmount, uint256 usdgAmount, uint256 feeBasisPoints);
    event ClosePosition(
        bytes32 key,
        uint256 size,
        uint256 collateral,
        uint256 averagePrice,
        uint256 entryFundingRate,
        uint256 reserveAmount,
        int256 realisedPnl
    );
    event CollectMarginFees(address token, uint256 feeUsd, uint256 feeTokens);
    event CollectSwapFees(address token, uint256 feeUsd, uint256 feeTokens);
    event DecreaseGuaranteedUsd(address token, uint256 amount);
    event DecreasePoolAmount(address token, uint256 amount);
    event DecreasePosition(
        bytes32 key,
        address account,
        address collateralToken,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool isLong,
        uint256 price,
        uint256 fee
    );
    event DecreaseReservedAmount(address token, uint256 amount);
    event DecreaseUsdgAmount(address token, uint256 amount);
    event DirectPoolDeposit(address token, uint256 amount);
    event IncreaseGuaranteedUsd(address token, uint256 amount);
    event IncreasePoolAmount(address token, uint256 amount);
    event IncreasePosition(
        bytes32 key,
        address account,
        address collateralToken,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool isLong,
        uint256 price,
        uint256 fee
    );
    event IncreaseReservedAmount(address token, uint256 amount);
    event IncreaseUsdgAmount(address token, uint256 amount);
    event LiquidatePosition(
        bytes32 key,
        address account,
        address collateralToken,
        address indexToken,
        bool isLong,
        uint256 size,
        uint256 collateral,
        uint256 reserveAmount,
        int256 realisedPnl,
        uint256 markPrice
    );
    event SellUSDG(address account, address token, uint256 usdgAmount, uint256 tokenAmount, uint256 feeBasisPoints);
    event Swap(
        address account,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 amountOutAfterFees,
        uint256 feeBasisPoints
    );
    event UpdateFundingRate(address token, uint256 fundingRate);
    event UpdatePnl(bytes32 key, bool hasProfit, uint256 delta);
    event UpdatePosition(
        bytes32 key,
        uint256 size,
        uint256 collateral,
        uint256 averagePrice,
        uint256 entryFundingRate,
        uint256 reserveAmount,
        int256 realisedPnl
    );

    function BASIS_POINTS_DIVISOR() external view returns (uint256);
    function FUNDING_RATE_PRECISION() external view returns (uint256);
    function MAX_FEE_BASIS_POINTS() external view returns (uint256);
    function MAX_FUNDING_RATE_FACTOR() external view returns (uint256);
    function MAX_LIQUIDATION_FEE_USD() external view returns (uint256);
    function MIN_FUNDING_RATE_INTERVAL() external view returns (uint256);
    function MIN_LEVERAGE() external view returns (uint256);
    function PRICE_PRECISION() external view returns (uint256);
    function USDG_DECIMALS() external view returns (uint256);
    function addRouter(address _router) external;
    function adjustForDecimals(uint256 _amount, address _tokenDiv, address _tokenMul) external view returns (uint256);
    function allWhitelistedTokens(uint256) external view returns (address);
    function allWhitelistedTokensLength() external view returns (uint256);
    function approvedRouters(address, address) external view returns (bool);
    function bufferAmounts(address) external view returns (uint256);
    function buyUSDG(address _token, address _receiver) external returns (uint256);
    function clearTokenConfig(address _token) external;
    function cumulativeFundingRates(address) external view returns (uint256);
    function decreasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver
    ) external returns (uint256);
    function directPoolDeposit(address _token) external;
    function errorController() external view returns (address);
    function errors(uint256) external view returns (string memory);
    function feeReserves(address) external view returns (uint256);
    function fundingInterval() external view returns (uint256);
    function fundingRateFactor() external view returns (uint256);
    function getDelta(
        address _indexToken,
        uint256 _size,
        uint256 _averagePrice,
        bool _isLong,
        uint256 _lastIncreasedTime
    ) external view returns (bool, uint256);
    function getFeeBasisPoints(
        address _token,
        uint256 _usdgDelta,
        uint256 _feeBasisPoints,
        uint256 _taxBasisPoints,
        bool _increment
    ) external view returns (uint256);
    function getFundingFee(address _token, uint256 _size, uint256 _entryFundingRate) external view returns (uint256);
    function getGlobalShortDelta(address _token) external view returns (bool, uint256);
    function getMaxPrice(address _token) external view returns (uint256);
    function getMinPrice(address _token) external view returns (uint256);
    function getNextAveragePrice(
        address _indexToken,
        uint256 _size,
        uint256 _averagePrice,
        bool _isLong,
        uint256 _nextPrice,
        uint256 _sizeDelta,
        uint256 _lastIncreasedTime
    ) external view returns (uint256);
    function getNextFundingRate(address _token) external view returns (uint256);
    function getNextGlobalShortAveragePrice(address _indexToken, uint256 _nextPrice, uint256 _sizeDelta)
        external
        view
        returns (uint256);
    function getPosition(address _account, address _collateralToken, address _indexToken, bool _isLong)
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256, bool, uint256);
    function getPositionDelta(address _account, address _collateralToken, address _indexToken, bool _isLong)
        external
        view
        returns (bool, uint256);
    function getPositionFee(uint256 _sizeDelta) external view returns (uint256);
    function getPositionKey(address _account, address _collateralToken, address _indexToken, bool _isLong)
        external
        pure
        returns (bytes32);
    function getPositionLeverage(address _account, address _collateralToken, address _indexToken, bool _isLong)
        external
        view
        returns (uint256);
    function getRedemptionAmount(address _token, uint256 _usdgAmount) external view returns (uint256);
    function getRedemptionCollateral(address _token) external view returns (uint256);
    function getRedemptionCollateralUsd(address _token) external view returns (uint256);
    function getTargetUsdgAmount(address _token) external view returns (uint256);
    function getUtilisation(address _token) external view returns (uint256);
    function globalShortAveragePrices(address) external view returns (uint256);
    function globalShortSizes(address) external view returns (uint256);
    function gov() external view returns (address);
    function guaranteedUsd(address) external view returns (uint256);
    function hasDynamicFees() external view returns (bool);
    function inManagerMode() external view returns (bool);
    function inPrivateLiquidationMode() external view returns (bool);
    function includeAmmPrice() external view returns (bool);
    function increasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _sizeDelta,
        bool _isLong
    ) external;
    function initialize(
        address _router,
        address _usdg,
        address _priceFeed,
        uint256 _liquidationFeeUsd,
        uint256 _fundingRateFactor,
        uint256 _stableFundingRateFactor
    ) external;
    function isInitialized() external view returns (bool);
    function isLeverageEnabled() external view returns (bool);
    function isLiquidator(address) external view returns (bool);
    function isManager(address) external view returns (bool);
    function isSwapEnabled() external view returns (bool);
    function lastFundingTimes(address) external view returns (uint256);
    function liquidatePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        bool _isLong,
        address _feeReceiver
    ) external;
    function liquidationFeeUsd() external view returns (uint256);
    function marginFeeBasisPoints() external view returns (uint256);
    function maxGasPrice() external view returns (uint256);
    function maxLeverage() external view returns (uint256);
    function maxUsdgAmounts(address) external view returns (uint256);
    function minProfitBasisPoints(address) external view returns (uint256);
    function minProfitTime() external view returns (uint256);
    function mintBurnFeeBasisPoints() external view returns (uint256);
    function poolAmounts(address) external view returns (uint256);
    function positions(bytes32)
        external
        view
        returns (
            uint256 size,
            uint256 collateral,
            uint256 averagePrice,
            uint256 entryFundingRate,
            uint256 reserveAmount,
            int256 realisedPnl,
            uint256 lastIncreasedTime
        );
    function priceFeed() external view returns (address);
    function removeRouter(address _router) external;
    function reservedAmounts(address) external view returns (uint256);
    function router() external view returns (address);
    function sellUSDG(address _token, address _receiver) external returns (uint256);
    function setBufferAmount(address _token, uint256 _amount) external;
    function setError(uint256 _errorCode, string memory _error) external;
    function setErrorController(address _errorController) external;
    function setFees(
        uint256 _taxBasisPoints,
        uint256 _stableTaxBasisPoints,
        uint256 _mintBurnFeeBasisPoints,
        uint256 _swapFeeBasisPoints,
        uint256 _stableSwapFeeBasisPoints,
        uint256 _marginFeeBasisPoints,
        uint256 _liquidationFeeUsd,
        uint256 _minProfitTime,
        bool _hasDynamicFees
    ) external;
    function setFundingRate(uint256 _fundingInterval, uint256 _fundingRateFactor, uint256 _stableFundingRateFactor)
        external;
    function setGov(address _gov) external;
    function setInManagerMode(bool _inManagerMode) external;
    function setInPrivateLiquidationMode(bool _inPrivateLiquidationMode) external;
    function setIsLeverageEnabled(bool _isLeverageEnabled) external;
    function setIsSwapEnabled(bool _isSwapEnabled) external;
    function setLiquidator(address _liquidator, bool _isActive) external;
    function setManager(address _manager, bool _isManager) external;
    function setMaxGasPrice(uint256 _maxGasPrice) external;
    function setMaxLeverage(uint256 _maxLeverage) external;
    function setPriceFeed(address _priceFeed) external;
    function setTokenConfig(
        address _token,
        uint256 _tokenDecimals,
        uint256 _tokenWeight,
        uint256 _minProfitBps,
        uint256 _maxUsdgAmount,
        bool _isStable,
        bool _isShortable
    ) external;
    function setUsdgAmount(address _token, uint256 _amount) external;
    function shortableTokens(address) external view returns (bool);
    function stableFundingRateFactor() external view returns (uint256);
    function stableSwapFeeBasisPoints() external view returns (uint256);
    function stableTaxBasisPoints() external view returns (uint256);
    function stableTokens(address) external view returns (bool);
    function swap(address _tokenIn, address _tokenOut, address _receiver) external returns (uint256);
    function swapFeeBasisPoints() external view returns (uint256);
    function taxBasisPoints() external view returns (uint256);
    function tokenBalances(address) external view returns (uint256);
    function tokenDecimals(address) external view returns (uint256);
    function tokenToUsdMin(address _token, uint256 _tokenAmount) external view returns (uint256);
    function tokenWeights(address) external view returns (uint256);
    function totalTokenWeights() external view returns (uint256);
    function updateCumulativeFundingRate(address _token) external;
    function upgradeVault(address _newVault, address _token, uint256 _amount) external;
    function usdToToken(address _token, uint256 _usdAmount, uint256 _price) external view returns (uint256);
    function usdToTokenMax(address _token, uint256 _usdAmount) external view returns (uint256);
    function usdToTokenMin(address _token, uint256 _usdAmount) external view returns (uint256);
    function usdg() external view returns (address);
    function usdgAmounts(address) external view returns (uint256);
    function useSwapPricing() external view returns (bool);
    function validateLiquidation(
        address _account,
        address _collateralToken,
        address _indexToken,
        bool _isLong,
        bool _raise
    ) external view returns (uint256, uint256);
    function whitelistedTokenCount() external view returns (uint256);
    function whitelistedTokens(address) external view returns (bool);
    function withdrawFees(address _token, address _receiver) external returns (uint256);
}
