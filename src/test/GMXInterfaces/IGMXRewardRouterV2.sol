// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IGMXRewardRouterV2 {
    event StakeGlp(address account, uint256 amount);
    event StakeGmx(address account, address token, uint256 amount);
    event UnstakeGlp(address account, uint256 amount);
    event UnstakeGmx(address account, address token, uint256 amount);

    receive() external payable;

    function acceptTransfer(address _sender) external;
    function batchCompoundForAccounts(address[] memory _accounts) external;
    function batchStakeGmxForAccount(address[] memory _accounts, uint256[] memory _amounts) external;
    function bnGmx() external view returns (address);
    function bonusGmxTracker() external view returns (address);
    function claim() external;
    function claimEsGmx() external;
    function claimFees() external;
    function compound() external;
    function compoundForAccount(address _account) external;
    function esGmx() external view returns (address);
    function feeGlpTracker() external view returns (address);
    function feeGmxTracker() external view returns (address);
    function glp() external view returns (address);
    function glpManager() external view returns (address);
    function glpVester() external view returns (address);
    function gmx() external view returns (address);
    function gmxVester() external view returns (address);
    function gov() external view returns (address);
    function handleRewards(
        bool _shouldClaimGmx,
        bool _shouldStakeGmx,
        bool _shouldClaimEsGmx,
        bool _shouldStakeEsGmx,
        bool _shouldStakeMultiplierPoints,
        bool _shouldClaimWeth,
        bool _shouldConvertWethToEth
    ) external;
    function initialize(
        address _weth,
        address _gmx,
        address _esGmx,
        address _bnGmx,
        address _glp,
        address _stakedGmxTracker,
        address _bonusGmxTracker,
        address _feeGmxTracker,
        address _feeGlpTracker,
        address _stakedGlpTracker,
        address _glpManager,
        address _gmxVester,
        address _glpVester
    ) external;
    function isInitialized() external view returns (bool);
    function mintAndStakeGlp(address _token, uint256 _amount, uint256 _minUsdg, uint256 _minGlp)
        external
        returns (uint256);
    function mintAndStakeGlpETH(uint256 _minUsdg, uint256 _minGlp) external payable returns (uint256);
    function pendingReceivers(address) external view returns (address);
    function setGov(address _gov) external;
    function signalTransfer(address _receiver) external;
    function stakeEsGmx(uint256 _amount) external;
    function stakeGmx(uint256 _amount) external;
    function stakeGmxForAccount(address _account, uint256 _amount) external;
    function stakedGlpTracker() external view returns (address);
    function stakedGmxTracker() external view returns (address);
    function unstakeAndRedeemGlp(address _tokenOut, uint256 _glpAmount, uint256 _minOut, address _receiver)
        external
        returns (uint256);
    function unstakeAndRedeemGlpETH(uint256 _glpAmount, uint256 _minOut, address payable _receiver)
        external
        returns (uint256);
    function unstakeEsGmx(uint256 _amount) external;
    function unstakeGmx(uint256 _amount) external;
    function weth() external view returns (address);
    function withdrawToken(address _token, address _account, uint256 _amount) external;
}
