// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IGMXRouter {
    event Swap(address account, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    receive() external payable;

    function addPlugin(address _plugin) external;
    function approvePlugin(address _plugin) external;
    function approvedPlugins(address, address) external view returns (bool);
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
    function denyPlugin(address _plugin) external;
    function directPoolDeposit(address _token, uint256 _amount) external;
    function gov() external view returns (address);
    function increasePosition(
        address[] memory _path,
        address _indexToken,
        uint256 _amountIn,
        uint256 _minOut,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _price
    ) external;
    function increasePositionETH(
        address[] memory _path,
        address _indexToken,
        uint256 _minOut,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _price
    ) external payable;
    function pluginDecreasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver
    ) external returns (uint256);
    function pluginIncreasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _sizeDelta,
        bool _isLong
    ) external;
    function pluginTransfer(address _token, address _account, address _receiver, uint256 _amount) external;
    function plugins(address) external view returns (bool);
    function removePlugin(address _plugin) external;
    function setGov(address _gov) external;
    function swap(address[] memory _path, uint256 _amountIn, uint256 _minOut, address _receiver) external;
    function swapETHToTokens(address[] memory _path, uint256 _minOut, address _receiver) external payable;
    function swapTokensToETH(address[] memory _path, uint256 _amountIn, uint256 _minOut, address payable _receiver)
        external;
    function usdg() external view returns (address);
    function vault() external view returns (address);
    function weth() external view returns (address);
}
