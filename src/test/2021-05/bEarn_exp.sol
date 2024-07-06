// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : 11M
// Attacker : https://bscscan.com/address/0x47f341d896b08daacb344d9021f955247e50d089
// Attack Contract : https://bscscan.com/address/0xef39f14213714001456e2e89eddbdf8c850c3be6
// Vulnerable Contract : https://bscscan.com/address/0xb390b07fcf76678089cb12d8e615d5fe494b01fb
// Attack Tx : https://bscscan.com/tx/0x603b2bbe2a7d0877b22531735ff686a7caad866f6c0435c37b7b49e4bfd9a36c

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xb390b07fcf76678089cb12d8e615d5fe494b01fb#code

// @Analysis
// Post-mortem : https://bearndao.medium.com/bvaults-busd-alpaca-strategy-exploit-post-mortem-and-bearn-s-compensation-plan-b0b38c3b5540
// Twitter Guy : 
// Hacking God : 
pragma solidity ^0.8.0;

contract bEarn is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 1_234_567;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(0);
    }

    function testExploit() public balanceLog {
        //implement exploit code here
    }
}
