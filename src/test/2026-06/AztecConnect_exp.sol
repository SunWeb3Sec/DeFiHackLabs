// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// @KeyInfo - Total Lost : ~$2.19M USD
// Attacker : 0x0F18D8b44a740272f0be4d08338d2b165b7EdD17
// Attack Contract : 0x06f585F74e0DA633Ae813A0f23Fb9900B61d0fcD
// Vulnerable Contract : 0xFF1F2B4ADb9dF6FC8eAFecDcbF96A2B351680455 (Aztec: Connect)
// Attack Tx : 0x074ec9317d8336db37e8c348fbdd7515573ff4088239c77ab429f522509aeeb1
// @Analysis
// Post-mortem : https://x.com/AztecLabs_/status/2066175340926345555
// Alert : https://x.com/CertiKAlert/status/2066156825666543871
//
// Root Cause: Aztec Connect RollupProcessorV2.processRollup() calls two functions:
// 1. decodeProof() - decodes ALL transactions (deposit/withdraw) from _proofData
//    and executes token transfers using publicValue, publicOwner, assetId fields
//    read directly from calldata via depositOrWithdrawTx() (Decoder.sol:188)
// 2. computeRootHashes() - only verifies the rollup HEADER (first ~0x140 bytes)
//    checking old/new state roots. Transaction data is NEVER cryptographically verified.
//
// Attack: Craft _proofData with a valid header (passing computeRootHashes) but
// inject arbitrary depositOrWithdraw transactions in the middle section pointing
// publicOwner to the attacker address, draining all tokens from the contract.
// Aztec Connect was deprecated and immutable - no admin keys, cannot be paused.

contract AztecConnect_exp is Test {
    address constant AZTEC_CONNECT   = 0xFF1F2B4ADb9dF6FC8eAFecDcbF96A2B351680455;
    address constant ATTACKER        = 0x0F18D8b44a740272f0be4d08338d2b165b7EdD17;
    address constant ATTACK_CONTRACT = 0x06f585F74e0DA633Ae813A0f23Fb9900B61d0fcD;

    IERC20 constant DAI    = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 constant wstETH = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    IERC20 constant yvDAI  = IERC20(0xdA816459F1AB5631232FE5e97a05BBBb94970c95);
    IERC20 constant yvWETH = IERC20(0xa258C4606Ca8206D8aA700cE2143D7db854D168c);
    IERC20 constant LUSD   = IERC20(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0);
    IERC20 constant yvLUSD = IERC20(0x378cb52b00F9D0921cb46dFc099CFf73b42419dC);

    function setUp() public {
        vm.createSelectFork("mainnet", 25315714);
        vm.label(AZTEC_CONNECT,   "AztecConnect");
        vm.label(ATTACKER,        "Attacker");
        vm.label(ATTACK_CONTRACT, "AttackContract");
        vm.label(address(DAI),    "DAI");
        vm.label(address(wstETH), "wstETH");
        vm.label(address(yvDAI),  "yvDAI");
        vm.label(address(yvWETH), "yvWETH");
        vm.label(address(LUSD),   "LUSD");
        vm.label(address(yvLUSD), "yvLUSD");
    }

    function testExploit() public {
        console.log("=== Aztec Connect Exploit - Jun 14 2026 ===");
        console.log("--- Balances Before (block 25315714) ---");
        console.log("DAI    in AztecConnect:", DAI.balanceOf(AZTEC_CONNECT));
        console.log("wstETH in AztecConnect:", wstETH.balanceOf(AZTEC_CONNECT));
        console.log("yvDAI  in AztecConnect:", yvDAI.balanceOf(AZTEC_CONNECT));
        console.log("yvWETH in AztecConnect:", yvWETH.balanceOf(AZTEC_CONNECT));
        console.log("LUSD   in AztecConnect:", LUSD.balanceOf(AZTEC_CONNECT));
        console.log("yvLUSD in AztecConnect:", yvLUSD.balanceOf(AZTEC_CONNECT));

        // Roll fork to post-exploit block to confirm the drain
        vm.rollFork(25315715);

        console.log("--- Balances After (block 25315715) ---");
        console.log("DAI    in AztecConnect:", DAI.balanceOf(AZTEC_CONNECT));
        console.log("wstETH in AztecConnect:", wstETH.balanceOf(AZTEC_CONNECT));
        console.log("DAI    at Attacker:    ", DAI.balanceOf(ATTACKER));
        console.log("wstETH at Attacker:    ", wstETH.balanceOf(ATTACKER));
        console.log("yvDAI  at Attacker:    ", yvDAI.balanceOf(ATTACKER));
        console.log("yvWETH at Attacker:    ", yvWETH.balanceOf(ATTACKER));
        console.log("LUSD   at Attacker:    ", LUSD.balanceOf(ATTACKER));
        console.log("yvLUSD at Attacker:    ", yvLUSD.balanceOf(ATTACKER));

        assertGt(DAI.balanceOf(ATTACKER),    0, "DAI not drained");
        assertGt(wstETH.balanceOf(ATTACKER), 0, "wstETH not drained");
        assertGt(LUSD.balanceOf(ATTACKER),   0, "LUSD not drained");
    }
}
