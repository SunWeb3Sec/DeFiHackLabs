// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IGMXPositionManagerV1 {
    event DecreasePositionReferral(
        address account, uint256 sizeDelta, uint256 marginFeeBasisPoints, bytes32 referralCode, address referrer
    );
    event IncreasePositionReferral(
        address account, uint256 sizeDelta, uint256 marginFeeBasisPoints, bytes32 referralCode, address referrer
    );
    event SetAdmin(address admin);
    event SetDepositFee(uint256 depositFee);
    event SetInLegacyMode(bool inLegacyMode);
    event SetIncreasePositionBufferBps(uint256 increasePositionBufferBps);
    event SetLiquidator(address indexed account, bool isActive);
    event SetMaxGlobalSizes(address[] tokens, uint256[] longSizes, uint256[] shortSizes);
    event SetOrderKeeper(address indexed account, bool isActive);
    event SetPartner(address account, bool isActive);
    event SetReferralStorage(address referralStorage);
    event SetShouldValidateIncreaseOrder(bool shouldValidateIncreaseOrder);
    event WithdrawFees(address token, address receiver, uint256 amount);

    receive() external payable;

    function BASIS_POINTS_DIVISOR() external view returns (uint256);
    function admin() external view returns (address);
    function approve(address _token, address _spender, uint256 _amount) external;
    function decreasePosition(
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver,
        uint256 _price
    ) external;
    function decreasePositionAndSwap(
        address[] memory _path,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver,
        uint256 _price,
        uint256 _minOut
    ) external;
    function decreasePositionAndSwapETH(
        address[] memory _path,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address payable _receiver,
        uint256 _price,
        uint256 _minOut
    ) external;
    function decreasePositionETH(
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address payable _receiver,
        uint256 _price
    ) external;
    function depositFee() external view returns (uint256);
    function executeDecreaseOrder(address _account, uint256 _orderIndex, address payable _feeReceiver) external;
    function executeIncreaseOrder(address _account, uint256 _orderIndex, address payable _feeReceiver) external;
    function executeSwapOrder(address _account, uint256 _orderIndex, address payable _feeReceiver) external;
    function feeReserves(address) external view returns (uint256);
    function gov() external view returns (address);
    function inLegacyMode() external view returns (bool);
    function increasePosition(
        address[] memory _path,
        address _indexToken,
        uint256 _amountIn,
        uint256 _minOut,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _price
    ) external;
    function increasePositionBufferBps() external view returns (uint256);
    function increasePositionETH(
        address[] memory _path,
        address _indexToken,
        uint256 _minOut,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _price
    ) external payable;
    function isLiquidator(address) external view returns (bool);
    function isOrderKeeper(address) external view returns (bool);
    function isPartner(address) external view returns (bool);
    function liquidatePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        bool _isLong,
        address _feeReceiver
    ) external;
    function maxGlobalLongSizes(address) external view returns (uint256);
    function maxGlobalShortSizes(address) external view returns (uint256);
    function orderBook() external view returns (address);
    function referralStorage() external view returns (address);
    function router() external view returns (address);
    function sendValue(address payable _receiver, uint256 _amount) external;
    function setAdmin(address _admin) external;
    function setDepositFee(uint256 _depositFee) external;
    function setGov(address _gov) external;
    function setInLegacyMode(bool _inLegacyMode) external;
    function setIncreasePositionBufferBps(uint256 _increasePositionBufferBps) external;
    function setLiquidator(address _account, bool _isActive) external;
    function setMaxGlobalSizes(address[] memory _tokens, uint256[] memory _longSizes, uint256[] memory _shortSizes)
        external;
    function setOrderKeeper(address _account, bool _isActive) external;
    function setPartner(address _account, bool _isActive) external;
    function setReferralStorage(address _referralStorage) external;
    function setShouldValidateIncreaseOrder(bool _shouldValidateIncreaseOrder) external;
    function shortsTracker() external view returns (address);
    function shouldValidateIncreaseOrder() external view returns (bool);
    function vault() external view returns (address);
    function weth() external view returns (address);
    function withdrawFees(address _token, address _receiver) external;
}
